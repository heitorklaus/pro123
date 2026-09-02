import 'package:intl/intl.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../proposals/domain/models/proposal_item_model.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../../settings/domain/models/company_model.dart';

/// Tag dinâmica disponível para inserção no editor
class ContractTagInfo {
  final String tag;
  final String label;
  final String category;
  final String example;

  const ContractTagInfo({
    required this.tag,
    required this.label,
    required this.category,
    required this.example,
  });
}

/// Motor de geração e interpolação do Contrato Padrão Fotovoltaico Oficial
class ContractTemplateEngine {
  /// Lista de tags dinâmicas suportadas pelo editor
  static const List<ContractTagInfo> availableTags = [
    // Contratante / Cliente
    ContractTagInfo(tag: '{{NOME_CONTRATANTE}}', label: 'Nome do Cliente', category: 'Cliente', example: 'Ana Maria Martins Debellis'),
    ContractTagInfo(tag: '{{TIPO_DOC_CONTRATANTE}}', label: 'Tipo Documento Cliente', category: 'Cliente', example: 'CPF'),
    ContractTagInfo(tag: '{{DOCUMENTO_CONTRATANTE}}', label: 'CPF / CNPJ Cliente', category: 'Cliente', example: '198.557.548-59'),
    ContractTagInfo(tag: '{{ENDERECO_CONTRATANTE}}', label: 'Endereço Completo do Cliente', category: 'Cliente', example: 'Rua N 12, Qd 22 - Cuiabá/MT'),
    ContractTagInfo(tag: '{{CIDADE_CLIENTE}}', label: 'Cidade do Cliente', category: 'Cliente', example: 'Cuiabá'),
    ContractTagInfo(tag: '{{UF_CLIENTE}}', label: 'Estado (UF) do Cliente', category: 'Cliente', example: 'MT'),
    ContractTagInfo(tag: '{{TELEFONE_CLIENTE}}', label: 'Telefone do Cliente', category: 'Cliente', example: '(65) 99999-8888'),
    ContractTagInfo(tag: '{{EMAIL_CLIENTE}}', label: 'E-mail do Cliente', category: 'Cliente', example: 'cliente@gmail.com'),

    // Contratada / Empresa Integradora
    ContractTagInfo(tag: '{{RAZAO_SOCIAL_EMPRESA}}', label: 'Razão Social da Empresa', category: 'Empresa', example: 'Mavis Tecnologia e Energia Solar Ltda'),
    ContractTagInfo(tag: '{{NOME_FANTASIA_EMPRESA}}', label: 'Nome Fantasia da Empresa', category: 'Empresa', example: 'Mavis Energia Solar'),
    ContractTagInfo(tag: '{{CNPJ_EMPRESA}}', label: 'CNPJ da Empresa', category: 'Empresa', example: '42.117.511/0001-38'),
    ContractTagInfo(tag: '{{ENDERECO_EMPRESA}}', label: 'Endereço da Empresa', category: 'Empresa', example: 'Av. Paulista, 1000 - São Paulo/SP'),
    ContractTagInfo(tag: '{{NOME_RESPONSAVEL_EMPRESA}}', label: 'Nome do Responsável / Administrador', category: 'Empresa', example: 'Heitor Fabricio Klaus Oliveira'),
    ContractTagInfo(tag: '{{CIDADE_EMPRESA}}', label: 'Cidade da Empresa', category: 'Empresa', example: 'Cuiabá'),
    ContractTagInfo(tag: '{{UF_EMPRESA}}', label: 'UF da Empresa', category: 'Empresa', example: 'MT'),

    // Dados Técnicos da Usina Fotovoltaica
    ContractTagInfo(tag: '{{POTENCIA_KWP}}', label: 'Potência da Usina (kWp)', category: 'Usina Solar', example: '6.84'),
    ContractTagInfo(tag: '{{GERACAO_MENSAL_KWH}}', label: 'Geração Estimada (kWh/mês)', category: 'Usina Solar', example: '3.900'),
    ContractTagInfo(tag: '{{TIPO_TELHADO}}', label: 'Tipo de Cobertura / Estrutura', category: 'Usina Solar', example: 'Cerâmico'),
    ContractTagInfo(tag: '{{DESCRICAO_EQUIPAMENTOS_KIT}}', label: 'Equipamentos do Kit Solar', category: 'Usina Solar', example: '12 módulos 570W e 1 inversor 5kW'),
    ContractTagInfo(tag: '{{DISTRIBUIDORA_ENERGIA}}', label: 'Concessionária de Energia', category: 'Usina Solar', example: 'Energisa'),

    // Fornecedor / Distribuidor do Kit
    ContractTagInfo(tag: '{{NOME_FORNECEDOR_DISTRIBUIDOR}}', label: 'Nome do Fornecedor / Distribuidor', category: 'Fornecedor', example: 'FOTUS ENERGIA SOLAR'),
    ContractTagInfo(tag: '{{CNPJ_FORNECEDOR}}', label: 'CNPJ do Fornecedor', category: 'Fornecedor', example: '07.117.654/0006-53'),

    // Valores e Pagamento
    ContractTagInfo(tag: '{{VALOR_EQUIPAMENTOS_FORMATADO}}', label: 'Valor dos Equipamentos', category: 'Valores', example: 'R\$ 9.722,64'),
    ContractTagInfo(tag: '{{VALOR_SERVICO_FORMATADO}}', label: 'Valor do Serviço / Instalação', category: 'Valores', example: 'R\$ 10.605,00'),
    ContractTagInfo(tag: '{{VALOR_SERVICO_EXTENSO}}', label: 'Valor do Serviço por Extenso', category: 'Valores', example: 'DEZ MIL SEISCENTOS E CINCO REAIS'),
    ContractTagInfo(tag: '{{VALOR_TOTAL_GLOBAL_FORMATADO}}', label: 'Valor Total Global do Projeto', category: 'Valores', example: 'R\$ 20.327,64'),
    ContractTagInfo(tag: '{{VALOR_TOTAL_GLOBAL_EXTENSO}}', label: 'Valor Total por Extenso', category: 'Valores', example: 'VINTE MIL TREZENTOS E VINTE E SETE REAIS E SESSENTA E QUATRO CENTAVOS'),
    ContractTagInfo(tag: '{{FORMA_PAGAMENTO_DETALHADA}}', label: 'Condições de Pagamento', category: 'Valores', example: 'No cartão de crédito em 12x sem juros'),

    // Prazos, Garantias e Jurídico
    ContractTagInfo(tag: '{{NUMERO_CONTRATO}}', label: 'Número do Contrato', category: 'Geral', example: 'CTR-2026-001'),
    ContractTagInfo(tag: '{{NUMERO_PROPOSTA}}', label: 'Número da Proposta Comercial', category: 'Geral', example: 'PROP-2026-101'),
    ContractTagInfo(tag: '{{PRAZO_EXECUCAO_OBRA}}', label: 'Prazo de Execução (dias)', category: 'Geral', example: '40 a 60'),
    ContractTagInfo(tag: '{{MESES_GARANTIA_INSTALACAO}}', label: 'Garantia de Instalação (meses)', category: 'Geral', example: '12'),
    ContractTagInfo(tag: '{{CIDADE_FORUM}}', label: 'Comarca / Foro Judicial', category: 'Jurídico', example: 'Cuiabá'),
    ContractTagInfo(tag: '{{UF_FORUM}}', label: 'UF do Foro', category: 'Jurídico', example: 'MT'),
    ContractTagInfo(tag: '{{DATA_EXTENSO_CONTRATO}}', label: 'Data Atual por Extenso', category: 'Geral', example: '1 de setembro de 2026'),
  ];

  /// Template padrão oficial de 5 páginas baseado no documento anexo
  static const String defaultContractTemplate = '''
# CONTRATO DE PRESTAÇÃO DE SERVIÇOS

**{{NOME_CONTRATANTE}}**, inscrito no {{TIPO_DOC_CONTRATANTE}} sob o nº **{{DOCUMENTO_CONTRATANTE}}**, residente e domiciliado a {{ENDERECO_CONTRATANTE}}, neste ato a seguir denominado simplesmente **"Contratante"** - de uma parte;

e **{{RAZAO_SOCIAL_EMPRESA}}**, estabelecida à {{ENDERECO_EMPRESA}}, inscrita no CNPJ sob o nº **{{CNPJ_EMPRESA}}**, neste ato representada por seu administrador legal **{{NOME_RESPONSAVEL_EMPRESA}}**, a seguir denominada simplesmente **"{{NOME_FANTASIA_EMPRESA}}"** ou **"Contratada"** - da outra parte.

---

### CONSIDERANDO QUE:

**A.** A **{{NOME_FANTASIA_EMPRESA}}** entende realizar a prestação de serviço de engenharia, projeto e instalação de um sistema gerador fotovoltaico com potência total de **{{POTENCIA_KWP}} kWp**, com capacidade média mensal de geração estimada de até **{{GERACAO_MENSAL_KWH}} kWh/mês**, no município de {{CIDADE_CLIENTE}}-{{UF_CLIENTE}}, de acordo com os índices de irradiação solar oficiais (CRESESB) em condições ideais livres de sombreamento e interferências, constituído em uma instalação fotovoltaica na cobertura do imóvel (estrutura para telhado **{{TIPO_TELHADO}}**) do Contratante.

**B.** O Sistema Gerador Solar é composto por: **{{DESCRICAO_EQUIPAMENTOS_KIT}}**; fornecido e faturado pela distribuidora **{{NOME_FORNECEDOR_DISTRIBUIDOR}}**, inscrita no CNPJ sob o nº {{CNPJ_FORNECEDOR}}; sendo a **{{NOME_FANTASIA_EMPRESA}}** a intermediadora técnica na indicação da compra; o valor dos Equipamentos foi acordado em **{{VALOR_EQUIPAMENTOS_FORMATADO}}**, cujo montante é repassado diretamente à distribuidora parceira **{{NOME_FORNECEDOR_DISTRIBUIDOR}}**, que será a responsável exclusiva pelo faturamento, entrega e garantia legal dos equipamentos solares fornecidos. Todo fornecimento de garantia de fábrica dos equipamentos e eventuais trocas correrão por conta do fabricante/distribuidor, cabendo à **{{NOME_FANTASIA_EMPRESA}}** prestar a garantia técnica dos serviços de instalação pelo período de até **{{MESES_GARANTIA_INSTALACAO}} meses**, mantendo o sistema em perfeito funcionamento e operação.

**C.** A **{{NOME_FANTASIA_EMPRESA}}**, após realização da visita técnica preliminar e/ou análise dos parâmetros estruturais e elétricos do local de instalação, verificou que o local atende às condições técnicas necessárias, aceitando realizar a obra nas condições estipuladas no presente instrumento.

**D.** Com o presente contrato, as partes têm entre si, justo e acordado, as cláusulas, termos e condições para o desenvolvimento e execução do projeto.

---

## TUDO É CONSIDERADO E ESTÁ DE ACORDO O SEGUINTE:

### 1. Objeto do Contrato
**1.1** A Contratante confia à **{{NOME_FANTASIA_EMPRESA}}**, e esta aceita, a execução de todas as atividades de engenharia e mão de obra necessárias para a realização, montagem, comissionamento e conexão do projeto fotovoltaico junto à rede de distribuição, as quais compreendem:
- Elaboração do Projeto Executivo de Engenharia Fotovoltaica e Emissão de ART/TRT;
- Tramitação de acesso e homologação do parecer de acesso junto à concessionária de energia (**{{DISTRIBUIDORA_ENERGIA}}**);
- Montagem e fixação das estruturas metálicas de suporte para os módulos fotovoltaicos;
- Fixação mecânica, cabeamento e conexões dos módulos solares fotovoltaicos;
- Instalação, parametrização e conexão do inversor solar grid-tie e quadros de proteção (String Box);
- Interligação do sistema fotovoltaico ao quadro de distribuição geral da residência/empresa;
- Fornecimento de todos os materiais elétricos complementares de instalação necessários para a perfeita integração do sistema (cabos solares com proteção UV, conectores MC4, terminais e eletrodutos).

**1.2** São expressamente **exclusos** do escopo do presente contrato os seguintes itens:
- Obras civis de alvenaria, reformas prediais e reforços em estruturas existentes;
- Obras de transmissão de energia em rede de média/alta tensão aérea externa;
- Reforço mecânico ou substituição de vigas e caibros de madeira/metálicos do telhado;
- Emissão de laudo ou cálculo estrutural detalhado de sobrecarga do telhado (caso exigido por órgão externo);
- Quaisquer outros serviços não descritos expressamente no item 1.1.

**1.3** As obras deverão ser executadas pela **{{NOME_FANTASIA_EMPRESA}}** com o mais alto padrão de qualidade técnica e segurança, em estrita observância às normas regulamentadoras brasileiras vigentes (especialmente ABNT NBR 5410, NBR 16690, NR-10 e NR-35).

**1.4** Fica pactuado que a execução dos trabalhos ocorre sob o regime de **"Serviço de Instalação e Homologação"**, cabendo à Contratada a coordenação técnica integral para a entrega da usina operante, ressalvadas as exceções do item 1.2.

**1.5** A **{{NOME_FANTASIA_EMPRESA}}** assume os riscos e custos ordinários estritamente vinculados aos serviços de montagem sob sua responsabilidade. Em nenhuma hipótese a Contratante ou a Contratada serão responsabilizadas por eventuais atrasos ou exigências extraordinárias imputáveis exclusivamente à concessionária de energia ou a órgãos reguladores.

---

### 2. Modalidade de Execução, Obrigações e Garantias da Contratada
**2.1** A **{{NOME_FANTASIA_EMPRESA}}** declara e garante:
- **a)** Dispor de equipe qualificada, com registro profissional ativo nos órgãos competentes (CREA/CFT) e capacidade técnica para a perfeita execução das obras;
- **b)** Que toda a instalação será realizada em conformidade com as normas técnicas da concessionária local (**{{DISTRIBUIDORA_ENERGIA}}**) e órgãos reguladores (ANEEL);
- **c)** Que realizou a avaliação técnica prévia do local de instalação, conhecendo as particularidades do imóvel.

**2.2** A Contratada declara haver dimensionado a remuneração estipulada para a execução das obras como justa, suficiente e remuneratória para todos os encargos previstos.

---

### 3. Obrigações a Cargo da Contratante
**3.1** A Contratante declara e garante ser legítima possuidora ou proprietária do imóvel, assegurando a plena disponibilidade física do local e concedendo livre acesso à equipe técnica da **{{NOME_FANTASIA_EMPRESA}}** durante o horário comercial para a realização dos serviços.

**3.2** A Contratante assume a responsabilidade pela guarda, custódia e integridade dos equipamentos e materiais entregues no imóvel até a conclusão dos serviços de instalação, não podendo contestar avarias causadas por terceiros ou intempéries após a entrega formal dos itens no endereço.

---

### 4. Valor e Modalidade de Pagamento
**4.1** Pela execução de todos os serviços de engenharia, mão de obra de instalação e homologação descritos neste contrato, a Contratante pagará à **{{NOME_FANTASIA_EMPRESA}}** o valor líquido de **{{VALOR_SERVICO_FORMATADO}}** ({{VALOR_SERVICO_EXTENSO}}).

**4.2** O investimento total global do projeto (Kit de Equipamentos Fotovoltaicos + Serviços de Instalação) perfaz a quantia total de **{{VALOR_TOTAL_GLOBAL_FORMATADO}}** ({{VALOR_TOTAL_GLOBAL_EXTENSO}}), que permanecerá fixo e irreajustável durante a vigência do contrato.

**4.3** O pagamento dos valores pactuados será efetuado na seguinte modalidade:
{{FORMA_PAGAMENTO_DETALHADA}}

---

### 5. Prazos e Cronograma de Execução
**5.1** As etapas de montagem física e comissionamento da usina solar serão concluídas em um prazo estimado de **{{PRAZO_EXECUCAO_OBRA}} dias**, contados a partir da entrega integral dos equipamentos no imóvel da Contratante e da confirmação da entrada financeira prevista no item 4.3.

**5.2** Os prazos para troca de medidor bidirecional e vistoria final da concessionária de energia dependem exclusivamente do cronograma regulatório da distribuidora (**{{DISTRIBUIDORA_ENERGIA}}**), não sendo a Contratada penalizada por dilações decorrentes de prazos da concessionária.

---

### 6. Variantes e Prazos Adicionais de Concessionária
**6.1** A **{{NOME_FANTASIA_EMPRESA}}** poderá executar pequenas adequações no layout dos painéis em função de particularidades de sombreamento ou telhado encontradas em campo, mantendo sempre a potência nominal contratada e comunicando a Contratante.

**6.2** Caso a concessionária de energia (**{{DISTRIBUIDORA_ENERGIA}}**) identifique, no parecer de acesso, a necessidade de execução de obras de reforço ou melhoria na rede de distribuição pública, o prazo legal de análise e aprovação poderá ser dilatado pela distribuidora conforme os prazos previstos nas resoluções normativas da ANEEL (Resolução 1000/2021 e 1059/2023), permanecendo a conexão vinculada ao cumprimento da respectiva obra pela concessionária.

**6.3** Eventuais alterações solicitadas expressamente pela Contratante que impliquem acréscimo de serviços ou materiais serão objeto de termo aditivo com orçamento correspondente.

---

### 7. Rescisão e Inadimplemento
**7.1** Em caso de inadimplemento de qualquer obrigação financeira por prazo superior a 5 (cinco) dias úteis do vencimento, a parte prejudicada poderá notificar a outra para regularização em até 15 (quinze) dias.

**7.2** Não sanada a pendência no prazo notificado, assistirá o direito de rescisão contratual, cabendo à Contratante o pagamento dos serviços já executados, o ressarcimento de eventuais despesas com materiais não restituíveis e a aplicação de multa penal não compensatória de 5% (cinco por cento) sobre o valor total do contrato.

---

### 8. Garantia de Funcionamento e Pós-Venda
**8.1** A **{{NOME_FANTASIA_EMPRESA}}** concede garantia técnica de **{{MESES_GARANTIA_INSTALACAO}} meses** sobre a mão de obra de instalação e conexões elétricas, contados a partir da data de ativação e teste do sistema gerador.

**8.2** A garantia dos equipamentos (módulos solares, inversor e estrutura) rege-se pelos termos e certificados dos respectivos fabricantes e distribuidores.

---

### 9. Foro Competente
**9.1** Para dirimir quaisquer dúvidas ou litígios oriundos do presente contrato, as partes elegem o Foro da Comarca de **{{CIDADE_FORUM}}/{{UF_FORUM}}**, com expressa renúncia a qualquer outro, por mais privilegiado que seja.

---

### 10. Disposições Finais
**10.1** O presente contrato substitui todo e qualquer entendimento anterior verbal ou escrito, constituindo a integralidade do acordo entre as Partes.

**10.2** E, por estarem justas e contratadas, as partes assinam o presente instrumento em 2 (duas) vias de igual teor e forma.

---

**{{CIDADE_FORUM}} - {{UF_FORUM}}, {{DATA_EXTENSO_CONTRATO}}**


_____________________________________________________
**CONTRATANTE:**
**{{NOME_CONTRATANTE}}**
{{TIPO_DOC_CONTRATANTE}}: {{DOCUMENTO_CONTRATANTE}}


_____________________________________________________
**CONTRATADA:**
**{{RAZAO_SOCIAL_EMPRESA}}**
{{NOME_RESPONSAVEL_EMPRESA}}
CNPJ: {{CNPJ_EMPRESA}}
''';

  /// Gera o texto do contrato com todas as variáveis interpoladas
  static String generateContractText({
    required ProposalModel proposal,
    required ClientModel? client,
    required CompanyModel? company,
    String? customTemplate,
    String? customResponsibleName,
    String? contractNumber,
  }) {
    final rawTemplate = (customTemplate != null && customTemplate.trim().isNotEmpty)
        ? customTemplate
        : defaultContractTemplate;
    String text = rawTemplate.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Dados do Cliente
    final clientName = client?.name ?? (proposal.clientName.isNotEmpty ? proposal.clientName : 'NOME DO CLIENTE');
    final clientDoc = client?.document ?? (proposal.clientDocument?.isNotEmpty == true ? proposal.clientDocument! : '000.000.000-00');
    final isPj = client?.type == ClientType.company || clientDoc.replaceAll(RegExp(r'\D'), '').length > 11;
    final clientDocType = isPj ? 'CNPJ' : 'CPF';

    String clientAddress = 'Endereço da Instalação Solar';
    if (client != null) {
      final parts = <String>[];
      if (client.street != null && client.street!.isNotEmpty) {
        parts.add('${client.street}${client.addressNumber != null ? ', ${client.addressNumber}' : ''}');
      }
      if (client.complement != null && client.complement!.isNotEmpty) parts.add(client.complement!);
      if (client.neighborhood != null && client.neighborhood!.isNotEmpty) parts.add('Bairro ${client.neighborhood}');
      if (client.city != null && client.city!.isNotEmpty) {
        parts.add('${client.city}${client.state != null ? '/${client.state}' : ''}');
      }
      if (client.zipCode != null && client.zipCode!.isNotEmpty) parts.add('CEP ${client.zipCode}');
      if (parts.isNotEmpty) clientAddress = parts.join(' - ');
    } else if (proposal.clientAddress != null && proposal.clientAddress!.isNotEmpty) {
      clientAddress = proposal.clientAddress!;
    }

    final clientCity = client?.city ?? company?.city ?? 'Cuiabá';
    final clientUf = client?.state ?? company?.state ?? 'MT';
    final clientPhone = client?.phone ?? proposal.clientPhone ?? '';
    final clientEmail = client?.email ?? proposal.clientEmail ?? '';

    // Dados da Empresa
    final companyName = company?.name ?? 'Mavis Energia Solar Ltda';
    final companyFantasia = company?.slogan?.isNotEmpty == true ? company!.slogan! : companyName;
    final companyCnpj = company?.document ?? '00.000.000/0001-00';
    final companyAdmin = customResponsibleName ?? (company != null ? company.name : 'Representante Legal');

    String companyAddress = 'Sede da Empresa';
    if (company != null) {
      final cParts = <String>[];
      if (company.street != null && company.street!.isNotEmpty) {
        cParts.add('${company.street}${company.number != null ? ', ${company.number}' : ''}');
      }
      if (company.complement != null && company.complement!.isNotEmpty) cParts.add(company.complement!);
      if (company.neighborhood != null && company.neighborhood!.isNotEmpty) cParts.add('Bairro ${company.neighborhood}');
      if (company.city != null && company.city!.isNotEmpty) {
        cParts.add('${company.city}${company.state != null ? '/${company.state}' : ''}');
      }
      if (company.zipCode != null && company.zipCode!.isNotEmpty) cParts.add('CEP ${company.zipCode}');
      if (cParts.isNotEmpty) companyAddress = cParts.join(' - ');
    }
    final companyCity = company?.city ?? 'Cuiabá';
    final companyUf = company?.state ?? 'MT';

    // Dados da Proposta / Usina
    ProposalItemModel? solarPlantItem;
    for (final item in proposal.items) {
      if (item.isSolarPlant || item.solarKilowatts != null) {
        solarPlantItem = item;
        break;
      }
    }

    final kwp = solarPlantItem?.solarKilowatts ?? 6.84;
    final generationKwh = mathEstimatedKwh(kwp);
    final roofType = solarPlantItem?.solarRoofType ?? 'Cerâmico';

    // Equipamentos do Kit
    String kitDescription = '';
    if (solarPlantItem?.solarComponents != null && solarPlantItem!.solarComponents!.isNotEmpty) {
      kitDescription = solarPlantItem.solarComponents!.join('; ');
    } else {
      kitDescription = proposal.items.map((e) => '${e.quantity.toStringAsFixed(0)}x ${e.name}').join(', ');
    }
    if (kitDescription.isEmpty) {
      kitDescription = 'Kit Gerador Fotovoltaico Completo ${kwp.toStringAsFixed(2)} kWp (Módulos Solares Monocristalinos N-Type, Inversor Grid-Tie, Estrutura de Fixação, String Box e Cabos Solares)';
    }

    final distributorName = 'Energisa'; // Concessionária de energia padrão ou do cliente
    final supplierName = 'FOTUS ENERGIA SOLAR';
    final supplierCnpj = '07.117.654/0006-53';

    // Valores
    final totalAmount = proposal.totalAmount > 0 ? proposal.totalAmount : 20327.64;
    final servicePrice = (totalAmount * 0.35); // Estimativa se não especificado
    final productsPrice = totalAmount - servicePrice;

    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final formattedTotal = currencyFormat.format(totalAmount);
    final formattedService = currencyFormat.format(servicePrice);
    final formattedProducts = currencyFormat.format(productsPrice);

    final serviceExtenso = numberToWordsPtBr(servicePrice);
    final totalExtenso = numberToWordsPtBr(totalAmount);

    final paymentTerms = proposal.paymentTerms.isNotEmpty
        ? proposal.paymentTerms.toUpperCase()
        : 'À VISTA VIA PIX OU EM ATÉ 12X NO CARTÃO DE CRÉDITO SEM JUROS';

    final deliveryTime = (proposal.deliveryTime != null && proposal.deliveryTime!.isNotEmpty)
        ? proposal.deliveryTime!
        : '40 a 60';

    final now = DateTime.now();
    final months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    final dataExtenso = '${now.day} de ${months[now.month - 1]} de ${now.year}';

    // Mapa de Substituição
    final replacements = <String, String>{
      '{{NOME_CONTRATANTE}}': clientName,
      '{{TIPO_DOC_CONTRATANTE}}': clientDocType,
      '{{DOCUMENTO_CONTRATANTE}}': clientDoc,
      '{{ENDERECO_CONTRATANTE}}': clientAddress,
      '{{CIDADE_CLIENTE}}': clientCity,
      '{{UF_CLIENTE}}': clientUf,
      '{{TELEFONE_CLIENTE}}': clientPhone,
      '{{EMAIL_CLIENTE}}': clientEmail,
      '{{RAZAO_SOCIAL_EMPRESA}}': companyName,
      '{{NOME_FANTASIA_EMPRESA}}': companyFantasia,
      '{{CNPJ_EMPRESA}}': companyCnpj,
      '{{ENDERECO_EMPRESA}}': companyAddress,
      '{{NOME_RESPONSAVEL_EMPRESA}}': companyAdmin,
      '{{CIDADE_EMPRESA}}': companyCity,
      '{{UF_EMPRESA}}': companyUf,
      '{{POTENCIA_KWP}}': kwp.toStringAsFixed(2),
      '{{GERACAO_MENSAL_KWH}}': generationKwh.toString(),
      '{{TIPO_TELHADO}}': roofType,
      '{{DESCRICAO_EQUIPAMENTOS_KIT}}': kitDescription,
      '{{DISTRIBUIDORA_ENERGIA}}': distributorName,
      '{{NOME_FORNECEDOR_DISTRIBUIDOR}}': supplierName,
      '{{CNPJ_FORNECEDOR}}': supplierCnpj,
      '{{VALOR_EQUIPAMENTOS_FORMATADO}}': formattedProducts,
      '{{VALOR_SERVICO_FORMATADO}}': formattedService,
      '{{VALOR_SERVICO_EXTENSO}}': serviceExtenso,
      '{{VALOR_TOTAL_GLOBAL_FORMATADO}}': formattedTotal,
      '{{VALOR_TOTAL_GLOBAL_EXTENSO}}': totalExtenso,
      '{{FORMA_PAGAMENTO_DETALHADA}}': paymentTerms,
      '{{NUMERO_CONTRATO}}': contractNumber ?? 'CTR-${now.year}-001',
      '{{NUMERO_PROPOSTA}}': proposal.proposalNumber,
      '{{PRAZO_EXECUCAO_OBRA}}': deliveryTime,
      '{{MESES_GARANTIA_INSTALACAO}}': '12',
      '{{CIDADE_FORUM}}': companyCity,
      '{{UF_FORUM}}': companyUf,
      '{{DATA_EXTENSO_CONTRATO}}': dataExtenso,
    };

    replacements.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    return text;
  }

  static int mathEstimatedKwh(double kwp) => (kwp * 130).round();

  /// Converte valor monetário em reais para texto por extenso em português
  static String numberToWordsPtBr(double value) {
    if (value <= 0) return 'ZERO REAIS';

    final intPart = value.floor();
    final centPart = ((value - intPart) * 100).round();

    final intWords = _intToWords(intPart);
    final String intLabel = intPart == 1 ? 'REAL' : 'REAIS';

    if (centPart == 0) {
      return '$intWords $intLabel'.toUpperCase();
    }

    final centWords = _intToWords(centPart);
    final String centLabel = centPart == 1 ? 'CENTAVO' : 'CENTAVOS';

    return '$intWords $intLabel E $centWords $centLabel'.toUpperCase();
  }

  static String _intToWords(int n) {
    if (n == 0) return 'ZERO';

    final unidades = [
      '', 'UM', 'DOIS', 'TRÊS', 'QUATRO', 'CINCO', 'SEIS', 'SETE', 'OITO', 'NOVE',
      'DEZ', 'ONZE', 'DOZE', 'TREZE', 'QUATORZE', 'QUINZE', 'DEZESSEIS', 'DEZESSETE',
      'DEZOITO', 'DEZENOVE'
    ];

    final dezenas = [
      '', '', 'VINTE', 'TRINTA', 'QUARENTA', 'CINQUENTA', 'SESSENTA', 'SETENTA',
      'OITENTA', 'NOVENTA'
    ];

    final centenas = [
      '', 'CENTO', 'DUZENTOS', 'TREZENTOS', 'QUATROCENTOS', 'QUINHENTOS',
      'SEISCENTOS', 'SETECENTOS', 'OITOCENTOS', 'NOVECENTOS'
    ];

    if (n == 100) return 'CEM';
    if (n < 20) return unidades[n];
    if (n < 100) {
      final d = n ~/ 10;
      final u = n % 10;
      return u == 0 ? dezenas[d] : '${dezenas[d]} E ${unidades[u]}';
    }
    if (n < 1000) {
      final c = n ~/ 100;
      final rest = n % 100;
      return rest == 0 ? centenas[c] : '${centenas[c]} E ${_intToWords(rest)}';
    }
    if (n < 1000000) {
      final mil = n ~/ 1000;
      final rest = n % 1000;
      final milText = mil == 1 ? 'MIL' : '${_intToWords(mil)} MIL';
      if (rest == 0) return milText;
      return rest < 100 || rest % 100 == 0
          ? '$milText E ${_intToWords(rest)}'
          : '$milText, ${_intToWords(rest)}';
    }
    if (n < 1000000000) {
      final milhao = n ~/ 1000000;
      final rest = n % 1000000;
      final milhaoText = milhao == 1 ? 'UM MILHÃO' : '${_intToWords(milhao)} MILHÕES';
      if (rest == 0) return milhaoText;
      return '$milhaoText, ${_intToWords(rest)}';
    }

    return n.toString();
  }
}
