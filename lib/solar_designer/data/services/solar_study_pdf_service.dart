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
  /// Compila o documento PDF em bytes
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
            : (study.mapsSections.isNotEmpty ? study.mapsSections : study.droneSections));

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
      totalModules = effectiveSections.fold(0, (acc, s) => acc + s.activeModuleCount);
    }
    if (totalKwp <= 0.01 && totalModules > 0) {
      totalKwp = (totalModules * moduleWatts) / 1000.0;
    }

    final addressResolved = clientAddress?.trim().isNotEmpty == true
        ? clientAddress!
        : (study.formattedAddress.isNotEmpty
            ? study.formattedAddress
            : (study.cep != null ? 'CEP: ${study.cep}' : 'Local de Instalação Não Informado'));

    final clientResolved = clientName?.trim().isNotEmpty == true
        ? clientName!
        : (study.clientName?.isNotEmpty == true ? study.clientName! : 'Cliente');

    // Paleta de Cores PDF
    const primaryNavy = PdfColor.fromInt(0xFF0F172A);
    const accentIndigo = PdfColor.fromInt(0xFF4F46E5);
    const successEmerald = PdfColor.fromInt(0xFF059669);
    const warningAmber = PdfColor.fromInt(0xFFD97706);
    const textDark = PdfColor.fromInt(0xFF1E293B);
    const textMuted = PdfColor.fromInt(0xFF64748B);
    const borderSlate = PdfColor.fromInt(0xFFE2E8F0);
    const bgCard = PdfColor.fromInt(0xFFF8FAFC);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (pw.Context ctx) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: borderSlate, width: 1.5)),
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
                  pw.Text(
                    company?.name.toUpperCase() ?? 'MAVIS CRM • ENERGIA SOLAR',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: accentIndigo,
                    ),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ESTUDO TÉCNICO & SOMBREAMENTO 3D',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.Text(
                      'Emissão: ${_formatDateTime(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8.5, color: textMuted),
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
              border: pw.Border(top: pw.BorderSide(color: borderSlate, width: 1.0)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Mavis Solar Intelligence • Projeção Fotogramétrica e Astronômica',
                  style: const pw.TextStyle(fontSize: 8, color: textMuted),
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
                border: pw.Border.all(color: borderSlate, width: 1),
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
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryNavy,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Cliente: $clientResolved',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Endereço: $addressResolved',
                          style: const pw.TextStyle(fontSize: 9.5, color: textMuted),
                        ),
                        if (study.cep != null && study.cep!.isNotEmpty) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'CEP: ${study.cep} • ${study.stateUf ?? ""} (${study.region ?? "Brasil"})',
                            style: const pw.TextStyle(fontSize: 9.5, color: textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 1,
                    height: 54,
                    color: borderSlate,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'COORDENADAS & SOLAR',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: textMuted,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Lat: ${study.latitude.toStringAsFixed(4)}° • Long: ${study.longitude.toStringAsFixed(4)}°',
                          style: const pw.TextStyle(fontSize: 9, color: textDark),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'HSP Médio: ${study.dailyHsp?.toStringAsFixed(2) ?? "5.10"} kWh/m²/dia',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: accentIndigo,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Consultor: ${study.createdByUserName.isNotEmpty ? study.createdByUserName : (company?.name ?? "Engenharia")}',
                          style: const pw.TextStyle(fontSize: 8.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ── 2. KPIS DE DESEMPENHO E GERAÇÃO ─────────────────────────────
            pw.Row(
              children: [
                _buildKpiCard(
                  title: 'POTÊNCIA DO SISTEMA',
                  value: '${totalKwp.toStringAsFixed(2)} kWp',
                  subtitle: '$totalModules Módulos Fotovoltaicos',
                  accentColor: accentIndigo,
                ),
                pw.SizedBox(width: 10),
                _buildKpiCard(
                  title: 'GERAÇÃO ESTIMADA',
                  value: '${study.estimatedMonthlyKwh.toStringAsFixed(0)} kWh/mês',
                  subtitle: 'Média de ~${(study.estimatedMonthlyKwh * 12 / 1000).toStringAsFixed(1)} MWh/ano',
                  accentColor: successEmerald,
                ),
                pw.SizedBox(width: 10),
                _buildKpiCard(
                  title: 'APROVEITAMENTO SOLAR',
                  value: '${effectiveSimulation.overallEfficiencyPercentage.toStringAsFixed(1)}%',
                  subtitle: 'Perda p/ sombra: ${effectiveSimulation.totalLossPercentage.toStringAsFixed(1)}%',
                  accentColor: effectiveSimulation.totalLossPercentage > 8.0 ? warningAmber : successEmerald,
                ),
                pw.SizedBox(width: 10),
                _buildKpiCard(
                  title: 'ÁREA DO TELHADO',
                  value: '${totalAreaM2 > 0 ? totalAreaM2.toStringAsFixed(1) : (totalModules * 2.5).toStringAsFixed(1)} m²',
                  subtitle: 'Água(s) Ocupada(s)',
                  accentColor: primaryNavy,
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── 3. FICHA TÉCNICA DO GERADOR SOLAR ───────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: bgCard,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderSlate),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EQUIPAMENTO CONFIGURADO:',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textMuted),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '$totalModules x $moduleModel (${moduleWatts.toStringAsFixed(0)}W)',
                        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: textDark),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'HORAS DE SOL ÚTEIS EQUIVALENTES:',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textMuted),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${effectiveSimulation.effectiveSunHours.toStringAsFixed(2)} horas/dia efetivas',
                        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: accentIndigo),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // ── 4. GALERIA DE FOTOS CAPTURADAS DO ESTUDO COM BORDAS ROUNDED ─
            pw.Text(
              'REGISTRO FOTOGRÁFICO DO ESTUDO & PROJEÇÃO DE SOMBRAS',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryNavy,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Imagens capturadas no simulador tridimensional apresentando o comportamento do Sol e manchas de sombreamento mútuo.',
              style: const pw.TextStyle(fontSize: 9, color: textMuted),
            ),
            pw.SizedBox(height: 12),

            if (capturedImages.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 40),
                decoration: pw.BoxDecoration(
                  color: bgCard,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: borderSlate, style: pw.BorderStyle.dashed),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Nenhuma foto capturada durante o estudo.',
                    style: const pw.TextStyle(fontSize: 10, color: textMuted),
                  ),
                ),
              )
            else
              _buildPhotoGrid(capturedImages),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Constrói a grade visual de fotos capturadas com bordas arredondadas e legendas
  static pw.Widget _buildPhotoGrid(List<MapEntry<RoofStudyPhoto, pw.MemoryImage>> photos) {
    if (photos.length == 1) {
      final item = photos.first;
      return _buildPhotoCard(item.key, item.value, height: 260);
    }

    final rows = <pw.Widget>[];
    for (int i = 0; i < photos.length; i += 2) {
      final first = photos[i];
      final second = (i + 1 < photos.length) ? photos[i + 1] : null;

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPhotoCard(first.key, first.value, height: 180)),
            pw.SizedBox(width: 12),
            if (second != null)
              pw.Expanded(child: _buildPhotoCard(second.key, second.value, height: 180))
            else
              pw.Expanded(child: pw.Container()),
          ],
        ),
      );
      rows.add(pw.SizedBox(height: 12));
    }

    return pw.Column(children: rows);
  }

  /// Card individual de foto com moldura, cantos arredondados e etiqueta de horário
  static pw.Widget _buildPhotoCard(
    RoofStudyPhoto photo,
    pw.MemoryImage image, {
    required double height,
  }) {
    const borderSlate = PdfColor.fromInt(0xFFCBD5E1);
    const bgHeader = PdfColor.fromInt(0xFF0F172A);

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
            pw.Container(
              height: height,
              color: const PdfColor.fromInt(0xFF020617),
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const PdfColor.fromInt(0xFFF1F5F9),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    photo.label.isNotEmpty ? photo.label : 'Simulação Solar',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: bgHeader,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFF38BDF8),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      _formatHour(photo.hourOfDay),
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF64748B)),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF64748B)),
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
    final fileName = 'estudo_solar_${cleanName.isNotEmpty ? cleanName : "mavis"}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
