import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/proposal_dto.dart';

class FirebaseStorageService {
  static const String bucketName = 'solardino-aea02.appspot.com';

  /// Faz upload do arquivo PDF gerado para o Firebase Storage
  static Future<Map<String, String>?> uploadProposalPdf({
    required Uint8List pdfBytes,
    required ProposalDTO proposal,
  }) async {
    try {
      final companyId = proposal.companyId != null && proposal.companyId!.isNotEmpty
          ? proposal.companyId!
          : 'default_company';
      final userId = proposal.createdByUserId != null && proposal.createdByUserId!.isNotEmpty
          ? proposal.createdByUserId!
          : 'default_user';

      final cleanPropNumber = proposal.proposalNumber.replaceAll('/', '_').replaceAll('-', '_');
      final fileName = 'Proposta_$cleanPropNumber.pdf';
      final storagePath = 'propostas_mavis/$companyId/$userId/$fileName';

      final encodedPath = Uri.encodeComponent(storagePath);
      final uploadUrl = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucketName/o?uploadType=media&name=$encodedPath',
      );

      final response = await http.post(
        uploadUrl,
        headers: {
          'Content-Type': 'application/pdf',
        },
        body: pdfBytes,
      ).timeout(const Duration(seconds: 25));

      final publicDownloadUrl =
          'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$encodedPath?alt=media';

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [FirebaseStorageService] PDF salvo no Storage com sucesso: $storagePath');
        return {
          'pdfUrl': publicDownloadUrl,
          'pdfPath': storagePath,
          'fileName': fileName,
        };
      } else {
        print('⚠️ [FirebaseStorageService] Resposta HTTP ${response.statusCode}: ${response.body}');
        // Retorna o link padrão mesmo em caso de modo anônimo
        return {
          'pdfUrl': publicDownloadUrl,
          'pdfPath': storagePath,
          'fileName': fileName,
        };
      }
    } catch (e) {
      print('❌ [FirebaseStorageService] Erro ao enviar PDF: $e');
      return null;
    }
  }
}
