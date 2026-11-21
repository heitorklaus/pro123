import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../settings/data/services/ai_usage_telemetry_service.dart';
import '../../../settings/data/services/system_settings_service.dart';
import 'audio_bytes_helper_stub.dart'
    if (dart.library.io) 'audio_bytes_helper_io.dart';
import 'faq_help_dialog.dart';

/// Botão flutuante + Dialog de Chat em Tempo Real com suporte a Texto, Imagem e Áudio
/// (Vídeos são bloqueados; usuários comuns respeitam a cota diária em MB definida no Painel Master).
class SupportChatFab extends StatefulWidget {
  final UserModel currentUser;

  const SupportChatFab({super.key, required this.currentUser});

  @override
  State<SupportChatFab> createState() => _SupportChatFabState();
}

class _SupportChatFabState extends State<SupportChatFab> {
  bool _menuExpanded = false;
  bool _isDialogOpen = false;
  OverlayEntry? _floatingEntry;
  Offset? _floatingOffset;
  Size _floatingSize = const Size(410, 520);
  int _lastHandledUnread = 0;
  Timestamp? _lastHandledUpdatedAt;

  bool get _isChatOpen => _isDialogOpen || _floatingEntry != null;

  @override
  void dispose() {
    _floatingEntry?.remove();
    _floatingEntry = null;
    super.dispose();
  }

  String get _ticketCode {
    final clean =
        widget.currentUser.uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix =
        (clean.length >= 5 ? clean.substring(0, 5) : clean).toUpperCase();
    return '#C$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final chatDocRef = FirebaseFirestore.instance
        .collection('support_chats')
        .doc(widget.currentUser.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: chatDocRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final unread = (data?['unreadByUser'] as num?)?.toInt() ?? 0;
        final updatedAt = data?['updatedAt'] as Timestamp?;

        if (unread > 0) {
          if (_isChatOpen) {
            chatDocRef.set({'unreadByUser': 0}, SetOptions(merge: true));
          } else if (updatedAt != _lastHandledUpdatedAt ||
              unread > _lastHandledUnread) {
            _lastHandledUpdatedAt = updatedAt;
            _lastHandledUnread = unread;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isChatOpen) {
                _openChatDialog(context);
              }
            });
          }
        } else {
          _lastHandledUnread = 0;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_menuExpanded) ...[
              _SupportSpeedDialButton(
                icon: Icons.help_outline_rounded,
                label: 'Perguntas Frequentes',
                color: const Color(0xFF6366F1),
                onTap: () {
                  setState(() => _menuExpanded = false);
                  showDialog(
                    context: context,
                    builder: (_) => const FaqHelpDialog(),
                  );
                },
              ),
              const SizedBox(height: 8),
              _SupportSpeedDialButton(
                icon: Icons.chat_rounded,
                label: 'Chat com Suporte',
                color: const Color(0xFF10B981),
                unreadCount: unread,
                onTap: () {
                  setState(() => _menuExpanded = false);
                  _openChatDialog(context);
                },
              ),
              const SizedBox(height: 10),
            ],
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _menuExpanded = !_menuExpanded),
                borderRadius: BorderRadius.circular(28),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Icon(
                        _menuExpanded
                            ? Icons.close_rounded
                            : Icons.support_agent_rounded,
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
                      if (unread > 0 && !_menuExpanded) ...[
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
            ),
          ],
        );
      },
    );
  }

  void _markRead() {
    FirebaseFirestore.instance
        .collection('support_chats')
        .doc(widget.currentUser.uid)
        .set({'unreadByUser': 0}, SetOptions(merge: true));
  }

  void _openChatDialog(BuildContext context) {
    if (_isChatOpen) {
      if (_floatingEntry != null) return;
      return;
    }
    _isDialogOpen = true;
    _markRead();

    showDialog(
      context: context,
      builder: (ctx) => _SupportChatDialog(
        currentUser: widget.currentUser,
        ticketCode: _ticketCode,
        isFloating: false,
        onToggleFloating: () {
          Navigator.of(ctx).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openFloatingChat();
          });
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    ).whenComplete(() {
      if (mounted) _isDialogOpen = false;
    });
  }

  void _closeFloatingChat() {
    _floatingEntry?.remove();
    _floatingEntry = null;
    if (mounted) setState(() {});
  }

  void _openFloatingChat() {
    if (_floatingEntry != null || !mounted) return;
    _markRead();

    final screenSize = MediaQuery.of(context).size;
    final maxW = (screenSize.width - 24).clamp(320.0, 760.0);
    final maxH = (screenSize.height - 24).clamp(380.0, 820.0);
    _floatingSize = Size(
      _floatingSize.width.clamp(320.0, maxW),
      _floatingSize.height.clamp(380.0, maxH),
    );
    _floatingOffset ??= Offset(
      (screenSize.width - _floatingSize.width - 24)
          .clamp(12.0, screenSize.width - _floatingSize.width - 12),
      (screenSize.height - _floatingSize.height - 84)
          .clamp(12.0, screenSize.height - _floatingSize.height - 12),
    );

    _floatingEntry = OverlayEntry(
      builder: (overlayCtx) {
        final s = MediaQuery.of(overlayCtx).size;
        final w = _floatingSize.width.clamp(320.0, (s.width - 24).clamp(320.0, 820.0));
        final h = _floatingSize.height.clamp(380.0, (s.height - 24).clamp(380.0, 860.0));
        final left = (_floatingOffset?.dx ?? 24.0)
            .clamp(8.0, (s.width - w - 8).clamp(8.0, s.width));
        final top = (_floatingOffset?.dy ?? 24.0)
            .clamp(8.0, (s.height - h - 8).clamp(8.0, s.height));

        return Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: _SupportChatDialog(
            currentUser: widget.currentUser,
            ticketCode: _ticketCode,
            isFloating: true,
            onToggleFloating: () {
              _closeFloatingChat();
              if (mounted) _openChatDialog(context);
            },
            onClose: _closeFloatingChat,
            onDrag: (delta) {
              _floatingOffset = Offset(
                (left + delta.dx).clamp(8.0, (s.width - w - 8).clamp(8.0, s.width)),
                (top + delta.dy).clamp(8.0, (s.height - h - 8).clamp(8.0, s.height)),
              );
              _floatingEntry?.markNeedsBuild();
            },
            onResize: (delta) {
              final nextW = (w + delta.dx).clamp(320.0, (s.width - left - 8).clamp(320.0, 820.0));
              final nextH = (h + delta.dy).clamp(380.0, (s.height - top - 8).clamp(380.0, 860.0));
              _floatingSize = Size(nextW, nextH);
              _floatingEntry?.markNeedsBuild();
            },
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_floatingEntry!);
    setState(() {});
  }
}

class _SupportChatDialog extends StatefulWidget {
  final UserModel currentUser;
  final String ticketCode;
  final bool isFloating;
  final VoidCallback? onToggleFloating;
  final VoidCallback? onClose;
  final ValueChanged<Offset>? onDrag;
  final ValueChanged<Offset>? onResize;

  const _SupportChatDialog({
    required this.currentUser,
    required this.ticketCode,
    this.isFloating = false,
    this.onToggleFloating,
    this.onClose,
    this.onDrag,
    this.onResize,
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
  DateTime? _lastTextSentAt;
  DateTime? _floodBlockedUntil;
  final List<DateTime> _recentTextSentTimestamps = [];
  String? _lastSeenDocId;
  int _lastSeenCount = 0;

  static const Set<String> _allowedImageExts = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif'
  };
  static const int _maxSingleFileBytes = 5 * 1024 * 1024; // 5 MB por arquivo
  static const int _maxTextChars = 800;
  static const Duration _textCooldown = Duration(seconds: 3);
  static const Duration _burstWindow = Duration(minutes: 1);
  static const int _maxBurstCount = 10;
  static const Duration _burstBlockDuration = Duration(seconds: 30);

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
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<bool> _checkTextFloodAndQuota(String text) async {
    if (text.length > _maxTextChars) {
      _showError(
          'Mensagem muito longa (máx. $_maxTextChars caracteres por envio).');
      return false;
    }
    if (widget.currentUser.isSuperAdmin) return true;

    final now = DateTime.now();
    if (_floodBlockedUntil != null && now.isBefore(_floodBlockedUntil!)) {
      final secs = _floodBlockedUntil!.difference(now).inSeconds + 1;
      _showError('Muitas mensagens seguidas. Aguarde ${secs}s para enviar.');
      return false;
    }

    if (_lastTextSentAt != null) {
      final diff = now.difference(_lastTextSentAt!);
      if (diff < _textCooldown) {
        final secs = (_textCooldown - diff).inSeconds + 1;
        _showError('Aguarde ${secs}s antes de enviar outra mensagem.');
        return false;
      }
    }

    _recentTextSentTimestamps
        .removeWhere((t) => now.difference(t) > _burstWindow);
    if (_recentTextSentTimestamps.length >= _maxBurstCount) {
      _floodBlockedUntil = now.add(_burstBlockDuration);
      _showError(
          'Limite de rajada atingido ($_maxBurstCount msgs/min). Aguarde 30s.');
      return false;
    }

    final cfg = await SystemSettingsService.getGlobalConfig();
    if (cfg.supportDailyTextQuota > 0) {
      final snap = await FirebaseFirestore.instance
          .collection('support_chats')
          .doc(widget.currentUser.uid)
          .get();
      final data = snap.data() ?? {};
      final sameDay = data['todayTextDate'] == _todayStr;
      final usedCount =
          sameDay ? ((data['todayTextCount'] as num?)?.toInt() ?? 0) : 0;
      if (usedCount >= cfg.supportDailyTextQuota) {
        _showError(
          'Limite diário de mensagens atingido ($usedCount / ${cfg.supportDailyTextQuota}). Aguarde a renovação amanhã.',
        );
        return false;
      }
    }
    return true;
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

    if (mediaType == 'text') {
      final allowed = await _checkTextFloodAndQuota(text);
      if (!allowed) return;
    }

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
      int? nextTextCount;
      if (mediaSizeBytes > 0 || mediaType == 'text') {
        final prevSnap = await chatRef.get();
        final prevData = prevSnap.data() ?? {};
        if (mediaSizeBytes > 0) {
          final sameDay = prevData['todayMediaDate'] == _todayStr;
          final prevUsed =
              sameDay ? ((prevData['todayMediaBytes'] as num?)?.toInt() ?? 0) : 0;
          nextMediaBytes = prevUsed + mediaSizeBytes;
        }
        if (mediaType == 'text') {
          final sameDayText = prevData['todayTextDate'] == _todayStr;
          final prevTextUsed = sameDayText
              ? ((prevData['todayTextCount'] as num?)?.toInt() ?? 0)
              : 0;
          nextTextCount = prevTextUsed + 1;
        }
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
        if (nextTextCount != null) ...{
          'todayTextDate': _todayStr,
          'todayTextCount': nextTextCount,
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

      if (mediaType == 'text') {
        final sentAt = DateTime.now();
        _lastTextSentAt = sentAt;
        _recentTextSentTimestamps.add(sentAt);
      }

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
      await AiUsageTelemetryService.recordUploadOrAgentCost(
        actionType: 'upload_support_media',
        bytes: uploadBytes.length,
        companyId: widget.currentUser.effectiveCompanyId,
        userId: widget.currentUser.uid,
        userName: widget.currentUser.name,
      );

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
        await AiUsageTelemetryService.recordUploadOrAgentCost(
          actionType: 'upload_support_audio',
          bytes: bytes.length,
          companyId: widget.currentUser.effectiveCompanyId,
          userId: widget.currentUser.uid,
          userName: widget.currentUser.name,
        );

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

    final windowContent = Material(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: widget.isFloating ? 16 : 0,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: widget.isFloating
            ? BorderSide(
                color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                width: 1.2,
              )
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              // Header (arrastável no modo flutuante)
              GestureDetector(
                onPanUpdate: widget.isFloating && widget.onDrag != null
                    ? (details) => widget.onDrag!(details.delta)
                    : null,
                child: MouseRegion(
                  cursor: widget.isFloating
                      ? SystemMouseCursors.grab
                      : MouseCursor.defer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.2),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.isFloating
                                    ? 'Modo livre • Arraste aqui para mover'
                                    : 'Protocolo ${widget.ticketCode} • Texto, Imagem e Áudio',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onToggleFloating != null)
                          IconButton(
                            tooltip: widget.isFloating
                                ? 'Centralizar janela'
                                : 'Soltar janela (mover/redimensionar)',
                            onPressed: widget.onToggleFloating,
                            icon: Icon(
                              widget.isFloating
                                  ? Icons.center_focus_strong_rounded
                                  : Icons.open_in_new_rounded,
                              color: Colors.white70,
                              size: 19,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Fechar chat',
                          onPressed: widget.onClose ??
                              () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
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
                    _lastSeenDocId = null;
                    _lastSeenCount = 0;
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

                  final latestId = docs.last.id;
                  if (latestId != _lastSeenDocId ||
                      docs.length != _lastSeenCount) {
                    _lastSeenDocId = latestId;
                    _lastSeenCount = docs.length;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.all(14),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[docs.length - 1 - i].data();
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
                            maxLength: _maxTextChars,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Digite sua mensagem...',
                              counterStyle: GoogleFonts.inter(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
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
        if (widget.isFloating && widget.onResize != null)
          Positioned(
            right: 2,
            bottom: 2,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeDownRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) => widget.onResize!(details.delta),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.south_east_rounded,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isFloating) {
      return SizedBox.expand(child: windowContent);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: 430,
        height: 560,
        child: windowContent,
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

class _SupportSpeedDialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int unreadCount;
  final VoidCallback onTap;

  const _SupportSpeedDialButton({
    required this.icon,
    required this.label,
    required this.color,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
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
  }
}
