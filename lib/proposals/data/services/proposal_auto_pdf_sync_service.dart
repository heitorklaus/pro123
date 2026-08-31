import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/proposal_model.dart';
import 'solar_proposal_pdf_service.dart';
import 'proposal_pdf_service.dart';

/// Serviço que escuta em tempo real a coleção 'proposals' e, assim que detecta
/// uma proposta criada externamente (como pelo robô WhatsApp no Node.js) sem PDF gerado,
/// compila o PDF nativo oficial no Flutter e faz o upload para o Firebase Storage!
class ProposalAutoPdfSyncService {
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  static final Set<String> _processingIds = {};

  /// Inicia a escuta em segundo plano para a empresa conectada
  static void startSync({String? companyId}) {
    if (companyId == null || companyId.isEmpty) return;

    // Cancela inscrição anterior se houver
    stopSync();

    debugPrint('[ProposalAutoPdfSyncService] 🚀 Iniciando ouvinte de propostas em tempo real para: $companyId');

    final query = FirebaseFirestore.instance
        .collection('proposals')
        .where('companyId', isEqualTo: companyId);

    _subscription = query.snapshots().listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          if (data == null) continue;

          final docId = change.doc.id;
          final pdfUrl = data['pdfUrl'] as String?;

          // Se a proposta ainda não possui o arquivo PDF gerado no Storage
          if (pdfUrl == null || pdfUrl.isEmpty) {
            if (_processingIds.contains(docId)) continue;
            _processingIds.add(docId);

            _compileAndUploadPdf(data, docId);
          }
        }
      }
    }, onError: (e) {
      debugPrint('[ProposalAutoPdfSyncService] ⚠️ Erro no ouvinte de propostas: $e');
    });
  }

  /// Compila o PDF usando o motor nativo do Flutter e envia para o Storage
  static Future<void> _compileAndUploadPdf(Map<String, dynamic> data, String docId) async {
    try {
      debugPrint('[ProposalAutoPdfSyncService] 📄 Compilando PDF oficial no Flutter para a proposta: $docId');
      final proposal = ProposalModel.fromMap(data, docId);

      final isSolar = proposal.items.any((i) =>
          i.isSolarPlant ||
          i.name.toLowerCase().contains('solar') ||
          i.name.toLowerCase().contains('usina') ||
          proposal.title.toLowerCase().contains('solar') ||
          proposal.title.toLowerCase().contains('usina'));

      Uint8List pdfBytes;
      if (isSolar) {
        pdfBytes = await SolarProposalPdfService.generateSolarProposalPdf(
          proposal,
          autoUploadToStorage: true,
        );
      } else {
        pdfBytes = await ProposalPdfService.generateProposalPdf(
          proposal,
          autoUploadToStorage: true,
        );
      }

      debugPrint('[ProposalAutoPdfSyncService] ✅ PDF oficial compilado e salvo no Storage com sucesso! (${pdfBytes.lengthInBytes} bytes)');
    } catch (e) {
      debugPrint('[ProposalAutoPdfSyncService] ❌ Erro ao compilar PDF para proposta $docId: $e');
    } finally {
      // Remove da fila de processamento após alguns segundos
      Future.delayed(const Duration(seconds: 10), () {
        _processingIds.remove(docId);
      });
    }
  }

  /// Encerra a escuta em segundo plano
  static void stopSync() {
    _subscription?.cancel();
    _subscription = null;
  }
}
