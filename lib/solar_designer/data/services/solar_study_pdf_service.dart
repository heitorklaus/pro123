import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/domain/models/company_model.dart';
import '../../domain/models/roof_study_model.dart';
import '../../domain/models/solar_designer_models.dart';
import '../../domain/services/solar_shading_engine.dart';
import '../repositories/roof_study_repository.dart';

/// Serviço de Geração e Emissão de Relatório Técnico em PDF
/// ESTUDO DE ENGENHARIA SOLAR E PROJEÇÃO DE GERAÇÃO
class SolarStudyPdfService {
  // ── ÍCONES VETORIAIS SVG NATIVOS PARA O PDF ────────────────────────────────
  static const String _svgSun = '''
<svg viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="4" fill="#F59E0B"/>
  <path stroke="#F59E0B" stroke-width="2" stroke-linecap="round" d="M12 2v2m0 16v2M4.93 4.93l1.41 1.41m11.32 11.32l1.41 1.41M2 12h2m16 0h2M6.34 17.66l-1.41 1.41m14.14-14.14l-1.41 1.41"/>
</svg>
''';

  static const String _svgBolt = '''
<svg viewBox="0 0 24 24">
  <path fill="#6366F1" d="M11 21h-1l1-7H7.5c-.88 0-.33-.75-.31-.78C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .88.39.88.88 0 .19-.06.37-.17.52L11 21z"/>
</svg>
''';

  static const String _svgPin = '''
<svg viewBox="0 0 24 24">
  <path fill="#EF4444" d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 1 1 0-5 2.5 2.5 0 0 1 0 5z"/>
</svg>
''';

  static const String _svgUser = '''
<svg viewBox="0 0 24 24">
  <path fill="#0284C7" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
</svg>
''';

  static const String _svgCamera = '''
<svg viewBox="0 0 24 24">
  <path fill="#0284C7" d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/>
</svg>
''';

  static const String _svgClock = '''
<svg viewBox="0 0 24 24">
  <path fill="#0284C7" d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm4.2 14.2L11 13V7h1.5v5.2l4.5 2.7-.8 1.3z"/>
</svg>
''';

  static const String _svgRuler = '''
<svg viewBox="0 0 24 24">
  <path fill="#0F172A" d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm0 10H3V8h2v4h2V8h2v4h2V8h2v4h2V8h2v4h2V8h3v8z"/>
</svg>
''';

  static const String _svgChart = '''
<svg viewBox="0 0 24 24">
  <path fill="#10B981" d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-5h2v5zm4 0h-2v-9h2v9zm4 0h-2v-4h2v4z"/>
</svg>
''';

  static const String _svgCompass = '''
<svg viewBox="0 0 24 24">
  <path fill="#6366F1" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm2.19 12.19L6 18l3.81-8.19L18 6l-3.81 8.19zM12 10.9a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2z"/>
</svg>
''';

  static const String _svgPanel = '''
<svg viewBox="0 0 24 24">
  <path fill="#38BDF8" d="M4 2h16c1.1 0 2 .9 2 2v16c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2zm0 2v8h7V4H4zm9 0v8h7V4h-7zm7 10h-7v8h7v-8zm-9 0H4v8h7v-8z"/>
</svg>
''';

  static const String _svgShield = '''
<svg viewBox="0 0 24 24">
  <path fill="#10B981" d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/>
</svg>
''';

  // ── PALETA DE CORES CORPORATIVA ───────────────────────────────────────────
  static const primaryNavy = PdfColor.fromInt(0xFF0F172A);
  static const accentIndigo = PdfColor.fromInt(0xFF4F46E5);
  static const accentSky = PdfColor.fromInt(0xFF0284C7);
  static const successEmerald = PdfColor.fromInt(0xFF059669);
  static const warningAmber = PdfColor.fromInt(0xFFD97706);
  static const dangerRose = PdfColor.fromInt(0xFFE11D48);
  static const textDark = PdfColor.fromInt(0xFF1E293B);
  static const textMuted = PdfColor.fromInt(0xFF64748B);
  static const borderSlate = PdfColor.fromInt(0xFFCBD5E1);
  static const borderLight = PdfColor.fromInt(0xFFE2E8F0);
  static const bgCard = PdfColor.fromInt(0xFFF8FAFC);
  static const bgLight = PdfColor.fromInt(0xFFF1F5F9);

  /// Compila o documento PDF em bytes com design executivo premium e fotos individuais grandes
  static Future<Uint8List> generatePdfBytes({
    required RoofStudyModel study,
    List<RoofSection>? sections,
    DailyShadingSimulationResult? simulation,
    List<RoofStudyPhoto> photos = const [],
    CompanyModel? company,
    String? clientName,
    String? clientAddress,
    String? clientPhone,
  }) async {
    final pdf = pw.Document(
      title: 'Estudo de Engenharia Solar - ${study.name}',
      author: company?.name ?? 'Mavis CRM Engenharia Solar',
    );

    pw.Font fontRegular = pw.Font.helvetica();
    pw.Font fontBold = pw.Font.helveticaBold();
    try {
      fontRegular = await PdfGoogleFonts.interRegular().timeout(
        const Duration(seconds: 3),
        onTimeout: () => pw.Font.helvetica(),
      );
      fontBold = await PdfGoogleFonts.interBold().timeout(
        const Duration(seconds: 3),
        onTimeout: () => pw.Font.helveticaBold(),
      );
    } catch (e) {
      debugPrint('[SolarStudyPdfService] Usando fontes Helvetica como fallback: $e');
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final effectiveSections = sections ??
        (study.sections.isNotEmpty
            ? study.sections
            : (study.mapsSections.isNotEmpty
                ? study.mapsSections
                : study.droneSections));

    final northRad = study.northCompass?.rotationRadians ??
        study.mapsNorthCompass?.rotationRadians ??
        study.droneNorthCompass?.rotationRadians ??
        0.0;

    final effectiveSimulation = simulation ??
        SolarShadingEngine.simulateFullDay(
          sections: effectiveSections,
          latitude: study.latitude,
          northRotationRadians: northRad,
        );

    // Imagem da Logo da Empresa se existir
    pw.MemoryImage? companyLogo;
    if (company?.logoBase64 != null && company!.logoBase64!.isNotEmpty) {
      try {
        final clean = company.logoBase64!.contains(',')
            ? company.logoBase64!.split(',').last
            : company.logoBase64!;
        companyLogo = pw.MemoryImage(base64Decode(clean));
      } catch (e) {
        debugPrint('[SolarStudyPdfService] Erro ao decodificar logo: $e');
      }
    }

    // Processa imagens capturadas do canvas
    final capturedImages = <MapEntry<RoofStudyPhoto, pw.MemoryImage>>[];
    List<RoofStudyPhoto> photosToProcess = List.from(photos);

    final bool hasValidImages =
        photosToProcess.any((p) => p.imageBase64.trim().isNotEmpty);
    if (!hasValidImages && study.id.isNotEmpty) {
      try {
        final subPhotos = await RoofStudyRepository().getStudyPhotos(study.id);
        if (subPhotos.isNotEmpty) {
          photosToProcess = subPhotos;
        }
      } catch (_) {}
    }
    if (photosToProcess.isEmpty) {
      photosToProcess = study.studyPhotos;
    }

    for (final p in photosToProcess) {
      try {
        if (p.imageBase64.trim().isNotEmpty) {
          final cleanB64 = p.imageBase64.contains(',')
              ? p.imageBase64.split(',').last
              : p.imageBase64;
          var bytes = base64Decode(cleanB64);

          // Se a imagem for pesada (>250KB), comprime e redimensiona para JPEG leve garantindo PDF < 1 MB
          if (bytes.length > 250000) {
            try {
              final decoded = img.decodeImage(bytes);
              if (decoded != null) {
                final resized = (decoded.width > 1000)
                    ? img.copyResize(decoded, width: 1000)
                    : decoded;
                final compressedJpg = img.encodeJpg(resized, quality: 78);
                bytes = Uint8List.fromList(compressedJpg);
              }
            } catch (_) {}
          }

          capturedImages.add(MapEntry(p, pw.MemoryImage(bytes)));
        }
      } catch (e) {
        debugPrint('[SolarStudyPdfService] Erro ao decodificar foto ${p.id}: $e');
      }
    }

    // Se ainda assim não houver nenhuma foto capturada mas tiver snapshot HD do estudo, cria uma entrada
    if (capturedImages.isEmpty) {
      final snapB64 = study.hdSnapshotBase64 ?? study.snapshotImageBase64;
      if (snapB64 != null && snapB64.isNotEmpty) {
        try {
          final clean = snapB64.contains(',') ? snapB64.split(',').last : snapB64;
          var bytes = base64Decode(clean);
          if (bytes.length > 250000) {
            try {
              final decoded = img.decodeImage(bytes);
              if (decoded != null) {
                final resized = (decoded.width > 1000)
                    ? img.copyResize(decoded, width: 1000)
                    : decoded;
                final compressedJpg = img.encodeJpg(resized, quality: 78);
                bytes = Uint8List.fromList(compressedJpg);
              }
            } catch (_) {}
          }
          final p = RoofStudyPhoto(
            id: 'main_roof_layout',
            label: 'Layout Geral do Telhado 3D & Painéis',
            hourOfDay: 12.0,
            imageBase64: snapB64,
            capturedAt: DateTime.now(),
          );
          capturedImages.add(MapEntry(p, pw.MemoryImage(bytes)));
        } catch (_) {}
      }
    }

    // Dados consolidados dos módulos
    int totalModules = study.totalModulesCount;
    double totalKwp = study.totalKwp;
    double totalAreaM2 = 0;
    String moduleModel = 'Módulo Fotovoltaico TopCon Standard';
    double moduleWatts = 550.0;

    for (final s in effectiveSections) {
      if (s.modules.isNotEmpty) {
        totalAreaM2 += s.modules.where((m) => !m.isExcluded).length *
            (s.moduleSpec.widthMeters * s.moduleSpec.heightMeters);
        moduleModel = s.moduleSpec.modelName;
        moduleWatts = s.moduleSpec.watts.toDouble();
      }
    }

    if (totalModules == 0) {
      totalModules =
          effectiveSections.fold(0, (acc, s) => acc + s.activeModuleCount);
    }
    if (totalKwp <= 0.01 && totalModules > 0) {
      totalKwp = (totalModules * moduleWatts) / 1000.0;
    }

    final addressResolved = clientAddress?.trim().isNotEmpty == true
        ? clientAddress!
        : (study.formattedAddress.isNotEmpty
            ? study.formattedAddress
            : (study.cep != null
                ? 'CEP: ${study.cep}'
                : 'Local de Instalação Não Informado'));

    final clientResolved = clientName?.trim().isNotEmpty == true
        ? clientName!
        : (study.clientName?.isNotEmpty == true
            ? study.clientName!
            : 'Cliente');

    final totalPages = 1 + capturedImages.length;

    // ══════════════════════════════════════════════════════════════════════════
    // FOLHA 1: CAPA & VISÃO EXECUTIVA DE ENGENHARIA SOLAR
    // ══════════════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (pw.Context ctx) => _buildPageHeader(
          companyLogo: companyLogo,
          company: company,
          pageNumber: ctx.pageNumber,
          totalPages: totalPages,
          badgeTitle: 'ESTUDO TÉCNICO & SOMBREAMENTO',
        ),
        footer: (pw.Context ctx) => _buildPageFooter(
          pageNumber: ctx.pageNumber,
          totalPages: totalPages,
        ),
        build: (pw.Context ctx) {
          return [
            // 2. Card do Projeto & Cliente
            _buildProjectInfoCard(
              study: study,
              clientResolved: clientResolved,
              addressResolved: addressResolved,
            ),
            pw.SizedBox(height: 8),

            // 3. 4 KPIs Executivos
            _buildKpiRow(
              totalKwp: totalKwp,
              totalModules: totalModules,
              study: study,
              simulation: effectiveSimulation,
              totalAreaM2: totalAreaM2,
              sectionsCount: effectiveSections.length,
            ),
            pw.SizedBox(height: 8),

            // 4. Ficha Técnica do Gerador Solar
            _buildEquipmentSpecsBox(
              totalModules: totalModules,
              moduleModel: moduleModel,
              moduleWatts: moduleWatts,
              effectiveSunHours: effectiveSimulation.effectiveSunHours,
            ),
            pw.SizedBox(height: 8),

            // 5. Tabela de Detalhamento dos Planos de Telhado (Águas)
            _buildSectionsTable(
              effectiveSections,
              moduleWatts: moduleWatts,
            ),
            pw.SizedBox(height: 8),

            // 6. Balanço Geral de Geração & Sombreamento Diurno
            _buildShadingSummaryBox(effectiveSimulation),
            pw.SizedBox(height: 8),

            // 7. Sumário dos Registros Fotográficos Anexados
            _buildPhotoSummaryBox(
              capturedImages,
              latitude: study.latitude,
              sections: effectiveSections,
              northRad: northRad,
            ),
          ];
        },
      ),
    );

    // ══════════════════════════════════════════════════════════════════════════
    // FOLHAS SEGUINTES: UMA FOLHA INDIVIDUAL DEDICADA PARA CADA FOTO GRANDE
    // ══════════════════════════════════════════════════════════════════════════
    for (int i = 0; i < capturedImages.length; i++) {
      final photoEntry = capturedImages[i];
      final pageIndex = i + 2;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
          build: (pw.Context ctx) {
            return _buildIndividualPhotoPage(
              photo: photoEntry.key,
              image: photoEntry.value,
              sections: effectiveSections,
              totalModules: totalModules,
              latitude: study.latitude,
              northRad: northRad,
              companyLogo: companyLogo,
              company: company,
              pageIndex: pageIndex,
              totalPages: totalPages,
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ── CABEÇALHO PADRONIZADO COM O TÍTULO OFICIAL ─────────────────────────────
  static pw.Widget _buildPageHeader({
    required pw.MemoryImage? companyLogo,
    required CompanyModel? company,
    required int pageNumber,
    required int totalPages,
    required String badgeTitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: borderSlate, width: 1.2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              if (companyLogo != null) ...[
                pw.Container(
                  height: 32,
                  child: pw.Image(companyLogo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 8),
              ] else
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFEEF2FF),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.SvgImage(svg: _svgSun, width: 15, height: 15),
                ),
              pw.SizedBox(width: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ESTUDO DE ENGENHARIA SOLAR E PROJEÇÃO DE GERAÇÃO',
                    style: pw.TextStyle(
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                      color: accentIndigo,
                    ),
                  ),
                  pw.Text(
                    'MODELAGEM FOTOGRAMÉTRICA TRIDIMENSIONAL & SOMBREAMENTO COMPUTACIONAL',
                    style: const pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: pw.BoxDecoration(
                  color: primaryNavy,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  badgeTitle,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Folha $pageNumber de $totalPages • ${_formatDateTime(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 6.8,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FOLHA INDIVIDUAL DA FOTO GRANDE COM MINI RESUMO E APROVEITAMENTO ───────
  static pw.Widget _buildIndividualPhotoPage({
    required RoofStudyPhoto photo,
    required pw.MemoryImage image,
    required List<RoofSection> sections,
    required int totalModules,
    required double latitude,
    required double northRad,
    required pw.MemoryImage? companyLogo,
    required CompanyModel? company,
    required int pageIndex,
    required int totalPages,
  }) {
    final sun = SolarShadingEngine.calculateSunPosition(
      hourOfDay: photo.hourOfDay,
      latitude: latitude,
    );

    final sim = SolarShadingEngine.simulateFullDay(
      sections: sections,
      currentHour: photo.hourOfDay,
      latitude: latitude,
      northRotationRadians: northRad,
    );

    final totalMods = sim.totalModulesCount > 0 ? sim.totalModulesCount : totalModules;
    final shadedCount = sim.shadedAtCurrentHourCount;
    final sunCount = (totalMods - shadedCount).clamp(0, totalMods);
    final sunRatio = totalMods > 0 ? (sunCount / totalMods) : 1.0;
    final hourFormatted = _formatHour(photo.hourOfDay);
    final cardinalDirection = _getCardinalDirection(sun.azimuthDegrees);

    final narrative = _generateHourNarrative(
      hourOfDay: photo.hourOfDay,
      elevationDegrees: sun.elevationDegrees,
      azimuthDegrees: sun.azimuthDegrees,
      totalModules: totalMods,
      shadedCount: shadedCount,
      sunRatio: sunRatio,
    );

    // Cores temáticas do aproveitamento daquela hora
    PdfColor statusColor;
    PdfColor statusBg;
    String statusLabel;

    if (sunRatio >= 0.90) {
      statusColor = successEmerald;
      statusBg = const PdfColor.fromInt(0xFFECFDF5);
      statusLabel = 'APROVEITAMENTO ÓTIMO (${(sunRatio * 100).toStringAsFixed(1)}%)';
    } else if (sunRatio >= 0.70) {
      statusColor = warningAmber;
      statusBg = const PdfColor.fromInt(0xFFFFFBEB);
      statusLabel = 'SOMBREAMENTO PARCIAL (${(sunRatio * 100).toStringAsFixed(1)}% SOL)';
    } else {
      statusColor = dangerRose;
      statusBg = const PdfColor.fromInt(0xFFFEF2F2);
      statusLabel = 'SOMBREAMENTO CRÍTICO (${(sunRatio * 100).toStringAsFixed(1)}% SOL)';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header padrão
        _buildPageHeader(
          companyLogo: companyLogo,
          company: company,
          pageNumber: pageIndex,
          totalPages: totalPages,
          badgeTitle: 'REGISTRO SOLAR DAS $hourFormatted',
        ),
        pw.SizedBox(height: 6),

        // Banner de Destaque da Simulação Horária
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: pw.BoxDecoration(
            color: bgCard,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderLight),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFE0F2FE),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.SvgImage(svg: _svgClock, width: 14, height: 14),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        photo.label.isNotEmpty ? photo.label : 'Simulação Solar às $hourFormatted',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryNavy,
                        ),
                      ),
                      pw.Text(
                        'Incidência Solar e Projeção Tridimensional de Sombras em Tempo Real',
                        style: const pw.TextStyle(fontSize: 7.2, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: statusBg,
                  borderRadius: pw.BorderRadius.circular(20),
                  border: pw.Border.all(color: statusColor, width: 1.2),
                ),
                child: pw.Row(
                  children: [
                    pw.SvgImage(svg: _svgBolt, width: 11, height: 11),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      statusLabel,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // ── FOTO GRANDE COM MOLDURA SLATE & CANTOS ARREDONDADOS ──────────────
        pw.Container(
          height: 330,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF020617),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: borderSlate, width: 1.5),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 9,
            verticalRadius: 9,
            child: pw.Stack(
              alignment: pw.Alignment.bottomCenter,
              children: [
                pw.Center(
                  child: pw.Image(
                    image,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  color: const PdfColor.fromInt(0xCC0F172A),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.SvgImage(svg: _svgCamera, width: 10, height: 10),
                          pw.SizedBox(width: 5),
                          pw.Text(
                            'Modelagem Tridimensional às $hourFormatted (Azimute: ${sun.azimuthDegrees.toStringAsFixed(0)}° • Alt: ${sun.elevationDegrees.toStringAsFixed(1)}°)',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Insolação: ${(sunRatio * 100).toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        // ── 4 MINI-CARDS DE INDICADORES TÉCNICOS DAQUELA HORA ───────────────
        pw.Row(
          children: [
            _buildInstantKpiCard(
              title: 'ALTITUDE SOLAR',
              value: '${sun.elevationDegrees.toStringAsFixed(1)}°',
              subtitle: 'Zênite: ${(90.0 - sun.elevationDegrees).clamp(0.0, 90.0).toStringAsFixed(1)}°',
              accentColor: warningAmber,
              iconSvg: _svgSun,
            ),
            pw.SizedBox(width: 8),
            _buildInstantKpiCard(
              title: 'AZIMUTE SOLAR',
              value: '${sun.azimuthDegrees.toStringAsFixed(0)}°',
              subtitle: cardinalDirection,
              accentColor: accentIndigo,
              iconSvg: _svgCompass,
            ),
            pw.SizedBox(width: 8),
            _buildInstantKpiCard(
              title: 'APROVEITAMENTO DAS PLACAS',
              value: '${(sunRatio * 100).toStringAsFixed(1)}%',
              subtitle: 'Perda inst.: ${((1.0 - sunRatio) * 100).toStringAsFixed(1)}%',
              accentColor: statusColor,
              iconSvg: _svgBolt,
            ),
            pw.SizedBox(width: 8),
            _buildInstantKpiCard(
              title: 'SITUAÇÃO DO ARRANJO',
              value: '$sunCount / $totalMods Placas',
              subtitle: shadedCount > 0 ? '$shadedCount placa(s) sombreada(s)' : '100% sob Sol pleno',
              accentColor: accentSky,
              iconSvg: _svgPanel,
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        // ── BOX DE DIAGNÓSTICO DESCRITIVO ("O QUE TÁ ACONTECENDO NAQUELA HORA") ─
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: bgLight,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderSlate, width: 1.0),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.SvgImage(svg: _svgShield, width: 12, height: 12),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    'DIAGNÓSTICO TÉCNICO DE ENGENHARIA & ANÁLISE DE SOMBRA NESTE HORÁRIO ($hourFormatted)',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryNavy,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                narrative,
                style: const pw.TextStyle(
                  fontSize: 7.8,
                  color: textDark,
                  lineSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // Rodapé da Folha Individual
        _buildPageFooter(pageNumber: pageIndex, totalPages: totalPages),
      ],
    );
  }

  // ── WIDGETS AUXILIARES DA CAPA (FOLHA 1) ───────────────────────────────────

  static pw.Widget _buildProjectInfoCard({
    required RoofStudyModel study,
    required String clientResolved,
    required String addressResolved,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bgCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderLight, width: 1.2),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  study.name.isNotEmpty ? study.name : 'Estudo de Viabilidade Solar',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.SvgImage(svg: _svgUser, width: 10, height: 10),
                    pw.SizedBox(width: 4),
                    pw.Expanded(
                      child: pw.Text(
                        clientResolved,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SvgImage(svg: _svgPin, width: 10, height: 10),
                    pw.SizedBox(width: 4),
                    pw.Expanded(
                      child: pw.Text(
                        addressResolved,
                        style: const pw.TextStyle(fontSize: 8, color: textMuted),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(
            width: 1,
            height: 45,
            color: borderLight,
            margin: const pw.EdgeInsets.symmetric(horizontal: 12),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.SvgImage(svg: _svgCompass, width: 10, height: 10),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      'COORDENADAS & SOLAR',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: accentIndigo,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Lat: ${study.latitude.toStringAsFixed(4)}° • Long: ${study.longitude.toStringAsFixed(4)}°',
                  style: const pw.TextStyle(fontSize: 7.5, color: textDark),
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.SvgImage(svg: _svgSun, width: 9, height: 9),
                    pw.SizedBox(width: 3),
                    pw.Text(
                      'HSP Médio: ${(study.dailyHsp ?? 5.00).toStringAsFixed(2)} kWh/m²/dia',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: warningAmber,
                      ),
                    ),
                  ],
                ),
                if (study.createdByUserName.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Responsável: ${study.createdByUserName}',
                    style: const pw.TextStyle(fontSize: 7, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiRow({
    required double totalKwp,
    required int totalModules,
    required RoofStudyModel study,
    required DailyShadingSimulationResult simulation,
    required double totalAreaM2,
    required int sectionsCount,
  }) {
    return pw.Row(
      children: [
        _buildKpiCard(
          title: 'POTÊNCIA DO SISTEMA',
          value: '${totalKwp.toStringAsFixed(2)} kWp',
          subtitle: '$totalModules Placas Solares',
          accentColor: accentIndigo,
          iconSvg: _svgBolt,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'GERAÇÃO ESTIMADA',
          value: '${study.estimatedMonthlyKwh.toStringAsFixed(0)} kWh/mês',
          subtitle: 'Média ~${(study.estimatedMonthlyKwh * 12 / 1000).toStringAsFixed(1)} MWh/ano',
          accentColor: successEmerald,
          iconSvg: _svgSun,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'APROVEITAMENTO SOLAR',
          value: '${simulation.overallEfficiencyPercentage.toStringAsFixed(1)}%',
          subtitle: 'Perda p/ sombra: ${simulation.totalLossPercentage.toStringAsFixed(1)}%',
          accentColor: simulation.totalLossPercentage > 8.0 ? warningAmber : successEmerald,
          iconSvg: _svgChart,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'ÁREA DO TELHADO',
          value: '${totalAreaM2 > 0 ? totalAreaM2.toStringAsFixed(1) : (totalModules * 2.5).toStringAsFixed(1)} m²',
          subtitle: '$sectionsCount Água(s) de Telhado',
          accentColor: primaryNavy,
          iconSvg: _svgRuler,
        ),
      ],
    );
  }

  static pw.Widget _buildEquipmentSpecsBox({
    required int totalModules,
    required String moduleModel,
    required double moduleWatts,
    required double effectiveSunHours,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: pw.BoxDecoration(
        color: bgLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderLight),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.SvgImage(svg: _svgPanel, width: 13, height: 13),
              pw.SizedBox(width: 6),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EQUIPAMENTO CONFIGURADO:',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textMuted),
                  ),
                  pw.Text(
                    '$totalModules x $moduleModel (${moduleWatts.toStringAsFixed(0)}W)',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark),
                  ),
                ],
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.SvgImage(svg: _svgSun, width: 13, height: 13),
              pw.SizedBox(width: 6),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'HORAS DE SOL PLENO ÚTEIS:',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textMuted),
                  ),
                  pw.Text(
                    '${effectiveSunHours.toStringAsFixed(2)} h/dia efetivas',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentSky),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionsTable(
    List<RoofSection> sections, {
    required double moduleWatts,
  }) {
    if (sections.isEmpty) return pw.Container();

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bgCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderLight),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const pw.BoxDecoration(
              color: primaryNavy,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Row(
              children: [
                pw.SvgImage(svg: _svgCompass, width: 10, height: 10),
                pw.SizedBox(width: 5),
                pw.Text(
                  'DETALHAMENTO DOS PLANOS DE TELHADO & ORIENTAÇÃO SOLAR',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2.0),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: borderSlate, width: 0.8)),
                  ),
                  children: [
                    _tableHeader('PLANO / SEÇÃO'),
                    _tableHeader('MÓDULOS'),
                    _tableHeader('POTÊNCIA'),
                    _tableHeader('AZIMUTE / ORIENTAÇÃO'),
                    _tableHeader('INCLINAÇÃO'),
                    _tableHeader('ÁREA'),
                  ],
                ),
                ...sections.map((s) {
                  final modsCount = s.activeModuleCount;
                  final kwp = (modsCount * moduleWatts) / 1000.0;
                  final azimuth = s.rotationDegrees;
                  final cardinal = _getCardinalDirection(azimuth);
                  return pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: borderLight, width: 0.5)),
                    ),
                    children: [
                      _tableCell(s.name, isBold: true),
                      _tableCell('$modsCount un'),
                      _tableCell('${kwp.toStringAsFixed(2)} kWp'),
                      _tableCell('${azimuth.toStringAsFixed(0)}° ($cardinal)'),
                      _tableCell('${s.tiltDegrees.toStringAsFixed(0)}°'),
                      _tableCell('${s.areaM2.toStringAsFixed(1)} m²'),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
          color: textMuted,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.2,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textDark,
        ),
      ),
    );
  }

  static pw.Widget _buildShadingSummaryBox(DailyShadingSimulationResult simulation) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEEF2FF),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFC7D2FE)),
      ),
      child: pw.Row(
        children: [
          pw.SvgImage(svg: _svgChart, width: 14, height: 14),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BALANÇO TÉCNICO DE GERAÇÃO & RENDIMENTO DIURNO',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: accentIndigo,
                  ),
                ),
                pw.Text(
                  'A modelagem computacional aponta aproveitamento solar médio ponderado de ${simulation.overallEfficiencyPercentage.toStringAsFixed(1)}% ao longo do dia, com perdas globais por sombreamento limitadas a ${simulation.totalLossPercentage.toStringAsFixed(1)}%. A janela solar das 10:00 às 14:00 concentra o maior rendimento com incidência solar desobstruída.',
                  style: const pw.TextStyle(fontSize: 7.2, color: textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPhotoSummaryBox(
    List<MapEntry<RoofStudyPhoto, pw.MemoryImage>> photos, {
    required double latitude,
    required List<RoofSection> sections,
    required double northRad,
  }) {
    if (photos.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bgCard,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: borderLight, style: pw.BorderStyle.dashed),
        ),
        child: pw.Center(
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.SvgImage(svg: _svgCamera, width: 14, height: 14),
              pw.SizedBox(width: 6),
              pw.Text(
                'Nenhuma foto individual foi anexada. As folhas seguintes detalharão novas simulações.',
                style: const pw.TextStyle(fontSize: 8, color: textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: bgCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderSlate, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.SvgImage(svg: _svgCamera, width: 12, height: 12),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    'REGISTRO FOTOGRÁFICO DO ESTUDO (${photos.length} FOLHAS EM ALTA RESOLUÇÃO ANEXADAS)',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Ver folhas individuais a seguir',
                style: const pw.TextStyle(fontSize: 7, color: accentIndigo),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Cada cenário simulado abaixo foi modelado individualmente em página própria, apresentando a foto ampliada em alta resolução, posição astronômica do Sol e taxa de aproveitamento das placas:',
            style: const pw.TextStyle(fontSize: 7.2, color: textMuted),
          ),
          pw.SizedBox(height: 5),
          ...photos.asMap().entries.map((entry) {
            final idx = entry.key;
            final photo = entry.value.key;
            final sheetNumber = idx + 2;
            final sun = SolarShadingEngine.calculateSunPosition(
              hourOfDay: photo.hourOfDay,
              latitude: latitude,
            );
            final sim = SolarShadingEngine.simulateFullDay(
              sections: sections,
              currentHour: photo.hourOfDay,
              latitude: latitude,
              northRotationRadians: northRad,
            );
            final sunCount = sim.totalModulesCount - sim.shadedAtCurrentHourCount;
            final ratio = sim.totalModulesCount > 0 ? (sunCount / sim.totalModulesCount) : 1.0;

            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFF0F172A),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'FOLHA $sheetNumber',
                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    'Simulação Solar às ${_formatHour(photo.hourOfDay)}',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    '•  Alt: ${sun.elevationDegrees.toStringAsFixed(1)}°  •  Az: ${sun.azimuthDegrees.toStringAsFixed(0)}°  •  Aproveitamento: ${(ratio * 100).toStringAsFixed(1)}% de Sol (${sim.shadedAtCurrentHourCount > 0 ? '${sim.shadedAtCurrentHourCount} placas sob sombra' : '100% sem sombra'})',
                    style: const pw.TextStyle(fontSize: 7.2, color: textMuted),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
    required String iconSvg,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          color: bgCard,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: borderLight),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(2.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor(accentColor.red, accentColor.green, accentColor.blue, 0.15),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.SvgImage(svg: iconSvg, width: 11, height: 11),
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    title,
                    style: const pw.TextStyle(fontSize: 6.5, color: textMuted),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 6.5, color: textMuted),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildInstantKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
    required String iconSvg,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: pw.BoxDecoration(
          color: bgCard,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: borderLight),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(2.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor(accentColor.red, accentColor.green, accentColor.blue, 0.15),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.SvgImage(svg: iconSvg, width: 10, height: 10),
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    title,
                    style: const pw.TextStyle(fontSize: 6.5, color: textMuted),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 6.5, color: textMuted),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPageFooter({
    required int pageNumber,
    required int totalPages,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderLight, width: 1.0)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.SvgImage(svg: _svgShield, width: 9, height: 9),
              pw.SizedBox(width: 4),
              pw.Text(
                'ESTUDO DE ENGENHARIA SOLAR E PROJEÇÃO DE GERAÇÃO • MODELAGEM 3D & SOMBREAMENTO',
                style: const pw.TextStyle(fontSize: 6.8, color: textMuted),
              ),
            ],
          ),
          pw.Text(
            'Folha $pageNumber de $totalPages',
            style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: textMuted),
          ),
        ],
      ),
    );
  }

  // ── HELPERS DE CÁLCULO E TEXTO ─────────────────────────────────────────────

  static String _getCardinalDirection(double azimuth) {
    final az = (azimuth % 360.0 + 360.0) % 360.0;
    if (az >= 337.5 || az < 22.5) return 'Norte (N)';
    if (az < 67.5) return 'Nordeste (NE)';
    if (az < 112.5) return 'Leste (L)';
    if (az < 157.5) return 'Sudeste (SE)';
    if (az < 202.5) return 'Sul (S)';
    if (az < 247.5) return 'Sudoeste (SO)';
    if (az < 292.5) return 'Oeste (O)';
    return 'Noroeste (NO)';
  }

  static String _generateHourNarrative({
    required double hourOfDay,
    required double elevationDegrees,
    required double azimuthDegrees,
    required int totalModules,
    required int shadedCount,
    required double sunRatio,
  }) {
    final hourFormatted = _formatHour(hourOfDay);
    final sunCount = totalModules - shadedCount;
    final percentSol = (sunRatio * 100.0).toStringAsFixed(1);
    final percentSombra = ((1.0 - sunRatio) * 100.0).toStringAsFixed(1);
    final cardinal = _getCardinalDirection(azimuthDegrees);

    String timePeriod;
    if (hourOfDay < 10.0) {
      timePeriod = 'período matutino';
    } else if (hourOfDay <= 13.5) {
      timePeriod = 'meio-dia solar (zênite)';
    } else if (hourOfDay <= 16.0) {
      timePeriod = 'período vespertino';
    } else {
      timePeriod = 'final da tarde';
    }

    if (shadedCount == 0) {
      return 'Às $hourFormatted ($timePeriod), o Sol encontra-se com altitude angular de ${elevationDegrees.toStringAsFixed(1)}° e azimute $cardinal (${azimuthDegrees.toStringAsFixed(0)}°). O arranjo fotovoltaico opera com 100% de incidência solar direta sobre todos os $totalModules módulos instalados, com índice de sombreamento nulo (0% de perda momentânea). As placas alcançam seu potencial ótimo de geração instantânea para os níveis de irradiância desta faixa horária.';
    } else {
      return 'Às $hourFormatted ($timePeriod), com o Sol posicionado a ${elevationDegrees.toStringAsFixed(1)}° de elevação e azimute $cardinal (${azimuthDegrees.toStringAsFixed(0)}°), observa-se projeção de sombras cobrindo $shadedCount de $totalModules módulos ($percentSombra% de atenuação momentânea). Um total de $sunCount módulos ($percentSol% do gerador) permanece sob radiação direta e plena. Os diodos de bypass dos módulos e os rastreadores de máxima potência (MPPT) isolam as células afetadas, mantendo a produtividade contínua das placas ativas.';
    }
  }

  static String _formatHour(double h) {
    final hour = h.floor();
    final minute = ((h - hour) * 60).round();
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Gera o PDF e realiza o download instantâneo
  static Future<void> generateAndDownloadPdf({
    required RoofStudyModel study,
    List<RoofSection>? sections,
    DailyShadingSimulationResult? simulation,
    List<RoofStudyPhoto> photos = const [],
    CompanyModel? company,
    String? clientName,
    String? clientAddress,
    String? clientPhone,
  }) async {
    List<RoofStudyPhoto> effectivePhotos = List.from(photos);
    final bool hasValidImages =
        effectivePhotos.any((p) => p.imageBase64.trim().isNotEmpty);
    if (!hasValidImages && study.id.isNotEmpty) {
      try {
        final subPhotos = await RoofStudyRepository().getStudyPhotos(study.id);
        if (subPhotos.isNotEmpty) {
          effectivePhotos = subPhotos;
        }
      } catch (_) {}
    }

    final bytes = await generatePdfBytes(
      study: study,
      sections: sections,
      simulation: simulation,
      photos: effectivePhotos,
      company: company,
      clientName: clientName,
      clientAddress: clientAddress,
      clientPhone: clientPhone,
    );

    final cleanName = study.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .trim();
    final fileName =
        'estudo_solar_${cleanName.isNotEmpty ? cleanName : "engenharia"}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
