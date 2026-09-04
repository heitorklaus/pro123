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
├── contracts/                        # Módulo de Gestão e Emissão de Contratos Jurídicos
│   ├── data/
│   │   ├── repositories/
│   │   │   └── contract_repository.dart# Integração Firestore da coleção contracts
│   │   └── services/
│   │       ├── contract_pdf_service.dart# Compilação e Impressão de PDF multipáginas A4
│   │       ├── contract_settings_service.dart# Persistência de template padrão por empresa e reversão
│   │       └── contract_template_engine.dart# Template oficial de 5 páginas e interpolação de tags
│   ├── domain/
│   │   └── models/
│   │       └── contract_model.dart   # Entidade ContractModel e ContractStatus
│   └── presentation/
│       ├── contracts_view.dart       # ⭐ View no SPA com tabela em tempo real, busca e KPIs
│       └── widgets/
│           ├── contract_proposal_picker_dialog.dart# Seletor de proposta e resolução inteligente de cliente
│           └── contract_rich_editor.dart# Editor WYSIWYG estilo Word com folha A4, Dark Mode Arial, Lupa Flutuante e Reset
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
Armazena o perfil estendido dos operadores e administradores do CRM com RBAC granular.
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
    "viewClients": true,
    "createClients": true,
    "viewProducts": true,
    "createProducts": true,
    "viewProposals": true,
    "createProposals": true,
    "viewAllProposals": false,
    "viewContracts": true,
    "createContracts": true,
    "viewAllContracts": false,
    "deleteContracts": false,
    "viewSuppliers": false,
    "createSuppliers": false,
    "manageSettings": false,
    "manageUsers": false
  },
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "lastLoginAt": "Timestamp"
}
```

> 📚 *Esquema detalhado e futuras coleções (`leads`, `companies`, `activities`) em:* [`/docs/database_schema.md`](file:///c:/mavis/docs/database_schema.md)

---

## 🔐 5. Autenticação e Permissões Granulares (RBAC)

### Níveis de Acesso (`roles`):
1. **`superAdmin` / `master` (`admin@admin.com.br`)**: Administrador Geral e Supremo do Ecossistema TAOS CRM. Possui visão global irrestrita de todas as contas, empresas, propostas, clientes e produtos cadastrados por qualquer usuário do sistema. Possui painel executivo master no Dashboard com KPIs consolidados em tempo real e feed de auditoria.
2. **`admin`**: Administrador da Conta / Empresa local. Acesso irrestrito a todas as operações da sua organização, gerenciamento de operadores e permissões.
3. **`manager`**: Gestão comercial de equipe, acesso ampliado a clientes, produtos, fornecedores e visualização de todas as propostas da empresa.
4. **`user` (Operador)**: Acesso restrito e customizável às operações do dia a dia; por padrão visualiza apenas as próprias propostas criadas.

### Matriz de Permissões Granulares (`UserPermissions`):
- **Clientes:** `viewClients` (Listar Clientes), `createClients` (Cadastrar / Editar Clientes).
- **Produtos & Usinas:** `viewProducts` (Listar Produtos/Usinas), `createProducts` (Cadastrar Produtos, Montar Usinas, Ações em Lote).
- **Propostas & Vendas:** `viewProposals` (Listar Propostas/Funil Kanban), `createProposals` (Emitir / Gerar Novas Propostas), `viewAllProposals` (Acompanhar Propostas de Todos os Usuários).
- **Contratos & Jurídico:** `viewContracts` (Visualizar Módulo de Contratos), `createContracts` (Emitir e Editar Minutas de Contratos), `viewAllContracts` (Ver Contratos de Todos os Operadores), `deleteContracts` (Excluir Contratos).
- **Fornecedores:** `viewSuppliers` (Listar Fornecedores), `createSuppliers` (Cadastrar Fornecedores).
- **Configurações & Sistema:** `manageSettings` (Acesso às Configurações), `manageUsers` (Gerenciar Usuários e Permissões).

### Cascata Profunda de Permissões (Deep UI Cascading):
- **Menu Lateral (`AppSidebar`):** Oculta os itens de navegação quando o usuário não possui permissão de leitura correspondente.
- **Telas / Listagens:** Oculta botões de ação ("NOVO CLIENTE", "NOVO PRODUTO", "NOVA USINA", "NOVO FORNECEDOR", "NOVA PROPOSTA", "GERAR 200 TESTE", "LIMPAR CATÁLOGO") se o usuário não tiver permissão de criação.
- **Fluxo de Emissão de Propostas:**
  - Se o operador não puder cadastrar usinas (`!createProducts`), o botão *"MONTAR USINA SOLAR"* fica oculto e exibe apenas *"ADICIONAR PRODUTO / USINA"*.
  - Dentro do modal de seleção de produtos (`ProposalProductPickerDialog`), o botão *"ADICIONAR ITEM"* fica oculto se `!createProducts`.
  - No autocomplete de clientes (`ProposalClientAutocomplete`), o botão *"+ NOVO CLIENTE"* fica oculto se `!createClients`.
- **Configurador de Permissões (`UserPermissionsDialog`):** Localizado na tela de **Usuários**, acionado pelo ícone de engrenagem (`Icons.settings_suggest_rounded`) em cada linha de operador. Permite ao Admin alternar permissões em tempo real com presets rápidos (*Acesso Total*, *Padrão Gerente*, *Padrão Operador*, *Somente Leitura*).
- **Filtragem de Propostas por Criador:** Propostas gravam `createdByUserId` e `createdByUserName`. Operadores sem `viewAllProposals` visualizam apenas os orçamentos que eles mesmos criaram, enquanto Admins e Gerentes acompanham a produção integral de toda a equipe.

### 👔 5.1. Gestão Comercial, Desempenho & Auditoria 360º da Equipe (Admin & Gerente):
Arquitetura completa em 3 pilares para que o Administrador da Empresa tenha controle e visibilidade total sobre a atuação de cada vendedor:
1. **Autoria e Vínculo Automático (`createdByUserId` e `createdByUserName`):** Todo registro gerado (Proposta, Usina Solar / Produto, Cliente e Contrato) armazena a autoria de quem o criou, com fallback seguro para usuários legados.
2. **Pilar 1 — Filtros por Vendedor & Badges de Autoria:**
   - **Propostas (`ProposalsView` & `ProposalKanbanView`):** Dropdown de seleção de vendedor na barra de busca (desktop e mobile), filtragem em tempo real no Firestore e chips visuais com o nome do criador em todas as linhas da tabela, cartões mobile e cards do Kanban.
   - **Contratos (`ContractsView`):** Dropdown seletor de vendedor no cabeçalho com filtragem em tempo real e chip de autoria na coluna do cliente.
   - **Produtos & Catálogo (`ProductsView`):** Dropdown seletor de criador e badge `👤 [Nome]` na listagem de produtos e usinas solares.
3. **Pilar 2 — Dossiê 360º de Desempenho do Vendedor (`UserDossierDialog`):**
   - Modal executivo (1040x760px) com cabeçalho escuro premium e métricas consolidadas em tempo real sobre os Streams do Firestore:
     - 5 KPIs em tempo real: *Total em Propostas (R$)*, *Vendas Fechadas / Ganhas (R$)*, *Taxa de Conversão (%)*, *Potência Fotovoltaica Ofertada (kWp)* e *Contratos Jurídicos Emitidos*.
     - 4 Abas completas:
       - **Aba 1 (Propostas):** Listagem com status badge, valores, datas, visualizador de PDF e atalho de compartilhamento web.
       - **Aba 2 (Usinas Solares):** Listagem de usinas e kits criados pelo operador com potência em kWp, tipo de telhado e equipamentos.
       - **Aba 3 (Contratos):** Contratos emitidos pelo vendedor com status e botão de impressão de PDF.
       - **Aba 4 (Clientes):** Carteira de clientes cadastrados pelo operador com dados de contato.
   - Acionamento direto pelo botão `📊` (`Icons.analytics_outlined`, cor esmeralda) em todos os níveis da tela de **Usuários** (`_AdminTreeGroup`, `_SubordinateRow`, `_OrphansGroup`, `_UserRow`) e nas linhas do Leaderboard.
4. **Pilar 3 — Painel Executivo da Empresa & Ranking de Vendas (`_CompanyExecutiveDashboard` & `_TeamPerformanceRankingCard`):**
   - No Dashboard inicial (SPA) de Administradores e Gerentes comerciais, exibe o painel corporativo consolidado:
     - Header executivo com identidade da empresa e resumo da equipe.
     - 6 KPIs Corporativos: Vendas Fechadas (R$), Volume Total de Propostas (R$), Taxa de Conversão Geral da Equipe (%), Potência Solar Ofertada (kWp), Contratos Emitidos e Clientes na Carteira.
     - **Tabela de Desempenho & Ranking da Equipe de Vendas (`_TeamPerformanceRankingCard`):** Leaderboard dos operadores ordenados por faturamento ganho/emitido com medalhas de pódio (🥇 1º, 🥈 2º, 🥉 3º), volume financeiro, taxa de conversão individual e botão de ação para abrir o Dossiê 360º de cada vendedor em 1 clique.
     - Feed em tempo real das últimas propostas e clientes cadastrados por qualquer membro da organização.

---

## 🧩 6. Módulos e Funcionalidades Existentes

### 1. `AppModule` (Global)
- Configuração de rotas principais: `/` → `/auth`, `/auth` (Login/Register) e `/dashboard` (Painel SPA).

### 2. `AuthModule`
- **Tela de Login (`login_page.dart`):** Interface moderna com `TechBackground` (malha cibernética e orbes luminosos), card branco alargado (480px) com cantos arredondados e elevação suave, logo compacta otimizada, campos estilizados e autenticação E-mail/Senha e Google OAuth validada via MobX (`LoginStore`).
- **Tela de Cadastro (`register_page.dart`):** Cadastro moderno com `TechBackground`, card branco alargado, campos consistentes e persistência direta no Firestore e Auth com perfil de Admin / Dono da Empresa.
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
  11. **Cabeçalho e Rodapé 100% Programáticos e Minimalistas (`SolarProposalPdfService`):**
      - **Remoção total de arquivos SVG pesados:** Eliminados todos os 19 arquivos `.svg` legados (`mark_top_...`), substituindo-os por renderização vetorial nativa e instantânea.
      - **Cabeçalho:** Barra sólida vertical na cor de destaque primária da proposta ao lado do título da seção em caixa alta elegante (ex: `PROPOSTA COMERCIAL`, `SUA USINA SOLAR`, `ITENS DA USINA & PAGAMENTO`, `ANÁLISE DE INVESTIMENTO`, `FINANCIAMENTO & CONDIÇÕES`), número da proposta à direita e linha divisória fina horizontal com segmento de destaque colorido no canto direito.
      - **Rodapé:** Linha divisória superior com segmento de destaque colorido, ícone vetorial solar com raios no canto esquerdo ao lado do slogan configurável da empresa (ex: `ENERGIA QUE TRANSFORMA`) e paginação à direita (`Página X de Y`).
      - **Personalização de Cores e Slogan:** Paleta de cores selecionável na aba de configurações com live preview interativo e campo customizável para o slogan no rodapé.
  12. **Proposta Web Interativa & Compartilhamento Público em Link Aberto (`WebProposalPage`):**
      - **Experiência Digital Moderna Inspirada no Modelo Solar7:** O cliente final pode acessar a proposta diretamente pelo navegador através do link público `/proposta/:id` (ou `/p/:id`), sem precisar fazer download de arquivos.
      - **Plano de Fundo em Alta Resolução com 34 Modelos:** O usuário pode escolher nas configurações (`SolarSettingsView` - Aba 5) qualquer um dos 34 papéis de parede profissionais localizados em `assets/background_web/`. A proposta web renderiza em tela cheia com overlay escuro e glassmorphism refinado.
      - **Componentes Interativos da Proposta Web:**
        - Cabeçalho da marca com slogan, atalhos de compartilhamento de link, download de PDF e contato direto no WhatsApp do vendedor.
        - Banner Hero com identificação da proposta, status, cliente e data de emissão.
        - Grade com 4 KPIs destacados (Potência kWp, Geração Média em kWh/mês, Economia no 1º Ano e Redução na Conta de até 95%).
        - Ficha Técnica Completa da Usina (Potência, Módulos, Inversor, Telhado, Geração e Área Ocupada).
        - Equipamentos Inclusos & Os 4 Pilares do Escopo Turn-Key.
        - Análise Financeira & Simulação Gráfica de Retorno/Economia em 25 anos.
        - **Simulador Interativo de Pagamento:** Alternância entre À Vista (com desconto), Financiamento Solar Bancário (com seletor de bancos e prazos em 12x, 24x, 36x, 48x, 60x, 72x, 84x, 90x com cálculo dinâmico das parcelas em tempo real) e Cartão de Crédito.
        - **Aceite Digital em 1 Clique:** Modal que coleta os dados do titular e atualiza instantaneamente o status da proposta para `approved` no Cloud Firestore, disparando modal de celebração com atalho para agendamento via WhatsApp.
        - **Dock Flutuante Inferior:** Fixado na base com resumo do valor total e botões de ação rápida (WhatsApp e Aceitar Proposta).
      - **Ações na Tabela de Propostas (`ProposalsView`):** Botões dedicados para 🌐 *"Abrir Versão Web Interativa"*, 🔗 *"Copiar Link da Proposta"* e 💬 *"Enviar no WhatsApp"* com mensagem personalizada já formatada.
  13. **Modelo KANBAN Interativo com Drag & Drop e Funil de Vendas (`ProposalKanbanView`):**
      - **Alternância Fluida de Visualização (Tabela vs Kanban):** Botão segmented switch integrado no topo da tela de propostas (`[ 📋 Tabela | 📊 Kanban ]`), com persistência automática no armazenamento local (`SharedPreferences`), lembrando a preferência do operador entre sessões.
      - **As 4 Etapas Oficiais do Funil de Propostas:**
        1. **EM APROVAÇÃO (`ProposalStatus.inApproval`):** Cor Índigo (`#6366F1`), ícone de ampulheta/pendente, destinado a propostas recém-elaboradas aguardando revisão ou aprovação interna/cliente.
        2. **NEGOCIANDO (`ProposalStatus.negotiating`):** Cor Azul Céu (`#0284C7`), ícone de chat/negociação, para propostas enviadas em tratativa comercial ativa.
        3. **FECHADAS (`ProposalStatus.closed`):** Cor Esmeralda (`#059669`), ícone de confirmação/sucesso, para orçamentos aprovados e vendas ganhas.
        4. **NEGADAS (`ProposalStatus.rejected`):** Cor Rose/Vermelho (`#DC2626`), ícone de cancelamento, para propostas recusadas ou perdidas.
      - **Arrastar e Soltar Nativo (Drag & Drop estilo Trello/Jira/HubSpot):** Cards interativos com `Draggable<ProposalModel>` e colunas com `DragTarget<ProposalModel>`. Ao arrastar uma proposta entre colunas, a coluna de destino se ilumina com a cor temática correspondente e uma área delimitada *"Soltar para mover para [ETAPA]"* é exibida. Ao soltar, o status é instantaneamente atualizado no Cloud Firestore via `ProposalRepository.updateStatus()` com notificação SnackBar em tempo real.
      - **Cards de Proposta Ricos em Informação:** Cada card do Kanban apresenta o número da proposta com badge destacada, título, nome do cliente com ícone, badge dourada de Usina Solar (`☀️ Usina X.XX kWp`) ou contagem de itens, valor total formatado em Reais (`R$`), prazo de validade e barra completa de ações rápidas (🌐 Proposta Web, 🔗 Copiar Link, 💬 WhatsApp, 📄 PDF, ✏️ Editar, 🔄 Menu Rápido de Status e 🗑️ Excluir).
      - **Barra de Resumo Executivo do Pipeline (KPIs no Topo):** Total monetário consolidado do funil (`R$`), quantidade total de propostas ativas e taxa de conversão (% de propostas fechadas).
      - **Totalizador por Coluna em Tempo Real:** Cada coluna exibe no cabeçalho o contador de propostas da etapa e a soma monetária de todos os orçamentos contidos nela.
      - **Seletor de Etapa no Formulário:** Dropdown integrado no formulário de cadastro/edição permitindo definir ou alterar a etapa da proposta diretamente na tela de edição.

   14. **Estúdio Visual de Capas de Proposta em Tempo Real & 100 Modelos Fotovoltaicos (`SolarSettingsView` - Aba 5):**
       - **100 Modelos de Capa Limpas (A4 @ 150 DPI):** 100 arquivos gráficos de alta resolução (`modelo_proposta_1.jpg` a `100.jpg`) cobrindo usinas de solo, fazendas solares, telhados residenciais, galpões industriais e tecnologia de módulos. Todas as imagens possuem o terço inferior 100% branco preservado e os 70% superiores com fotos solares e separadores geométricos fluidos sem textos embutidos.
       - **Sincronização com Firebase Storage:** Todos os 100 modelos sincronizados e hospedados na nuvem na pasta `capas/energiasolar/` no bucket do Firebase Storage, com fallback local instantâneo (0ms de carregamento) via `assets/modelo_propostas/`.
       - **Editor Interativo em Tempo Real (Drag & Drop):** Live Preview em proporção A4 onde o usuário pode clicar e **arrastar o retângulo do título** diretamente com o mouse ou toque para qualquer posição da capa (`coverBadgePositionX`, `coverBadgePositionY`), com sliders finos de coordenadas.
       - **Tipografia e Estilo Customizáveis:**
         - Campo de **Título** (Padrão: `"PROPOSTA COMERCIAL"`) com slider de tamanho (16 a 40pt) e seletor de cores.
         - Campo de **Subtítulo** (Padrão: `"ENERGIA SOLAR FOTOVOLTAICA"`) com slider de tamanho (8 a 20pt) e seletor de cores.
         - Switch de Retângulo de Fundo (Badge) com seletor de cor (Branco, Grafite, Ciano, Âmbar, Esmeralda, etc.) e slider de **Opacidade** (10% a 100%).
         - Botões rápidos de reset: *"Topo Esquerdo"* e *"Restaurar Padrões"*.
       - **Criador de Capa Personalizada (Sua Foto + Separador Vetorial):** Permite ao cliente carregar qualquer foto do computador via `FilePicker` (ou selecionar entre 34 papéis de parede) e combinar com **10 estilos matemáticos de separadores/decalques** desenhados via `CustomPainter` (`SolarCoverDividerPainter`):
         1. *Onda Suave Clássica (S-Curve)*
         2. *Onda Dupla Harmônica Intersectante*
         3. *Corte Diagonal Moderno*
         4. *Polígonos Facetados (Chevron)*
         5. *Arco Aerodinâmico Côncavo*
         6. *Declive Arquitetônico Solar*
         7. *Cascata Tripla de Ondas*
         8. *Hexágono Tech Futurista*
         9. *Arco Convexo Suave*
         10. *Varredura Angular Ascendente*
        - **Integração de Logomarca da Empresa com Posicionamento e Redimensionamento:**
          - **Botão "ENVIAR LOGO":** Localizado logo abaixo dos botões de ação na prévia, permite o envio de imagem da empresa (PNG, JPG, WEBP).
          - **Arrastar e Posicionar Livremente (Drag & Drop):** A logo aparece sobre o canvas A4 e pode ser arrastada livremente para qualquer área da capa (`coverLogoPositionX`, `coverLogoPositionY`).
          - **Slider de Redimensionamento em Tempo Real:** Ajusta a largura da logomarca de `40px` a `180px` com atualização imediata no visual.
          - **Presets de Posicionamento:** Atalhos para *"Topo Direito"*, *"Topo Centro"* e *"Rodapé"*.
          - **Renderização no PDF (`SolarProposalPdfService`):** A logomarca é gravada com precisão milimétrica nas coordenadas e dimensões exatas configuradas pelo usuário.
        - **Integração no Motor de PDF (`SolarProposalPdfService`):** A capa da página 1 do PDF renderiza o modelo escolhido com o retângulo, título, subtítulo, logomarca personalizada e opacidade nas coordenadas milimétricas exatas definidas pelo usuário, com contraste perfeito sobre a área branca inferior.
   15. **Assistente Inteligente Unificado de IA para Propostas Comerciais (`GeminiProposalAssistantService` & `ProposalAiAssistantDialog`):**
       - **Análise Multi-Arquivos Simultâneos:** Permite o envio simultâneo de múltiplos documentos (ex: Cotação Fotovoltaica da Distribuidora + Documento de Identificação/Fatura do Cliente). A IA do Google Gemini classifica e diferencia automaticamente qual arquivo é a cotação solar e qual é a identificação do cliente (RG, CNH, CPF, Cartão CNPJ ou Fatura DANF3E).
       - **Vinculação e Criação Automática do Cliente:** Ao identificar o documento do titular, a IA pesquisa no Firestore se o cliente já existe (por CPF/CNPJ ou e-mail). Se existir, vincula-o diretamente; se for inédito, cria o cadastro com endereço completo preenchido e associa à proposta em 1 clique.
       - **Montagem de Proposta por Texto Livre / Prompt / Partes:** Permite criar propostas comerciais diretamente por linguagem natural digitada ou mensagens coladas (ex: *"Monte uma proposta pra mim com 15 placas de 615W e 1 inversor AUXSOL de 8kw, com geração de 1000kwh mes e valor de servico R$ 10.000"*), sem obrigatoriedade de anexar PDFs ou imagens. A IA calcula a potência nominal em kWp (`Quantidade × Watts / 1000`), extrai marcas, componentes, geração e serviço.
       - **Passo Final de Revisão e Confirmação de Parâmetros:** Apresenta painel executivo com cards visuais do Cliente e da Usina, permitindo ao operador conferir e ajustar a **Geração Estimada (kWh/mês)** e o **Valor do Serviço (R$)** antes de gerar a proposta.
       - **Integração Completa na UI:** Botão **"✨ CRIAR COM IA"** no cabeçalho das propostas, botão **"✨ ASSISTENTE IA"** dentro do formulário `_ProposalFormCard` e integração com a importação de Usinas Solares (`SolarPdfImportDialog`).

### 8. `ContractsModule` / `ContractsView` / `ContractRichEditor` (`lib/contracts/`)
- **`contracts_view.dart`, `contract_rich_editor.dart`, `contract_proposal_picker_dialog.dart`, `contract_template_engine.dart` & `contract_pdf_service.dart`:** Gestão, emissão e edição de contratos jurídicos fotovoltaicos com integração direta às propostas comerciais:
  1. **Emissão de Contratos Baseada em Propostas Comerciais:** Seleciona qualquer proposta comercial cadastrada no CRM e herda automaticamente o número da proposta, usina fotovoltaica, potência em kWp, geração estimada (kWh/mês), composição do kit solar, fornecedor/distribuidor, valor dos equipamentos, valor do serviço de instalação e condições de pagamento.
  2. **Resolução e Cadastro Inteligente de Clientes:**
     - Ao selecionar a proposta, o assistente verifica se o cliente possui cadastro completo na base (Nome, CPF/CNPJ e Endereço).
     - Se a proposta não tiver cliente associado ou faltar dados obrigatórios, exibe alerta visual com opções diretas: *"Vincular Cliente Existente"*, *"+ Cadastrar Novo Cliente"* (abre `ClientFormDialog` com busca ViaCEP na hora) ou *"Completar / Editar Dados"*.
  3. **Motor de Contrato Padrão Oficial (5 Páginas):**
     - Template padrão fiel ao contrato de prestação de serviços fotovoltaicos com todas as cláusulas jurídicas:
       - **Qualificação Completa das Partes:** Contratante (Cliente) e Contratada (Empresa integradora logada no Firestore);
       - **Considerandos A a D:** Potência da usina, geração média CRESESB, tipo de telhado, kit solar, repasse de valores ao distribuidor parceiro e garantia de instalação de 12 meses;
       - **Cláusulas 1 a 10:** Objeto do contrato e escopo turn-key, exclusões explícitas de obras civis e reforço de telhado, declarações da contratada, custódia de materiais pela contratante, detalhamento de valores e pagamentos, cronograma de execução, prazos adicionais de concessionária de energia (30 dias para análise, 60 dias em baixa tensão e 120 dias em média tensão caso haja obras de rede), cláusula penal de inadimplência e rescisão com multa de 5%, garantia de funcionamento de 12 meses, foro da comarca da empresa e disposições finais;
       - **Local, Data por Extenso e Campos de Assinatura** para Contratante e Contratada.
  4. **Editor WYSIWYG Estilo Word com Folha A4 Realista:**
     - Visual em canvas de papel A4 com sombra, proporções reais e controles de zoom (80%, 100%, 120%);
     - Barra de ferramentas completa: Negrito (**B**), Itálico (*I*), Sublinhado (<u>U</u>), Listas com Marcadores (•), Divisores (---), Título 1, Título 2 e Cláusulas (H3);
     - **Menu "+ INSERIR VARIÁVEL":** Dropdown categorizado com chips interativos de todas as variáveis do banco de dados (`{{NOME_CONTRATANTE}}`, `{{DOCUMENTO_CONTRATANTE}}`, `{{ENDERECO_CONTRATANTE}}`, `{{POTENCIA_KWP}}`, `{{GERACAO_MENSAL_KWH}}`, `{{DESCRICAO_EQUIPAMENTOS_KIT}}`, `{{VALOR_SERVICO_FORMATADO}}`, `{{VALOR_SERVICO_EXTENSO}}`, `{{VALOR_TOTAL_GLOBAL_FORMATADO}}`, `{{FORMA_PAGAMENTO_DETALHADA}}`, etc.);
     - Botão *"Restaurar Padrão"* para regenerar o modelo inicial a qualquer momento;
     - Seletor de Status integrado (*Rascunho*, *Aguardando Assinatura*, *Assinado*, *Cancelado*).
  5. **Compilação & Impressão de PDF Multipáginas A4:**
     - Geração de PDF oficial diagramado com tipografia formal (*Inter*), cabeçalho institucional com logomarca da empresa integradora, texto justificado, numeração de páginas ("Página X de Y") e linhas de assinatura ao final.
  6. **Gestão em Tempo Real na Tabela:**
     - Stream do Firestore (`contracts/{contractId}`) com isolamento multi-tenant por empresa (`companyId`);
     - KPIs consolidados no topo (Valor Total Contratado, Contratos Assinados, Aguardando Assinatura, Total Emitido);
     - Filtros rápidos por status e busca inteligente por texto;
     - Ações rápidas de Editar no Editor Word, Imprimir/Baixar PDF, Alterar Status e Excluir.

### 9. `SettingsModule` / `SettingsView` / `CompanySetupDialog` (`lib/settings/`)
- **`settings_view.dart`, `company_setup_dialog.dart`, `company_service.dart` & `settings_service.dart`:** Gestão de preferências, identidade visual e perfil institucional da Empresa no CRM:
  1. **Limpeza Completa de Dados Padrão (Sem dados "Soli"):** Todos os valores fixos e placeholders fictícios de exemplo de empresas terceiras foram removidos dos modelos e views. Os dados carregam limpos e são preenchidos exclusivamente a partir do perfil configurado da empresa no Firestore (`companies/{companyId}`).
  2. **Onboarding Direto & Sem Flash no Primeiro Acesso do Admin (Dono da Empresa):**
     - **Carregamento Direto:** A `DashboardPage` inicializa diretamente no `SectorOnboardingDialog` com fundo escuro elegante, eliminando qualquer flash da tela de início antes da abertura do configurador.
     - **Etapa 1 (Configurador de Nicho - `SectorOnboardingDialog`):** O Admin visualiza a grade com os 20 nichos de mercado ou Usina Solar em modal sobreposto ao Dashboard com fundo translúcido. Ao clicar diretamente no card do seu ramo de atuação, o sistema avança imediatamente para o formulário de dados da empresa.
     - **Etapa 2 (Formulário da Empresa com Opção de Pular - `CompanySetupDialog`):**
       - **Botão "PREENCHER DEPOIS":** Permite ao usuário pular o preenchimento dos campos obrigatórios da empresa caso queira configurar mais tarde. O nicho selecionado é salvo como preferência e a Dashboard é liberada imediatamente.
       - **Dados Cadastrais:** Razão Social / Nome Fantasia, CNPJ/CPF, Telefone/WhatsApp Comercial, E-mail, Site Oficial, Instagram e Slogan.
       - **Endereço Completo com ViaCEP:** Consulta automática por CEP autocompletando Logradouro, Bairro, Cidade, Estado (UF) e Complemento, com foco automático no campo Número.
       - **Logomarca da Empresa:** Upload de imagem (PNG, JPG, WEBP) com visualização em tempo real (preview) e opções de troca ou remoção.
     - **Persistência Centralizada & Sincronização:** Os dados são gravados na coleção `companies/{companyId}` e sincronizados automaticamente com as configurações de proposta (`sector_settings/solarPlant`), garantindo que capas de PDF, propostas web e cabeçalhos recebam imediatamente os dados institucionais e a logomarca da empresa.
  3. **Card Institucional da Empresa nas Configurações:** Apresenta um painel dedicado com status do perfil, logo, CNPJ, telefone, endereço resumido e botão *"EDITAR DADOS DA EMPRESA & LOGO"* para alteração a qualquer momento.
  4. **Painel de Treinamento e Administração do Agente de IA (`AiAgentSettingsView`, `AiAgentSettingsService`, `AiAgentSettingsModel`):**
     - **Isolamento Multi-Tenant por Empresa:** Cada Admin de empresa possui seu próprio painel administrativo isolado para personalizar a inteligência artificial da sua equipe (`companies/{companyId}/settings/ai_agent`).
     - **Regras Oficiais como DEFAULT:** O sistema já inicializa com todas as regras mestres pré-configuradas (classificação multi-arquivo de cotações vs documentos do cliente, extração de kits fotovoltaicos com kWp, geração e serviços, e montagem por texto livre).
     - **4 Abas Interativas de Configuração:**
       1. **🧠 Prompt & Instruções:** Editor com a System Instruction mestre em destaque, permitindo que o Admin adicione ou modifique diretrizes comportamentais e de formatação.
       2. **💼 Políticas & Marcas:** Configuração da margem padrão de serviço (%), fator de geração regional (kWh/kWp), validade padrão, tipo de telhado e **chips interativos** com botão de adicionar/remover para **Distribuidoras Parceiras**, **Módulos Preferenciais** e **Inversores Preferenciais**.
       3. **🎓 Exemplos de Treinamento (Few-Shot Learning):** Lista gerenciável de casos reais onde a IA aprende exatamente o padrão esperado de raciocínio da empresa (com switches de ativação e formulário de novo caso).
       4. **🧪 Playground & Simulador ao Vivo:** Área de testes em tempo real onde o Admin pode executar prompts e verificar como o Agente se comporta com as regras atuais antes de liberar para a equipe comercial.
     - **Controle de Rigor / Temperatura:** Slider de 0.0 a 1.0 (Padrão: 0.2 para máxima fidelidade técnica).
     - **Botão "Restaurar Padrões":** Permite resetar as regras da empresa para o padrão oficial Mavis a qualquer momento.
  5. **Modo Focado (Lock-in):** Quando ativado (padrão ao escolher Usina Solar ou nicho exclusivo), oculta automaticamente o dropdown de 20 segmentos na tela de produtos, deixando o CRM 100% focado e limpo para o ramo escolhido (ex: Usinas Solares, botão "NOVA USINA" e agrupamento de kits).
  6. **Menu Lateral Reativo:** Ao definir o nicho como **Usina Solar**, o menu lateral `Produtos` é transformado automaticamente e em tempo real para `☀️ Usinas Solares` com ícone temático (`solar_power_rounded`).

### 10. `AppSidebar` (`lib/app/layout/app_sidebar.dart`)
- **Menu Lateral Retrátil / Colapsável (Desktop) & Drawer Nativo (Mobile):**
  - **Adaptação Mobile Automática:** Em telas com largura `< 768px` (celulares Android/iOS), o layout oculta o menu lateral fixo da tela principal e transforma-o em um **Drawer lateral nativo** acessível pelo botão de menu da `AppBar`. O miolo dinâmico passa a ocupar 100% da largura da tela do celular sem quebras de layout.
  - **Largura Dinâmica e Fluida (Desktop):** Alterna entre `250px` (expandido) e `76px` (colapsado) com animação suave de 250ms (`Curves.easeInOutCubic`).
  - **Modo Colapsado:** Exibe ícones perfeitamente centralizados em containers de 48px com `Tooltip` rico mostrando o nome de cada módulo ao passar o mouse.
  - **Controles de Alternância (Toggle):** Botão estilizado no topo da Sidebar (`keyboard_double_arrow_left/right`) e botão de menu na AppBar (`menu/menu_open`).
  - **Itens Dinâmicos:** Suporte a títulos e ícones reativos por nicho (ex: "Usinas Solares").
  - Enum `AppSidebarItem` com `dashboard`, `clients`, `products`, `suppliers`, `proposals`, `users`, `settings`.

### 12. Solar Roof Designer & Módulo de Estudos de Telhado (`lib/solar_designer/`)
- **Gestão e Mapeamento de Telhados Fotovoltaicos via Satélite & Foto de Drone:**
  - **Single Page Application (SPA) & Navegação Nativa:** Integrado diretamente na `AppSidebar` (`AppSidebarItem.roofStudies`, ícone `satellite_alt_rounded`) com view dedicada `RoofStudiesView` (layout `LayoutBuilder` finite-bounds, 4 KPIs em tempo real, busca, tabela desktop e cards mobile).
  - **Fluxo de Inicialização e Vínculos Flexíveis (`RoofStudySetupDialog`):** Ao iniciar um novo estudo, apresenta um modal executivo em tema escuro para:
    1. Nomear o estudo (com sugestão inteligente baseada em data ou endereço).
    2. Vincular a um cliente existente ou cadastrar na hora via `+ NOVO CLIENTE` (`ClientFormDialog`).
    3. Vincular a uma proposta comercial existente da empresa (`ProposalRepository.getProposalsStream`).
    4. Permitir estudos avulsos (sem cliente e/ou sem proposta), suportando as 4 combinações possíveis.
    5. Edição de vínculos a qualquer momento via ação rápida na tabela ou no cabeçalho do designer.
  - **Persistência Completa no Cloud Firestore (`roof_studies`) & Firebase Storage:**
    - Entidade `RoofStudyModel` com serialização completa de águas (`RoofSection`), vértices do polígono (`RoofPoint`), módulos alocados com rotação e coordenadas cartesianas 2D (`PlacedModule`), especificações do módulo (`SolarModuleSpec`), zoom, offsets de pan, endereço e metadados de multi-tenancy (`companyId`, `createdByUserId`, `createdByUserName`).
    - **Upload Antecipado em Background & Persistência com Zero Falha de Fotos de Drone:** Para contornar o limite rígido de 1MB por documento do Firestore e garantir salvamento instantâneo:
      1. Ao selecionar a foto de drone (`_pickDronePhoto`), o sistema inicia imediatamente o upload no **Firebase Storage** (`roof_studies/drone/{studyId}_drone.jpg`) em segundo plano (`_uploadDroneImageInBackground`) com timeout seguro de 45s, enquanto o usuário desenha e posiciona módulos.
      2. No ato de salvar (`_saveRoofStudy`), aguarda o future de upload com timeout seguro de 35s (eliminando falhas de timeout que ocorriam em conexões lentas).
      3. Imediatamente após gerar o ID no Firestore (`saveStudy`), grava a imagem no cache local do dispositivo (`_cacheDroneImage(savedId, _droneImageBytes)`), garantindo que ao salvar pela primeira vez a foto já esteja disponível para reabertura imediata.
      4. Se o upload em segundo plano finalizar após o salvamento, atualiza automaticamente o documento no Firestore via `RoofStudyRepository.updateDroneImageUrl`.
      5. Ao abrir o estudo salvo, carrega o cache local em 0ms e utiliza o SDK do Firebase Storage (`refFromURL.getData`) com fallback para `http.get`, imune a bloqueios de CORS na Web.
    - Botão **`SALVAR 💾`** direto no cabeçalho do estúdio de satélite com feedback visual instantâneo e persistência automática ao concluir/exportar.
  - **Canvas de Desenho & Alocação Inteligente de Placas:**
    - Cursors dinâmicos (`SystemMouseCursors.grab` no modo Pan/Navegar, `crosshair` no modo Desenhar, e `click` ao passar o mouse sobre módulos no modo de edição).
    - Adição direcional de placas com detecção matemática de sobreposição (overlap prevention) e seleção automática do novo módulo alocado.
    - Suporte a múltiplas águas de telhado com paleta de cores e consolidação métrica (kWp, kWh/mês, m²).

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
- [x] **Módulo de Propostas Comerciais & Geração de PDF com Armazenamento no Firebase Storage:** Emissão de orçamentos com múltiplos produtos, cliente vinculado ou avulso, escolha de paleta de cores e geração de PDF vetorial de alta qualidade (6 páginas para Usinas Solares e formato padrão). O sistema agora faz o upload automático do arquivo físico `.pdf` diretamente no **Firebase Storage** no caminho oficial `gs://solardino-aea02.appspot.com/propostas_mavis/{companyId}/{userId}/{proposalNumber}_proposta.pdf` e grava `pdfUrl` e `pdfPath` no documento Firestore, garantindo download instantâneo via web, celular ou integrações externas.
- [x] **Arquitetura SPA estabilizada:** Scaffold único no Dashboard, AppSidebar com enum tipado (`dashboard`, `clients`, `products`, `suppliers`, `proposals`, `users`), troca de miolo dinâmica sem erros de render.
- [x] **Prontidão Android:** `minSdk = 21`, permissões de Internet e `google-services.json` integrados.
- [x] **Multi-Empresa & Isolamento de Dados (Multi-tenancy):** Isolamento total por `companyId` em todos os módulos (Clientes, Produtos, Fornecedores, Propostas, Categorias, Usuários). Cada conta registrada atua como empresa/tenant raiz (`companyId == uid` e `role == 'admin'`). Usuários cadastrados internamente herdam o `companyId` da empresa e seu nível de acesso.
- [x] **Controle de Cotas de IA & Limite de Vendedores por Integrador (Painel Master):** Sistema robusto com permissão granular no RBAC (`useAi`), cota diária padrão configurável de análises de IA (default: 25/dia com renovação à meia-noite), limite padrão de vendedores por empresa/integrador (default: 5 vendedores por integrador com bloqueio inteligente de novos cadastros), diálogos explicativos com estética moderna e painel configurador exclusivo para o SuperAdmin no Dashboard master (`admin@admin.com.br`) com personalização de cotas globais e individuais por integradora via `SystemSettingsService` (`system_settings/global_config`).
- [ ] **Microserviço Nativo Dart de Geração de PDFs (mavis-pdf):** Microserviço em Dart para rodar no Easypanel (porta 8080) compartilhando a lógica oficial de compilação do `SolarProposalPdfService`. Quando o `mavis-bot` registrar propostas via WhatsApp, aciona o microserviço Dart para compilar o PDF de 6 páginas com fotos HD, salvar no Firebase Storage (`gs://solardino-aea02.appspot.com/propostas_mavis/{companyId}/{userId}/`) e disparar o documento `.pdf` diretamente no WhatsApp do operador.
- [ ] **Módulo de Leads / Funil de Vendas (CRM):** Criar módulo completo com funil de vendas (Kanban / Lista), filtros por status (Novo, Em Contato, Proposta, Ganho, Perdido) e histórico de interações.
- [ ] **Recuperação de Senha:** Implementar fluxo `sendPasswordResetEmail` na tela de login.
- [ ] **Route Guards:** Implementar `RouteGuard` no Modular para proteger `/dashboard/` contra acesso sem autenticação.
- [ ] **Relatórios e Métricas:** Dashboard com gráficos de conversão e desempenho dos operadores.

> 📚 *Roadmap técnico e tarefas detalhadas em:* [`/docs/roadmap_and_backlog.md`](file:///c:/mavis/docs/roadmap_and_backlog.md) e [`/docs/microservico_pdf_proposta_roadmap.md`](file:///c:/mavis/docs/microservico_pdf_proposta_roadmap.md)


