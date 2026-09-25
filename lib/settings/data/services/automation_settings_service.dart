import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../../domain/models/automation_settings_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import 'automation_preset_catalog.dart';
import 'company_service.dart';

/// Modelo de Capa Vertical Split de Automação com divisor geométrico e tipografia estilizada
class VerticalSplitCoverModel {
  final String id;
  final String name;
  final int dividerType; // 0 = Diagonal, 1 = Raio de Energia, 2 = Sol/Arco
  final String imageName;
  final String headline;
  final String subheadline;
  final String rightTitle;
  final String rightSubtitle;
  final String rightTagline;
  final String rightFooter;
  final String accentColor;

  const VerticalSplitCoverModel({
    required this.id,
    required this.name,
    required this.dividerType,
    required this.imageName,
    required this.headline,
    required this.subheadline,
    this.rightTitle = 'PROPOSTA',
    this.rightSubtitle = 'AUTOMAÇÃO',
    required this.rightTagline,
    required this.rightFooter,
    this.accentColor = '#38BDF8',
  });
}

class AutomationSettingsService {
  static const _storageBaseUrl = 'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o';
  static final Map<String, Uint8List> _coverBytesCache = {};
  static final Map<String, Uint8List> _webBgBytesCache = {};

  AutomationSettingsService();

  /// Invalida entradas no cache de imagem
  static void invalidateCoverCache(String url) {
    final cleanUrl = url.trim();
    _coverBytesCache.remove(cleanUrl);
    final cleanName = cleanUrl
        .replaceFirst('assets/modelo_propostas/', '')
        .replaceFirst('capas/automacao/', '')
        .replaceFirst('capas/energiasolar/', '');
    _coverBytesCache.remove(cleanName);
  }

  /// Retorna a URL direta no Firebase Storage da capa de Automação (Thumbnail/Small)
  static String getSmallCoverUrl(String fileName) {
    return getBigCoverUrl(fileName);
  }

  /// Retorna a URL direta no Firebase Storage da capa de Automação (Alta Resolução)
  static String getBigCoverUrl(String fileName) {
    return getWebBackgroundUrl(fileName);
  }

  /// Retorna a URL bruta do Firebase Storage (sem proxy CORS)
  static String getRawStorageUrl(String fileName) {
    return getBigCoverUrl(fileName);
  }

  /// Retorna a URL do papel de parede de Automação no Firebase Storage
  static String getWebBackgroundUrl(String fileName) {
    final clean = fileName.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    final cleanName = clean.isEmpty
        ? 'modelo_automacao_1.jpg'
        : clean
            .replaceFirst('assets/background_web/', '')
            .replaceFirst('assets/wallpaper_propostas/', '')
            .replaceFirst('wallpapers/automacao/', '')
            .replaceFirst('wallpapers/energiasolar/', '')
            .replaceFirst('capas/automacao/', '')
            .replaceFirst('capas/energiasolar/', '');

    if (cleanName.startsWith('modelo_automacao_')) {
      final encoded = Uri.encodeComponent('capas/automacao/$cleanName');
      return '$_storageBaseUrl/$encoded?alt=media';
    }
    if (cleanName.startsWith('modelo_proposta_')) {
      final encoded = Uri.encodeComponent('capas/energiasolar/$cleanName');
      return '$_storageBaseUrl/$encoded?alt=media';
    }

    final encoded = Uri.encodeComponent('wallpapers/energiasolar/$cleanName');
    return '$_storageBaseUrl/$encoded?alt=media';
  }

  /// Baixa e armazena em cache na memória os bytes da capa do Firebase Storage
  static Future<Uint8List?> fetchCoverBytes(String fileName) async {
    final clean = fileName.trim();
    if (clean.isEmpty) return null;

    // 1. Base64
    if (clean.contains('base64,') || clean.startsWith('data:image')) {
      try {
        final raw = clean.contains(',') ? clean.split(',').last.trim() : clean;
        final bytes = base64Decode(raw);
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {}
    }

    // 2. Asset Local
    if (clean.startsWith('assets/')) {
      try {
        final data = await rootBundle.load(clean);
        final bytes = data.buffer.asUint8List();
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {}
    }

    final cleanName = clean
        .replaceFirst('assets/modelo_propostas/', '')
        .replaceFirst('capas/automacao/', '')
        .replaceFirst('capas/energiasolar/', '');

    if (_coverBytesCache.containsKey(cleanName)) {
      return _coverBytesCache[cleanName];
    }

    // 3. Download HTTP Direto do Firebase Storage
    try {
      final url = getBigCoverUrl(cleanName);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        _coverBytesCache[cleanName] = bytes;
        return bytes;
      }
    } catch (_) {}

    // 4. Fallback via proxy wsrv.nl (forçando output=jpg para compatibilidade total com o motor PDF)
    try {
      final url = getBigCoverUrl(cleanName);
      final wsrvUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}&output=jpg';
      final response = await http.get(Uri.parse(wsrvUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        _coverBytesCache[cleanName] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('[AutomationSettingsService] Erro ao baixar capa $cleanName: $e');
    }

    // 5. Fallback via fetchWebBackgroundBytes
    try {
      final bytes = await fetchWebBackgroundBytes(cleanName);
      if (bytes != null && bytes.isNotEmpty) {
        _coverBytesCache[cleanName] = bytes;
        return bytes;
      }
    } catch (_) {}

    return null;
  }

  /// Baixa e armazena em cache os bytes do papel de parede (Web Background)
  static Future<Uint8List?> fetchWebBackgroundBytes(String fileName) async {
    final clean = fileName.trim();
    final cleanName = clean.isEmpty
        ? 'AdobeStock_1030854734.jpg'
        : clean
            .replaceFirst('assets/background_web/', '')
            .replaceFirst('assets/wallpaper_propostas/', '')
            .replaceFirst('wallpapers/automacao/', '')
            .replaceFirst('wallpapers/energiasolar/', '');

    if (_webBgBytesCache.containsKey(cleanName)) {
      return _webBgBytesCache[cleanName];
    }

    try {
      final url = getWebBackgroundUrl(cleanName);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        _webBgBytesCache[cleanName] = bytes;
        return bytes;
      }
    } catch (_) {}

    try {
      final url = getWebBackgroundUrl(cleanName);
      final wsrvUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}&output=jpg';
      final response = await http.get(Uri.parse(wsrvUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        _webBgBytesCache[cleanName] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('[AutomationSettingsService] Erro ao baixar wallpaper $cleanName: $e');
    }

    return null;
  }

  /// Lista das 100 capas padrão de Automação no Firebase Storage
  static List<String> getDefaultCoverList() {
    final list = <String>[];
    for (int i = 1; i <= 100; i++) {
      list.add('modelo_automacao_$i.jpg');
    }
    return list;
  }

  /// Lista dos 34 papéis de parede HD disponíveis
  static List<String> getDefaultWebBackgroundList() {
    return AutomationSettingsModel.availableWebBackgrounds;
  }

  /// Lista dos 100 modelos de capas no "Estilo Vertical Split" para Automação Residencial
  static List<VerticalSplitCoverModel> getDefaultVerticalSplitList() {
    final webBgs = getDefaultWebBackgroundList();
    final headlines = [
      {
        'h': 'A CASA QUE\nENTENDE\nVOCÊ',
        's': 'ARQUITETURA, CONFORTO\nE TECNOLOGIA\nEM UMA EXPERIÊNCIA ÚNICA.',
        't': 'PROJETO DE AUTOMAÇÃO\nRESIDENCIAL HIGH-END',
        'f': 'CONFORTO HOJE.\nMAIS INTELIGÊNCIA\nAMANHÃ.',
      },
      {
        'h': 'TECNOLOGIA\nQUE TRANSFORMA\nO SEU LAR',
        's': 'ILUMINAÇÃO CÊNICA.\nÁUDIO MULTIROOM.\nCLIMATIZAÇÃO INTELIGENTE.',
        't': 'ENGENHARIA E DESIGN\nINTEGRADOS AO SEU ESTILO',
        'f': 'INTELIGÊNCIA RESIDENCIAL\nDO CONCEITO À ENTREGA.',
      },
      {
        'h': 'VIVA O\nFUTURO\nHOJE',
        's': 'CONTROLE TOTAL.\nSEGURANÇA INTELIGENTE.\nSOFISTICAÇÃO.',
        't': 'SOLUÇÕES EXCLUSIVAS\nEM AUTOMAÇÃO RESIDENCIAL',
        'f': 'ARQUITETURA & TECNOLOGIA\nEM HARMONIA PERFEITA.',
      },
      {
        'h': 'CONFORTO\nNA PALMA\nDA SUA MÃO',
        's': 'CENAS PERSONALIZADAS.\nEFICIÊNCIA ENERGÉTICA.\nEXPERIÊNCIA IMERSIVA.',
        't': 'SISTEMAS INTEGRADOS\nDE ALTA PERFORMANCE',
        'f': 'TECNOLOGIA INVISÍVEL.\nBEM-ESTAR INCOMPARÁVEL.',
      },
      {
        'h': 'INTELIGÊNCIA\nE DESIGN\nEM HARMONIA',
        's': 'HOME CINEMA HIGH-END.\nACESSO BIOMÉTRICO.\nREDE MESH GIGABIT.',
        't': 'ARQUITETURA HIGH-TECH\nPARA CLIENTES EXIGENTES',
        'f': 'SEGURANÇA E ELEGÂNCIA\nINTEGRADAS COM PRECISÃO.',
      },
      {
        'h': 'EXPERIÊNCIA\nRESIDENCIAL\nDEFINITIVA',
        's': 'AUTOMAÇÃO COMPLETA.\nÁUDIO HIGH-FIDELITY.\nCLIMATIZAÇÃO HVAC.',
        't': 'ENGENHARIA ELETRÔNICA\nDE ALTO PADRÃO',
        'f': 'TRANSFORME A SUA CASA\nEM UM REFÚGIO INTELIGENTE.',
      },
    ];

    final list = <VerticalSplitCoverModel>[];
    for (int i = 1; i <= 100; i++) {
      final divType = (i - 1) % 3;
      final bgImg = webBgs[(i - 1) % webBgs.length];
      final textPreset = headlines[(i - 1) % headlines.length];

      String typeName;
      switch (divType) {
        case 1:
          typeName = 'Raio Tech';
          break;
        case 2:
          typeName = 'Arco Curvo';
          break;
        case 0:
        default:
          typeName = 'Corte Diagonal';
          break;
      }

      list.add(VerticalSplitCoverModel(
        id: 'auto_vertical_split_$i',
        name: '$typeName #$i',
        dividerType: divType,
        imageName: bgImg,
        headline: textPreset['h']!,
        subheadline: textPreset['s']!,
        rightTagline: textPreset['t']!,
        rightFooter: textPreset['f']!,
        accentColor: '#38BDF8',
      ));
    }
    return list;
  }

  /// Lista dos estilos de separadores geométricos / decalques
  static List<Map<String, dynamic>> getAvailableDividers() {
    return const [
      {'id': -1, 'name': 'Sem Divisor (Foto Completa)', 'desc': 'Exibe a imagem inteira em tela cheia, sem recorte geométrico'},
      {'id': 0, 'name': 'Onda Suave Clássica (S-Curve)', 'desc': 'Curva orgânica fluida com fita de destaque ciano'},
      {'id': 1, 'name': 'Onda Dupla Harmônica', 'desc': 'Duas ondas high-tech intersectantes'},
      {'id': 2, 'name': 'Corte Diagonal Moderno', 'desc': 'Design angular cibernético com fita tripla'},
      {'id': 3, 'name': 'Polígonos Facetados (Chevron)', 'desc': 'Geometria cristalina com vértices dinâmicos'},
      {'id': 4, 'name': 'Arco Aerodinâmico Côncavo', 'desc': 'Arco estilizado parabólico ascendente'},
      {'id': 5, 'name': 'Declive Arquitetônico Minimalista', 'desc': 'Ângulos inspirados na arquitetura contemporânea'},
      {'id': 6, 'name': 'Cascata Tripla de Ondas', 'desc': 'Três ondulações ritmadas em degradê suave'},
      {'id': 7, 'name': 'Hexágono Tech Futurista', 'desc': 'Geometria chanfrada com alta identidade visual'},
      {'id': 8, 'name': 'Split Screen Vertical Sólido', 'desc': 'Divisão lateral limpa estilo editorial A4'},
      {'id': 9, 'name': 'Fita Curva Senoidal Tripla', 'desc': 'Três faixas dinâmicas paralelas decorativas'},
    ];
  }

  /// Salva as configurações no Firestore (Método Estático)
  static Future<void> saveSettings(AutomationSettingsModel settings) async {
    try {
      String id = settings.companyId.trim();
      if (id.isEmpty) {
        final auth = AuthRepository();
        id = (await auth.getCurrentCompanyId()) ?? '';
      }
      if (id.isEmpty) {
        final user = await AuthRepository().getCurrentUser();
        id = user?.companyId ?? '';
      }
      if (id.isEmpty) id = 'default_company';

      final finalSettings = settings.companyId != id ? settings.copyWith(companyId: id) : settings;

      await FirebaseFirestore.instance
          .collection('automation_settings')
          .doc(id)
          .set(finalSettings.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AutomationSettingsService] Erro ao salvar configurações: $e');
    }
  }

  static Future<AutomationSettingsModel> loadSettings({String? companyId}) async {
    AutomationSettingsModel? model;
    String id = companyId?.trim() ?? '';
    try {
      if (id.isEmpty) {
        final auth = AuthRepository();
        id = (await auth.getCurrentCompanyId()) ?? '';
      }
      if (id.isEmpty) {
        final user = await AuthRepository().getCurrentUser();
        id = user?.companyId ?? '';
      }
      if (id.isEmpty) id = 'default_company';

      final doc = await FirebaseFirestore.instance.collection('automation_settings').doc(id).get();
      if (doc.exists && doc.data() != null) {
        final loaded = AutomationSettingsModel.fromMap(doc.data()!);
        model = loaded.copyWith(companyId: loaded.companyId.isNotEmpty ? loaded.companyId : id);
      }
      // Se não encontrou pelo id específico, tenta fallback em 'default_company'
      if (model == null && id != 'default_company') {
        final fallbackDoc = await FirebaseFirestore.instance.collection('automation_settings').doc('default_company').get();
        if (fallbackDoc.exists && fallbackDoc.data() != null) {
          final loaded = AutomationSettingsModel.fromMap(fallbackDoc.data()!);
          model = loaded.copyWith(companyId: id);
        }
      }
    } catch (e) {
      debugPrint('[AutomationSettingsService] Erro ao carregar configurações: $e');
    }

    AutomationSettingsModel finalModel = model ?? AutomationSettingsModel(companyId: id);

    // ── INTEGRAÇÃO COM CADASTRO OFICIAL DA EMPRESA (CNPJ / RECEITA) ──
    // Se os dados da empresa estiverem vazios ou com o placeholder fictício mockado ('ARBO AUTOMAÇÃO'),
    // busca os dados reais da empresa cadastrada no CompanyService.
    final bool needsCompanySync = finalModel.companyName.isEmpty ||
        finalModel.companyName == 'ARBO AUTOMAÇÃO' ||
        finalModel.companyDoc == '12.345.678/0001-90';

    if (needsCompanySync) {
      try {
        final company = await CompanyService.getCompany(companyId: id != 'default_company' ? id : null);
        if (company != null && (company.name.isNotEmpty || company.document.isNotEmpty)) {
          final effectiveName = company.tradeName?.trim().isNotEmpty == true
              ? company.tradeName!.trim()
              : (company.name.trim().isNotEmpty ? company.name.trim() : (company.corporateName ?? finalModel.companyName));

          finalModel = finalModel.copyWith(
            companyName: effectiveName.isNotEmpty ? effectiveName : finalModel.companyName,
            companyDoc: company.document.isNotEmpty ? company.document : finalModel.companyDoc,
            companyPhone: company.phone.isNotEmpty ? company.phone : finalModel.companyPhone,
            companyEmail: (company.email?.isNotEmpty == true ? company.email : company.companyEmail) ?? finalModel.companyEmail,
            companyWebsite: company.website?.isNotEmpty == true ? company.website! : finalModel.companyWebsite,
            companyInstagram: company.instagram?.isNotEmpty == true ? company.instagram! : finalModel.companyInstagram,
            companySlogan: company.slogan?.isNotEmpty == true ? company.slogan! : finalModel.companySlogan,
            companyLogoBase64: company.logoBase64 ?? finalModel.companyLogoBase64,
            cep: company.zipCode?.isNotEmpty == true ? company.zipCode! : finalModel.cep,
            logradouro: company.street?.isNotEmpty == true ? company.street! : finalModel.logradouro,
            numero: company.number?.isNotEmpty == true ? company.number! : finalModel.numero,
            complemento: company.complement?.isNotEmpty == true ? company.complement! : finalModel.complemento,
            bairro: company.neighborhood?.isNotEmpty == true ? company.neighborhood! : finalModel.bairro,
            cidade: company.city?.isNotEmpty == true ? company.city! : finalModel.cidade,
            uf: company.state?.isNotEmpty == true ? company.state! : finalModel.uf,
          );
        }
      } catch (e) {
        debugPrint('[AutomationSettingsService] Falha ao hidratar com dados da empresa: $e');
      }
    }

    return finalModel;
  }

  /// Busca a lista dinâmica de capas de automação
  static Future<List<String>> fetchAvailableCovers() async {
    return getDefaultCoverList();
  }

  /// Obtém a configuração de automação da empresa
  Future<AutomationSettingsModel> fetchSettings(String companyId) async {
    return loadSettings(companyId: companyId);
  }

  /// Aplica um preset do catálogo e ajusta o modelo
  AutomationSettingsModel applyPreset(AutomationSettingsModel current, String presetId) {
    final preset = AutomationPresetCatalog.getPresetById(presetId);
    return current.copyWith(
      activeCategory: preset.category,
      activePresetId: preset.id,
      isFullPhoto: preset.isFullPhoto,
      customDividerStyle: preset.customDividerStyle,
      coverTag: preset.coverTag,
      coverHeadline: preset.headline,
      coverSubheadline: preset.subheadline,
      coverImageUrl: preset.imageUrl,
      selectedCoverTemplate: preset.imageUrl,
      primaryColorHex: preset.primaryColorHex,
      nodes: preset.defaultNodes.isNotEmpty ? preset.defaultNodes : current.nodes,
    );
  }
}
