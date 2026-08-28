# 🏛️ Arquitetura Detalhada - Mavis CRM

Este documento aprofunda os padrões arquiteturais, ciclo de vida de dados e decisões de design implementadas no **Mavis CRM**.

---

## 1. Clean Architecture & Feature-First Pattern

O projeto é particionado em **Módulos Independentes por Funcionalidade (Feature Modules)**. Cada módulo encapsula suas três camadas essenciais:

```
[ Camada de Apresentação (Presentation) ]
       │
       ▼ (Acessa dados através de)
[ Camada de Domínio (Domain - Models / Enums) ]
       ▲
       │ (Implementado por)
[ Camada de Dados (Data - Repositories / DataSources) ]
```

### Camadas e Responsabilidades:

### 1. Presentation (Apresentação)
- **Widgets e Páginas (`*_page.dart`, `*_view.dart`):** Responsáveis estritamente pela renderização de tela e captura de eventos do usuário. Devem ser desacoplados de regras de negócio diretas.
- **Controllers / Stores (`*_store.dart`):** Implementados com **MobX**. Mantêm o estado reativo da tela, validam entradas de formulários e acionam repositórios.

### 2. Domain (Domínio)
- **Modelos (`*_model.dart`):** Entidades puras do negócio (`UserModel`, `ClientModel`, `ProductModel`, `SubcategoryModel`).
- **Enums & Regras:** `ProductSector` (20 segmentos comerciais do Brasil), `ProductUnit`, `ProductStatus`, factories de conversão `toMap()` e `fromMap()`.

### 3. Data (Dados)
- **Repositories (`*_repository.dart`):** Comunicação com SDKs externos (Firebase Auth, Cloud Firestore, API REST ViaCEP).

---

## 2. Injeção de Dependências e Roteamento (Flutter Modular)

O projeto utiliza o **`flutter_modular`** (v5) para gerenciar o ciclo de vida dos objetos e a navegação:

- **Escopo Global (`AppModule`):**
  - Declaração de rotas-raiz (`/` -> `/auth`, `/auth` e `/dashboard`).
- **Escopo Dashboard (`DashboardModule`):**
  - Registra serviços e repositórios compartilhados:
    - `AuthRepository` (lazySingleton)
    - `RegisterStore` (lazySingleton)
    - `ClientRepository` (lazySingleton)
    - `ProductRepository` (lazySingleton)

### Fallback Seguro para Injeção:
```dart
try {
  _repo = Modular.get<ProductRepository>();
} catch (_) {
  _repo = ProductRepository(); // fallback direto
}
```

---

## 3. Padrão SPA (Single Page Application) — Área Autenticada

A área autenticada usa um **único Scaffold** (`DashboardPage`) que nunca é desmontado. O conteúdo central ("miolo") é trocado dinamicamente via `setState` baseado em `AppSidebarItem`.

```
DashboardPage (único Scaffold da área autenticada)
 ├── AppBar (persistente)
 └── Row
      ├── AppSidebar (250px — enum AppSidebarItem)
      └── Expanded → _buildMiolo() → switch(_activeItem)
           ├── [dashboard] → _WelcomeCard
           ├── [clients]   → ClientsView (Tabela + Form com ViaCEP auto)
           ├── [products]  → ProductsView (Tabela + Wizard 20 Segmentos + Form Dinâmico + Popup Subcat)
           └── [users]     → UsersView (Tabela + Form de Operadores)
```

---

## 4. Módulos Implementados e Decisões de Design

### 4.1. Módulo de Produtos & Serviços (`lib/products/`)
- **Wizard de Ramificação Pré-Cadastro:** Grade visual interativa com busca rápida para escolha entre **20 Segmentos Comerciais do Brasil** (Limpeza, Alimentos, Vestuário, Construção, Autopeças, TI, Serviços, Mecânica, etc.).
- **Formulário Adaptativo:** Adapta campos técnicos com base no nicho (ex: Diluição/Volume para produtos de limpeza; Grade/Cor para moda; Carga horária para cursos).
- **Gerenciador de Subcategorias (Popup Modal Grande):** Ícone no campo de subcategoria abre diálogo de 680x600px para inclusão instantânea, pesquisa, edição e exclusão de subcategorias no Firestore, com botão "SELECIONAR" que auto-preenche o formulário.
- **Tabela em Tempo Real:** Conexão `Stream<List<ProductModel>>`, filtros por segmento, busca global (nome, SKU, EAN) e badges de controle de estoque.

### 4.2. Módulo de Clientes (`lib/clients/`)
- **Suporte a PF e PJ:** Cadastro de Pessoa Física e Jurídica.
- **Consulta Automática de CEP (ViaCEP):** Ao digitar 8 dígitos, consome a API pública `https://viacep.com.br/ws/{cep}/json/` e auto-preenche logradouro, bairro, cidade, UF e complemento, focando automaticamente no campo "Número".

### 4.3. Módulo de Usuários e RBAC (`lib/auth/`, `lib/users/`)
- **Autenticação Dupla:** E-mail/senha e Google OAuth (Web e Mobile).
- **Controle de Acesso:** Perfis `admin`, `manager` e `user` com matriz de permissões booleanas.

---

## 5. Regras Críticas de Layout Flutter Web / Mobile

1. **`LayoutBuilder` na Raiz do Miolo:** Todos os widgets injetados no miolo do Dashboard devem conter `LayoutBuilder` ou dimensões finitas explícitas para eliminar o erro `Cannot hit test a render box with no size`.
2. **Evitar `GridView.builder(shrinkWrap: true)` em Scrolls Infinitos:** Utilizar `Wrap` responsivo com larguras finitas calculadas (`cardWidth`).
3. **Padrão Obrigatório de Botões em `Row`/`Column`:** Utilizar `Material` + `InkWell` + `Ink` para garantir que o Flutter calcule os bounds de hit-testing perfeitamente.
