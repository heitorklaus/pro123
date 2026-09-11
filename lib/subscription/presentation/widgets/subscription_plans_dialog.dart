import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/services/subscription_service.dart';
import 'pix_checkout_dialog.dart';

/// Modal oficial de Planos & Assinaturas acionado a qualquer momento pelo Dashboard
class SubscriptionPlansDialog extends StatefulWidget {
  final VoidCallback? onSubscribed;

  const SubscriptionPlansDialog({
    super.key,
    this.onSubscribed,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSubscribed}) {
    return showDialog(
      context: context,
      builder: (ctx) => SubscriptionPlansDialog(onSubscribed: onSubscribed),
    );
  }

  @override
  State<SubscriptionPlansDialog> createState() => _SubscriptionPlansDialogState();
}

class _SubscriptionPlansDialogState extends State<SubscriptionPlansDialog> {
  SubscriptionPlan _selectedPlan = SubscriptionPlan.monthly;

  void _proceedToPix() {
    Navigator.of(context).pop();
    PixCheckoutDialog.show(
      context,
      plan: _selectedPlan,
      onSuccess: widget.onSubscribed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final isMonthly = _selectedPlan == SubscriptionPlan.monthly;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Planos TAOS CRM PRO',
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Acesso ilimitado a todas as ferramentas e IA',
                                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),

                // Conteúdo
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 28 : 20),
                  child: Column(
                    children: [
                      // Seletor de Frequência (Mensal vs Semestral)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedPlan = SubscriptionPlan.monthly),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isMonthly ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: isMonthly
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'MENSAL • R\$ 99,00',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isMonthly ? FontWeight.w700 : FontWeight.w500,
                                        color: isMonthly ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedPlan = SubscriptionPlan.semiannual),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !isMonthly ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !isMonthly
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'SEMESTRAL • R\$ 450,00',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: !isMonthly ? FontWeight.w700 : FontWeight.w500,
                                          color: !isMonthly ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '-24%',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Card do Preço em Destaque
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMonthly ? 'Plano Mensal Pro' : 'Plano Semestral Pro (6 meses)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isMonthly
                                      ? 'Renovação mensal flexível sem fidelidade'
                                      : 'Equivalente a R\$ 75,00/mês (Economize R\$ 144,00)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: isMonthly ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                                    fontWeight: isMonthly ? FontWeight.w400 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isMonthly ? 'R\$ 99,00' : 'R\$ 450,00',
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  isMonthly ? '/ mês via PIX' : 'por 6 meses via PIX',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Lista de Recursos Inclusos
                      _buildBenefitItem('Usinas Solares, Kits e Produtos ilimitados no catálogo'),
                      _buildBenefitItem('Geração e Compartilhamento de Propostas em PDF de alta conversão'),
                      _buildBenefitItem('Emissão e Assinatura de Contratos com tags inteligentes'),
                      _buildBenefitItem('Visão Computacional e OCR com IA (Faturas de Energia e Cotações)'),
                      _buildBenefitItem('Suporte Técnico humanizado e atualizações inclusas'),

                      const SizedBox(height: 26),

                      // Botão Prosseguir para o PIX
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: _proceedToPix,
                          icon: const Icon(Icons.pix_rounded, color: Color(0xFF10B981), size: 20),
                          label: Text(
                            isMonthly
                                ? 'PAGAR COM PIX • R\$ 99,00'
                                : 'PAGAR COM PIX • R\$ 450,00',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF10B981)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
