import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'package:mavis_microservice/generator/solar_credit_boleto_engine.dart';
import 'package:mavis_microservice/generator/solar_proposal_pdf_engine.dart';
import 'package:mavis_microservice/models/proposal_dto.dart';
import 'package:mavis_microservice/models/solar_credit_dto.dart';
import 'package:mavis_microservice/services/firebase_storage_service.dart';
import 'package:mavis_microservice/services/firestore_gd_service.dart';
import 'package:mavis_microservice/services/firestore_settings_service.dart';

void main(List<String> args) async {
  final app = Router();

  // Health check
  app.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'online',
        'service': 'Mavis PDF Generator Microservice',
        'engine': 'Dart Native PDF 6-Pages Solar Engine (Synced with CRM Firestore)',
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
          '/generate': 'POST - Gera PDF sincronizado com Firestore, salva no Storage e retorna URLs + Base64',
          '/generate/raw': 'POST - Gera PDF sincronizado com Firestore e retorna os bytes brutos (application/pdf)',
          '/gd/check-uc': 'POST - Verifica se a UC é recebedora em Créditos Solares (GD) para heitorklaus@hotmail.com e retorna resumo + botões',
          '/gd/generate-boleto': 'POST - Gera PDF do Boleto/Demonstrativo GD, salva no Firestore/Storage e retorna URL + Base64',
          '/gd/action': 'POST - Trata cliques nos botões pré-definidos (GD_GERAR_BOLETO, GD_GERAR_PROPOSTA, GD_CANCELAR)',
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

      Map<String, dynamic>? reqSettingsMap;
      if (body.containsKey('settings') && body['settings'] is Map) {
        reqSettingsMap = Map<String, dynamic>.from(body['settings'] as Map);
      }

      // Busca automaticamente as configurações vivas do CRM no Firestore (companies/{companyId}/sector_settings/solarPlant)
      final settings = await FirestoreSettingsService.resolveSettings(
        proposal: proposal,
        requestSettingsMap: reqSettingsMap,
      );

      print('🚀 [mavis-pdf] Compilando PDF oficial sincronizado para: ${proposal.proposalNumber} (${proposal.clientName})');
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
      final proposalMap = body.containsKey('proposal')
          ? Map<String, dynamic>.from(body['proposal'] as Map)
          : body;

      final proposal = ProposalDTO.fromMap(proposalMap);

      Map<String, dynamic>? reqSettingsMap;
      if (body.containsKey('settings') && body['settings'] is Map) {
        reqSettingsMap = Map<String, dynamic>.from(body['settings'] as Map);
      }

      final settings = await FirestoreSettingsService.resolveSettings(
        proposal: proposal,
        requestSettingsMap: reqSettingsMap,
      );

      final pdfBytes = await SolarProposalPdfEngine.generatePdf(
        proposal: proposal,
        settings: settings,
      );

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

  // ── CRÉDITOS SOLARES (GD): Verificar UC Recebedora + Resumo Ilustrado + Botões ──
  app.post('/gd/check-uc', (Request request) async {
    try {
      final bodyText = await request.readAsString();
      final Map<String, dynamic> body = jsonDecode(bodyText);
      final ucNumber = (body['uc'] ?? body['ucNumber'] ?? '').toString().trim();
      final ownerEmail = body['ownerEmail']?.toString();
      final companyId = body['companyId']?.toString();
      final billData = body['billData'] is Map
          ? Map<String, dynamic>.from(body['billData'] as Map)
          : Map<String, dynamic>.from(body);

      if (!FirestoreGdService.isAllowedForAdmin(ownerEmail: ownerEmail, companyId: companyId)) {
        return Response.ok(
          jsonEncode({
            'allowed': false,
            'isBeneficiary': false,
            'nextAction': 'PROPOSAL_FLOW',
            'reason': 'Fluxo de Créditos Solares (GD) habilitado apenas para heitorklaus@hotmail.com',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      if (ucNumber.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Número da UC não informado'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final beneficiary = body['beneficiary'] is Map
          ? GdBeneficiaryDTO.fromMap(
              Map<String, dynamic>.from(body['beneficiary'] as Map),
              (body['beneficiary']['id'] ?? '').toString(),
            )
          : await FirestoreGdService.findBeneficiaryByUc(
              ucNumber: ucNumber,
              companyId: companyId,
            );

      if (beneficiary == null) {
        return Response.ok(
          jsonEncode({
            'allowed': true,
            'isBeneficiary': false,
            'uc': ucNumber,
            'nextAction': 'PROPOSAL_FLOW',
            'buttons': GdBillCalculationDTO.predefinedButtons(),
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final calc = GdBillCalculationDTO.fromBeneficiaryAndBill(
        beneficiary: beneficiary,
        billData: billData,
      );

      return Response.ok(
        jsonEncode({
          'allowed': true,
          'isBeneficiary': true,
          'nextAction': 'AWAIT_GD_BUTTON',
          'beneficiary': beneficiary.toMap(),
          'calculation': calc.toMap(),
          'summaryText': calc.buildWhatsAppSummary(),
          'buttons': GdBillCalculationDTO.predefinedButtons(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e, stack) {
      print('❌ [mavis-pdf] Erro em /gd/check-uc: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  });

  // ── CRÉDITOS SOLARES (GD): Gerar PDF do Boleto/Demonstrativo + Salvar no Firestore ──
  app.post('/gd/generate-boleto', (Request request) async {
    try {
      final bodyText = await request.readAsString();
      final Map<String, dynamic> body = jsonDecode(bodyText);
      final ucNumber = (body['uc'] ?? body['ucNumber'] ?? '').toString().trim();
      final ownerEmail = body['ownerEmail']?.toString();
      final companyId = body['companyId']?.toString();
      final saveToFirestore = body['saveToFirestore'] != false;
      final billData = body['billData'] is Map
          ? Map<String, dynamic>.from(body['billData'] as Map)
          : Map<String, dynamic>.from(body);

      if (!FirestoreGdService.isAllowedForAdmin(ownerEmail: ownerEmail, companyId: companyId)) {
        return Response.forbidden(
          jsonEncode({'error': 'Fluxo de Créditos Solares (GD) habilitado apenas para heitorklaus@hotmail.com'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final beneficiary = body['beneficiary'] is Map
          ? GdBeneficiaryDTO.fromMap(
              Map<String, dynamic>.from(body['beneficiary'] as Map),
              (body['beneficiary']['id'] ?? '').toString(),
            )
          : await FirestoreGdService.findBeneficiaryByUc(
              ucNumber: ucNumber,
              companyId: companyId,
            );

      if (beneficiary == null) {
        return Response.notFound(
          jsonEncode({'error': 'UC $ucNumber não encontrada como recebedora de créditos GD.'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final calc = GdBillCalculationDTO.fromBeneficiaryAndBill(
        beneficiary: beneficiary,
        billData: billData,
      );

      final pdfBytes = await SolarCreditBoletoEngine.generatePdf(calc: calc);

      String? billDocId;
      if (saveToFirestore) {
        billDocId = await FirestoreGdService.saveBillToFirestore(calc);
      }

      final safeUc = ucNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'Boleto_GD_${safeUc}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final uploadUrl = await FirebaseStorageService.uploadPdf(
        pdfBytes: pdfBytes,
        fileName: 'gd_boletos/$fileName',
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'billId': billDocId,
          'fileName': fileName,
          'pdfUrl': uploadUrl,
          'pdfBase64': base64Encode(pdfBytes),
          'sizeBytes': pdfBytes.length,
          'summaryText': calc.buildWhatsAppSummary(),
          'calculation': calc.toMap(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e, stack) {
      print('❌ [mavis-pdf] Erro em /gd/generate-boleto: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  });

  // ── CRÉDITOS SOLARES (GD): Roteador dos Botões Pré-Definidos (inclui CANCELAR global) ──
  app.post('/gd/action', (Request request) async {
    try {
      final bodyText = await request.readAsString();
      final Map<String, dynamic> body = jsonDecode(bodyText);
      final actionRaw = (body['action'] ?? body['buttonId'] ?? '').toString().trim().toUpperCase();

      if (actionRaw == 'CANCELAR' || actionRaw == 'GD_CANCELAR') {
        return Response.ok(
          jsonEncode({
            'success': true,
            'action': 'RESET_CONVERSATION',
            'resetSession': true,
            'message': '❌ *Atendimento cancelado.* Conversa resetada! Envie uma nova conta de energia ou mensagem quando desejar recomeçar.',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      if (actionRaw == 'GERAR PROPOSTA PARA ESTA CONTA' || actionRaw == 'GD_GERAR_PROPOSTA') {
        return Response.ok(
          jsonEncode({
            'success': true,
            'action': 'PROPOSAL_FLOW',
            'resetSession': false,
            'message': '☀️ *Perfeito!* Seguindo com o fluxo normal de geração da *Proposta Comercial* para esta conta...',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      if (actionRaw == 'GERAR BOLETO' || actionRaw == 'GD_GERAR_BOLETO') {
        final ucNumber = (body['uc'] ?? body['ucNumber'] ?? '').toString().trim();
        final ownerEmail = body['ownerEmail']?.toString();
        final companyId = body['companyId']?.toString();
        final billData = body['billData'] is Map
            ? Map<String, dynamic>.from(body['billData'] as Map)
            : Map<String, dynamic>.from(body);

        if (!FirestoreGdService.isAllowedForAdmin(ownerEmail: ownerEmail, companyId: companyId)) {
          return Response.forbidden(
            jsonEncode({'error': 'Ação permitida apenas para heitorklaus@hotmail.com'}),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          );
        }

        final beneficiary = body['beneficiary'] is Map
            ? GdBeneficiaryDTO.fromMap(
                Map<String, dynamic>.from(body['beneficiary'] as Map),
                (body['beneficiary']['id'] ?? '').toString(),
              )
            : await FirestoreGdService.findBeneficiaryByUc(
                ucNumber: ucNumber,
                companyId: companyId,
              );
        if (beneficiary == null) {
          return Response.notFound(
            jsonEncode({'error': 'UC $ucNumber não encontrada como recebedora de créditos GD.'}),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          );
        }

        final calc = GdBillCalculationDTO.fromBeneficiaryAndBill(
          beneficiary: beneficiary,
          billData: billData,
        );
        final pdfBytes = await SolarCreditBoletoEngine.generatePdf(calc: calc);
        final saveToFirestore = body['saveToFirestore'] != false;
        final billDocId = saveToFirestore ? await FirestoreGdService.saveBillToFirestore(calc) : null;
        final safeUc = ucNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final fileName = 'Boleto_GD_${safeUc}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final uploadUrl = await FirebaseStorageService.uploadPdf(
          pdfBytes: pdfBytes,
          fileName: 'gd_boletos/$fileName',
        );

        return Response.ok(
          jsonEncode({
            'success': true,
            'action': 'SEND_BOLETO_PDF',
            'billId': billDocId,
            'fileName': fileName,
            'pdfUrl': uploadUrl,
            'pdfBase64': base64Encode(pdfBytes),
            'message': '✅ *Boleto / Demonstrativo GD gerado com sucesso!* Segue o PDF para envio ao cliente.',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      return Response.badRequest(
        body: jsonEncode({
          'error': 'Ação desconhecida: $actionRaw',
          'validActions': ['GD_GERAR_BOLETO', 'GD_GERAR_PROPOSTA', 'GD_CANCELAR'],
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e, stack) {
      print('❌ [mavis-pdf] Erro em /gd/action: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
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
