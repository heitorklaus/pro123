import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Ponto de coordenada geográfica (Latitude e Longitude)
class GeoCoordinate {
  final double latitude;
  final double longitude;
  final String formattedAddress;

  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });

  /// Ponto central padrão no Brasil (Brasília)
  static const defaultLocation = GeoCoordinate(
    latitude: -15.7975,
    longitude: -47.8919,
    formattedAddress: 'Brasília, DF, Brasil',
  );
}

/// Provedores de imagens de satélite disponíveis
enum SatelliteSource {
  googleHybrid, // Google Maps Satélite com ruas e rotulagem (Padrão)
  googleSatellite, // Google Maps Satélite puro
  esriWorldImagery, // ArcGIS Esri World Imagery HD
}

extension SatelliteSourceExt on SatelliteSource {
  String get label {
    switch (this) {
      case SatelliteSource.googleHybrid:
        return 'Google Híbrido';
      case SatelliteSource.googleSatellite:
        return 'Google Satélite';
      case SatelliteSource.esriWorldImagery:
        return 'ArcGIS Satélite';
    }
  }
}

/// Serviço de geocodificação de endereços e fornecimento de imagens aéreas de satélite em alta resolução
class SatelliteMapService {
  /// Geocodifica um endereço ou CEP brasileiro para coordenadas geográficas (Lat/Lng)
  static Future<GeoCoordinate?> searchAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    try {
      String searchQuery = cleanQuery;

      // 1. Se for CEP, consulta primeiro o ViaCEP para obter rua, bairro e cidade precisos
      final digitsOnly = cleanQuery.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length == 8) {
        final viaCepUri = Uri.parse('https://viacep.com.br/ws/$digitsOnly/json/');
        final viaCepRes = await http.get(viaCepUri).timeout(const Duration(seconds: 5));
        if (viaCepRes.statusCode == 200) {
          final data = jsonDecode(viaCepRes.body) as Map<String, dynamic>;
          if (data['erro'] != true) {
            final logradouro = data['logradouro'] as String? ?? '';
            final bairro = data['bairro'] as String? ?? '';
            final localidade = data['localidade'] as String? ?? '';
            final uf = data['uf'] as String? ?? '';
            searchQuery = [logradouro, bairro, localidade, uf, 'Brasil']
                .where((s) => s.isNotEmpty)
                .join(', ');
          }
        }
      }

      // 2. Consulta a API pública de Geocodificação Nominatim (OpenStreetMap)
      final encodedQuery = Uri.encodeComponent(searchQuery);
      final nominatimUri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1&countrycodes=br',
      );

      final response = await http.get(
        nominatimUri,
        headers: {'User-Agent': 'MavisTaosCRM/1.0 (contact@taoscrm.com)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(first['lon']?.toString() ?? '') ?? 0.0;
          final displayName = first['display_name']?.toString() ?? searchQuery;

          if (lat != 0.0 && lon != 0.0) {
            return GeoCoordinate(
              latitude: lat,
              longitude: lon,
              formattedAddress: displayName,
            );
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[SatelliteMapService] Erro ao geocodificar endereço: $e');
      return null;
    }
  }

  /// Retorna a URL do mosaico de satélite de acordo com o provedor escolhido
  static String getTileUrl(int x, int y, int zoom, {SatelliteSource source = SatelliteSource.googleHybrid}) {
    // Distribui o tráfego entre os servidores de mosaico (mt0, mt1, mt2, mt3)
    final serverId = (x + y).abs() % 4;

    switch (source) {
      case SatelliteSource.googleHybrid:
        return 'https://mt$serverId.google.com/vt/lyrs=y&x=$x&y=$y&z=$zoom';
      case SatelliteSource.googleSatellite:
        return 'https://mt$serverId.google.com/vt/lyrs=s&x=$x&y=$y&z=$zoom';
      case SatelliteSource.esriWorldImagery:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$zoom/$y/$x';
    }
  }

  /// Retorna a URL do mosaico de satélite da Esri World Imagery (ArcGIS) em alta definição
  static String getEsriTileUrl(int x, int y, int zoom) {
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$zoom/$y/$x';
  }

  /// Retorna a URL de imagem estática do Google Maps Satellite (caso possua chave de API configurada)
  static String getGoogleSatelliteStaticUrl({
    required double latitude,
    required double longitude,
    required int zoom,
    required int width,
    required int height,
    required String apiKey,
  }) {
    return 'https://maps.googleapis.com/maps/api/staticmap?center=$latitude,$longitude&zoom=$zoom&size=${width}x$height&scale=2&maptype=satellite&key=$apiKey';
  }

  /// Converte Latitude/Longitude e Zoom para coordenadas numéricas de tile (X, Y) na projeção Web Mercator
  static math.Point<double> latLngToTileCoords(double lat, double lng, int zoom) {
    final latRad = lat * (math.pi / 180.0);
    final n = math.pow(2.0, zoom);
    final x = ((lng + 180.0) / 360.0) * n;
    final y = (1.0 - math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi) / 2.0 * n;
    return math.Point<double>(x, y);
  }

  /// Converte coordenadas de tile de volta para Latitude/Longitude
  static math.Point<double> tileCoordsToLatLng(double x, double y, int zoom) {
    final n = math.pow(2.0, zoom);
    final lonDeg = (x / n) * 360.0 - 180.0;
    final sinhParam = math.pi * (1.0 - 2.0 * (y / n));
    final sinhValue = (math.exp(sinhParam) - math.exp(-sinhParam)) / 2.0;
    final latRad = math.atan(sinhValue);
    final latDeg = latRad * (180.0 / math.pi);
    return math.Point<double>(latDeg, lonDeg);
  }
}
