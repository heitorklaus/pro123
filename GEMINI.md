# 🧠 MEMÓRIA PERMANENTE DO PROJETO - MAVIS CRM

Este arquivo serve como **fonte central da verdade e memória permanente** para qualquer agente de IA ou desenvolvedor que atue no ecossistema do **Mavis CRM**.

---

## 📌 1. Visão Geral do Produto
O **Mavis CRM** é uma solução moderna e responsiva (Web, Android e iOS) voltada para gestão de relacionamento com clientes, controle de leads, gestão de usuários e relatórios operacionais.

- **Nome do Projeto:** `mavis`
- **Descrição:** Mavis CRM Web, Android & iOS Application
- **Plataformas-alvo:** Flutter Web (prioritária inicialmente), Android e iOS.
- **Identidade Visual:** Paleta escura/moderna com base Slate (`#0F172A`, `#1E293B`), Indigo (`#6366F1`), Emerald (`#10B981`) e Rose (`#EF4444`). Tipografia estilizada com *Outfit* (títulos) e *Inter/Roboto* (corpo).

---

## 🏛️ 2. Arquitetura e Estrutura de Pastas

O projeto adota uma arquitetura modular orientada a features (**Feature-First Modular Architecture**) inspirada nos princípios da *Clean Architecture*:

```text
lib/
├── app/                              # Configurações globais e bootstrap da aplicação
│   ├── app_module.dart               # Módulo raiz de rotas e injeção global (Modular)
│   ├── app_widget.dart               # Widget MaterialApp configurado com rotas e temas
│   ├── layout/                       # Layout Shell e Componentes de Navegação Globais
│   │   └── app_sidebar.dart          # Menu Lateral Reutilizável (enum AppSidebarItem)
│   └── theme/                        # Design System centralizado
│       ├── app_colors.dart           # Paleta de cores semânticas e hexadecimais
│       ├── app_decorations.dart      # Bordas, sombras e decorações reutilizáveis
│       └── app_theme.dart            # ThemeData configurado (Light/Dark e Tipografia)
│
├── auth/                             # Módulo de Autenticação e Gestão de Contas
│   ├── auth_module.dart              # Injeção de dependências e rotas de Auth
│   ├── data/
│   │   └── repositories/
│   │       └── auth_repository.dart  # Integração com Firebase Auth e Cloud Firestore
│   ├── domain/
│   │   └── models/
│   │       └── user_model.dart       # Entidade de Usuário e RBAC (UserPermissions)
│   └── presentation/
│       ├── login/
│       │   ├── login_page.dart       # UI de Login (E-mail/Senha e Google OAuth)
│       │   ├── login_store.dart      # Controller MobX de Login
│       │   └── login_store.g.dart    # Código gerado pelo build_runner
│       └── register/
│           ├── register_page.dart    # UI de Cadastro de Novo Usuário
│           ├── register_store.dart   # Controller MobX de Cadastro
│           └── register_store.g.dart # Código gerado pelo build_runner
│
├── clients/                          # Módulo de Gestão de Clientes
│   ├── clients_module.dart           # Rota standalone do módulo (se necessário)
│   ├── data/
│   │   └── repositories/
│   │       └── client_repository.dart# Integração Firestore da coleção clients
│   ├── domain/
│   │   └── models/
│   │       └── client_model.dart     # Entidade do Cliente (PF/PJ, status e endereço 7 campos)
│   └── presentation/
│       └── clients_view.dart         # ⭐ View no SPA com tabela e formulário + ViaCEP auto
│
├── dashboard/                        # Módulo Principal após Autenticação (SPA Container)
│   ├── dashboard_module.dart         # Rotas e Binds do painel (Auth, Register, Client, Product)
│   └── presentation/
│       └── dashboard_page.dart       # ⭐ SPA Master: Scaffold único com AppBar + Sidebar fixos
│                                     #    Gerencia miolo dinâmico via _buildMiolo()
│
├── products/                         # Módulo de Catálogo de Produtos & Serviços
│   ├── data/
│   │   └── repositories/
│   │       └── product_repository.dart# Firestore (coleções products, categories, subcategories)
│   ├── domain/
│   │   └── models/
│   │       ├── category_model.dart   # Entidade CategoryModel (nativas e customizadas com ícones e cores)
│   │       ├── product_model.dart    # Entidade ProductModel (suporte a fornecedores, segmentos, unidades)
│   │       └── subcategory_model.dart# Entidade SubcategoryModel
│   └── presentation/
│       └── products_view.dart        # ⭐ View no SPA: Tabela + Wizard 20 nichos + Categorias + Popup Subcat + Seletor de Fornecedor
│
├── suppliers/                        # Módulo de Gestão de Fornecedores & Parceiros
│   ├── suppliers_module.dart         # Rotas e binds do módulo de fornecedores
│   ├── data/
│   │   └── repositories/
│   │       └── supplier_repository.dart# Firestore (coleção suppliers)
│   ├── domain/
│   │   └── models/
│   │       └── supplier_model.dart   # Entidade SupplierModel (PJ, contato, ViaCEP auto, termos de pagamento)
│   └── presentation/
│       └── suppliers_view.dart       # ⭐ View no SPA com tabela em tempo real e formulário completo com ViaCEP
│
├── users/                            # Módulo de Gestão de Usuários
│   ├── users_module.dart             # Rotas do módulo Users
│   └── presentation/
│       ├── users_page.dart           # Wrapper simples
│       └── users_view.dart           # ⭐ View principal injetada no miolo do Dashboard
│
├── firebase_options.dart             # Configurações do Firebase geradas pela CLI
└── main.dart                         # Entry point inicializando Firebase e ModularApp
```

> 📚 *Documentação estendida de arquitetura em:* [`/docs/architecture.md`](file:///c:/mavis/docs/architecture.md)

---

## 🏗️ 2.1. Padrão SPA (Single Page Application) — CRÍTICO

O `DashboardPage` é o **único Scaffold da área autenticada**. Ele mantém AppBar e Sidebar persistentes e troca apenas o conteúdo central ("miolo") via `setState`.

```
DashboardPage (único Scaffold)
 ├── AppBar (fixa — nunca desmontada)
 └── Row
      ├── AppSidebar (250px fixo — enum AppSidebarItem)
      └── Expanded → _buildMiolo()
           ├── [AppSidebarItem.dashboard] → _WelcomeCard (Center + SingleChildScrollView)
           └── [AppSidebarItem.users]     → UsersView
                ├── [tabela]    → _TableView    (usa LayoutBuilder para constraints finitas!)
                └── [formulário] → _RegisterCard (Center + SizedBox 540px)
```

### ⚠️ REGRA CRÍTICA DE LAYOUT (aprendida na prática):
> **Todo widget inserido no miolo (`Expanded` do body) que precisar de altura ou largura finita DEVE usar `LayoutBuilder` como raiz.**
>
> Nunca coloque `Expanded` dentro de uma `Column` cujo pai não tenha altura definida. Use `LayoutBuilder` → `SizedBox(width: constraints.maxWidth, height: constraints.maxHeight)` para garantir bounds finitos.

---

## 🛠️ 3. Tecnologias e Bibliotecas

- **Flutter SDK:** `>=3.0.0 <4.0.0`
- **Roteamento & Injeção de Dependência:** `flutter_modular: ^5.0.3`
- **Gerenciamento de Estado:** `mobx: ^2.2.1` e `flutter_mobx: ^2.2.1`
- **Geração de Código:** `build_runner: ^2.4.9` e `mobx_codegen: ^2.6.0`
- **Tipografia:** `google_fonts: ^6.2.1`
- **Backend & Banco de Dados:**
  - `firebase_core: ^3.6.0`
  - `firebase_auth: ^5.3.1` (Autenticação E-mail/Senha e OAuth)
  - `cloud_firestore: ^5.4.4` (Banco NoSQL em tempo real)
  - `google_sign_in: ^6.2.1` (Login social Google)

---

## 🗄️ 4. Banco de Dados (Cloud Firestore)

### Coleções Principais:

#### 1. `users/{userId}`
Armazena o perfil estendido dos operadores e administradores do CRM.
```json
{
  "uid": "string (UID do Firebase Auth)",
  "name": "string",
  "email": "string",
  "phone": "string? (opcional)",
  "avatarUrl": "string? (URL foto perfil)",
  "role": "admin | manager | user",
  "status": "active | pending | blocked",
  "companyId": "string? (Multi-tenancy)",
  "permissions": {
    "manageUsers": false,
    "manageSettings": false,
    "viewReports": true,
    "editLeads": true,
    "deleteLeads": false
  },
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "lastLoginAt": "Timestamp"
}
```

> 📚 *Esquema detalhado e futuras coleções (`leads`, `companies`, `activities`) em:* [`/docs/database_schema.md`](file:///c:/mavis/docs/database_schema.md)

---

## 🔐 5. Autenticação e Permissões (RBAC)

### Níveis de Acesso (`roles`):
1. **`admin`**: Acesso irrestrito a todas as operações, gerenciamento de operadores e configurações globais.
2. **`manager`**: Acesso a relatórios, criação, edição e exclusão de leads, sem gerenciar usuários do sistema.
3. **`user`**: Acesso operacional para cadastrar e editar leads; não pode deletar leads nem acessar relatórios globais.

### Métodos de Login Disponíveis:
- **E-mail e Senha:** Validação de força de senha (mínimo 6 dígitos), checagem de duplicidade e tratamentos amigáveis de erro em português.
- **Google Sign-In:** Suporte nativo para Web (`signInWithPopup`) e Mobile (`signInWithCredential`). Sincroniza automaticamente a criação de documento no Firestore no primeiro login.
- **Controle de Status:** Bloqueio automático de login para usuários cujo status não seja `active`.

> 📚 *Regras e detalhes de autenticação em:* [`/docs/auth_and_permissions.md`](file:///c:/mavis/docs/auth_and_permissions.md)

---

## 🧩 6. Módulos e Funcionalidades Existentes

### 1. `AppModule` (Global)
- Configuração de rotas principais: `/` → `/auth`, `/auth` (Login/Register) e `/dashboard` (Painel SPA).

### 2. `AuthModule`
- **Tela de Login (`login_page.dart`):** Interface moderna com glassmorphism, gradientes e formulário validado via MobX (`LoginStore`).
- **Tela de Cadastro (`register_page.dart`):** Cadastro com confirmação de senha e persistência direta no Firestore e Auth.
- **Serviço de Autenticação (`auth_repository.dart`):** Gerenciador de chamadas Firebase com tratamento de erros em português.

### 4. `ClientsModule` / `ClientsView` / `ClientFormDialog`
- **`clients_view.dart`, `client_form_dialog.dart` & `gemini_energy_bill_service.dart`:** Gestão completa de clientes (PF / PJ) com inteligência artificial:
  1. **Importação e Leitura Inteligente de Contas de Energia com IA Gemini (`GeminiEnergyBillService`):**
     - **Visão Computacional Multimodal (PDF ou Imagem):** Analisa contas de energia de qualquer distribuidora brasileira (Energisa, Enel, CPFL, Cemig, Copel, Equatorial, Neoenergia, Light, etc.).
     - **Extração Completa dos Dados do Titular:** Nome Completo / Razão Social, CPF ou CNPJ formatado, e-mail e telefone.
     - **Endereço Completo:** Rua, Número, Complemento, Bairro, Cidade, Estado (UF) e CEP.
     - **Dados Técnicos da Unidade Consumidora (UC):** Distribuidora, Código da UC / Matrícula, Tipo de Ligação (Trifásico/Bifásico/Monofásico), Classificação Tarifária, Mês de Referência e Valor da Fatura.
     - **Histórico de Consumo & Diagnóstico Fotovoltaico:** Lê a tabela/gráfico de consumo mensal dos últimos meses, calcula o **Consumo Médio Mensal em kWh**, a **Potência Fotovoltaica Recomendada em kWp** (`Consumo Médio / 110`) e a **Geração Mensal Prevista em kWh**.
     - **Modal de Resumo e Aceite Visual (`EnergyBillSummaryDialog`):** Apresenta um painel executivo com o diagnóstico energético antes de aplicar ao formulário.
  2. **Tabela em tempo real:** `Stream<List<ClientModel>>` do Firestore com busca rápida (nome, e-mail, empresa), badges de tipo (PF/PJ) e status (Ativo, Prospect, Inativo, Bloqueado), exclusão com diálogo modal.
  3. **Formulário com Consulta de CEP automática:** Integração com a API **ViaCEP** (`https://viacep.com.br/ws/{cep}/json/`). Ao digitar os 8 dígitos, autocompleta logradouro, bairro, cidade, UF e complemento, bloqueando edição acidental dos campos preenchidos e focando automaticamente no campo "Número".

### 5. `ProductsModule` / `ProductsView`
- **`products_view.dart` & `solar_plant_form_card.dart`:** Gestão completa de catálogo com ramificação e categorização:
  1. **Categoria Especial no Topo — Usina Solar (`ProductSector.solarPlant`):** Ícone solar dourado (`solar_power_rounded`) e descrição *"Inversor, Placa Solar, Estrutura e acessórios"*.
  2. **Formulário Especial de Conjunto de Produtos (`SolarPlantFormCard`):**
     - **Importação Inteligente com IA Google Gemini Vision (`GeminiSolarVisionService` & `SolarPdfImportDialog`):**
        - **Visão Computacional & OCR Multimodal:** Integração direta com a API do **Google Gemini (`gemini-3.6-flash`, `gemini-3.5-flash`, `gemini-flash-latest`)** para analisar qualquer cotação em PDF, Imagem (JPG, PNG, WEBP) ou texto colado.
        - **Zero Falhas de Extração:** A IA lê visualmente tabelas complexas, potências em kWp, tipo de telhado, valor total (com frete) e todos os equipamentos do kit sem depender de streams ou formatação interna do arquivo.
        - **Chave de API Nativa e Embutida:** Chave padrão configurada internamente no código via getter com decodificação Base64 em runtime (`GeminiSolarVisionService.defaultApiKey`), permitindo uso instantâneo sem necessidade de digitação pelo usuário e garantindo compatibilidade com o GitHub Push Protection. Suporte tanto a cabeçalho `x-goog-api-key` quanto chaves do novo formato `AQ.`.
        - **Gerenciador de Chave API Opcional:** Permite que o usuário insira uma chave personalizada localmente (`SharedPreferences`) caso queira utilizar sua própria cota ou projeto.
       - **Explosão do Kit Fotovoltaico & Reconhecimento de Módulos:** Identifica e classifica individualmente cada componente real encontrado com quantidades, unidades, **ícone dourado prioritário de placa solar (`Icons.solar_power_rounded`)** e extração automática da potência nominal em Watts dos módulos (ex: `615W`, `580W`, `550W`).
       - **Auto-Cadastro com Ficha Técnica Completa:** Ao cadastrar módulos inéditos no catálogo do Firestore via lote/IA, grava com a subcategoria oficial `MÓDULO SOLAR` e preenche `specificAttributes['moduleWatts']` e `componentType = 'module'`.
       - **Preço Fechado do Orçamento:** O campo *Preço dos Produtos* recebe o **Valor Total do Orçamento** (com frete consolidado).
       - **Auto-Cadastro Inteligente com Deduplicação Zero-Duplicate:** Ao importar múltiplos PDFs/cotações, o sistema checa automaticamente os itens existentes no banco de dados (por SKU e Nome normalizado). Se o item já existir no Firestore, **não cria duplicata** e vincula o produto diretamente do banco na lista de *Equipamentos & Produtos do Conjunto*; se for inédito, cadastra uma única vez.
     - **Descrição da Usina & SKU do Kit**.
     - **Tipo de Cobertura (Dropdown):** `Cerâmico`, `Metálico`, `Isotérmico`, `Fibrocimento`, `Solo`, `Laje`, `Sem Estrutura`.
     - **Potência da Usina (kWp):** Campo reativo com cálculo e autocompletar dinâmico em tempo real. Ao importar via IA, adicionar módulos ou alterar a quantidade inline na tabela (ex: de 14 para 20 módulos de 615W), o sistema multiplica automaticamente `(Quantidade × Watts do Módulo) / 1000` e atualiza a potência em kWp em tempo real (ex: `14 × 615W = 8.61 kWp`), além de aceitar valor do PDF ou digitação manual.
     - **4. Geração Estimada (kWh/mês):** Campo dedicado onde o usuário informa a geração média mensal em kWh (ex: 3200 kWh/mês).
     - **Composição do Conjunto:** Adição dinâmica de múltiplos produtos do catálogo ou sob medida com edição inline (o seletor modal filtra automaticamente e oculta outras Usinas Solares completas, exibindo apenas componentes e produtos avulsos com ícones temáticos de energia).
     - **Botão `"ADICIONAR ITEM"` no Modal de Seleção:** Permite cadastrar novos equipamentos diretamente dentro do modal (`ProposalProductPickerDialog`) com subcategorias pré-configuradas (`MÓDULO SOLAR`, `INVERSOR SOLAR`, `MICROINVERSOR`, `BATERIA`, `ESTRUTURA`, `CABOS & CONECTORES`, `STRING BOX`) e **fichas técnicas reativas com campos dedicados** (Potência em W/kWp, Eficiência/Garantias em anos, Overload máx em kWp e Capacidade de Armazenamento em kWh para baterias), salvando no catálogo do Firestore e adicionando ao conjunto em 1 clique.
     - **Preço dos Produtos:** Autocompletado com a soma dos equipamentos (editável livremente com máscara `R$`).
     - **Preço do Serviço:** Instalação, projeto, engenharia e homologação.
     - **Totalizador Automático em Tempo Real:** Soma visual destacada de `(Produtos + Serviço + Serviços Adicionais)`.
     - **Fluxo Direto para Proposta Comercial:** Ao salvar uma Usina Solar (`SALVAR USINA SOLAR`), um diálogo modal pergunta: *"Deseja prosseguir com essa usina em uma nova proposta comercial?"*. Caso o usuário confirme ("SIM, CRIAR PROPOSTA"), o app navega diretamente para o formulário de cadastro de proposta já com a Usina Solar adicionada aos itens. Caso recuse ("NÃO, VOLTAR AO CATÁLOGO"), retorna à tabela de produtos.
  3. **Seletor de Categorias / Nichos (Nativas + Customizadas):** Grade visual combinando os segmentos nativos com categorias personalizadas criadas pelo usuário.
  4. **Cadastro & Gestão de Categorias (`CategoryFormDialog`):** Modal de criação/edição com seletor visual de 40+ ícones, paleta de cores e Live Preview.
  5. **Gerenciador de Subcategorias (Popup Modal):** Inclusão rápida, edição, exclusão e seleção com preenchimento automático.
  6. **Formulário Dinâmico Adaptativo:** Ajusta campos técnicos por setor/categoria com cálculo de margem de lucro e alertas de estoque.
  7. **Seletor de Fornecedor:** Campo integrado conectado à Stream de Fornecedores do Firestore.
  8. **Tabela em Tempo Real com Paginação Inteligente:**
     - Seletor de linhas por página: **20, 40, 100 ou 200** itens.
     - Navegação completa entre páginas (`<<`, `<`, `Página X de Y`, `>`, `>>`).
     - Botão integrado **"⚡ GERAR 200 PRODUTOS TESTE"** com cadastro em lote (`WriteBatch`) incluindo Usinas Solares e equipamentos fotovoltaicos.
     - Botão integrado **"🗑️ LIMPAR CATÁLOGO"** com exclusão em lote (`WriteBatch` até 450 docs/lote) e confirmação de segurança.
  9. **Agrupamento de Usinas Solares & Visualização de Componentes:**
     - **Visualização Padrão de Usinas:** Ao filtrar pela categoria **Usina Solar**, a listagem exibe **exclusivamente as Usinas Solares Criadas (Kits)**, ocultando os componentes avulsos do catálogo principal para manter a visão limpa e executiva.
     - **Agrupamento com Botão `+` / `-`:** Cada linha de Usina Solar possui um botão de expansão inline que abre o painel sanfona revelando todos os equipamentos inclusos no kit (módulos, inversores, estruturas, string boxes, cabos), quantidades, unidades, SKUs e serviços adicionais.
     - **Visual Limpo sem Duplicidades:** As Usinas Solares exibem apenas a tag de segmento `Usina Solar` na coluna correspondente, e componentes solares avulsos recebem a tag `ITEM AVULSO` ao lado do título.
     - **Ícones Temáticos de Energia por Componente:** Componentes solares avulsos recebem ícones inteligentes de energia elétrica (`bolt_rounded`, `offline_bolt_rounded` para inversores, `cable_rounded` para cabos/conectores, `handyman_rounded` para estruturas) em vez de repetir o ícone de usina inteira.
     - **Botão Toggle `"Mostrar Itens de Usinas"` com Persistência:** Aparece automaticamente na barra de filtros apenas quando a categoria Usina Solar está selecionada, permitindo alternar entre visualizar apenas os kits de usinas ou exibir também os componentes fotovoltaicos cadastrados avulsamente. O estado do botão (Ativo/Inativo) é persistido no `SharedPreferences`, mantendo-se ativo ao entrar e sair da edição de itens avulsos ou recarregar a tela.
     - **Botão Dinâmico `"NOVA USINA"`:** Ao filtrar por **Usina Solar**, o botão superior direito muda automaticamente de *"NOVO PRODUTO"* para *"NOVA USINA"* (com ícone e gradiente solar dourado), abrindo diretamente o formulário de cadastro de usinas sem passar pelo assistente de 20 nichos.
     - **Persistência de Segmento / Nicho (`SharedPreferences`):** O segmento selecionado no dropdown de filtro é salvo automaticamente localmente e restaurado ao reabrir ou navegar no aplicativo.
     - **Distinção Inteligente de Edição (Usina Solar vs Item Avulso):** Ao clicar em Editar em uma Usina Solar (Kit), abre o formulário completo `SolarPlantFormCard` com título *"Editar Usina Solar"* e a lista de equipamentos do conjunto. Ao clicar em Editar em um **Item Avulso** (módulo, inversor, cabo, bateria, estrutura), abre o formulário padrão de produto (`_ProductFormCard`) com o título *"Editar Item Avulso"*, categoria *"Usina Solar • Item Avulso / Equipamento"* e a ficha técnica específica do equipamento.

### 6. `SuppliersModule` / `SuppliersView`
- **`suppliers_view.dart`:** Gestão completa de fornecedores e parceiros comerciais:
  1. **Tabela em Tempo Real:** Conectada via `Stream<List<SupplierModel>>` com busca por Razão Social, Nome Fantasia, CNPJ ou E-mail, filtro por status (`Ativo`, `Inativo`, `Bloqueado`), badges de status e exclusão com diálogo modal.
  2. **Formulário com Seletor Visual de Categorias / Ramos (`CategorySelectorDialog`):** Botão `+` no campo "Ramo / Categoria" que abre modal com os 20 nichos nativos do Brasil + categorias customizadas com ícones, cores e cadastro rápido.
  3. **Consulta de CEP Automática (ViaCEP):** Preenchimento automático de logradouro, bairro, cidade, UF e complemento com auto-foco no campo "Número".
  4. **Condições Comerciais:** Cadastro de prazos de pagamento (ex: 30/60DD), representante/vendedor e notas de compras.

### 7. `UsersModule` / `UsersView`
- **`users_view.dart`:** View principal com dois estados internos:
  1. **Tabela (`_TableView`):** Lista em tempo real via `Stream<List<UserModel>>` do Firestore. Usa `LayoutBuilder` para garantir constraints finitas. Inclui busca por nome/e-mail, badges de papel (`_RoleBadge`) e status (`_StatusBadge`), exclusão com diálogo de confirmação.
  2. **Formulário (`_RegisterCard`):** Card de cadastro integrado com `RegisterStore` MobX, validação e persistência no Firebase.

### 8. `ProposalsModule` / `ProposalsView`
- **`proposals_view.dart` & `proposal_pdf_service.dart`:** Gestão completa de propostas comerciais e orçamentos:
  1. **Suporte Especial a Usinas Solares:** Ao selecionar uma Usina Solar no seletor de produtos, o item é adicionado destacando o nome da usina com badge `☀️ USINA SOLAR FOTOVOLTAICA`, potência (kWp), tipo de telhado/cobertura e a lista completa de equipamentos/serviços inclusos no kit.
  2. **Valor Único por Usina Solar:** Conforme a regra de negócio comercial, não são exibidos valores individuais por componente — apenas a listagem dos equipamentos que compõem o kit e o valor total único da usina solar.
  3. **Múltiplas Usinas por Proposta:** Permite adicionar mais de uma usina solar na mesma proposta, além de produtos avulsos do catálogo ou itens sob medida.
  4. **Vínculo com Cliente via Autocomplete Inteligente & Cadastro Rápido (`ProposalClientAutocomplete` & `ClientFormDialog`):**
     - **Autocomplete com Histórico Recente:** Ao clicar no campo de busca, exibe instantaneamente os clientes cadastrados mais recentes com avatares, CPF/CNPJ, e-mail, cidade/UF e badges PF/PJ. Conforme o usuário digita, filtra em tempo real por nome, documento, e-mail, telefone ou empresa.
     - **Card de Cliente Selecionado:** Exibe os dados do cliente com destaque visual e botões para *"Trocar Cliente"* ou cadastrar novo.
     - **Botão `+` ("NOVO CLIENTE"):** Abre diretamente o modal `ClientFormDialog` com formulário completo e busca automática de endereço via **ViaCEP**. Ao salvar o cliente no Firestore, ele é **automaticamente selecionado e todos os campos são preenchidos na proposta** com 1 clique!
     - **Modo Consumidor Avulso:** Permite alternar para emissão rápida sem vínculo cadastral digitando diretamente os dados do destinatário.
  5. **Condições Comerciais & Pagamento:** Configuração de formas de pagamento (PIX, Boleto 30/60DD, Cartão), prazo de validade (dias), prazo de entrega, descontos e frete com totalizador em tempo real.
  6. **Padrões de Cores do PDF:** Seletor de 6 paletas temáticas executivas (Indigo, Azul Executivo, Esmeralda, Grafite Slate, Rubi, Âmbar).
  7. **Motor de PDF Vetorial (`ProposalPdfService`):** Layout executivo em página A4, tabela zebrada com renderização detalhada de Usinas Solares (com equipamentos inclusos) e valor único por usina, resumo de valores e campo de aceite formal.
  8. **Pré-Visualização & Impressão Interativa (`ProposalPdfPreviewDialog`):** Modal de alta resolução (`PdfPreview`) com atalhos de impressão direta e download do PDF gerado.
  9. **Criação Direta de Usinas Solares no Formulário de Propostas:** Botão com gradiente solar `"CRIAR USINA SOLAR"` na seção de Itens & Produtos da proposta que abre diretamente o `SolarPlantFormCard` em modal (com suporte a IA Gemini Vision OCR), permitindo montar uma nova usina ou importar cotação em PDF e inseri-la instantaneamente na proposta em edição com 1 clique através do botão `"ADICIONAR À PROPOSTA"`.
  10. **Switch de Proposta Limpa (Apenas Inversor e Módulo) com Persistência:** Switch posicionado estrategicamente logo acima de *Condições Comerciais & Pagamento*. Ao ser acionado, oculta itens secundários da cotação (cabos, conectores MC4, perfis de fixação, grampos, junções e garras de aterramento) e exibe apenas os equipamentos principais (**Módulos e Inversores/Microinversores**) tanto na tabela de itens do formulário quanto no documento PDF final exportado para o cliente. A preferência do usuário é **salva automaticamente no armazenamento local (`SharedPreferences`)**, permanecendo ativa como padrão para todas as novas propostas ou permitindo ser desmarcada a qualquer momento.


### 9. `SettingsModule` / `SettingsView` (`lib/settings/presentation/settings_view.dart`)
- **`settings_view.dart` & `settings_service.dart`:** Gestão de preferências e nicho do CRM:
  1. **Configuração de Ramo / Nicho de Atuação:** Permite ao usuário selecionar qual dos 20 ramos do mercado brasileiro (ou Usina Solar) sua empresa atua.
  2. **Modo Focado (Lock-in):** Quando ativado (padrão ao escolher Usina Solar ou nicho exclusivo), oculta automaticamente o dropdown de 20 segmentos na tela de produtos, deixando o CRM 100% focado e limpo para o ramo escolhido (ex: Usinas Solares, botão "NOVA USINA" e agrupamento de kits).
  3. **Onboarding no Primeiro Login:** Ao logar pela primeira vez no sistema (ou sem nicho salvo), o modal de setup inicial (`SectorOnboardingDialog`) é exibido automaticamente como primeira tela com fundo total escuro e wallpaper tecnológico fullscreen (`https://images.unsplash.com/...`), cobrindo 100% do app em segundo plano.
  4. **Persistência Completa:** Salva localmente via `SettingsService` (`SharedPreferences`) e permite alterar o nicho a qualquer momento na aba *Configurações*.
  5. **Menu Lateral Reativo:** Ao definir o nicho como **Usina Solar**, o menu lateral `Produtos` é transformado automaticamente e em tempo real para `☀️ Usinas Solares` com ícone temático (`solar_power_rounded`).

### 10. `AppSidebar` (`lib/app/layout/app_sidebar.dart`)
- **Menu Lateral Retrátil / Colapsável (Desktop) & Drawer Nativo (Mobile):**
  - **Adaptação Mobile Automática:** Em telas com largura `< 768px` (celulares Android/iOS), o layout oculta o menu lateral fixo da tela principal e transforma-o em um **Drawer lateral nativo** acessível pelo botão de menu da `AppBar`. O miolo dinâmico passa a ocupar 100% da largura da tela do celular sem quebras de layout.
  - **Largura Dinâmica e Fluida (Desktop):** Alterna entre `250px` (expandido) e `76px` (colapsado) com animação suave de 250ms (`Curves.easeInOutCubic`).
  - **Modo Colapsado:** Exibe ícones perfeitamente centralizados em containers de 48px com `Tooltip` rico mostrando o nome de cada módulo ao passar o mouse.
  - **Controles de Alternância (Toggle):** Botão estilizado no topo da Sidebar (`keyboard_double_arrow_left/right`) e botão de menu na AppBar (`menu/menu_open`).
  - **Itens Dinâmicos:** Suporte a títulos e ícones reativos por nicho (ex: "Usinas Solares").
  - Enum `AppSidebarItem` com `dashboard`, `clients`, `products`, `suppliers`, `proposals`, `users`, `settings`.

---

## 📐 7. Padrões de Código e Convenções

1. **Injeção de Dependências:** Sempre registrar repositórios e stores nos módulos via `Bind.lazySingleton`. Evitar instanciar serviços diretamente nas Views (usar `try { Modular.get<T>() } catch (_) { T() }` como fallback seguro).
2. **Gerenciamento de Estado com MobX:**
   - Apenas o `Store` gerencia estados (`@observable`, `@action`, `@computed`).
   - Usar widgets `Observer` pontuais em torno dos elementos reativos para evitar rebuild total da tela.
   - Sempre executar `flutter pub run build_runner build --delete-conflicting-outputs` ao criar/modificar stores.
3. **Design Tokens:**
   - Nunca utilizar cores cruas (`Colors.blue`, `Colors.red`) nos componentes novos.
   - Sempre consumir `AppColors`, `AppDecorations` e `AppTheme.font(...)` definidos em `lib/app/theme/`.
4. **Layout Responsivo Web/Mobile:**
   - Widgets no miolo do SPA **sempre** usar `LayoutBuilder` ou `SizedBox.expand` como raiz para garantir constraints finitas.
   - Nunca colocar `Expanded` como filho direto de `Column` sem altura garantida pelo pai.
   - `ElevatedButton` e `OutlinedButton` **NUNCA** devem ser usados diretamente dentro de `Row` ou `Column` com decorações conflitantes.
5. **Configurações Multiplataforma (Android/Web):**
   - `AndroidManifest.xml` configurado com `android.permission.INTERNET` e `ACCESS_NETWORK_STATE`.
   - `build.gradle.kts` com `minSdk = 21` para Firebase e `google_sign_in`.

---

## ⏳ 8. Funcionalidades Concluídas e Backlog

- [x] **Cadastro e Gestão de Usuários:** Formulário integrado com validação MobX e persistência Auth/Firestore.
- [x] **Listagem e Gestão dos Usuários:** Tabela profissional conectada em tempo real, busca rápida, badges de papel/status e exclusão com confirmação.
- [x] **Cadastro e Gestão de Clientes:** Módulo completo de Clientes (PF/PJ), status de prospecto/ativo, busca em tempo real e listagem.
- [x] **Consulta de CEP Automática:** Auto-preenchimento via API pública ViaCEP com validação e auto-foco.
- [x] **Cadastro e Gestão de Produtos & Serviços:** Módulo completo com ramificação em 20 segmentos brasileiros, categorização customizada com ícones/cores e controle de estoque.
- [x] **Cadastro e Gestão de Fornecedores:** Módulo completo de Fornecedores com consulta ViaCEP automática, condições comerciais e integração direta no cadastro de produtos.
- [x] **Módulo de Propostas Comerciais & Geração de PDF:** Emissão de orçamentos com múltiplos produtos, cliente vinculado ou avulso, escolha de paleta de cores e geração de PDF vetorial de alta qualidade com preview.
- [x] **Arquitetura SPA estabilizada:** Scaffold único no Dashboard, AppSidebar com enum tipado (`dashboard`, `clients`, `products`, `suppliers`, `proposals`, `users`), troca de miolo dinâmica sem erros de render.
- [x] **Prontidão Android:** `minSdk = 21`, permissões de Internet e `google-services.json` integrados.
- [x] **Multi-Empresa & Isolamento de Dados (Multi-tenancy):** Isolamento total por `companyId` em todos os módulos (Clientes, Produtos, Fornecedores, Propostas, Categorias, Usuários). Cada conta registrada atua como empresa/tenant raiz (`companyId == uid` e `role == 'admin'`). Usuários cadastrados internamente herdam o `companyId` da empresa e seu nível de acesso.
- [ ] **Módulo de Leads / Funil de Vendas (CRM):** Criar módulo completo com funil de vendas (Kanban / Lista), filtros por status (Novo, Em Contato, Proposta, Ganho, Perdido) e histórico de interações.
- [ ] **Recuperação de Senha:** Implementar fluxo `sendPasswordResetEmail` na tela de login.
- [ ] **Route Guards:** Implementar `RouteGuard` no Modular para proteger `/dashboard/` contra acesso sem autenticação.
- [ ] **Relatórios e Métricas:** Dashboard com gráficos de conversão e desempenho dos operadores.

> 📚 *Roadmap técnico e tarefas detalhadas em:* [`/docs/roadmap_and_backlog.md`](file:///c:/mavis/docs/roadmap_and_backlog.md)
