import 'dart:typed_data';
import 'package:mavis/products/domain/models/product_model.dart';
import 'package:mavis/products/presentation/widgets/automation_proposal_customizer_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Implementação Fallback para Plataformas Não-Web
class AutomationPreviewBridge {
  static ProductModel? activeProduct;
  static AutomationProposalThemeConfig? activeTheme;
  static String? latestGlbDataUrl;
  static String? latestGlbFileName;

  static Future<void> save3DModelBytes(String fileName, Uint8List bytes, [String? studyId]) async {
    latestGlbFileName = fileName;
  }

  static Future<String?> get3DModelBlobUrl([String? studyId]) async {
    return latestGlbDataUrl;
  }

  static Future<ProductModel> resolve3DModelForProduct(ProductModel product) async {
    return product;
  }

  static Future<void> savePreviewData(ProductModel product) async {
    activeProduct = product;
  }

  static Future<ProductModel?> loadPreviewData([String? studyId]) async {
    return activeProduct;
  }

  static Future<void> openPreviewInNewTab({
    required String fullUrl,
    required ProductModel previewProduct,
    required AutomationProposalThemeConfig themeConfig,
  }) async {
    activeProduct = previewProduct;
    activeTheme = themeConfig;
    await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
  }

  static void downloadGlbFile(String url, String fileName) {
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
