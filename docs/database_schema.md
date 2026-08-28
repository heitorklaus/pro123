# 🗄️ Esquema do Banco de Dados - Cloud Firestore

Este documento descreve o modelo de dados NoSQL do Cloud Firestore para o **Mavis CRM**, incluindo coleções ativas, relacionamentos e planejamento de regras de segurança.

---

## 1. Visão Geral da Modelagem

O Mavis utiliza um banco NoSQL orientado a documentos (**Cloud Firestore**). Os documentos são estruturados com suporte a multi-tenancy (`companyId`), controle granular de permissões (RBAC) e ramificação comercial adaptativa.

---

## 2. Coleções Ativas

### 2.1. Coleção: `users`
- **Caminho:** `/users/{userId}`
- **Chave Primária (`Document ID`):** O mesmo `uid` gerado pelo Firebase Authentication.
- **Descrição:** Contém o perfil completo, credenciais e permissões operacionais do usuário.

| Campo | Tipo | Obrigatório | Descrição |
| :--- | :--- | :--- | :--- |
| `uid` | `string` | Sim | Identificador único do Firebase Auth |
| `name` | `string` | Sim | Nome completo do usuário |
| `email` | `string` | Sim | E-mail corporativo de acesso |
| `phone` | `string` | Não | Número de telefone/WhatsApp |
| `avatarUrl` | `string` | Não | Link da foto de perfil |
| `role` | `string` | Sim | Papel (`admin`, `manager`, `user`) |
| `status` | `string` | Sim | Status da conta (`active`, `pending`, `blocked`) |
| `companyId` | `string` | Não | ID da empresa para multi-tenancy |
| `permissions` | `map` | Sim | Mapa de permissões booleanas (`manageUsers`, `manageSettings`, etc.) |
| `createdAt` | `timestamp`| Sim | Data e hora de criação da conta |
| `updatedAt` | `timestamp`| Sim | Data e hora da última modificação |
| `lastLoginAt` | `timestamp`| Não | Data e hora do último acesso com sucesso |

---

### 2.2. Coleção: `clients`
- **Caminho:** `/clients/{clientId}`
- **Chave Primária (`Document ID`):** Auto-gerado pelo Firestore.
- **Descrição:** Cadastro completo de clientes (Pessoa Física e Pessoa Jurídica) com endereço estruturado.

| Campo | Tipo | Obrigatório | Descrição |
| :--- | :--- | :--- | :--- |
| `name` | `string` | Sim | Nome completo ou Razão Social |
| `email` | `string` | Sim | E-mail principal para contato |
| `phone` | `string` | Sim | Telefone / WhatsApp do cliente |
| `document` | `string` | Não | CPF ou CNPJ |
| `clientType` | `string` | Sim | Tipo: `pf` (Pessoa Física) ou `pj` (Pessoa Jurídica) |
| `companyName`| `string` | Não | Nome Fantasia / Empresa (para PJ) |
| `status` | `string` | Sim | Status: `active`, `prospect`, `inactive`, `blocked` |
| `zipCode` | `string` | Não | CEP consultado via ViaCEP |
| `street` | `string` | Não | Logradouro / Rua |
| `addressNumber`| `string`| Não | Número do imóvel |
| `complement` | `string` | Não | Complemento (apto, bloco, sala) |
| `neighborhood`| `string`| Não | Bairro |
| `city` | `string` | Não | Cidade |
| `state` | `string` | Não | UF do Estado (ex: SP, RJ, MG) |
| `notes` | `string` | Não | Observações internas sobre o cliente |
| `createdAt` | `timestamp`| Sim | Data e hora de cadastro |
| `updatedAt` | `timestamp`| Sim | Data e hora da última atualização |

---

### 2.3. Coleção: `products`
- **Caminho:** `/products/{productId}`
- **Chave Primária (`Document ID`):** Auto-gerado pelo Firestore.
- **Descrição:** Catálogo de produtos e serviços com suporte aos **20 segmentos comerciais brasileiros** e campos específicos dinâmicos.

| Campo | Tipo | Obrigatório | Descrição |
| :--- | :--- | :--- | :--- |
| `name` | `string` | Sim | Nome do produto ou serviço |
| `sku` | `string` | Não | Código de controle interno / SKU |
| `barcode` | `string` | Não | Código de barras comercial (EAN/GTIN) |
| `sector` | `string` | Sim | Segmento comercial (`cleaning`, `fashion`, `food`, etc.) |
| `subcategory`| `string`| Não | Subcategoria do item |
| `description`| `string`| Não | Detalhes, instruções e composição |
| `salePrice` | `number` | Sim | Preço final de venda |
| `costPrice` | `number` | Não | Preço de custo para cálculo de margem |
| `stockQuantity`| `number`| Sim | Quantidade atual em estoque (default: 0) |
| `minStock` | `number` | Sim | Estoque mínimo para disparo de alerta (default: 5) |
| `unit` | `string` | Sim | Unidade comercial (`UN`, `CX`, `KG`, `LT`, `HR`, `SV`, etc.) |
| `ncm` | `string` | Não | Código de Nomenclatura Comum do Mercosul |
| `status` | `string` | Sim | Status: `active`, `inactive`, `outOfStock` |
| `specificAttributes`| `map` | Sim | Atributos técnicos exclusivos do segmento escolhido |
| `createdAt` | `timestamp`| Sim | Data e hora de inclusão |
| `updatedAt` | `timestamp`| Sim | Data e hora da última edição |

---

### 2.4. Coleção: `subcategories`
- **Caminho:** `/subcategories/{subcategoryId}`
- **Chave Primária (`Document ID`):** Auto-gerado pelo Firestore.
- **Descrição:** Lista de subcategorias vinculadas por segmento comercial para seleção rápida e organização no catálogo.

| Campo | Tipo | Obrigatório | Descrição |
| :--- | :--- | :--- | :--- |
| `name` | `string` | Sim | Nome da subcategoria (ex: "Desinfetantes", "Camisetas") |
| `sector` | `string` | Sim | Identificador do segmento (`cleaning`, `fashion`, etc.) |
| `createdAt` | `timestamp`| Sim | Data de criação |

---

## 3. Coleções Planejadas (Módulos de CRM & Vendas)

### Coleção: `leads`
- **Caminho:** `/leads/{leadId}`
- **Descrição:** Oportunidades comerciais e funil de vendas (Kanban e Lista).

```json
{
  "id": "lead_uuid",
  "name": "Acme Indústria Ltda",
  "contactPerson": "Carlos Ferreira",
  "email": "carlos@acme.com",
  "phone": "+55 11 99999-8888",
  "value": 15000.00,
  "stage": "new | contacted | proposal_sent | won | lost",
  "assignedTo": "userId_do_responsavel",
  "companyId": "company_uuid",
  "tags": ["Software", "Inbound", "Urgente"],
  "notes": "Cliente solicitou proposta comercial personalizada.",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "closedAt": "Timestamp?"
}
```

---

## 4. Diretrizes de Segurança (Firestore Security Rules)

1. **Autenticação Obrigatória:** Nenhuma coleção deve aceitar leitura ou escrita desautenticada (`request.auth != null`).
2. **Isolamento de Contas Inativas:** Usuários com `status != 'active'` não devem conseguir ler ou modificar documentos.
3. **Escrita em `users`:** Apenas administradores podem alterar `role` e `permissions`.
4. **Catálogo e Clientes:** Operadores autenticados podem ler e registrar clientes e produtos.
