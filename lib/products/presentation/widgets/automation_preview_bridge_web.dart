// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:mavis/products/domain/models/product_model.dart';
import 'package:mavis/products/presentation/widgets/automation_proposal_customizer_dialog.dart';

/// Ponte Web para transferência de rascunhos de propostas e modelos 3D pesados
/// com persistência em IndexedDB (sem limite de 5MB do localStorage).
class AutomationPreviewBridge {
  static ProductModel? activeProduct;
  static AutomationProposalThemeConfig? activeTheme;
  static String? latestGlbDataUrl;
  static String? latestGlbFileName;

  static const String _dbName = 'mavis_automation_db';
  static const int _dbVersion = 3;
  static const String _storeStudies = 'preview_store';
  static const String _storeModels = 'models_store';

  static Future<dynamic> _openDb() async {
    try {
      final idb = html.window.indexedDB;
      if (idb == null) return null;
      return await idb.open(
        _dbName,
        version: _dbVersion,
        onUpgradeNeeded: (e) {
          final dynamic db = (e.target as dynamic).result;
          if (!db.objectStoreNames.contains(_storeStudies)) {
            db.createObjectStore(_storeStudies);
          }
          if (!db.objectStoreNames.contains(_storeModels)) {
            db.createObjectStore(_storeModels);
          }
        },
      );
    } catch (_) {
      return null;
    }
  }

  /// Salva os bytes reais do arquivo 3D no IndexedDB e cria Blob URL para uso imediato
  static Future<void> save3DModelBytes(String fileName, Uint8List bytes, [String? studyId]) async {
    latestGlbFileName = fileName;

    // Cria Blob URL direto no contexto Web da aba atual
    try {
      final blob = html.Blob([bytes], 'model/gltf-binary');
      final blobUrl = '${html.Url.createObjectUrlFromBlob(blob)}#model.glb';
      latestGlbDataUrl = blobUrl;
    } catch (_) {}

    // Converte para Base64 para persistência segura em IndexedDB
    final base64String = base64Encode(bytes);

    try {
      final dynamic db = await _openDb();
      if (db != null) {
        final dynamic tx = db.transaction(_storeModels, 'readwrite');
        final dynamic store = tx.objectStore(_storeModels);
        store.put(base64String, 'global_active_glb_base64');
        store.put(fileName, 'global_active_glb_name');
        store.put(bytes, 'global_active_glb_bytes');

        if (studyId != null && studyId.isNotEmpty && studyId != 'preview' && studyId != 'draft') {
          store.put(base64String, 'base64_$studyId');
          store.put(fileName, 'name_$studyId');
          store.put(bytes, 'bytes_$studyId');
        }
        await tx.completed;
      }
    } catch (_) {}
  }

  /// Recupera o Blob URL para renderização no `<model-viewer>` a partir do IndexedDB
  static Future<String?> get3DModelBlobUrl([String? studyId]) async {
    if (latestGlbDataUrl != null &&
        latestGlbDataUrl!.isNotEmpty &&
        !latestGlbDataUrl!.startsWith('indexeddb:')) {
      return latestGlbDataUrl;
    }

    try {
      final dynamic db = await _openDb();
      if (db != null) {
        final dynamic tx = db.transaction(_storeModels, 'readonly');
        final dynamic store = tx.objectStore(_storeModels);

        dynamic raw;
        if (studyId != null && studyId.isNotEmpty && studyId != 'preview' && studyId != 'draft') {
          try {
            raw = await store.getObject('base64_$studyId');
          } catch (_) {}
          if (raw == null) {
            try {
              raw = await store.getObject('bytes_$studyId');
            } catch (_) {}
          }
        }

        if (raw == null) {
          try {
            raw = await store.getObject('global_active_glb_base64');
          } catch (_) {}
        }
        if (raw == null) {
          try {
            raw = await store.getObject('global_active_glb_bytes');
          } catch (_) {}
        }

        Uint8List? bytes;
        if (raw is String && raw.isNotEmpty) {
          final clean = raw.startsWith('data:') ? raw.substring(raw.indexOf(',') + 1) : raw;
          bytes = base64Decode(clean);
        } else if (raw is Uint8List) {
          bytes = raw;
        } else if (raw is ByteBuffer) {
          bytes = raw.asUint8List();
        } else if (raw is List) {
          bytes = Uint8List.fromList(List<int>.from(raw));
        }

        if (bytes != null && bytes.isNotEmpty) {
          final blob = html.Blob([bytes], 'model/gltf-binary');
          final blobUrl = '${html.Url.createObjectUrlFromBlob(blob)}#model.glb';
          latestGlbDataUrl = blobUrl;
          return blobUrl;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Resolve e injeta o modelo 3D no tema do produto garantindo renderização
  static Future<ProductModel> resolve3DModelForProduct(ProductModel product) async {
    final attrs = Map<String, dynamic>.from(product.specificAttributes);
    var themeMap = <String, dynamic>{};
    if (attrs['proposalTheme'] is Map) {
      themeMap = Map<String, dynamic>.from(attrs['proposalTheme'] as Map);
    }

    final rawGlb = themeMap['glbModelUrl']?.toString();
    final hasExistingValid = rawGlb != null &&
        rawGlb.trim().isNotEmpty &&
        !rawGlb.startsWith('indexeddb:') &&
        (rawGlb.startsWith('http') || rawGlb.startsWith('blob:') || rawGlb.startsWith('data:') || rawGlb.startsWith('assets/'));

    if (hasExistingValid) {
      themeMap['hasGlbModel'] = true;
      attrs['proposalTheme'] = themeMap;
      return product.copyWith(specificAttributes: attrs);
    }

    // Busca o Blob URL persistido no IndexedDB
    final resolvedUrl = await get3DModelBlobUrl(product.id);
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      themeMap['glbModelUrl'] = resolvedUrl;
      themeMap['hasGlbModel'] = true;
      if (latestGlbFileName != null && latestGlbFileName!.isNotEmpty) {
        themeMap['glbFileName'] = latestGlbFileName;
      }
      attrs['proposalTheme'] = themeMap;
      return product.copyWith(specificAttributes: attrs);
    }

    return product;
  }

  /// Salva dados do rascunho de forma resiliente no IndexedDB
  static Future<void> savePreviewData(ProductModel product) async {
    activeProduct = product;

    // Se o produto tiver tema com GLB, registra na memória e no IndexedDB
    final attrs = product.specificAttributes;
    if (attrs['proposalTheme'] is Map) {
      final themeMap = Map<String, dynamic>.from(attrs['proposalTheme'] as Map);
      final glbUrl = themeMap['glbModelUrl']?.toString();
      final fileName = themeMap['glbFileName']?.toString() ?? 'modelo.glb';

      if (glbUrl != null && glbUrl.startsWith('data:')) {
        latestGlbDataUrl = glbUrl;
        latestGlbFileName = fileName;
        try {
          final comma = glbUrl.indexOf(',');
          final base64Str = comma != -1 ? glbUrl.substring(comma + 1) : glbUrl;
          final dynamic db = await _openDb();
          if (db != null) {
            final dynamic tx = db.transaction(_storeModels, 'readwrite');
            final dynamic store = tx.objectStore(_storeModels);
            store.put(base64Str, 'global_active_glb_base64');
            store.put(fileName, 'global_active_glb_name');
            if (product.id.isNotEmpty && product.id != 'preview_mode') {
              store.put(base64Str, 'base64_${product.id}');
              store.put(fileName, 'name_${product.id}');
            }
            await tx.completed;
          }
        } catch (_) {}
      } else if (glbUrl != null && glbUrl.startsWith('blob:')) {
        latestGlbDataUrl = glbUrl;
        latestGlbFileName = fileName;
      }
    }

    // Serializa produto (omitindo base64 gigante do JSON para não sobrecarregar)
    final safeProduct = _stripLargeGlbFromJson(product);
    final map = safeProduct.toMap();
    map['id'] = product.id;
    map['createdAt'] = product.createdAt.toIso8601String();
    map['updatedAt'] = product.updatedAt.toIso8601String();
    final jsonStr = jsonEncode(map);

    try {
      html.window.sessionStorage['mavis_automation_preview_study'] = jsonStr;
    } catch (_) {}

    try {
      html.window.localStorage['mavis_automation_preview_study'] = jsonStr;
    } catch (_) {}

    try {
      final dynamic db = await _openDb();
      if (db != null) {
        final dynamic tx = db.transaction(_storeStudies, 'readwrite');
        final dynamic store = tx.objectStore(_storeStudies);
        store.put(jsonStr, 'latest_preview_study');
        if (product.id.isNotEmpty && product.id != 'preview_mode') {
          store.put(jsonStr, 'study_${product.id}');
        }
        await tx.completed;
      }
    } catch (_) {}
  }

  /// Remove base64 gigante do JSON para manter a escrita rápida e leve
  static ProductModel _stripLargeGlbFromJson(ProductModel product) {
    final attrs = Map<String, dynamic>.from(product.specificAttributes);
    if (attrs['proposalTheme'] is Map) {
      final themeMap = Map<String, dynamic>.from(attrs['proposalTheme'] as Map);
      final glbUrl = themeMap['glbModelUrl']?.toString() ?? '';
      if (glbUrl.startsWith('data:') && glbUrl.length > 50000) {
        themeMap['glbModelUrl'] = '';
        themeMap['hasGlbModel'] = true;
        attrs['proposalTheme'] = themeMap;
        return product.copyWith(specificAttributes: attrs);
      }
    }
    return product;
  }

  /// Carrega o rascunho na nova aba aberta
  static Future<ProductModel?> loadPreviewData([String? studyId]) async {
    if (activeProduct != null) {
      return await resolve3DModelForProduct(activeProduct!);
    }

    try {
      final dynamic db = await _openDb();
      if (db != null) {
        final dynamic tx = db.transaction(_storeStudies, 'readonly');
        final dynamic store = tx.objectStore(_storeStudies);

        String? raw;
        if (studyId != null && studyId.isNotEmpty && studyId != 'preview') {
          try {
            final dynamic res = await store.getObject('study_$studyId');
            if (res is String) raw = res;
          } catch (_) {}
        }

        if (raw == null || raw.isEmpty) {
          try {
            final dynamic res = await store.getObject('latest_preview_study');
            if (res is String) raw = res;
          } catch (_) {}
        }

        if (raw != null && raw.isNotEmpty) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final id = map['id']?.toString() ?? (studyId ?? 'preview_mode');
          final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now();
          final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now();
          var prod = ProductModel.fromMap(map, id).copyWith(
            createdAt: createdAt,
            updatedAt: updatedAt,
          );
          prod = await resolve3DModelForProduct(prod);
          activeProduct = prod;
          return prod;
        }
      }
    } catch (_) {}

    try {
      final raw = html.window.sessionStorage['mavis_automation_preview_study'];
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final id = map['id']?.toString() ?? (studyId ?? 'preview_mode');
        final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now();
        final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now();
        var prod = ProductModel.fromMap(map, id).copyWith(
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
        prod = await resolve3DModelForProduct(prod);
        activeProduct = prod;
        return prod;
      }
    } catch (_) {}

    return null;
  }

  /// Abre a proposta web estritamente em uma nova aba (_blank)
  static Future<void> openPreviewInNewTab({
    required String fullUrl,
    required ProductModel previewProduct,
    required AutomationProposalThemeConfig themeConfig,
  }) async {
    activeProduct = previewProduct;
    activeTheme = themeConfig;

    if (themeConfig.glbModelUrl != null &&
        themeConfig.glbModelUrl!.isNotEmpty &&
        !themeConfig.glbModelUrl!.startsWith('indexeddb:')) {
      latestGlbDataUrl = themeConfig.glbModelUrl;
      latestGlbFileName = themeConfig.glbFileName;
    }

    // Salva no IndexedDB antes de abrir a aba para garantir sincronização
    await savePreviewData(previewProduct);

    // Abre a nova aba diretamente no navegador via window.open
    try {
      html.window.open(fullUrl, '_blank');
    } catch (_) {
      final anchor = html.AnchorElement(href: fullUrl)
        ..target = '_blank'
        ..rel = 'noopener noreferrer';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    }
  }

  /// Baixa o arquivo .GLB ativo diretamente para o computador do usuário
  static void downloadGlbFile(String url, String fileName) {
    if (url.isEmpty || url.startsWith('indexeddb:')) return;
    try {
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName.isNotEmpty ? fileName : 'casa_3d_modelo.glb')
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
    } catch (_) {
      try {
        html.window.open(url, '_blank');
      } catch (_) {}
    }
  }
}
