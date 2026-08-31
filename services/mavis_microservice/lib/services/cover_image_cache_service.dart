import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CoverImageCacheService {
  static final Map<String, Uint8List> _cache = {};

  static const String defaultCoverUrl =
      'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o/capas%2Fenergiasolar%2Fmodelo_proposta_3.jpg?alt=media';

  /// Obtém a imagem da capa em bytes (com cache em memória para velocidade instantânea)
  static Future<Uint8List?> getCoverBytes([String? url]) async {
    final targetUrl = (url != null && url.isNotEmpty) ? url : defaultCoverUrl;

    if (_cache.containsKey(targetUrl)) {
      return _cache[targetUrl];
    }

    try {
      final res = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        _cache[targetUrl] = res.bodyBytes;
        return res.bodyBytes;
      }
    } catch (e) {
      print('⚠️ [CoverImageCacheService] Falha ao baixar capa de $targetUrl: $e');
    }

    return null;
  }
}
