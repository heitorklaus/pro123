import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/domain/models/company_model.dart';
import '../../domain/models/roof_study_model.dart';
import '../../domain/models/solar_designer_models.dart';
import '../../domain/services/solar_shading_engine.dart';

/// Serviço de Geração e Emissão de PDF para Estudo de Telhado & Sombreamento Solar
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

  /// Compila o documento PDF em bytes com design executivo premium e ícones vetoriais
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
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final effectiveSections = (sections != null && sections.isNotEmpty)
        ? sections
        : (study.sections.isNotEmpty
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
    final photosToProcess = photos.isNotEmpty ? photos : study.studyPhotos;

    for (final p in photosToProcess) {
      try {
        final cleanB64 = p.imageBase64.contains(',')
            ? p.imageBase64.split(',').last
            : p.imageBase64;
        final bytes = base64Decode(cleanB64);
        capturedImages.add(MapEntry(p, pw.MemoryImage(bytes)));
      } catch (e) {
        debugPrint('[SolarStudyPdfService] Erro ao decodificar foto ${p.id}: $e');
      }
    }

    // Dados consolidados dos módulos
    int totalModules = study.totalModulesCount;
    double totalKwp = study.totalKwp;
    double totalAreaM2 = 0;
    String moduleModel = 'Módulo Fotovoltaico Standard';
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

    // Paleta de Cores Premium
    const primaryNavy = PdfColor.fromInt(0xFF0F172A);
    const accentIndigo = PdfColor.fromInt(0xFF4F46E5);
    const accentSky = PdfColor.fromInt(0xFF0284C7);
    const successEmerald = PdfColor.fromInt(0xFF059669);
    const warningAmber = PdfColor.fromInt(0xFFD97706);
    const textDark = PdfColor.fromInt(0xFF1E293B);
    const textMuted = PdfColor.fromInt(0xFF64748B);
    const borderSlate = PdfColor.fromInt(0xFFE2E8F0);
    const bgCard = PdfColor.fromInt(0xFFF8FAFC);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (pw.Context ctx) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: borderSlate, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (companyLogo != null)
                  pw.Container(
                    height: 38,
                    child: pw.Image(companyLogo, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFEEF2FF),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.SvgImage(svg: _svgSun, width: 16, height: 16),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        company?.name.toUpperCase() ??
                            'MAVIS CRM • ENERGIA SOLAR',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: accentIndigo,
                        ),
                      ),
                    ],
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFF0F172A),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        'ESTUDO TÉCNICO & SOMBREAMENTO',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Emissão: ${_formatDateTime(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(top: pw.BorderSide(color: borderSlate, width: 1.0)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.SvgImage(svg: _svgShield, width: 10, height: 10),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      'Mavis Solar Engineering • Simulação Fotogramétrica Tridimensional',
                      style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                    ),
                  ],
                ),
                pw.Text(
                  'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: textMuted),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            // ── 1. CABEÇALHO DO ESTUDO & CLIENTE ────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: bgCard,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: borderSlate, width: 1.2),
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
                          study.name.isNotEmpty
                              ? study.name
                              : 'Estudo de Viabilidade Solar',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryNavy,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          children: [
                            pw.SvgImage(svg: _svgUser, width: 11, height: 11),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              child: pw.Text(
                                clientResolved,
                                style: pw.TextStyle(
                                  fontSize: 10.5,
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
                            pw.SvgImage(svg: _svgPin, width: 11, height: 11),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              child: pw.Text(
                                addressResolved,
                                style: const pw.TextStyle(
                                    fontSize: 9, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                        if (study.cep != null && study.cep!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 16),
                            child: pw.Text(
                              'CEP: ${study.cep} • ${study.stateUf ?? ""} (${study.region ?? "Brasil"})',
                              style: const pw.TextStyle(
                                  fontSize: 8.5, color: textMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 1,
                    height: 56,
                    color: borderSlate,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.SvgImage(svg: _svgCompass, width: 11, height: 11),
                            pw.SizedBox(width: 5),
                            pw.Text(
                              'COORDENADAS & SOLAR',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Lat: ${study.latitude.toStringAsFixed(4)}° • Long: ${study.longitude.toStringAsFixed(4)}°',
                          style: const pw.TextStyle(fontSize: 8.5, color: textDark),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          children: [
                            pw.SvgImage(svg: _svgSun, width: 10, height: 10),
                            pw.SizedBox(width: 4),
                            pw.Text(
                              'HSP: ${study.dailyHsp?.toStringAsFixed(2) ?? "5.10"} kWh/m²/dia',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: accentSky,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Responsável: ${study.createdByUserName.isNotEmpty ? study.createdByUserName : (company?.name ?? "Engenharia")}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ── 2. KPIS DE DESEMPENHO E GERAÇÃO COM ÍCONES VETORIAIS ────────
            pw.Row(
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
                  value:
                      '${study.estimatedMonthlyKwh.toStringAsFixed(0)} kWh/mês',
                  subtitle:
                      'Média ~${(study.estimatedMonthlyKwh * 12 / 1000).toStringAsFixed(1)} MWh/ano',
                  accentColor: successEmerald,
                  iconSvg: _svgSun,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'APROVEITAMENTO SOLAR',
                  value:
                      '${effectiveSimulation.overallEfficiencyPercentage.toStringAsFixed(1)}%',
                  subtitle:
                      'Perda p/ sombra: ${effectiveSimulation.totalLossPercentage.toStringAsFixed(1)}%',
                  accentColor: effectiveSimulation.totalLossPercentage > 8.0
                      ? warningAmber
                      : successEmerald,
                  iconSvg: _svgChart,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'ÁREA DO TELHADO',
                  value:
                      '${totalAreaM2 > 0 ? totalAreaM2.toStringAsFixed(1) : (totalModules * 2.5).toStringAsFixed(1)} m²',
                  subtitle: '${effectiveSections.length} Água(s) de Telhado',
                  accentColor: primaryNavy,
                  iconSvg: _svgRuler,
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // ── 3. FICHA TÉCNICA DO GERADOR SOLAR ───────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderSlate),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.SvgImage(svg: _svgPanel, width: 14, height: 14),
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'EQUIPAMENTO CONFIGURADO:',
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: textMuted),
                          ),
                          pw.Text(
                            '$totalModules x $moduleModel (${moduleWatts.toStringAsFixed(0)}W)',
                            style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.SvgImage(svg: _svgSun, width: 14, height: 14),
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'HORAS DE SOL PLENO ÚTEIS:',
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: textMuted),
                          ),
                          pw.Text(
                            '${effectiveSimulation.effectiveSunHours.toStringAsFixed(2)} h/dia efetivas',
                            style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: accentSky),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ── 4. GALERIA DE FOTOS CAPTURADAS DO ESTUDO COM BORDAS ROUNDED ─
            pw.Row(
              children: [
                pw.SvgImage(svg: _svgCamera, width: 14, height: 14),
                pw.SizedBox(width: 6),
                pw.Text(
                  'REGISTRO FOTOGRÁFICO DO ESTUDO & PROJEÇÃO DE SOMBRAS',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryNavy,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Imagens capturadas no simulador tridimensional apresentando o comportamento do Sol e manchas de sombreamento.',
              style: const pw.TextStyle(fontSize: 8.5, color: textMuted),
            ),
            pw.SizedBox(height: 10),

            if (capturedImages.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 36),
                decoration: pw.BoxDecoration(
                  color: bgCard,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(
                      color: borderSlate, style: pw.BorderStyle.dashed),
                ),
                child: pw.Center(
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.SvgImage(svg: _svgCamera, width: 28, height: 28),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Nenhuma foto capturada durante o estudo.',
                        style: const pw.TextStyle(
                            fontSize: 9.5, color: textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildPhotoGrid(capturedImages, latitude: study.latitude),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Constrói a grade visual de fotos capturadas com bordas arredondadas, ícones e legendas
  static pw.Widget _buildPhotoGrid(
    List<MapEntry<RoofStudyPhoto, pw.MemoryImage>> photos, {
    required double latitude,
  }) {
    if (photos.length == 1) {
      final item = photos.first;
      return _buildPhotoCard(item.key, item.value, height: 250, latitude: latitude);
    }

    final rows = <pw.Widget>[];
    for (int i = 0; i < photos.length; i += 2) {
      final first = photos[i];
      final second = (i + 1 < photos.length) ? photos[i + 1] : null;

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
                child: _buildPhotoCard(first.key, first.value,
                    height: 165, latitude: latitude)),
            pw.SizedBox(width: 10),
            if (second != null)
              pw.Expanded(
                  child: _buildPhotoCard(second.key, second.value,
                      height: 165, latitude: latitude))
            else
              pw.Expanded(child: pw.Container()),
          ],
        ),
      );
      rows.add(pw.SizedBox(height: 10));
    }

    return pw.Column(children: rows);
  }

  /// Card individual de foto com moldura, cantos arredondados, ícone de relógio e métrica solar
  static pw.Widget _buildPhotoCard(
    RoofStudyPhoto photo,
    pw.MemoryImage image, {
    required double height,
    required double latitude,
  }) {
    const borderSlate = PdfColor.fromInt(0xFFCBD5E1);
    const bgHeader = PdfColor.fromInt(0xFF0F172A);

    final sun = SolarShadingEngine.calculateSunPosition(
      hourOfDay: photo.hourOfDay,
      latitude: latitude,
    );

    final String solarInfo = sun.isSunUp
        ? 'Alt: ${sun.elevationDegrees.toStringAsFixed(1)}° • Az: ${sun.azimuthDegrees.toStringAsFixed(0)}°'
        : 'Sol abaixo do horizonte';

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: borderSlate, width: 1.2),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 10,
        verticalRadius: 10,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Topo da Foto com Título e Tag de Horário com Ícone de Relógio
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: const PdfColor.fromInt(0xFFF8FAFC),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        pw.SvgImage(svg: _svgCamera, width: 11, height: 11),
                        pw.SizedBox(width: 5),
                        pw.Expanded(
                          child: pw.Text(
                            photo.label.isNotEmpty
                                ? photo.label
                                : 'Simulação Solar',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: bgHeader,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFE0F2FE),
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(
                          color: const PdfColor.fromInt(0xFF38BDF8), width: 0.8),
                    ),
                    child: pw.Row(
                      children: [
                        pw.SvgImage(svg: _svgClock, width: 9, height: 9),
                        pw.SizedBox(width: 3),
                        pw.Text(
                          _formatHour(photo.hourOfDay),
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF0369A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Imagem capturada com fundo escuro elegante
            pw.Container(
              height: height,
              color: const PdfColor.fromInt(0xFF020617),
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            ),

            // Barra inferior com dados de posição solar astronômica
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: const PdfColor.fromInt(0xFF0F172A),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.SvgImage(svg: _svgSun, width: 9, height: 9),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        solarInfo,
                        style: const pw.TextStyle(
                            fontSize: 7.5, color: PdfColor.fromInt(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Simulação 3D',
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF38BDF8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de KPI individual estilizado com ícone vetorial
  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
    required String iconSvg,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor(
                      accentColor.red,
                      accentColor.green,
                      accentColor.blue,
                      0.15,
                    ),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.SvgImage(svg: iconSvg, width: 12, height: 12),
                ),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: pw.Text(
                    title,
                    style: const pw.TextStyle(
                        fontSize: 6.8,
                        color: PdfColor.fromInt(0xFF64748B)),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(
                  fontSize: 6.8, color: PdfColor.fromInt(0xFF64748B)),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
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
    final bytes = await generatePdfBytes(
      study: study,
      sections: sections,
      simulation: simulation,
      photos: photos,
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
        'estudo_solar_${cleanName.isNotEmpty ? cleanName : "mavis"}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
