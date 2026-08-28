# 🦅 Mavis CRM

Aplicação moderna e responsiva (Web, Android e iOS) de **Gestão de Relacionamento com Clientes (CRM)**, controle operacional, cadastro de catálogo por segmentos comerciais e gestão de acessos.

---

## 🚀 Tecnologias Utilizadas
- **Framework:** [Flutter](https://flutter.dev) (Dart SDK `>=3.0.0 <4.0.0`)
- **Arquitetura:** Feature-First Modular Architecture ([Flutter Modular v5](https://modular.flutterando.com.br))
- **Gerenciamento de Estado:** [MobX](https://mobx.pub) & `flutter_mobx`
- **Backend & Database:** Firebase Auth, Cloud Firestore NoSQL em tempo real
- **APIs Externas:** [ViaCEP](https://viacep.com.br) para preenchimento automático de endereços
- **Design System:** Paleta moderna Slate/Indigo com tipografia Google Fonts (Outfit & Roboto/Inter)

---

## 📦 Módulos Implementados

### 1. 🔐 Autenticação & Permissões (RBAC)
- Login com E-mail/Senha e Google OAuth (Web e Mobile).
- Cadastro de novos operadores integrado ao Firebase Auth e Cloud Firestore.
- Perfis de acesso: `admin`, `manager` e `user` com matriz de permissões granulares.

### 2. 🏛️ Dashboard SPA Master
- Scaffold persistente único para a área autenticada.
- Menu lateral responsivo (`AppSidebar`).
- Troca dinâmica de conteúdo central sem re-renderização da estrutura global.

### 3. 👥 Gestão de Usuários
- Tabela de operadores em tempo real com busca por nome e e-mail.
- Badges de papel e status (`active`, `pending`, `blocked`).
- Exclusão com confirmação modal e formulário de novo operador.

### 4. 🏢 Gestão de Clientes (PF / PJ)
- Cadastro completo de Pessoa Física e Jurídica.
- **Consulta de CEP Automática (ViaCEP):** Preenche logradouro, bairro, cidade, UF e complemento automaticamente ao digitar o CEP, com foco automático no número.
- Tabela com busca em tempo real e badges de status do cliente.

### 5. 📦 Catálogo de Produtos & Serviços
- **Wizard de Ramificação Pré-Cadastro:** Grade visual interativa com busca rápida para escolha entre **20 Segmentos Comerciais do Brasil** (Limpeza, Moda, Alimentos, Construção, Autopeças, TI, Serviços, etc.).
- **Formulário Adaptativo Dinâmico:** Ajusta campos técnicos exclusivos por segmento (diluição, grade/cor, validade, compatibilidade de veículos, etc.).
- **Gerenciador de Subcategorias (Popup Modal):** Inclusão, busca, edição e exclusão de subcategorias vinculadas ao nicho, com seleção em 1 clique.
- **Controle de Estoque e Margem:** Alertas visuais de estoque baixo e cálculo de lucro em tempo real.

---

## 🛠️ Como Executar o Projeto

### Pré-requisitos:
- Flutter SDK instalado e adicionado ao `PATH`.
- Chrome ou Emulador/Dispositivo Android conectado.

### Rodar no Navegador (Web):
```bash
flutter run -d chrome
```

### Rodar no Android:
```bash
flutter run -d android
```

### Gerar Código MobX (se alterar Stores):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
