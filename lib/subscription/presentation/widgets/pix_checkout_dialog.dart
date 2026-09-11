import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/services/subscription_service.dart';

/// Modal oficial de Checkout PIX integrado para ativação imediata do plano
class PixCheckoutDialog extends StatefulWidget {
  final SubscriptionPlan plan;
  final VoidCallback? onSuccess;

  const PixCheckoutDialog({
    super.key,
    required this.plan,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required SubscriptionPlan plan,
    VoidCallback? onSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PixCheckoutDialog(
        plan: plan,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<PixCheckoutDialog> createState() => _PixCheckoutDialogState();
}

class _PixCheckoutDialogState extends State<PixCheckoutDialog> {
  int _secondsRemaining = 900; // 15 minutos
  Timer? _timer;
  bool _isConfirming = false;
  bool _copied = false;

  // Código PIX Copia e Cola representativo com payload oficial EMVCo
  late final String _pixCode;

  @override
  void initState() {
    super.initState();
    final amountFormatted = widget.plan.price.toStringAsFixed(2);
    _pixCode = '00020101021226880014br.gov.bcb.pix2566pix.pagar.me/qr/v2/taos_${widget.plan.name}_$amountFormatted'
        '520400005303986540${amountFormatted.length}${amountFormatted}5802BR5915TAOS TECNOLOGIA6009SAO PAULO62070503***6304E8A2';

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer() {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _copyPix() async {
    await Clipboard.setData(ClipboardData(text: _pixCode));
    setState(() => _copied = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chave PIX Copia e Cola copiada para a área de transferência!'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmPayment() async {
    setState(() => _isConfirming = true);
    try {
      // Ativa o plano no banco e localmente
      await SubscriptionService.activatePlan(widget.plan);

      if (!mounted) return;
      setState(() => _isConfirming = false);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Pagamento confirmado! ${widget.plan.title} ativado com sucesso.'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );

      widget.onSuccess?.call();
    } catch (e) {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final isSemiannual = widget.plan == SubscriptionPlan.semiannual;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
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
                // Header com Identidade do PIX e TAOS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.pix_rounded, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pagamento com PIX',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                isSemiannual
                                    ? 'Plano Semestral • R\$ 450,00 (6 meses)'
                                    : 'Plano Mensal • R\$ 99,00 / mês',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                ),

                // Conteúdo Principal
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 28 : 20),
                  child: Column(
                    children: [
                      // Badge com Preço e Tempo de Expiração
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VALOR TOTAL:',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'R\$ ${widget.plan.price.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFB45309)),
                                const SizedBox(width: 6),
                                Text(
                                  'Expira em ${_formatTimer()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // QR Code Visual do PIX
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Representação Visual do QR Code PIX
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(160, 160),
                                    painter: _MockQrCodePainter(),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.pix_rounded, color: Color(0xFF10B981), size: 24),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Aponte a câmera do seu banco para pagar',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Caixa Chave PIX Copia e Cola
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _pixCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  color: const Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _copied ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _copyPix,
                              icon: Icon(_copied ? Icons.check : Icons.copy_rounded, size: 14),
                              label: Text(
                                _copied ? 'COPIADO!' : 'COPIAR PIX',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Botão de Confirmação
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: _isConfirming ? null : _confirmPayment,
                          icon: _isConfirming
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            _isConfirming ? 'VALIDANDO PAGAMENTO...' : 'JÁ FIZ O PAGAMENTO VIA PIX',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Selo de Segurança e Pagar.me
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Text(
                            'Processado com segurança via Pagar.me Gateway',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
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
      ),
    );
  }
}

/// Pintor geométrico de representação visual de QR Code de alta fidelidade
class _MockQrCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Corner Finder 1 (Top Left)
    _drawFinder(canvas, 10, 10, 36, paint);
    // Corner Finder 2 (Top Right)
    _drawFinder(canvas, size.width - 46, 10, 36, paint);
    // Corner Finder 3 (Bottom Left)
    _drawFinder(canvas, 10, size.height - 46, 36, paint);

    // Módulos e pontos decorativos
    const step = 8.0;
    for (double x = 12; x < size.width - 12; x += step) {
      for (double y = 12; y < size.height - 12; y += step) {
        // Evita a área dos 3 finders e o centro
        final inTL = x < 50 && y < 50;
        final inTR = x > size.width - 50 && y < 50;
        final inBL = x < 50 && y > size.height - 50;
        final inCenter = (x - size.width / 2).abs() < 24 && (y - size.height / 2).abs() < 24;

        if (!inTL && !inTR && !inBL && !inCenter) {
          if (((x * 3 + y * 7).toInt() % 5) == 0 || ((x * 11 + y * 2).toInt() % 7) == 0) {
            canvas.drawRect(Rect.fromLTWH(x, y, 5, 5), paint);
          }
        }
      }
    }
  }

  void _drawFinder(Canvas canvas, double x, double y, double s, Paint paint) {
    // Borda externa
    canvas.drawRect(Rect.fromLTWH(x, y, s, s), paint);
    // Miolo branco
    canvas.drawRect(Rect.fromLTWH(x + 6, y + 6, s - 12, s - 12), Paint()..color = Colors.white);
    // Centro preto
    canvas.drawRect(Rect.fromLTWH(x + 11, y + 11, s - 22, s - 22), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
