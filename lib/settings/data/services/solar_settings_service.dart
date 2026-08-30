import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../domain/models/solar_settings_model.dart';

class SolarSettingsService {
  static const _storageBaseUrl = 'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o';
  static const _localCacheKey = 'mavis_solar_settings_cache';

  /// Retorna a URL do thumbnail da capa (Small)
  static String getSmallCoverUrl(String fileName) {
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }
    final encoded = Uri.encodeComponent('capas/energiasolar/$fileName');
    return '$_storageBaseUrl/$encoded?alt=media';
  }

  /// Retorna a URL em alta resolução da capa (Big)
  static String getBigCoverUrl(String fileName) {
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }
    final encoded = Uri.encodeComponent('capas/energiasolar/$fileName');
    return '$_storageBaseUrl/$encoded?alt=media';
  }

  /// Lista das 100 capas fotovoltaicas padrão em alta resolução
  static List<String> getDefaultCoverList() {
    final list = <String>[];
    for (int i = 1; i <= 100; i++) {
      list.add('modelo_proposta_$i.jpg');
    }
    return list;
  }

  /// Lista dos 10 estilos de separadores geométricos / decalques
  static List<Map<String, dynamic>> getAvailableDividers() {
    return const [
      {'id': 0, 'name': 'Onda Suave Clássica (S-Curve)', 'desc': 'Curva orgânica dupla com fita de destaque'},
      {'id': 1, 'name': 'Onda Dupla Harmônica', 'desc': 'Duas ondas fluidas intersectantes em degradê'},
      {'id': 2, 'name': 'Corte Diagonal Moderno', 'desc': 'Design angular tecnológico com fita tripla'},
      {'id': 3, 'name': 'Polígonos Facetados (Chevron)', 'desc': 'Geometria cristalina com vértices dinâmicos'},
      {'id': 4, 'name': 'Arco Aerodinâmico Côncavo', 'desc': 'Arco estilizado parabólico ascendente'},
      {'id': 5, 'name': 'Declive Arquitetônico Solar', 'desc': 'Ângulos inspirados na inclinação dos telhados'},
      {'id': 6, 'name': 'Cascata Tripla de Ondas', 'desc': 'Três ondulações ritmadas em degradê suave'},
      {'id': 7, 'name': 'Hexágono Tech Futurista', 'desc': 'Geometria chanfrada com alta identidade visual'},
      {'id': 8, 'name': 'Arco Convexo Aerodinâmico', 'desc': 'Curvatura suave e elegante voltada para o topo'},
      {'id': 9, 'name': 'Varredura Angular Ascendente', 'desc': 'Transição fluida inclinada de alta energia'},
    ];
  }

  /// Lista unificada de Paletas de Cores para Cabeçalho & Rodapé Minimalistas
  static List<Map<String, dynamic>> getAvailableSvgThemes() {
    return const [
      {'fileName': '#2563EB', 'name': 'Azul Royal Tradicional', 'color': 0xFF2563EB},
      {'fileName': '#0284C7', 'name': 'Azul Corporativo Clean', 'color': 0xFF0284C7},
      {'fileName': '#0EA5E9', 'name': 'Azul Oceano', 'color': 0xFF0EA5E9},
      {'fileName': '#38BDF8', 'name': 'Azul Claro Suave', 'color': 0xFF38BDF8},
      {'fileName': '#10B981', 'name': 'Verde Esmeralda', 'color': 0xFF10B981},
      {'fileName': '#059669', 'name': 'Verde Sustentável', 'color': 0xFF059669},
      {'fileName': '#F59E0B', 'name': 'Amarelo Solar Dourado', 'color': 0xFFF59E0B},
      {'fileName': '#F97316', 'name': 'Laranja Energia', 'color': 0xFFF97316},
      {'fileName': '#8B5CF6', 'name': 'Roxo Tecnológico', 'color': 0xFF8B5CF6},
      {'fileName': '#EF4444', 'name': 'Vermelho Rubi', 'color': 0xFFEF4444},
      {'fileName': '#0F172A', 'name': 'Preto Grafite Minimalista', 'color': 0xFF0F172A},
      {'fileName': '#475569', 'name': 'Cinza Ardósia Neutro', 'color': 0xFF475569},
    ];
  }

  /// Métodos de compatibilidade retroativa
  static List<Map<String, String>> getAvailableSvgHeaders() => getAvailableSvgThemes().map((e) => {'fileName': e['fileName'] as String, 'name': e['name'] as String}).toList();
  static List<Map<String, String>> getAvailableSvgFooters() => getAvailableSvgThemes().map((e) => {'fileName': e['fileName'] as String, 'name': e['name'] as String}).toList();

  /// Busca a lista dinâmica de capas diretamente do Firebase Storage API ou fallback local
  static Future<List<String>> fetchAvailableCovers() async {
    try {
      final uri = Uri.parse('$_storageBaseUrl?prefix=capas%2Fenergiasolar%2F');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final set = <String>{};
          for (final item in items) {
            final name = item['name'] as String? ?? '';
            if (name.startsWith('capas/energiasolar/')) {
              final fileName = name.replaceFirst('capas/energiasolar/', '');
              if (fileName.isNotEmpty) {
                set.add(fileName);
              }
            }
          }
          if (set.isNotEmpty) {
            final sorted = set.toList();
            sorted.sort((a, b) {
              final numA = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 999;
              final numB = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 999;
              return numA.compareTo(numB);
            });
            return sorted;
          }
        }
      }
    } catch (e) {
      debugPrint('[SolarSettingsService] Erro ao buscar capas dinâmicas (usando lista padrão): $e');
    }
    return getDefaultCoverList();
  }

  /// Carrega as configurações de Usina Solar da empresa
  static Future<SolarSettingsModel> loadSettings({String? companyId}) async {
    try {
      String? cid = companyId;
      if (cid == null || cid.isEmpty) {
        final auth = AuthRepository();
        cid = await auth.getCurrentCompanyId();
      }

      // 1. Tenta carregar do Firestore
      if (cid != null && cid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(cid)
            .collection('sector_settings')
            .doc('solarPlant')
            .get();

        if (doc.exists && doc.data() != null) {
          final model = SolarSettingsModel.fromMap(doc.data()!);
          // Salva no cache local
          _cacheLocalSettings(model);
          return model;
        }
      }

      // 2. Fallback no cache local SharedPreferences
      final local = await _loadLocalSettings();
      if (local != null) return local;
    } catch (e) {
      debugPrint('[SolarSettingsService] Erro ao carregar configurações: $e');
    }

    return SolarSettingsModel.initial();
  }

  /// Salva as configurações de Usina Solar no Firestore e no cache local
  static Future<void> saveSettings(SolarSettingsModel settings, {String? companyId}) async {
    try {
      String? cid = companyId;
      if (cid == null || cid.isEmpty) {
        final auth = AuthRepository();
        cid = await auth.getCurrentCompanyId();
      }

      await _cacheLocalSettings(settings);

      if (cid != null && cid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(cid)
            .collection('sector_settings')
            .doc('solarPlant')
            .set(settings.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[SolarSettingsService] Erro ao salvar configurações: $e');
      rethrow;
    }
  }

  static Future<void> _cacheLocalSettings(SolarSettingsModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localCacheKey, jsonEncode(model.toMap()));
    } catch (_) {}
  }

  static Future<SolarSettingsModel?> _loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_localCacheKey);
      if (str != null && str.isNotEmpty) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return SolarSettingsModel.fromMap(map);
      }
    } catch (_) {}
    return null;
  }
}
