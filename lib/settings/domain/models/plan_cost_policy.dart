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

  /// Estimativas exibidas ao cliente final (em MB, análises de PDF e propostas WhatsApp).
  /// Podem ser ajustadas livremente a qualquer momento sem expor custos internos.
  static ({
    String title,
    String priceLabel,
    int monthlyPdfAnalyses,
    int monthlyWhatsAppProposals,
    int monthlyUploadMb,
    String dailyMixedSummary,
  }) clientBenefitsForTier(String? tier) {
    switch (normalizeTier(tier)) {
      case 'gold':
        return (
          title: 'GOLD',
          priceLabel: 'R\$ 79,90',
          monthlyPdfAnalyses: 510,
          monthlyWhatsAppProposals: 1715,
          monthlyUploadMb: 940,
          dailyMixedSummary: '~16 msgs Agente + ~11 PDFs/dia',
        );
      case 'diamond':
        return (
          title: 'DIAMOND',
          priceLabel: 'R\$ 99,90',
          monthlyPdfAnalyses: 640,
          monthlyWhatsAppProposals: 2145,
          monthlyUploadMb: 1170,
          dailyMixedSummary: '~20 msgs Agente + ~13 PDFs/dia',
        );
      case 'premium':
      default:
        return (
          title: 'PREMIUM',
          priceLabel: 'R\$ 59,90',
          monthlyPdfAnalyses: 380,
          monthlyWhatsAppProposals: 1280,
          monthlyUploadMb: 700,
          dailyMixedSummary: '~12 msgs Agente + ~8 PDFs/dia',
        );
    }
  }
}
