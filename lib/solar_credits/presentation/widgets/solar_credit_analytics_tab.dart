import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/solar_credit_repository.dart';
import '../../domain/models/solar_credit_models.dart';

class SolarCreditAnalyticsTab extends StatefulWidget {
  final List<SolarGeneratorPlantModel> plants;
  final List<SolarCreditBeneficiaryModel> beneficiaries;
  final List<SolarCreditBillModel> bills;
  final SolarCreditRepository repository;

  const SolarCreditAnalyticsTab({
    super.key,
    required this.plants,
    required this.beneficiaries,
    required this.bills,
    required this.repository,
  });

  @override
  State<SolarCreditAnalyticsTab> createState() =>
      _SolarCreditAnalyticsTabState();
}

class _SolarCreditAnalyticsTabState extends State<SolarCreditAnalyticsTab> {
  final _numFmt = NumberFormat('#,##0', 'pt_BR');
  final _decFmt = NumberFormat('#,##0.00', 'pt_BR');

  String _selectedPlantId = 'all';

  @override
  Widget build(BuildContext context) {
    final activePlants = widget.plants;
    final selectedPlant = _selectedPlantId == 'all'
        ? null
        : activePlants
            .where((p) => p.id == _selectedPlantId)
            .firstOrNull;

    final filteredBeneficiaries = _selectedPlantId == 'all'
        ? widget.beneficiaries
        : widget.beneficiaries
            .where((b) => b.receivesFromPlant(_selectedPlantId, selectedPlant?.name))
            .toList();

    final filteredBills = _selectedPlantId == 'all'
        ? widget.bills
        : widget.bills
            .where((b) => b.generatorPlantId == _selectedPlantId)
            .toList();

    // Cálculo consolidado da(s) usina(s)
    final totalGenerationCapacityKwh = selectedPlant != null
        ? selectedPlant.estimatedMonthlyGenerationKwh
        : activePlants.fold<double>(
            0.0,
            (acc, p) => acc + p.estimatedMonthlyGenerationKwh,
          );

    final totalAllocatedPercent = filteredBeneficiaries.fold<double>(
      0.0,
      (acc, b) =>
          acc +
          (_selectedPlantId == 'all'
              ? b.effectivePlantAllocations.fold<double>(
                  0.0,
                  (s, a) => s + a.allocationPercent,
                )
              : b.allocationPercentForPlant(
                  _selectedPlantId,
                  selectedPlant?.name,
                )),
    );

    final totalClientConsumptionKwh = filteredBeneficiaries.fold<double>(
      0.0,
      (acc, b) => acc + _effectiveConsumptionKwh(b, filteredBills),
    );

    final totalAccumulatedBalanceKwh = filteredBeneficiaries.fold<double>(
      0.0,
      (acc, b) => acc + _effectiveAccumulatedBalanceKwh(b, filteredBills),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BARRA DE FILTRO POR USINA GERADORA ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inteligência de Rateio & Consumo por Usina (Concessionária)',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Identifique quais clientes estão sobrando saldo e quais precisam de mais % na Energisa',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activePlants.any((p) => p.id == _selectedPlantId)
                        ? _selectedPlantId
                        : 'all',
                    dropdownColor: const Color(0xFF0F172A),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF38BDF8),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          '🏭 Todas as Usinas (${activePlants.length})',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      ...activePlants.map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '☀️ ${p.name} (${p.regime.shortLabel} • ${_numFmt.format(p.estimatedMonthlyGenerationKwh)} kWh/mês)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedPlantId = v);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 4 CARDS RESUMO DO BALANÇO ENERGÉTICO DA USINA ───────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            final cardW = isNarrow
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth - 36) / 4;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardW,
                  child: _buildSummaryMetricCard(
                    title: 'GERAÇÃO ESTIMADA DA USINA',
                    value: '${_numFmt.format(totalGenerationCapacityKwh)} kWh',
                    subtitle: selectedPlant != null
                        ? 'Usina: ${selectedPlant.name} (${selectedPlant.regime.shortLabel})'
                        : 'Soma de ${activePlants.length} usina(s) cadastrada(s)',
                    icon: Icons.solar_power_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _buildSummaryMetricCard(
                    title: 'CONSUMO REAL DOS CLIENTES',
                    value: '${_numFmt.format(totalClientConsumptionKwh)} kWh',
                    subtitle: totalGenerationCapacityKwh > 0
                        ? 'Consome ${_decFmt.format((totalClientConsumptionKwh / totalGenerationCapacityKwh) * 100)}% da geração'
                        : '${filteredBeneficiaries.length} UCs beneficiárias',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _buildSummaryMetricCard(
                    title: 'SOMA DE % NA ENERGISA',
                    value: '${_decFmt.format(totalAllocatedPercent)}%',
                    subtitle: selectedPlant != null
                        ? (totalAllocatedPercent > 100.01
                            ? '⚠️ Atenção: Passou de 100% na usina!'
                            : 'Restam ${_decFmt.format(math.max(0, 100 - totalAllocatedPercent))}% livres para alocar')
                        : 'Distribuído em ${filteredBeneficiaries.length} clientes',
                    icon: Icons.pie_chart_rounded,
                    color: totalAllocatedPercent > 100.01
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _buildSummaryMetricCard(
                    title: 'SALDO ACUMULADO NOS RODAPÉS',
                    value: '${_numFmt.format(totalAccumulatedBalanceKwh)} kWh',
                    subtitle: 'Estoque total de créditos nas UCs dos clientes',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF818CF8),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // ── GRÁFICO COMPARATIVO POR CLIENTE (CONSUMO vs CRÉDITO INJETADO vs SALDO) ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gráfico de Consumo vs. Crédito Recebido & Saldo Acumulado por Cliente',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Compare visualmente quanto cada cliente consome, quanto recebe da usina e quanto já acumulou de saldo no rodapé',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 14,
                    children: [
                      _buildLegendDot(
                        'Consumo Mensal (kWh)',
                        const Color(0xFFEF4444),
                      ),
                      _buildLegendDot(
                        'Crédito Alocado / Injetado (kWh)',
                        const Color(0xFF10B981),
                      ),
                      _buildLegendDot(
                        'Saldo Acumulado no Rodapé (kWh)',
                        const Color(0xFF38BDF8),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (filteredBeneficiaries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'Nenhum cliente cadastrado nesta usina ainda. Cadastre seus clientes ou envie um PDF na aba "Explosão IA & Lançamento".',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                )
              else
                Column(
                  children: filteredBeneficiaries.map((b) {
                    final plant = selectedPlant ??
                        activePlants
                            .where((p) => p.id == b.generatorPlantId)
                            .firstOrNull;
                    final plantGen =
                        plant?.estimatedMonthlyGenerationKwh ?? 0.0;
                    final currentPctOnContext = selectedPlant != null
                        ? b.allocationPercentForPlant(
                            selectedPlant.id,
                            selectedPlant.name,
                          )
                        : b.utilityAllocationPercent;

                    final consumptionKwh =
                        _effectiveConsumptionKwh(b, filteredBills);
                    final totalFromAllPlantsKwh =
                        b.totalAllocatedCreditsKwh(activePlants);
                    final allocatedCreditKwh = totalFromAllPlantsKwh > 0
                        ? totalFromAllPlantsKwh
                        : (plantGen > 0
                            ? (plantGen * (currentPctOnContext / 100.0))
                            : _effectiveInjectedKwh(b, filteredBills));
                    final balanceKwh =
                        _effectiveAccumulatedBalanceKwh(b, filteredBills);

                    final maxVal = math.max(
                      100.0,
                      math.max(
                        consumptionKwh,
                        math.max(allocatedCreditKwh, balanceKwh),
                      ),
                    );

                    final diagnosis = _diagnoseBeneficiary(
                      consumptionKwh: consumptionKwh,
                      allocatedKwh: allocatedCreditKwh,
                      balanceKwh: balanceKwh,
                      currentPercent: currentPctOnContext,
                      plantGenKwh: plantGen,
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: diagnosis.statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      b.clientName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'UC: ${b.ucNumber} • ${b.allPlantsSummaryLabel}',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: diagnosis.statusColor
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: diagnosis.statusColor,
                                  ),
                                ),
                                child: Text(
                                  diagnosis.badgeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: diagnosis.statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Barras comparativas
                          _buildHorizontalBar(
                            label: 'Consumo Médio/Atual:',
                            valueKwh: consumptionKwh,
                            maxKwh: maxVal,
                            color: const Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 6),
                          _buildHorizontalBar(
                            label: b.hasMultiplePlants
                                ? 'Crédito Total (${b.effectivePlantAllocations.length} Usinas):'
                                : 'Crédito da Usina (${_decFmt.format(currentPctOnContext)}%):',
                            valueKwh: allocatedCreditKwh,
                            maxKwh: maxVal,
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(height: 6),
                          _buildHorizontalBar(
                            label: 'Saldo Acumulado no Rodapé:',
                            valueKwh: balanceKwh,
                            maxKwh: maxVal,
                            color: const Color(0xFF38BDF8),
                          ),
                          const SizedBox(height: 10),

                          // Recomendação de Remanejamento de % na Concessionária
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '💡 ${diagnosis.recommendationText}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                                if (diagnosis.suggestedPercent != null &&
                                    (diagnosis.suggestedPercent! -
                                                currentPctOnContext)
                                            .abs() >=
                                        0.5)
                                  TextButton.icon(
                                    onPressed: () async {
                                      await widget.repository
                                          .updateBeneficiaryAllocation(
                                        beneficiaryId: b.id,
                                        plantId: plant?.id,
                                        newAllocationPercent:
                                            diagnosis.suggestedPercent!,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Rateio de ${b.clientName} atualizado para ${_decFmt.format(diagnosis.suggestedPercent!)}%!',
                                            ),
                                            backgroundColor:
                                                const Color(0xFF10B981),
                                          ),
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.15),
                                      foregroundColor: const Color(0xFF38BDF8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.sync_alt_rounded,
                                      size: 15,
                                    ),
                                    label: Text(
                                      'Ajustar p/ ${_decFmt.format(diagnosis.suggestedPercent!)}%',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  double _effectiveConsumptionKwh(
    SolarCreditBeneficiaryModel b,
    List<SolarCreditBillModel> bills,
  ) {
    final clientBills =
        bills.where((bill) => bill.beneficiaryId == b.id).toList();
    if (clientBills.isNotEmpty) {
      return clientBills.first.consumptionKwh;
    }
    return b.averageMonthlyConsumptionKwh;
  }

  double _effectiveInjectedKwh(
    SolarCreditBeneficiaryModel b,
    List<SolarCreditBillModel> bills,
  ) {
    final clientBills =
        bills.where((bill) => bill.beneficiaryId == b.id).toList();
    if (clientBills.isNotEmpty) {
      return clientBills.first.totalInjectedKwh;
    }
    return b.lastInjectedKwh;
  }

  double _effectiveAccumulatedBalanceKwh(
    SolarCreditBeneficiaryModel b,
    List<SolarCreditBillModel> bills,
  ) {
    final clientBills =
        bills.where((bill) => bill.beneficiaryId == b.id).toList();
    if (clientBills.isNotEmpty) {
      return clientBills.first.accumulatedBalanceKwh;
    }
    return b.lastAccumulatedBalanceKwh;
  }

  _RateioDiagnosis _diagnoseBeneficiary({
    required double consumptionKwh,
    required double allocatedKwh,
    required double balanceKwh,
    required double currentPercent,
    required double plantGenKwh,
  }) {
    double? suggestedPercent;
    if (plantGenKwh > 0 && consumptionKwh > 0) {
      // Se o cliente já tem muito saldo acumulado (> 2x o consumo mensal), sugere reduzir para consumir o estoque em 6 meses
      double targetMonthlyNeed = consumptionKwh;
      if (balanceKwh > consumptionKwh * 1.5) {
        targetMonthlyNeed = math.max(0.0, consumptionKwh - (balanceKwh / 6.0));
      } else if (balanceKwh < consumptionKwh * 0.2 &&
          allocatedKwh < consumptionKwh) {
        targetMonthlyNeed = consumptionKwh * 1.05;
      }
      suggestedPercent =
          ((targetMonthlyNeed / plantGenKwh) * 100.0).clamp(0.0, 100.0);
    }

    // 1. Verifica sobra alta de saldo ou crédito alocado muito acima do consumo
    if (balanceKwh > consumptionKwh * 1.5 && balanceKwh >= 500) {
      final monthsStock = consumptionKwh > 0
          ? (balanceKwh / consumptionKwh).toStringAsFixed(1)
          : 'vários';
      return _RateioDiagnosis(
        badgeText: '🔵 SOBRANDO CRÉDITO (SALDO ALTO)',
        statusColor: const Color(0xFF38BDF8),
        recommendationText:
            'Cliente possui ${_numFmt.format(balanceKwh)} kWh acumulados no rodapé (~$monthsStock meses de estoque). Você pode REDUZIR a % dele na Energisa${suggestedPercent != null ? ' de ${_decFmt.format(currentPercent)}% para ~${_decFmt.format(suggestedPercent)}%' : ''} e realocar para outro cliente.',
        suggestedPercent: suggestedPercent,
      );
    }

    if (allocatedKwh > consumptionKwh * 1.18 && consumptionKwh > 0) {
      final diffKwh = allocatedKwh - consumptionKwh;
      return _RateioDiagnosis(
        badgeText: '🔵 SOBRANDO MÊS A MÊS (+${_numFmt.format(diffKwh)} kWh)',
        statusColor: const Color(0xFF38BDF8),
        recommendationText:
            'Recebe ~${_numFmt.format(allocatedKwh)} kWh/mês mas consome ${_numFmt.format(consumptionKwh)} kWh/mês. Sobra mensal de ${_numFmt.format(diffKwh)} kWh.${suggestedPercent != null ? ' Sugestão na Energisa: ${_decFmt.format(suggestedPercent)}%.' : ''}',
        suggestedPercent: suggestedPercent,
      );
    }

    // 2. Verifica falta de crédito (consumo maior que o alocado e saldo baixo)
    if (consumptionKwh > allocatedKwh * 1.10 &&
        balanceKwh < consumptionKwh * 0.8) {
      final deficit = consumptionKwh - allocatedKwh;
      return _RateioDiagnosis(
        badgeText: '🔴 PRECISANDO DE MAIS CRÉDITO (-${_numFmt.format(deficit)} kWh)',
        statusColor: const Color(0xFFEF4444),
        recommendationText:
            'Consome ${_numFmt.format(consumptionKwh)} kWh/mês, mas recebe ~${_numFmt.format(allocatedKwh)} kWh/mês (déficit de ${_numFmt.format(deficit)} kWh). AUMENTE a % na Energisa${suggestedPercent != null ? ' de ${_decFmt.format(currentPercent)}% para ~${_decFmt.format(suggestedPercent)}%' : ''}.',
        suggestedPercent: suggestedPercent,
      );
    }

    return _RateioDiagnosis(
      badgeText: '🟢 RATEIO EQUILIBRADO',
      statusColor: const Color(0xFF10B981),
      recommendationText:
          'Consumo (${_numFmt.format(consumptionKwh)} kWh) e créditos estão equilibrados. Saldo de reserva atual: ${_numFmt.format(balanceKwh)} kWh.',
      suggestedPercent: suggestedPercent,
    );
  }

  Widget _buildHorizontalBar({
    required String label,
    required double valueKwh,
    required double maxKwh,
    required Color color,
  }) {
    final ratio = (valueKwh / maxKwh).clamp(0.02, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 210,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFFCBD5E1),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              color: const Color(0xFF1E293B),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 95,
          child: Text(
            '${_numFmt.format(valueKwh)} kWh',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateioDiagnosis {
  final String badgeText;
  final Color statusColor;
  final String recommendationText;
  final double? suggestedPercent;

  const _RateioDiagnosis({
    required this.badgeText,
    required this.statusColor,
    required this.recommendationText,
    this.suggestedPercent,
  });
}

