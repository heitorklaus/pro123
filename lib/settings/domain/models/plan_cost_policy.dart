import 'package:intl/intl.dart';

/// Política financeira de planos e margem mínima de 80% de lucro (teto de 20% de custo).
class PlanCostPolicy {
  static const double targetProfitMargin = 0.80;
  static const double maxCostRatioOfPlan = 0.20; // 100% - 80% = 20%
  static const double nearLimitRatioOfCap = 0.75; // Alerta a partir de 75% do teto de custo

  static final NumberFormat _brlFmt =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  static String normalizeTier(String? tier) {
    final t = (tier ?? 'premium').trim().toLowerCase();
    if (t == 'gold') return 'gold';
    if (t == 'diamond') return 'diamond';
    return 'premium';
  }

  static String tierDisplayName(String? tier) => normalizeTier(tier).toUpperCase();

  /// Valor mensal cobrado do cliente em R$.
  static double planPriceBrl(String? tier) {
    switch (normalizeTier(tier)) {
      case 'gold':
        return 79.90;
      case 'diamond':
        return 99.90;
      case 'premium':
      default:
        return 59.90;
    }
  }

  /// Teto máximo de custo mensal permitido (20% do valor do plano) para garantir 80% de lucro.
  static double maxMonthlyCostBrl(String? tier) {
    return planPriceBrl(tier) * maxCostRatioOfPlan;
  }

  /// Custo estimado em R$ de um upload (capa, logo, PDF ou mídia) + gravação em banco/storage.
  /// Considera tráfego/armazenamento + operações Firestore convertidos em centavos de R$.
  static double calculateUploadCostBrl(
    int bytes, {
    double usdToBrlRate = 5.80,
    bool isAgentOrPdf = false,
  }) {
    final mb = bytes / (1024.0 * 1024.0);
    // Storage + Egress + Operações (~US$ 0.002/MB + base operacional) convertido para BRL
    final usd = (mb * 0.0025) + (isAgentOrPdf ? 0.0008 : 0.0004);
    final brl = usd * usdToBrlRate;
    return brl < 0.005 ? 0.005 : brl; // Mínimo de 0,5 centavo por operação registrada
  }

  static String formatBrl(double value) => _brlFmt.format(value);
}
