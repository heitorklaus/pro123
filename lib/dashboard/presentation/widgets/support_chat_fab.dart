import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../settings/data/services/system_settings_service.dart';
import 'audio_bytes_helper_stub.dart'
    if (dart.library.io) 'audio_bytes_helper_io.dart';

/// Botão flutuante + Dialog de Chat em Tempo Real com suporte a Texto, Imagem e Áudio
/// (Vídeos são bloqueados; usuários comuns respeitam a cota diária em MB definida no Painel Master).
class SupportChatFab extends StatelessWidget {
  final UserModel currentUser;

  const SupportChatFab({super.key, required this.currentUser});

  String get _ticketCode {
    final clean = currentUser.uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix =
        (clean.length >= 5 ? clean.substring(0, 5) : clean).toUpperCase();
    return '#C$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final chatDocRef = FirebaseFirestore.instance
        .collection('support_chats')
        .doc(currentUser.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: chatDocRef.snapshots(),
      builder: (context, snap) {
        final unread =
            (snap.data?.data()?['unreadByUser'] as num?)?.toInt() ?? 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openChatDialog(context),
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Suporte',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openChatDialog(BuildContext context) {
    FirebaseFirestore.instance
        .collection('support_chats')
        .doc(currentUser.uid)
        .set({'unreadByUser': 0}, SetOptions(merge: true));

    showDialog(
      context: context,
      builder: (ctx) => _SupportChatDialog(
        currentUser: currentUser,
        ticketCode: _ticketCode,
      ),
    );
  }
}

class _SupportChatDialog extends StatefulWidget {
  final UserModel currentUser;
  final String ticketCode;

  const _SupportChatDialog({
    required this.currentUser,
    required this.ticketCode,
  });

  @override
  State<_SupportChatDialog> createState() => _SupportChatDialogState();
}

class _SupportChatDialogState extends State<_SupportChatDialog> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _sending = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  static const Set<String> _allowedImageExts = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif'
  };
  static const int _maxSingleFileBytes = 5 * 1024 * 1024; // 5 MB por arquivo

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<bool> _checkMediaQuota(int incomingBytes) async {
    if (incomingBytes > _maxSingleFileBytes) {
      _showError('Arquivo muito grande. O limite máximo por envio é 5 MB.');
      return false;
    }
    if (widget.currentUser.isSuperAdmin) return true;

    final cfg = await SystemSettingsService.getGlobalConfig();
    final limitBytes = (cfg.supportDailyMediaLimitMb * 1024 * 1024).round();
    if (limitBytes <= 0) return true;

    final snap = await FirebaseFirestore.instance
        .collection('support_chats')
        .doc(widget.currentUser.uid)
        .get();
    final data = snap.data() ?? {};
    final sameDay = data['todayMediaDate'] == _todayStr;
    final usedBytes =
        sameDay ? ((data['todayMediaBytes'] as num?)?.toInt() ?? 0) : 0;

    if (usedBytes + incomingBytes > limitBytes) {
      final usedMb = (usedBytes / (1024 * 1024)).toStringAsFixed(2);
      final limitMb = cfg.supportDailyMediaLimitMb.toStringAsFixed(0);
      _showError(
        'Limite diário de mídia atingido ($usedMb MB / $limitMb MB). Envie apenas texto ou aguarde a renovação amanhã.',
      );
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 180), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({
    String? customText,
    String mediaType = 'text',
    String? mediaUrl,
    int mediaSizeBytes = 0,
  }) async {
    final text = (customText ?? _msgCtrl.text).trim();
    if (text.isEmpty && mediaUrl == null) return;
    if (_sending) return;

    setState(() => _sending = true);
    if (customText == null) _msgCtrl.clear();

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(widget.currentUser.uid);

      final userName = widget.currentUser.name.trim().isNotEmpty
          ? widget.currentUser.name.trim()
          : widget.currentUser.email;

      int nextMediaBytes = 0;
      if (mediaSizeBytes > 0) {
        final prevSnap = await chatRef.get();
        final prevData = prevSnap.data() ?? {};
        final sameDay = prevData['todayMediaDate'] == _todayStr;
        final prevUsed =
            sameDay ? ((prevData['todayMediaBytes'] as num?)?.toInt() ?? 0) : 0;
        nextMediaBytes = prevUsed + mediaSizeBytes;
      }

      final previewLabel = mediaType == 'image'
          ? '📷 [Imagem]'
          : (mediaType == 'audio' ? '🎙️ [Áudio]' : text);

      await chatRef.set({
        'userId': widget.currentUser.uid,
        'userName': userName,
        'userEmail': widget.currentUser.email,
        'userPhone': widget.currentUser.phone ?? '',
        'companyId': widget.currentUser.effectiveCompanyId,
        'ticketCode': widget.ticketCode,
        'lastMessage': previewLabel,
        'lastSenderRole': 'user',
        'lastMediaType': mediaType,
        'lastMediaUrl': mediaUrl,
        'pendingWhatsappPush': true,
        'unreadByAdmin': FieldValue.increment(1),
        'unreadByUser': 0,
        if (mediaSizeBytes > 0) ...{
          'todayMediaDate': _todayStr,
          'todayMediaBytes': nextMediaBytes,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderId': widget.currentUser.uid,
        'senderName': userName,
        'senderRole': 'user',
        'text': text,
        'mediaType': mediaType,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaSizeBytes > 0) 'mediaSizeBytes': mediaSizeBytes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      _showError('Erro ao enviar mensagem: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendInlineMedia({
    required Uint8List bytes,
    required String contentType,
    required String mediaType,
    required String ext,
    required String text,
  }) async {
    final chatRef = FirebaseFirestore.instance
        .collection('support_chats')
        .doc(widget.currentUser.uid);

    final userName = widget.currentUser.name.trim().isNotEmpty
        ? widget.currentUser.name.trim()
        : widget.currentUser.email;

    final prevSnap = await chatRef.get();
    final prevData = prevSnap.data() ?? {};
    final sameDay = prevData['todayMediaDate'] == _todayStr;
    final prevUsed =
        sameDay ? ((prevData['todayMediaBytes'] as num?)?.toInt() ?? 0) : 0;
    final nextMediaBytes = prevUsed + bytes.length;
    final b64 = base64Encode(bytes);

    await chatRef.set({
      'userId': widget.currentUser.uid,
      'userName': userName,
      'userEmail': widget.currentUser.email,
      'userPhone': widget.currentUser.phone ?? '',
      'companyId': widget.currentUser.effectiveCompanyId,
      'ticketCode': widget.ticketCode,
      'lastMessage': mediaType == 'audio' ? '🎙️ [Áudio]' : '📷 [Imagem]',
      'lastSenderRole': 'user',
      'lastMediaType': mediaType,
      'lastMediaUrl': null,
      'lastMediaBase64': b64,
      'lastMediaContentType': contentType,
      'lastMediaExt': ext,
      'pendingWhatsappPush': true,
      'unreadByAdmin': FieldValue.increment(1),
      'unreadByUser': 0,
      'todayMediaDate': _todayStr,
      'todayMediaBytes': nextMediaBytes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      'senderId': widget.currentUser.uid,
      'senderName': userName,
      'senderRole': 'user',
      'text': text,
      'mediaType': mediaType,
      'mediaBase64': b64,
      'mediaSizeBytes': bytes.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickAndSendImage() async {
    if (_sending || _isRecording) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedImageExts.toList(),
      );
      if (files.isEmpty) return;

      final file = files.first;
      final ext = (file.extension ?? '').toLowerCase();
      if (!_allowedImageExts.contains(ext)) {
        _showError(
            'Apenas imagens (JPG, PNG, WEBP) são permitidas. Vídeos não são aceitos.');
        return;
      }

      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        if (file.path != null && !kIsWeb) {
          bytes = await readLocalAudioBytes(file.path!);
        }
      }
      if (bytes == null || bytes.isEmpty) return;

      final allowed = await _checkMediaQuota(bytes.length);
      if (!allowed) return;

      setState(() => _sending = true);
      var uploadBytes = bytes;
      var uploadExt = ext;
      var contentType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

      // Comprime imagens grandes (> 450 KB) para JPEG leve e nítido
      if (uploadBytes.length > 450 * 1024) {
        final decoded = img.decodeImage(uploadBytes);
        if (decoded != null) {
          final resized = decoded.width > 1280
              ? img.copyResize(decoded, width: 1280)
              : decoded;
          uploadBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
          uploadExt = 'jpg';
          contentType = 'image/jpeg';
        }
      }

      if (kIsWeb && uploadBytes.length <= 700 * 1024) {
        await _sendInlineMedia(
          bytes: uploadBytes,
          contentType: contentType,
          mediaType: 'image',
          ext: uploadExt,
          text: '📷 Imagem enviada',
        );
        if (mounted) setState(() => _sending = false);
        _scrollToBottom();
        return;
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('support_chats/${widget.currentUser.uid}/img_$ts.$uploadExt');
      await ref
          .putData(uploadBytes, SettableMetadata(contentType: contentType))
          .timeout(const Duration(seconds: 12));
      final url = await ref.getDownloadURL().timeout(const Duration(seconds: 8));

      setState(() => _sending = false);
      await _sendMessage(
        customText: '📷 Imagem enviada',
        mediaType: 'image',
        mediaUrl: url,
        mediaSizeBytes: uploadBytes.length,
      );
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      _showError('Falha ao enviar imagem: $e');
    }
  }

  Future<void> _toggleAudioRecording() async {
    if (_sending) return;
    if (!_isRecording) {
      try {
        final hasPerm = await _audioRecorder.hasPermission();
        if (!hasPerm) {
          _showError('Permissão de microfone negada no navegador/aparelho.');
          return;
        }
        final path = kIsWeb
            ? ''
            : '${DateTime.now().millisecondsSinceEpoch}_support_audio.m4a';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: 64000,
            sampleRate: 48000,
          ),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
        });
        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _recordSeconds++);
          if (_recordSeconds >= 120) {
            _toggleAudioRecording(); // Limite de segurança de 2 min
          }
        });
      } catch (e) {
        _showError('Não foi possível iniciar o microfone: $e');
      }
    } else {
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
        _sending = true;
      });
      try {
        final recordedPath = await _audioRecorder.stop();
        if (recordedPath == null || recordedPath.isEmpty) {
          setState(() => _sending = false);
          return;
        }

        Uint8List bytes;
        if (kIsWeb) {
          final res = await http.get(Uri.parse(recordedPath));
          bytes = res.bodyBytes;
        } else {
          bytes = await readLocalAudioBytes(recordedPath);
        }
        if (bytes.isEmpty) {
          setState(() => _sending = false);
          return;
        }

        setState(() => _sending = false);
        final allowed = await _checkMediaQuota(bytes.length);
        if (!allowed) return;

        setState(() => _sending = true);
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ext = kIsWeb ? 'webm' : 'ogg';
        final mime = kIsWeb ? 'audio/webm' : 'audio/ogg';
        if (kIsWeb && bytes.length <= 700 * 1024) {
          await _sendInlineMedia(
            bytes: bytes,
            contentType: mime,
            mediaType: 'audio',
            ext: ext,
            text: '🎙️ Áudio (${_recordSeconds}s)',
          );
          if (mounted) setState(() => _sending = false);
          _scrollToBottom();
          return;
        }

        final ref = FirebaseStorage.instance
            .ref('support_chats/${widget.currentUser.uid}/aud_$ts.$ext');
        await ref
            .putData(bytes, SettableMetadata(contentType: mime))
            .timeout(const Duration(seconds: 12));
        final url = await ref.getDownloadURL().timeout(const Duration(seconds: 8));

        setState(() => _sending = false);
        await _sendMessage(
          customText: '🎙️ Áudio (${_recordSeconds}s)',
          mediaType: 'audio',
          mediaUrl: url,
          mediaSizeBytes: bytes.length,
        );
      } catch (e) {
        if (mounted) setState(() => _sending = false);
        _showError('Erro ao enviar áudio: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messagesStream = FirebaseFirestore.instance
        .collection('support_chats')
        .doc(widget.currentUser.uid)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(60)
        .snapshots();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 430,
        height: 560,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atendimento & Suporte TAOS',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Protocolo ${widget.ticketCode} • Texto, Imagem e Áudio',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Mensagens em tempo real
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: messagesStream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Envie sua dúvida por texto, foto ou áudio! Nossa equipe responde em tempo real por aqui.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(14),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final isUser = d['senderRole'] == 'user';
                      final text = (d['text'] ?? '').toString();
                      final mediaType = (d['mediaType'] ?? 'text').toString();
                      final mediaUrl = d['mediaUrl'] as String?;
                      final mediaBase64 = d['mediaBase64'] as String?;
                      final ts = (d['createdAt'] as Timestamp?)?.toDate();
                      final timeStr =
                          ts != null ? DateFormat('HH:mm').format(ts) : '';

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 9),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF6366F1)
                                : (isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                Text(
                                  (d['senderName'] ?? 'Suporte TAOS')
                                      .toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 3),
                              ],
                              if (mediaType == 'image' &&
                                  (mediaUrl != null || mediaBase64 != null)) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: mediaBase64 != null
                                      ? Image.memory(
                                          base64Decode(mediaBase64),
                                          width: 240,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.broken_image_outlined),
                                        )
                                      : Image.network(
                                          mediaUrl!,
                                          width: 240,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.broken_image_outlined),
                                        ),
                                ),
                                const SizedBox(height: 6),
                              ] else if (mediaType == 'audio' &&
                                  (mediaUrl != null || mediaBase64 != null)) ...[
                                _AudioBubblePlayer(
                                  url: mediaUrl,
                                  base64Data: mediaBase64,
                                  isUser: isUser,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (text.isNotEmpty &&
                                  !(mediaType == 'image' &&
                                      text == '📷 Imagem enviada'))
                                Text(
                                  text,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isUser
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                  ),
                                ),
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    timeStr,
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      color: isUser
                                          ? Colors.white70
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Barra de entrada: Imagem + Microfone + Texto + Enviar
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Enviar Imagem (vídeos bloqueados)',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 34, minHeight: 34),
                    onPressed:
                        (_sending || _isRecording) ? null : _pickAndSendImage,
                    icon: const Icon(Icons.image_outlined,
                        color: Color(0xFF6366F1), size: 20),
                  ),
                  IconButton(
                    tooltip:
                        _isRecording ? 'Parar e enviar áudio' : 'Gravar áudio',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 34, minHeight: 34),
                    onPressed: _sending ? null : _toggleAudioRecording,
                    icon: Icon(
                      _isRecording
                          ? Icons.stop_circle_rounded
                          : Icons.mic_rounded,
                      color: _isRecording
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _isRecording
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '🔴 Gravando áudio... ${_recordSeconds}s (toque no Stop ou Enviar)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          )
                        : TextField(
                            controller: _msgCtrl,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Digite sua mensagem...',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _isRecording ? 'Parar e enviar áudio' : 'Enviar',
                    onPressed: _sending
                        ? null
                        : (_isRecording
                            ? _toggleAudioRecording
                            : () => _sendMessage()),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBubblePlayer extends StatefulWidget {
  final String? url;
  final String? base64Data;
  final bool isUser;
  final bool isDark;

  const _AudioBubblePlayer({
    this.url,
    this.base64Data,
    required this.isUser,
    required this.isDark,
  });

  @override
  State<_AudioBubblePlayer> createState() => _AudioBubblePlayerState();
}

class _AudioBubblePlayerState extends State<_AudioBubblePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else if (widget.base64Data != null) {
      await _player.play(BytesSource(base64Decode(widget.base64Data!)));
    } else if (widget.url != null) {
      await _player.play(UrlSource(widget.url!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isUser
        ? Colors.white
        : (widget.isDark ? Colors.white : const Color(0xFF0F172A));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _toggle,
          icon: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: fg,
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _playing ? 'Reproduzindo áudio...' : 'Ouvir áudio',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    );
  }
}
