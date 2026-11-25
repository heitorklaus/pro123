import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../data/repositories/solar_credit_repository.dart';
import '../../domain/models/solar_credit_models.dart';

/// Diálogo executivo de alerta de faturas de Créditos Solar (GD) a <= 10 dias do vencimento.
///
/// Regra Multi-Conta:
/// - Hoje o módulo Créditos Solar (GD) está restrito ao SuperAdmin (`heitorklaus@hotmail.com`).
/// - Quando habilitado para admins de outras contas no futuro, basta liberar
///   em [isUserEligibleForAlerts] mantendo todo o isolamento por `companyId`.
class SolarCreditDueAlertDialog extends StatefulWidget {
  final List<SolarCreditBillModel> bills;
  final SolarCreditRepository repository;
  final String? focusBillId;
  final VoidCallback? onOpenSolarCredits;

  const SolarCreditDueAlertDialog({
    super.key,
    required this.bills,
    required this.repository,
    this.focusBillId,
    this.onOpenSolarCredits,
  });

  /// Evita repetir o popup automaticamente várias vezes na mesma sessão
  static final Set<String> _sessionDismissedBillIds = <String>{};
  static bool _isDialogOpen = false;

  /// Define quem recebe os popups de vencimento de Créditos Solar.
  /// Hoje: SuperAdmin (`heitorklaus@hotmail.com`).
  /// Futuro: quando o módulo GD for liberado para Admins de conta, incluir `user.isAdmin`.
  static bool isUserEligibleForAlerts(UserModel user) {
    return user.isSuperAdmin;
  }

  /// Verifica no Firestore as faturas pendentes com vencimento <= 10 dias
  /// e exibe o popup se houver pendências ainda não dispensadas na sessão.
  static Future<void> checkAndShowIfNeeded(
    BuildContext context, {
    required UserModel currentUser,
    String? focusBillId,
    bool forceShow = false,
    VoidCallback? onOpenSolarCredits,
  }) async {
    if (!isUserEligibleForAlerts(currentUser)) return;
    if (_isDialogOpen && !forceShow) return;

    try {
      final repo = SolarCreditRepository();
      final nearDue = await repo.getPendingBillsNearDue(
        companyId: currentUser.effectiveCompanyId,
        maxDays: 10,
      );

      final visibleBills = forceShow
          ? nearDue
          : nearDue
              .where((b) => !_sessionDismissedBillIds.contains(b.id))
              .toList();

      if (visibleBills.isEmpty || !context.mounted) return;

      // Se veio de um Push Notification com billId específico, coloca essa fatura no topo
      if (focusBillId != null && focusBillId.isNotEmpty) {
        visibleBills.sort((a, b) {
          if (a.id == focusBillId) return -1;
          if (b.id == focusBillId) return 1;
          return (a.daysUntilDue ?? 999).compareTo(b.daysUntilDue ?? 999);
        });
      }

      _isDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => SolarCreditDueAlertDialog(
          bills: visibleBills,
          repository: repo,
          focusBillId: focusBillId,
          onOpenSolarCredits: onOpenSolarCredits,
        ),
      );
    } catch (e) {
      debugPrint('[SolarCreditDueAlertDialog] Erro ao checar vencimentos: $e');
    } finally {
      _isDialogOpen = false;
    }
  }

  @override
  State<SolarCreditDueAlertDialog> createState() =>
      _SolarCreditDueAlertDialogState();
}

class _SolarCreditDueAlertDialogState extends State<SolarCreditDueAlertDialog> {
  late List<SolarCreditBillModel> _bills;
  final Set<String> _busyBillIds = <String>{};
  final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _bills = List<SolarCreditBillModel>.from(widget.bills);
  }

  Future<void> _markAsPaid(SolarCreditBillModel bill) async {
    setState(() => _busyBillIds.add(bill.id));
    try {
      await widget.repository.updateBillPaymentStatus(bill.id, 'paid');
      SolarCreditDueAlertDialog._sessionDismissedBillIds.add(bill.id);
      if (!mounted) return;
      setState(() {
        _bills.removeWhere((b) => b.id == bill.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Fatura de ${bill.clientName} (${bill.referenceMonth}) marcada como PAGA. Não lembraremos mais dela.',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_bills.isEmpty && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao marcar fatura como paga: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBillIds.remove(bill.id));
    }
  }

  void _keepReminding(SolarCreditBillModel bill) {
    SolarCreditDueAlertDialog._sessionDismissedBillIds.add(bill.id);
    setState(() {
      _bills.removeWhere((b) => b.id == bill.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔔 Ok! Continuaremos lembrando da fatura de ${bill.clientName} nos próximos acessos/dias.',
        ),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (_bills.isEmpty && mounted) Navigator.pop(context);
  }

  Future<void> _rescheduleOnlyThisBill(SolarCreditBillModel bill) async {
    final now = DateTime.now();
    final currentEffective = bill.effectiveDueDate ?? now;
    final initialDate = currentEffective.isBefore(now) ? now : currentEffective;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText:
          'Nova data de pagamento (somente fatura ${bill.referenceMonth})',
      confirmText: 'CONFIRMAR DATA',
      cancelText: 'CANCELAR',
    );

    if (picked == null || !mounted) return;

    final formatted = DateFormat('dd/MM/yyyy').format(picked);
    setState(() => _busyBillIds.add(bill.id));
    try {
      await widget.repository.updateBillPromisedPaymentDate(bill.id, formatted);
      if (!mounted) return;

      final daysDiff = DateTime(picked.year, picked.month, picked.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      if (daysDiff > 10) {
        setState(() {
          _bills.removeWhere((b) => b.id == bill.id);
        });
      } else {
        // Atualiza em memória para refletir a nova data imediatamente
        final updatedMap = bill.toMap()..['promisedPaymentDate'] = formatted;
        final updatedBill = SolarCreditBillModel.fromMap(updatedMap, bill.id);
        setState(() {
          final idx = _bills.indexWhere((b) => b.id == bill.id);
          if (idx >= 0) _bills[idx] = updatedBill;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📅 Nova data ($formatted) salva somente para a fatura ${bill.referenceMonth} de ${bill.clientName}. As próximas faturas seguem o vencimento normal.',
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_bills.isEmpty && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reagendar data da fatura: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBillIds.remove(bill.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFFF59E0B),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aviso de Vencimento — Créditos Solar (GD)',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '${_bills.length} fatura(s) pendente(s) vencendo em até 10 dias ou já vencidas',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar por agora',
                    onPressed: () {
                      for (final b in _bills) {
                        SolarCreditDueAlertDialog._sessionDismissedBillIds
                            .add(b.id);
                      }
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de faturas
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _bills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final days = bill.daysUntilDue ?? 0;
                    final isOverdue = days < 0;
                    final isToday = days == 0;
                    final badgeColor = (isOverdue || isToday)
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B);
                    final badgeText = isOverdue
                        ? 'VENCIDA HÁ ${days.abs()} DIA(S)'
                        : (isToday
                            ? 'VENCE HOJE'
                            : 'VENCE EM $days DIA(S)');
                    final isBusy = _busyBillIds.contains(bill.id);
                    final isFocused = widget.focusBillId == bill.id;
                    final hasPromised = bill.promisedPaymentDate != null &&
                        bill.promisedPaymentDate!.trim().isNotEmpty;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isFocused
                              ? const Color(0xFF38BDF8)
                              : badgeColor.withValues(alpha: 0.45),
                          width: isFocused ? 1.8 : 1.1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bill.clientName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'UC: ${bill.ucNumber} • Ref: ${bill.referenceMonth} • Usina: ${bill.generatorPlantName}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: badgeColor),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Valores e Datas
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              Text(
                                '💳 Valor Solar 7: ${_currencyFmt.format(bill.solarCompanyAmountToPayRs)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF38BDF8),
                                ),
                              ),
                              Text(
                                '📆 Vencimento da fatura: ${bill.dueDate}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: textPrimary,
                                ),
                              ),
                              if (hasPromised)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '📅 Nova data combinada (só esta fatura): ${bill.promisedPaymentDate}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 3 Botões de ação
                          if (isBusy)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: LinearProgressIndicator(minHeight: 3),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _markAsPaid(bill),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'NÃO ME LEMBRAR MAIS, FATURA PAGA',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _keepReminding(bill),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF38BDF8),
                                    side: const BorderSide(
                                      color: Color(0xFF38BDF8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.notifications_paused_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'OK, CONTINUAR ME LEMBRANDO',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _rescheduleOnlyThisBill(bill),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF59E0B),
                                    side: const BorderSide(
                                      color: Color(0xFFF59E0B),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'CLIENTE PODERÁ PAGAR (ESCOLHER DATA)',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Rodapé
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onOpenSolarCredits != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenSolarCredits?.call();
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('ABRIR MÓDULO CRÉDITOS SOLAR'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      for (final b in _bills) {
                        SolarCreditDueAlertDialog._sessionDismissedBillIds
                            .add(b.id);
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      foregroundColor: textPrimary,
                    ),
                    child: const Text('FECHAR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
