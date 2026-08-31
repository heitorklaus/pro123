import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'package:mavis_microservice/generator/solar_proposal_pdf_engine.dart';
import 'package:mavis_microservice/models/proposal_dto.dart';
import 'package:mavis_microservice/models/solar_settings_dto.dart';
import 'package:mavis_microservice/services/firebase_storage_service.dart';

void main(List<String> args) async {
  final app = Router();

  // Health check
  app.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'online',
        'service': 'Mavis PDF Generator Microservice',
        'engine': 'Dart Native PDF 6-Pages Solar Engine',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  });

  app.get('/', (Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'online',
        'endpoints': {
          '/health': 'GET - Verifica integridade do serviço',
          '/generate': 'POST - Gera PDF, salva no Storage e retorna URLs + Base64',
          '/generate/raw': 'POST - Gera PDF e retorna os bytes brutos (application/pdf)',
        },
      }),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  });

  // Geração de Proposta Comercial (JSON + Storage Upload + Base64)
  app.post('/generate', (Request request) async {
    try {
      final bodyText = await request.readAsString();
      if (bodyText.trim().isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Corpo da requisição vazio'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final Map<String, dynamic> body = jsonDecode(bodyText);

      Map<String, dynamic> proposalMap;
      if (body.containsKey('proposal')) {
        proposalMap = Map<String, dynamic>.from(body['proposal'] as Map);
      } else {
        proposalMap = body;
      }

      final proposal = ProposalDTO.fromMap(proposalMap);

      SolarSettingsDTO? settings;
      if (body.containsKey('settings') && body['settings'] != null) {
        settings = SolarSettingsDTO.fromMap(Map<String, dynamic>.from(body['settings'] as Map));
      }

      print('🚀 [mavis-pdf] Compilando PDF oficial para: ${proposal.proposalNumber} (${proposal.clientName})');
      final pdfBytes = await SolarProposalPdfEngine.generatePdf(
        proposal: proposal,
        settings: settings,
      );

      // Upload opcional/automático para o Storage
      final shouldUpload = body['uploadToStorage'] != false;
      Map<String, String>? storageResult;

      if (shouldUpload) {
        storageResult = await FirebaseStorageService.uploadProposalPdf(
          pdfBytes: pdfBytes,
          proposal: proposal,
        );
      }

      final pdfBase64 = base64Encode(pdfBytes);

      return Response.ok(
        jsonEncode({
          'success': true,
          'proposalNumber': proposal.proposalNumber,
          'clientName': proposal.clientName,
          'totalAmount': proposal.totalAmount,
          'pdfUrl': storageResult?['pdfUrl'],
          'pdfPath': storageResult?['pdfPath'],
          'fileName': storageResult?['fileName'] ?? 'Proposta_${proposal.proposalNumber}.pdf',
          'pdfBase64': pdfBase64,
          'bytesLength': pdfBytes.lengthInBytes,
        }),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e, stack) {
      print('❌ [mavis-pdf] Erro ao gerar proposta: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Retorno direto do arquivo binário (application/pdf)
  app.post('/generate/raw', (Request request) async {
    try {
      final bodyText = await request.readAsString();
      final Map<String, dynamic> body = jsonDecode(bodyText);
      final proposalMap = body.containsKey('proposal') ? body['proposal'] as Map<String, dynamic> : body;

      final proposal = ProposalDTO.fromMap(proposalMap);
      final pdfBytes = await SolarProposalPdfEngine.generatePdf(proposal: proposal);

      return Response.ok(
        pdfBytes,
        headers: {
          'Content-Type': 'application/pdf',
          'Content-Disposition': 'inline; filename="Proposta_${proposal.proposalNumber}.pdf"',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Middleware padrão
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(app.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('☀️ [mavis-pdf] Servidor Nativo Dart rodando na porta ${server.port}');
}
