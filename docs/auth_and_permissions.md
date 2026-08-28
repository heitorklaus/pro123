# 🔐 Autenticação e Permissões (RBAC) - Mavis CRM

Este documento especifica a infraestrutura de autenticação, login social e o sistema de controle de acesso baseado em funções (**Role-Based Access Control - RBAC**) no Mavis CRM.

---

## 1. Métodos de Autenticação

A aplicação utiliza o **Firebase Authentication** integrado ao **Cloud Firestore** através da classe `AuthRepository` (`lib/auth/data/repositories/auth_repository.dart`).

### 1.1. Login por E-mail e Senha
- **Cadastro:** Cria as credenciais no Auth e imediatamente insere um documento correspondente em `/users/{uid}` com o papel padrão `user`.
- **Login:** Autentica com o Auth e consulta o Firestore para verificar se a conta está ativa (`status == 'active'`). Se inativa ou bloqueada, o login é recusado com mensagem amigável.
- **Tratamento de Exceções:** Mapeamento em português para erros do Firebase (`email-already-in-use`, `wrong-password`, `user-disabled`, etc.).

### 1.2. Login com Conta Google
- **Detecção de Plataforma (`kIsWeb`):**
  - **Web:** Utiliza `FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())`.
  - **Mobile (Android/iOS):** Utiliza o plugin `google_sign_in` para obter o `idToken` e `accessToken`, convertendo-os em `OAuthCredential`.
- **Sincronização com Firestore:** Se for o primeiro acesso da conta Google, o perfil é criado no Firestore automaticamente com `status: 'active'` e permissões padrão. Se já existir, apenas o `lastLoginAt` é atualizado.

---

## 2. Matriz de Permissões (RBAC)

O controle de acesso é gerenciado pelas classes `UserModel` e `UserPermissions` (`lib/auth/domain/models/user_model.dart`).

### 2.1. Papéis (`roles`) e Permissões Padrão:

| Permissão | `admin` | `manager` | `user` |
| :--- | :---: | :---: | :---: |
| **`manageUsers`** (Criar, editar e excluir operadores) | ✅ **Sim** | ❌ Não | ❌ Não |
| **`manageSettings`** (Configurações globais do sistema) | ✅ **Sim** | ❌ Não | ❌ Não |
| **`viewReports`** (Acessar métricas e relatórios avançados)| ✅ **Sim** | ✅ **Sim** | ❌ Não |
| **`editLeads`** (Criar e atualizar oportunidades) | ✅ **Sim** | ✅ **Sim** | ✅ **Sim** |
| **`deleteLeads`** (Excluir oportunidades comerciais) | ✅ **Sim** | ✅ **Sim** | ❌ Não |

### 2.2. Getters Auxiliares no `UserModel`:
```dart
bool get isAdmin => role == 'admin';
bool get isManager => role == 'manager' || isAdmin;
bool get isActive => status == 'active';
```

---

## 3. Fluxo de Sessão e Rotas Protegidas

1. **Inicialização:** A rota inicial `/` carrega o `AuthModule` (`/login`).
2. **Ao Logar:** Ao obter sucesso no `controller.login()` ou `controller.loginWithGoogle()`, a aplicação executa `Modular.to.navigate('/dashboard/')`.
3. **Logout:** O botão na AppBar do Dashboard chama `_authRepository.logout()` e redireciona de volta para `/auth/login`.
