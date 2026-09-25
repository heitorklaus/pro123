import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/proposal_pages_models.dart';
import 'cover_header_footer_widgets.dart';

/// Canvas Interativo A4 da Página 2: Renderiza fielmente os cards de diferenciais,
/// escopo do projeto, cabeçalho, rodapé e o banner ilustrativo tecnológico
class CoverPage2InteractiveCanvas extends StatelessWidget {
  final double width;
  final double height;
  final double scale;
  final bool isSolar;
  final Color primaryColor;
  final List<ProposalPageCard> cards;
  final String? selectedCardId;
  final ValueChanged<String> onSelectCard;
  final bool showHeader;
  final int headerStyle;
  final String headerText1;
  final String headerText2;
  final String headerText3;
  final String headerBgColor;
  final String headerTextColor;
  final String headerIconColor;
  final bool showFooter;
  final int footerStyle;
  final String footerText1;
  final String footerText2;
  final String footerText3;
  final String footerText4;
  final String footerBgColor;
  final String footerTextColor;
  final String footerIconColor;
  final bool showIllustration;
  final String illustrationType; // 'banner', 'isometric', 'photo', 'none'

  const CoverPage2InteractiveCanvas({
    super.key,
    required this.width,
    required this.height,
    required this.scale,
    required this.isSolar,
    required this.primaryColor,
    required this.cards,
    this.selectedCardId,
    required this.onSelectCard,
    required this.showHeader,
    required this.headerStyle,
    required this.headerText1,
    required this.headerText2,
    required this.headerText3,
    required this.headerBgColor,
    required this.headerTextColor,
    required this.headerIconColor,
    required this.showFooter,
    required this.footerStyle,
    required this.footerText1,
    required this.footerText2,
    required this.footerText3,
    required this.footerText4,
    required this.footerBgColor,
    required this.footerTextColor,
    required this.footerIconColor,
    required this.showIllustration,
    required this.illustrationType,
  });

  @override
  Widget build(BuildContext context) {
    // Separa cards visíveis em grupo 1 (Diferenciais) e grupo 2 (Escopo)
    final visibleCards = cards.where((c) => c.isVisible).toList();
    final firstGroup = visibleCards.take(4).toList();
    final secondGroup = visibleCards.skip(4).take(4).toList();

    return Container(
      width: width,
      height: height,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho Oficial
          if (showHeader)
            CoverHeaderWidget(
              styleId: headerStyle,
              text1: headerText1.isNotEmpty ? headerText1 : (isSolar ? 'ENERGIA SOLAR FOTOVOLTAICA' : 'AUTOMAÇÃO RESIDENCIAL'),
              text2: headerText2.isNotEmpty ? headerText2 : 'PROPOSTA TÉCNICA COMERCIAL',
              text3: headerText3.isNotEmpty ? headerText3 : 'Página 2 de 5',
              scale: scale,
              accentColor: primaryColor,
              customBgColorHex: headerBgColor,
              customTextColorHex: headerTextColor,
              customIconColorHex: headerIconColor,
            ),

          // 2. Miolo da Página 2
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22 * scale, vertical: 10 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 2 * scale),
                  Text(
                    isSolar
                        ? 'Por que escolher a nossa solução solar?'
                        : 'Por que escolher a nossa solução de automação?',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8 * scale),

                  // Grupo 1: Diferenciais (Grid 2x2)
                  if (firstGroup.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(child: _buildCardItem(firstGroup[0])),
                        if (firstGroup.length > 1) ...[
                          SizedBox(width: 8 * scale),
                          Expanded(child: _buildCardItem(firstGroup[1])),
                        ],
                      ],
                    ),
                    if (firstGroup.length > 2) ...[
                      SizedBox(height: 7 * scale),
                      Row(
                        children: [
                          Expanded(child: _buildCardItem(firstGroup[2])),
                          if (firstGroup.length > 3) ...[
                            SizedBox(width: 8 * scale),
                            Expanded(child: _buildCardItem(firstGroup[3])),
                          ],
                        ],
                      ),
                    ],
                  ],

                  SizedBox(height: 12 * scale),
                  Text(
                    isSolar
                        ? 'Escopo do Fornecimento & Solução Turn-Key'
                        : 'Escopo do Projeto & Solução Turn-Key',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8 * scale),

                  // Grupo 2: Escopo (Grid 2x2)
                  if (secondGroup.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(child: _buildCardItem(secondGroup[0])),
                        if (secondGroup.length > 1) ...[
                          SizedBox(width: 8 * scale),
                          Expanded(child: _buildCardItem(secondGroup[1])),
                        ],
                      ],
                    ),
                    if (secondGroup.length > 2) ...[
                      SizedBox(height: 7 * scale),
                      Row(
                        children: [
                          Expanded(child: _buildCardItem(secondGroup[2])),
                          if (secondGroup.length > 3) ...[
                            SizedBox(width: 8 * scale),
                            Expanded(child: _buildCardItem(secondGroup[3])),
                          ],
                        ],
                      ),
                    ],
                  ],

                  // 3. Ilustração Tecnológica Inferior
                  if (showIllustration && illustrationType != 'none') ...[
                    SizedBox(height: 8 * scale),
                    Expanded(child: _buildBottomIllustration()),
                  ],
                ],
              ),
            ),
          ),

          // 4. Rodapé Oficial
          if (showFooter)
            CoverFooterWidget(
              styleId: footerStyle,
              text1: footerText1.isNotEmpty ? footerText1 : 'EXPERIÊNCIA ÚNICA • ALTA ENGENHARIA',
              text2: footerText2.isNotEmpty ? footerText2 : 'contato@empresa.com.br',
              text3: footerText3.isNotEmpty ? footerText3 : 'www.empresa.com.br',
              text4: footerText4.isNotEmpty ? footerText4 : 'Página 2 de 5',
              scale: scale,
              accentColor: primaryColor,
              customBgColorHex: footerBgColor,
              customTextColorHex: footerTextColor,
              customIconColorHex: footerIconColor,
            ),
        ],
      ),
    );
  }

  Widget _buildCardItem(ProposalPageCard card) {
    final isSelected = selectedCardId == card.id;
    final cardColor = Color(int.tryParse(card.colorHex.replaceAll('#', '0xFF')) ?? 0xFF0284C7);

    return InkWell(
      onTap: () => onSelectCard(card.id),
      borderRadius: BorderRadius.circular(8 * scale),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Card Branco Retangular
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 10 * scale),
            padding: EdgeInsets.only(
              top: 14 * scale,
              bottom: 6 * scale,
              left: 8 * scale,
              right: 8 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8 * scale),
              border: Border.all(
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                width: isSelected ? 2.0 : 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isSelected ? 6 * scale : 4 * scale,
                  offset: Offset(0, 2 * scale),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 8.2 * scale,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2 * scale),
                Text(
                  card.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 6.5 * scale,
                    color: const Color(0xFF64748B),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Badge Circular Superior com Ícone
          Positioned(
            top: 0,
            child: Container(
              width: 20 * scale,
              height: 20 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3 * scale,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getCardIcon(card.iconKey),
                  size: 11 * scale,
                  color: cardColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIllustration() {
    String headerLabel = isSolar ? 'ENGENHARIA FOTOVOLTAICA DE ALTA PERFORMANCE' : 'ECOSSISTEMA RESIDENCIAL INTEGRADO & IOT';
    String headerSub = isSolar ? 'Módulos Tier-1 • Inversores Homologados • Homologação' : 'Wi-Fi 6 Mesh • Automação Total • Cenas Inteligentes';

    switch (illustrationType.toLowerCase()) {
      case 'blueprint':
        headerLabel = 'PROJETO TÉCNICO & INFRAESTRUTURA DE ENGENHARIA';
        headerSub = 'Normas ABNT NBR 5410 • Cabeamento Estruturado Cat6A • ART/CREA';
        break;
      case 'cyberdark':
        headerLabel = 'INFRAESTRUTURA CIBERNÉTICA & SEGURANÇA LOCAL';
        headerSub = 'Criptografia Local AES-256 • Conexão Local sem Nuvem • Latência Zero';
        break;
      case 'luxurygold':
        headerLabel = 'PADRÃO ALTA NOBREZA & DESIGN EUROPEU';
        headerSub = 'Metais Nobres Escovados • Keypads de Vidro • Atendimento Concierge VIP';
        break;
      case 'timeline':
        headerLabel = 'JORNADA DO CLIENTE & PROCESSO TURN-KEY DE ENTREGA';
        headerSub = '1. Projeto ➔ 2. Infraestrutura ➔ 3. Programação ➔ 4. Entrega Técnica';
        break;
      case 'solarflow':
        headerLabel = 'FLUXO ENERGÉTICO DO GERADOR SOLAR FOTOVOLTAICO';
        headerSub = 'Módulos Fotovoltaicos ➔ Inversor Grid-Tie ➔ Quadro Geral ➔ Consumo & Rede';
        break;
      case 'iotnetwork':
        headerLabel = 'TOPOLOGIA DE REDE MESH & HUB CENTRAL IOT';
        headerSub = 'Protocolos Zigbee 3.0 • Matter • Thread • Wi-Fi 6 Corporativo';
        break;
      case 'greeneco':
        headerLabel = 'EFICIÊNCIA ENERGÉTICA & PRESERVAÇÃO AMBIENTAL';
        headerSub = 'Redução de Emissões de CO2 • Certificação Verde • Economia Sustentável';
        break;
    }

    final ilType = illustrationType.toLowerCase();
    Color contBg = const Color(0xFFF8FAFC);
    Color contBorder = const Color(0xFFE2E8F0);
    Color subColor = const Color(0xFF64748B);

    if (ilType == 'cyberdark') {
      contBg = const Color(0xFF090D16);
      contBorder = const Color(0xFF1E293B);
      subColor = const Color(0xFF94A3B8);
    } else if (ilType == 'blueprint') {
      contBg = const Color(0xFF0F2744);
      contBorder = const Color(0xFF1E40AF);
      subColor = const Color(0xFF93C5FD);
    } else if (ilType == 'luxurygold') {
      contBg = const Color(0xFF1C1917);
      contBorder = const Color(0xFFD97706);
      subColor = const Color(0xFFFDE68A);
    } else if (ilType == 'solarflow') {
      contBg = const Color(0xFFFEF3C7);
      contBorder = const Color(0xFFF59E0B);
      subColor = const Color(0xFF92400E);
    } else if (ilType == 'iotnetwork') {
      contBg = const Color(0xFFEEF2FF);
      contBorder = const Color(0xFF818CF8);
      subColor = const Color(0xFF4338CA);
    } else if (ilType == 'greeneco') {
      contBg = const Color(0xFFECFDF5);
      contBorder = const Color(0xFF10B981);
      subColor = const Color(0xFF065F46);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: contBg,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: contBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 5 * scale,
                    height: 5 * scale,
                    decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 4 * scale),
                  Text(
                    headerLabel,
                    style: GoogleFonts.inter(
                      fontSize: 6.8 * scale,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                headerSub,
                style: GoogleFonts.inter(
                  fontSize: 6.0 * scale,
                  color: subColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 3 * scale),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6 * scale),
              child: _buildSpecificIllustrationContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificIllustrationContent() {
    switch (illustrationType.toLowerCase()) {
      case 'isometric':
        return Image.asset(
          'assets/images/smart_home_isometric.jpg',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackIllustration(Icons.layers_rounded),
        );

      case 'blueprint':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F2744),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(color: const Color(0xFF1E40AF), width: 1),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBlueprintStep('1. TUBULAÇÃO', 'Conduítes Secos', Icons.architecture_rounded),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFF60A5FA), size: 12 * scale),
              _buildBlueprintStep('2. RACK CAT6A', 'Patch Panel', Icons.dns_rounded),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFF60A5FA), size: 12 * scale),
              _buildBlueprintStep('3. QUADRO QDA', 'Disjuntores & DPS', Icons.electric_bolt_rounded),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFF60A5FA), size: 12 * scale),
              _buildBlueprintStep('4. COMISSIONAMENTO', 'Testes Ponto a Ponto', Icons.verified_rounded),
            ],
          ),
        );

      case 'cyberdark':
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF050B14), Color(0xFF0D1B2A)],
            ),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCyberBadge('GATEWAY LOCAL', 'AES-256', Icons.lock_outline_rounded, const Color(0xFF38BDF8)),
              _buildCyberBadge('REDE MESH', 'Zero Latência', Icons.wifi_rounded, const Color(0xFF06B6D4)),
              _buildCyberBadge('DISPOSITIVOS', 'Matter / Zigbee', Icons.hub_rounded, const Color(0xFF818CF8)),
              _buildCyberBadge('STATUS GERAL', '100% Online', Icons.check_circle_outline_rounded, const Color(0xFF10B981)),
            ],
          ),
        );

      case 'luxurygold':
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C1917), Color(0xFF292524)],
            ),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(color: const Color(0xFFD97706), width: 1),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLuxuryBadge('ALTA NOBREZA', 'Materiais Europeus', Icons.workspace_premium_rounded),
              _buildLuxuryBadge('SONORIZAÇÃO HI-RES', 'Amplificadores DSP', Icons.surround_sound_rounded),
              _buildLuxuryBadge('GARANTIA VIP', '3 Anos com Troca', Icons.shield_rounded),
              _buildLuxuryBadge('CONCIERGE DEDICADO', 'Suporte Prioritário', Icons.star_rounded),
            ],
          ),
        );

      case 'timeline':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
          child: Row(
            children: [
              _buildTimelineStep(1, 'Projeto', 'Estudo & Dimensionamento', const Color(0xFF0284C7)),
              _buildTimelineDivider(),
              _buildTimelineStep(2, 'Infraestrutura', 'Tubulações & Cabos', const Color(0xFF0284C7)),
              _buildTimelineDivider(),
              _buildTimelineStep(3, 'Instalação', 'Módulos & Keypads', const Color(0xFF0284C7)),
              _buildTimelineDivider(),
              _buildTimelineStep(4, 'Treinamento', 'Cenas & Entrega', const Color(0xFF10B981)),
            ],
          ),
        );

      case 'solarflow':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFlowStep('Painéis Solares', 'Captação Solar', Icons.solar_power_rounded, const Color(0xFFD97706)),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFFF59E0B), size: 14 * scale),
              _buildFlowStep('Inversor Grid-Tie', 'Conversão CC/CA', Icons.swap_horiz_rounded, const Color(0xFF0284C7)),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFFF59E0B), size: 14 * scale),
              _buildFlowStep('Quadro Geral', 'Alimentação da Casa', Icons.bolt_rounded, const Color(0xFF10B981)),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFFF59E0B), size: 14 * scale),
              _buildFlowStep('Rede da Concessionária', 'Créditos em kWh', Icons.power_rounded, const Color(0xFF6366F1)),
            ],
          ),
        );

      case 'iotnetwork':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(color: const Color(0xFF818CF8)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNetworkNode('Iluminação', Icons.lightbulb_rounded, const Color(0xFF6366F1)),
              _buildNetworkNode('Segurança', Icons.shield_rounded, const Color(0xFF0284C7)),
              _buildNetworkHub('HUB CENTRAL\nMATTER', Icons.hub_rounded, const Color(0xFF4338CA)),
              _buildNetworkNode('Clima', Icons.thermostat_rounded, const Color(0xFF059669)),
              _buildNetworkNode('Áudio Hi-Fi', Icons.music_note_rounded, const Color(0xFFD97706)),
            ],
          ),
        );

      case 'greeneco':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEcoBadge('ENERGIA LIMPA', '100% Renovável', Icons.solar_power_rounded, const Color(0xFF10B981)),
              _buildEcoBadge('MENOS CO2', '-2.4 Ton/ano', Icons.eco_rounded, const Color(0xFF059669)),
              _buildEcoBadge('EFICIÊNCIA A+', 'Zero Desperdício', Icons.energy_savings_leaf_rounded, const Color(0xFF047857)),
              _buildEcoBadge('ECONOMIA', 'Até 95% Menos', Icons.trending_down_rounded, const Color(0xFF0284C7)),
            ],
          ),
        );

      case 'banner':
      default:
        return Image.asset(
          'assets/images/smart_home_banner.jpg',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackIllustration(isSolar ? Icons.solar_power_rounded : Icons.home_rounded),
        );
    }
  }

  Widget _buildBlueprintStep(String title, String subtitle, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF93C5FD), size: 14 * scale),
        SizedBox(height: 2 * scale),
        Text(title, style: GoogleFonts.inter(fontSize: 6.5 * scale, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 5.5 * scale, color: const Color(0xFF93C5FD))),
      ],
    );
  }

  Widget _buildCyberBadge(String title, String subtitle, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14 * scale),
        SizedBox(height: 2 * scale),
        Text(title, style: GoogleFonts.inter(fontSize: 6.5 * scale, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 5.5 * scale, color: color)),
      ],
    );
  }

  Widget _buildLuxuryBadge(String title, String subtitle, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFF59E0B), size: 14 * scale),
        SizedBox(height: 2 * scale),
        Text(title, style: GoogleFonts.inter(fontSize: 6.5 * scale, fontWeight: FontWeight.bold, color: const Color(0xFFFEF3C7))),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 5.5 * scale, color: const Color(0xFFD97706))),
      ],
    );
  }

  Widget _buildTimelineStep(int num, String title, String subtitle, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14 * scale,
            height: 14 * scale,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$num',
                style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(title, style: GoogleFonts.inter(fontSize: 6.5 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 5.2 * scale, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildTimelineDivider() {
    return Container(
      width: 18 * scale,
      height: 1.5,
      color: const Color(0xFF94A3B8),
      margin: EdgeInsets.symmetric(horizontal: 4 * scale),
    );
  }

  Widget _buildFlowStep(String title, String subtitle, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14 * scale),
        SizedBox(height: 2 * scale),
        Text(title, style: GoogleFonts.inter(fontSize: 6.5 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 5.5 * scale, color: const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildNetworkNode(String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(4 * scale),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.5))),
          child: Icon(icon, color: color, size: 11 * scale),
        ),
        SizedBox(height: 2 * scale),
        Text(label, style: GoogleFonts.inter(fontSize: 6.0 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildNetworkHub(String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6 * scale),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4 * scale)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13 * scale),
          SizedBox(height: 2 * scale),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 5.5 * scale, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
        ],
      ),
    );
  }

  Widget _buildEcoBadge(String title, String subtitle, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14 * scale),
        SizedBox(height: 2 * scale),
        Text(title, style: GoogleFonts.inter(fontSize: 6.5 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF065F46))),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 5.5 * scale, color: color)),
      ],
    );
  }

  Widget _buildFallbackIllustration(IconData icon) {
    return Center(
      child: Icon(
        icon,
        size: 32 * scale,
        color: primaryColor.withValues(alpha: 0.4),
      ),
    );
  }

  IconData _getCardIcon(String key) {
    switch (key.toLowerCase()) {
      case 'lightbulb':
      case 'light':
        return Icons.lightbulb_outline_rounded;
      case 'shield':
        return Icons.shield_outlined;
      case 'eco':
        return Icons.eco_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'blueprint':
      case 'engineering':
        return Icons.architecture_rounded;
      case 'phone':
        return Icons.smartphone_rounded;
      case 'award':
        return Icons.verified_rounded;
      case 'handshake':
        return Icons.handshake_outlined;
      case 'solar_power':
        return Icons.solar_power_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'coins':
        return Icons.monetization_on_outlined;
      case 'chart':
        return Icons.trending_up_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'camera':
        return Icons.videocam_outlined;
      case 'lock':
        return Icons.lock_outline_rounded;
      default:
        return Icons.star_border_rounded;
    }
  }
}
