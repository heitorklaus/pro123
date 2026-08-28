# 🗺️ Roadmap Técnico e Backlog - Mavis CRM

Este documento reúne os próximos passos do desenvolvimento, dívidas técnicas a serem resolvidas e novas funcionalidades planejadas para o **Mavis CRM**.

---

## ✅ Concluído com Sucesso

### Fase 0 — Fundação & Design System
- [x] Projeto Flutter criado e configurado com Firebase (Auth + Firestore).
- [x] Design System centralizado (`AppColors`, `AppTheme`, `AppDecorations`).
- [x] Módulo de autenticação completo (Login E-mail/Senha + Google OAuth).
- [x] `UserModel` com RBAC granular (`UserPermissions`) e `AuthRepository`.
- [x] **Prontidão Android:** `AndroidManifest.xml` com permissões de rede, `minSdk = 21` e `google-services.json`.

### Fase 1 — Dashboard SPA e Gestão de Usuários
- [x] **Arquitetura SPA Master:** `DashboardPage` como Scaffold único da área autenticada.
- [x] **`AppSidebar`:** Menu lateral desacoplado e reutilizável com enum `AppSidebarItem`.
- [x] **`UsersView` (Tabela & Form):** Lista em tempo real via Stream Firestore, busca rápida, badges de papel/status e exclusão com diálogo de confirmação.

### Fase 2 — Módulo de Clientes (PF / PJ) & Consulta de CEP Automática
- [x] **`ClientModel` & `ClientRepository`:** Suporte a Pessoa Física e Jurídica, status do cliente e endereço estruturado.
- [x] **`ClientsView` (Tabela & Form):** Tabela em tempo real com busca rápida e badges visuais.
- [x] **Integração ViaCEP:** Consulta assíncrona automática via API pública brasileira, auto-preenchimento de 5 campos de endereço com bloqueio e auto-foco no campo "Número".

### Fase 3 — Módulo de Produtos & Serviços (Ramificação em 20 Segmentos)
- [x] **Wizard de Ramificação Pré-Cadastro:** Grade visual e busca rápida para escolha entre os **20 Segmentos Comerciais do Brasil** (Limpeza, Moda, Alimentos, Construção, TI, Mecânica, Serviços, etc.).
- [x] **Formulário Dinâmico Adaptativo:** Ajuste automático de campos técnicos por nicho + cálculo de margem de lucro e controle de estoque com alertas.
- [x] **Gerenciador de Subcategorias (Popup Modal Grande):** Suffix icon no campo de subcategoria abrindo diálogo de 680x600px para inclusão instantânea, pesquisa, edição e exclusão de subcategorias no Firestore com seleção automática.
- [x] **Tabela de Catálogo:** Listagem em tempo real, busca global (nome, SKU, EAN), filtro por segmento e badges de estoque.

---

## 📌 Próximas Tarefas Prioritárias

### 4.1. Módulo de Leads / Funil de Vendas (Pipeline & CRM)
- [ ] Criar `lib/leads/leads_module.dart` com Binds e rotas.
- [ ] Implementar `LeadModel` (nome, contato, valor, responsável, estágio, tags, notas).
- [ ] Adicionar coleção `leads/{leadId}` no Firestore.
- [ ] Adicionar item **"Leads"** no `AppSidebar` com `AppSidebarItem.leads`.
- [ ] Visualização em **Kanban** com colunas (*Novo*, *Contato*, *Proposta*, *Fechado*, *Perdido*).
- [ ] Visualização em **Tabela** com filtros rápidos e busca.

### 4.2. Recuperação de Senha (Forgot Password)
- [ ] Adicionar botão "Esqueci minha senha" na tela de Login.
- [ ] Modal solicitando e-mail e disparando `FirebaseAuth.instance.sendPasswordResetEmail(email)`.
- [ ] Feedback visual de sucesso/erro em português.

### 4.3. Route Guards (Segurança Modular)
- [ ] Implementar `RouteGuard` no Modular para proteger rotas contra acesso sem autenticação.
- [ ] Redirecionar usuários com status diferente de `active` para tela de aviso.

---

## 🚀 Fase Futura — Recursos Avançados

- [ ] **Multi-empresa (Multi-tenancy):** Filtrar todas as coleções por `companyId`.
- [ ] **Dashboard com Gráficos e Métricas:** Integração com gráficos de funil e volume de vendas.
- [ ] **Histórico e Atividades:** Registro de telefonemas, notas e reuniões em cada Lead.
- [ ] **Perfil do Usuário Logado:** Edição de dados e avatar.
