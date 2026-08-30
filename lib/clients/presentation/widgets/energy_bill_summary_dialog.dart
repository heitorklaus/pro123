import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../domain/models/parsed_energy_bill.dart';

/// Modal de Resumo e Aceite do Diagnóstico de Conta de Energia processada pela IA Gemini
class EnergyBillSummaryDialog extends StatelessWidget {
  final ParsedEnergyBill parsedBill;
  final VoidCallback onAccept;

  const EnergyBillSummaryDialog({
    super.key,
    required this.parsedBill,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isCompany = parsedBill.clientType.name == 'company';
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 20,
        vertical: isMobile ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header Dourado / IA ───────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 14 : 18,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Resumo da Conta de Energia',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'IA GEMINI VISION',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFCD34D),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Revise os dados cadastrais e o dimensionamento fotovoltaico antes de aplicar ao formulário',
                            style: GoogleFonts.inter(
                                fontSize: 11.5, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),

              // ── Corpo com Rolagem ─────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── CARD PRINCIPAL: PREVISÃO DE GERAÇÃO & POTÊNCIA FOTOVOLTAICA ──
                      Container(
                        padding: EdgeInsets.all(isMobile ? 14 : 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFFDE68A), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.solar_power_rounded,
                                    color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'PREVISÃO DE GERAÇÃO & POTÊNCIA SOLAR SUGERIDA',
                                    style: GoogleFonts.inter(
                                      fontSize: isMobile ? 11 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF92400E),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Grid de Indicadores Solares (Responsivo)
                            if (isMobile) ...[
                              _metricCard(
                                title: 'Consumo Médio Mensal',
                                value:
                                    '${parsedBill.averageMonthlyConsumptionKwh.toStringAsFixed(0)} kWh/mês',
                                icon: Icons.electric_meter_outlined,
                                iconColor: const Color(0xFFD97706),
                                textColor: const Color(0xFF78350F),
                              ),
                              const SizedBox(height: 8),
                              _metricCard(
                                title: 'Potência Solar Sugerida',
                                value:
                                    '${parsedBill.suggestedSolarKwP.toStringAsFixed(2)} kWp',
                                icon: Icons.bolt_rounded,
                                iconColor: const Color(0xFF059669),
                                textColor: const Color(0xFF065F46),
                              ),
                              const SizedBox(height: 8),
                              _metricCard(
                                title: 'Geração Prevista',
                                value:
                                    '${parsedBill.estimatedMonthlyGenerationKwh.toStringAsFixed(0)} kWh/mês',
                                icon: Icons.wb_sunny_outlined,
                                iconColor: const Color(0xFFD97706),
                                textColor: const Color(0xFF78350F),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  // Consumo Médio
                                  Expanded(
                                    child: _metricCard(
                                      title: 'Consumo Médio Mensal',
                                      value:
                                          '${parsedBill.averageMonthlyConsumptionKwh.toStringAsFixed(0)} kWh/mês',
                                      icon: Icons.electric_meter_outlined,
                                      iconColor: const Color(0xFFD97706),
                                      textColor: const Color(0xFF78350F),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Potência Recomendada
                                  Expanded(
                                    child: _metricCard(
                                      title: 'Potência Solar Sugerida',
                                      value:
                                          '${parsedBill.suggestedSolarKwP.toStringAsFixed(2)} kWp',
                                      icon: Icons.bolt_rounded,
                                      iconColor: const Color(0xFF059669),
                                      textColor: const Color(0xFF065F46),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Geração Estimada
                                  Expanded(
                                    child: _metricCard(
                                      title: 'Geração Prevista',
                                      value:
                                          '${parsedBill.estimatedMonthlyGenerationKwh.toStringAsFixed(0)} kWh/mês',
                                      icon: Icons.wb_sunny_outlined,
                                      iconColor: const Color(0xFFD97706),
                                      textColor: const Color(0xFF78350F),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── CARDS LADO A LADO (CLIENTE vs UNIDADE CONSUMIDORA) ──
                      if (isMobile) ...[
                        _infoSection(
                          title: 'Titular / Pagador',
                          icon: Icons.person_pin_circle_outlined,
                          children: [
                            _infoRow(
                              'Nome / Razão:',
                              parsedBill.clientName ?? 'Não identificado',
                              isBold: true,
                            ),
                            _infoRow(
                              isCompany ? 'CNPJ:' : 'CPF:',
                              parsedBill.document ?? 'Não identificado',
                            ),
                            _infoRow(
                              'Tipo:',
                              isCompany
                                  ? 'Pessoa Jurídica (PJ)'
                                  : 'Pessoa Física (PF)',
                            ),
                            _infoRow(
                              'Endereço:',
                              '${parsedBill.street ?? ''}${parsedBill.addressNumber != null ? ", ${parsedBill.addressNumber}" : ""}',
                            ),
                            _infoRow(
                              'Bairro / Cidade:',
                              '${parsedBill.neighborhood ?? ''}${parsedBill.city != null ? " - ${parsedBill.city}" : ""}/${parsedBill.state ?? ""}',
                            ),
                            _infoRow('CEP:',
                                parsedBill.zipCode ?? 'Não identificado'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _infoSection(
                          title: 'Unidade Consumidora (UC)',
                          icon: Icons.power_outlined,
                          children: [
                            _infoRow(
                              'Distribuidora:',
                              parsedBill.utilityCompany ?? 'Não identificada',
                              isBold: true,
                            ),
                            _infoRow(
                              'Número da UC / Código:',
                              parsedBill.ucNumber ?? 'Não identificado',
                              isBold: true,
                            ),
                            _infoRow(
                              'Tipo de Ligação:',
                              parsedBill.connectionType ?? 'Trifásico',
                            ),
                            _infoRow(
                              'Classificação / Grupo:',
                              parsedBill.tariffGroup ?? 'B1 Residencial',
                            ),
                            if (parsedBill.currentBillAmount != null)
                              _infoRow(
                                'Valor da Fatura:',
                                currencyFormat
                                    .format(parsedBill.currentBillAmount),
                              ),
                            if (parsedBill.referenceMonth != null)
                              _infoRow(
                                'Mês Referência:',
                                parsedBill.referenceMonth!,
                              ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card 1: Dados do Cliente & Endereço
                            Expanded(
                              child: _infoSection(
                                title: 'Titular / Pagador',
                                icon: Icons.person_pin_circle_outlined,
                                children: [
                                  _infoRow(
                                    'Nome / Razão:',
                                    parsedBill.clientName ?? 'Não identificado',
                                    isBold: true,
                                  ),
                                  _infoRow(
                                    isCompany ? 'CNPJ:' : 'CPF:',
                                    parsedBill.document ?? 'Não identificado',
                                  ),
                                  _infoRow(
                                    'Tipo:',
                                    isCompany
                                        ? 'Pessoa Jurídica (PJ)'
                                        : 'Pessoa Física (PF)',
                                  ),
                                  _infoRow(
                                    'Endereço:',
                                    '${parsedBill.street ?? ''}${parsedBill.addressNumber != null ? ", ${parsedBill.addressNumber}" : ""}',
                                  ),
                                  _infoRow(
                                    'Bairro / Cidade:',
                                    '${parsedBill.neighborhood ?? ''}${parsedBill.city != null ? " - ${parsedBill.city}" : ""}/${parsedBill.state ?? ""}',
                                  ),
                                  _infoRow('CEP:',
                                      parsedBill.zipCode ?? 'Não identificado'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Card 2: Dados da Unidade Consumidora (UC)
                            Expanded(
                              child: _infoSection(
                                title: 'Unidade Consumidora (UC)',
                                icon: Icons.power_outlined,
                                children: [
                                  _infoRow(
                                    'Distribuidora:',
                                    parsedBill.utilityCompany ??
                                        'Não identificada',
                                    isBold: true,
                                  ),
                                  _infoRow(
                                    'Número da UC / Código:',
                                    parsedBill.ucNumber ?? 'Não identificado',
                                    isBold: true,
                                  ),
                                  _infoRow(
                                    'Tipo de Ligação:',
                                    parsedBill.connectionType ?? 'Trifásico',
                                  ),
                                  _infoRow(
                                    'Classificação / Grupo:',
                                    parsedBill.tariffGroup ?? 'B1 Residencial',
                                  ),
                                  if (parsedBill.currentBillAmount != null)
                                    _infoRow(
                                      'Valor da Fatura:',
                                      currencyFormat
                                          .format(parsedBill.currentBillAmount),
                                    ),
                                  if (parsedBill.referenceMonth != null)
                                    _infoRow(
                                      'Mês Referência:',
                                      parsedBill.referenceMonth!,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),

                      // ── HISTÓRICO DE CONSUMO DOS ÚLTIMOS MESES ──────────────
                      if (parsedBill.history.isNotEmpty) ...[
                        _infoSection(
                          title:
                              'Histórico de Consumo Faturado (${parsedBill.history.length} meses identificados)',
                          icon: Icons.bar_chart_rounded,
                          children: [
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: parsedBill.history.map((h) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        h.month,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${h.consumptionKwh.toStringAsFixed(0)} kWh',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Rodapé de Aceite ──────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 12 : 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Os dados preencherão o formulário de cadastro automaticamente.',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF64748B),
                                    side: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: Text('CANCELAR',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onAccept();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text('APLICAR',
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Os dados preencherão o formulário de cadastro automaticamente.',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'CANCELAR',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    onAccept();
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF059669),
                                          Color(0xFF047857)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF059669)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 11),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              color: Colors.white,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'APLICAR DADOS',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF92400E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _infoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: const Color(0xFF1E293B)),
              ),
            ],
          ),
          const Divider(color: AppColors.divider, height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
