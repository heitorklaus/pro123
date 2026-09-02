import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Configurações Globais do Sistema / Ecossistema Master (`system_settings/global_config`)
class GlobalSystemConfig {
  final int defaultDailyAiQuota; // Cota padrão de análises de IA por usuário/dia (ex: 25)
  final int defaultMaxSellersPerCompany; // Limite padrão de vendedores por empresa/integrador (ex: 5)
  final DateTime updatedAt;
  final String? updatedBy;

  const GlobalSystemConfig({
    this.defaultDailyAiQuota = 25,
    this.defaultMaxSellersPerCompany = 5,
    required this.updatedAt,
    this.updatedBy,
  });

  factory GlobalSystemConfig.defaultConfig() {
    return GlobalSystemConfig(
      defaultDailyAiQuota: 25,
      defaultMaxSellersPerCompany: 5,
      updatedAt: DateTime.now(),
      updatedBy: 'system',
    );
  }

  factory GlobalSystemConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return GlobalSystemConfig.defaultConfig();
    return GlobalSystemConfig(
      defaultDailyAiQuota: map['defaultDailyAiQuota'] as int? ?? 25,
      defaultMaxSellersPerCompany: map['defaultMaxSellersPerCompany'] as int? ?? 5,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultDailyAiQuota': defaultDailyAiQuota,
      'defaultMaxSellersPerCompany': defaultMaxSellersPerCompany,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  GlobalSystemConfig copyWith({
    int? defaultDailyAiQuota,
    int? defaultMaxSellersPerCompany,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return GlobalSystemConfig(
      defaultDailyAiQuota: defaultDailyAiQuota ?? this.defaultDailyAiQuota,
      defaultMaxSellersPerCompany: defaultMaxSellersPerCompany ?? this.defaultMaxSellersPerCompany,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
