import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Configurações Globais do Sistema / Ecossistema Master (`system_settings/global_config`)
class GlobalSystemConfig {
  final int defaultDailyAiQuota; // Cota padrão de análises de IA por usuário/dia (ex: 25)
  final int defaultMaxSellersPerCompany; // Limite padrão de vendedores por empresa/integrador (ex: 5)
  final double usdToBrlRate; // Cotação USD -> BRL para cálculo de custo em reais
  final int premiumDailyTokens; // Cota diária de tokens para o grupo PREMIUM (padrão)
  final int goldDailyTokens; // Cota diária de tokens para o grupo GOLD
  final int diamondDailyTokens; // Cota diária de tokens para o grupo DIAMOND
  final double premiumDailyBrl; // Teto opcional diário em R$ (0 = sem teto extra além dos tokens)
  final double goldDailyBrl;
  final double diamondDailyBrl;
  final double geminiInputUsdPer1M; // Preço USD por 1M tokens de entrada
  final double geminiOutputUsdPer1M; // Preço USD por 1M tokens de saída
  final bool aiEnabledForUsers; // Liga/Desliga IA para usuários comuns (false = só admin@admin.com.br)
  final bool allowPublicRegistration; // Liga/Desliga novos cadastros públicos de usuários
  final double supportDailyMediaLimitMb; // Cota diária de imagem/áudio (MB) no Chat de Suporte por usuário
  final DateTime updatedAt;
  final String? updatedBy;

  const GlobalSystemConfig({
    this.defaultDailyAiQuota = 25,
    this.defaultMaxSellersPerCompany = 5,
    this.usdToBrlRate = 5.80,
    this.premiumDailyTokens = 300000,
    this.goldDailyTokens = 750000,
    this.diamondDailyTokens = 2000000,
    this.premiumDailyBrl = 0.0,
    this.goldDailyBrl = 0.0,
    this.diamondDailyBrl = 0.0,
    this.geminiInputUsdPer1M = 0.30,
    this.geminiOutputUsdPer1M = 2.50,
    this.aiEnabledForUsers = true,
    this.allowPublicRegistration = true,
    this.supportDailyMediaLimitMb = 10.0,
    required this.updatedAt,
    this.updatedBy,
  });

  int tokenQuotaForTier(String tier) {
    switch (tier.toLowerCase().trim()) {
      case 'diamond':
        return diamondDailyTokens;
      case 'gold':
        return goldDailyTokens;
      case 'premium':
      default:
        return premiumDailyTokens;
    }
  }

  double brlQuotaForTier(String tier) {
    switch (tier.toLowerCase().trim()) {
      case 'diamond':
        return diamondDailyBrl;
      case 'gold':
        return goldDailyBrl;
      case 'premium':
      default:
        return premiumDailyBrl;
    }
  }

  factory GlobalSystemConfig.defaultConfig() {
    return GlobalSystemConfig(
      defaultDailyAiQuota: 25,
      defaultMaxSellersPerCompany: 5,
      usdToBrlRate: 5.80,
      premiumDailyTokens: 300000,
      goldDailyTokens: 750000,
      diamondDailyTokens: 2000000,
      premiumDailyBrl: 0.0,
      goldDailyBrl: 0.0,
      diamondDailyBrl: 0.0,
      geminiInputUsdPer1M: 0.30,
      geminiOutputUsdPer1M: 2.50,
      aiEnabledForUsers: true,
      allowPublicRegistration: true,
      supportDailyMediaLimitMb: 10.0,
      updatedAt: DateTime.now(),
      updatedBy: 'system',
    );
  }

  factory GlobalSystemConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return GlobalSystemConfig.defaultConfig();
    return GlobalSystemConfig(
      defaultDailyAiQuota: (map['defaultDailyAiQuota'] as num?)?.toInt() ?? 25,
      defaultMaxSellersPerCompany: (map['defaultMaxSellersPerCompany'] as num?)?.toInt() ?? 5,
      usdToBrlRate: (map['usdToBrlRate'] as num?)?.toDouble() ?? 5.80,
      premiumDailyTokens: (map['premiumDailyTokens'] as num?)?.toInt() ?? 300000,
      goldDailyTokens: (map['goldDailyTokens'] as num?)?.toInt() ?? 750000,
      diamondDailyTokens: (map['diamondDailyTokens'] as num?)?.toInt() ?? 2000000,
      premiumDailyBrl: (map['premiumDailyBrl'] as num?)?.toDouble() ?? 0.0,
      goldDailyBrl: (map['goldDailyBrl'] as num?)?.toDouble() ?? 0.0,
      diamondDailyBrl: (map['diamondDailyBrl'] as num?)?.toDouble() ?? 0.0,
      geminiInputUsdPer1M: (map['geminiInputUsdPer1M'] as num?)?.toDouble() ?? 0.30,
      geminiOutputUsdPer1M: (map['geminiOutputUsdPer1M'] as num?)?.toDouble() ?? 2.50,
      aiEnabledForUsers: map['aiEnabledForUsers'] as bool? ?? true,
      allowPublicRegistration: map['allowPublicRegistration'] as bool? ?? true,
      supportDailyMediaLimitMb: (map['supportDailyMediaLimitMb'] as num?)?.toDouble() ?? 10.0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultDailyAiQuota': defaultDailyAiQuota,
      'defaultMaxSellersPerCompany': defaultMaxSellersPerCompany,
      'usdToBrlRate': usdToBrlRate,
      'premiumDailyTokens': premiumDailyTokens,
      'goldDailyTokens': goldDailyTokens,
      'diamondDailyTokens': diamondDailyTokens,
      'premiumDailyBrl': premiumDailyBrl,
      'goldDailyBrl': goldDailyBrl,
      'diamondDailyBrl': diamondDailyBrl,
      'geminiInputUsdPer1M': geminiInputUsdPer1M,
      'geminiOutputUsdPer1M': geminiOutputUsdPer1M,
      'aiEnabledForUsers': aiEnabledForUsers,
      'allowPublicRegistration': allowPublicRegistration,
      'supportDailyMediaLimitMb': supportDailyMediaLimitMb,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  GlobalSystemConfig copyWith({
    int? defaultDailyAiQuota,
    int? defaultMaxSellersPerCompany,
    double? usdToBrlRate,
    int? premiumDailyTokens,
    int? goldDailyTokens,
    int? diamondDailyTokens,
    double? premiumDailyBrl,
    double? goldDailyBrl,
    double? diamondDailyBrl,
    double? geminiInputUsdPer1M,
    double? geminiOutputUsdPer1M,
    bool? aiEnabledForUsers,
    bool? allowPublicRegistration,
    double? supportDailyMediaLimitMb,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return GlobalSystemConfig(
      defaultDailyAiQuota: defaultDailyAiQuota ?? this.defaultDailyAiQuota,
      defaultMaxSellersPerCompany: defaultMaxSellersPerCompany ?? this.defaultMaxSellersPerCompany,
      usdToBrlRate: usdToBrlRate ?? this.usdToBrlRate,
      premiumDailyTokens: premiumDailyTokens ?? this.premiumDailyTokens,
      goldDailyTokens: goldDailyTokens ?? this.goldDailyTokens,
      diamondDailyTokens: diamondDailyTokens ?? this.diamondDailyTokens,
      premiumDailyBrl: premiumDailyBrl ?? this.premiumDailyBrl,
      goldDailyBrl: goldDailyBrl ?? this.goldDailyBrl,
      diamondDailyBrl: diamondDailyBrl ?? this.diamondDailyBrl,
      geminiInputUsdPer1M: geminiInputUsdPer1M ?? this.geminiInputUsdPer1M,
      geminiOutputUsdPer1M: geminiOutputUsdPer1M ?? this.geminiOutputUsdPer1M,
      aiEnabledForUsers: aiEnabledForUsers ?? this.aiEnabledForUsers,
      allowPublicRegistration: allowPublicRegistration ?? this.allowPublicRegistration,
      supportDailyMediaLimitMb: supportDailyMediaLimitMb ?? this.supportDailyMediaLimitMb,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
