import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CoverImageCacheService {
  static const String _storageBaseUrl =
      'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o';
  static final Map<String, Uint8List> _coverBytesCache = {};
  static final Map<String, Uint8List> _webBgBytesCache = {};

  static const String defaultCoverUrl =
      'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o/capas%2Fenergiasolar%2Fmodelo_proposta_1.jpg?alt=media';

  static String getBigCoverUrl(String fileName) {
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }
    final cleanName = fileName
        .replaceFirst('assets/modelo_propostas/', '')
        .replaceFirst('capas/energiasolar/', '');
    final encoded = Uri.encodeComponent('capas/energiasolar/$cleanName');
    return '$_storageBaseUrl/$encoded?alt=media';
  }

  static String getWebBackgroundUrl(String fileName) {
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }
    final cleanName = fileName
        .replaceFirst('assets/background_web/', '')
        .replaceFirst('assets/wallpaper_propostas/', '')
        .replaceFirst('wallpapers/energiasolar/', '')
        .replaceFirst('wallpapers/automacao/', '')
        .replaceFirst('capas/energiasolar/', '')
        .replaceFirst('capas/automacao/', '');

    if (cleanName.startsWith('modelo_proposta_')) {
      final encoded = Uri.encodeComponent('capas/energiasolar/$cleanName');
      return '$_storageBaseUrl/$encoded?alt=media';
    }
    if (cleanName.startsWith('modelo_automacao_')) {
      final encoded = Uri.encodeComponent('capas/automacao/$cleanName');
      return '$_storageBaseUrl/$encoded?alt=media';
    }

    final encoded = Uri.encodeComponent('wallpapers/energiasolar/$cleanName');
    return '$_storageBaseUrl/$encoded?alt=media';
  }

  static Future<Uint8List?> fetchCoverBytes(String fileName) async {
    final cleanName = fileName
        .replaceFirst('assets/modelo_propostas/', '')
        .replaceFirst('capas/energiasolar/', '');
    if (_coverBytesCache.containsKey(cleanName)) {
      return _coverBytesCache[cleanName];
    }
    try {
      final url = getBigCoverUrl(cleanName);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _coverBytesCache[cleanName] = response.bodyBytes;
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List?> fetchWebBackgroundBytes(String fileName) async {
    final cleanName = fileName
        .replaceFirst('assets/background_web/', '')
        .replaceFirst('assets/wallpaper_propostas/', '')
        .replaceFirst('wallpapers/energiasolar/', '');
    if (_webBgBytesCache.containsKey(cleanName)) {
      return _webBgBytesCache[cleanName];
    }
    try {
      final url = getWebBackgroundUrl(cleanName);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _webBgBytesCache[cleanName] = response.bodyBytes;
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List?> getCoverBytes([String? url]) async {
    final targetUrl = (url != null && url.isNotEmpty) ? url : defaultCoverUrl;

    if (_coverBytesCache.containsKey(targetUrl)) {
      return _coverBytesCache[targetUrl];
    }

    try {
      final res = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        _coverBytesCache[targetUrl] = res.bodyBytes;
        return res.bodyBytes;
      }
    } catch (e) {
      print('⚠️ [CoverImageCacheService] Falha ao baixar capa de $targetUrl: $e');
    }

    return null;
  }
}
