# 🚀 Roteiro de Implementação: Microserviço Dart de PDF & Automação WhatsApp

Este documento detalha a arquitetura, próximos passos e especificações para a implementação do **Microserviço Nativo Dart de Geração de PDFs de Propostas Comerciais** integrado ao **Mavis CRM** e ao **Robô Copiloto WhatsApp**.

---

## 📌 1. Visão Geral da Arquitetura

```text
[ Vendedor no WhatsApp ]
        │
        ▼ 1. "Agente, gera proposta pro Ricardo..."
[ Robô WhatsApp (mavis-bot no Easypanel) ]
        │
        ├── 2. Grava Cliente, Produtos, Usina e Proposta no Cloud Firestore (Google)
        │
        ▼ 3. POST http://mavis-pdf:8080/generate { proposalId: "..." }
[ Microserviço Dart (mavis-pdf no Easypanel ou Google Cloud Run) ]
        │
        ├── 4. Executa o código nativo oficial do SolarProposalPdfService em Dart
        ├── 5. Baixa a capa HD do Firebase Storage
        ├── 6. Compila o PDF de 6 páginas com tabelas, simulações de 20 anos e bancos
        ├── 7. Faz upload do arquivo .pdf para:
        │      gs://solardino-aea02.appspot.com/propostas_mavis/{companyId}/{userId}/{fileName}
        └── 8. Atualiza o Firestore com 'pdfUrl' e 'pdfPath' e retorna os bytes do PDF
        │
        ▼ 9. Evolution API (mavis-ia)
[ Vendedor recebe o arquivo .pdf oficial anexado no WhatsApp em 1 segundo! ]
```

---

## 🛠️ 2. Próximos Passos para Amanhã:

### 🔹 Passo 1: Criar o Microserviço Dart (`mavis-pdf`)
- Criar a pasta do microserviço com `pubspec.yaml` (dependências: `shelf`, `shelf_router`, `pdf`, `intl`, `http`).
- Criar o servidor `bin/server.dart` expondo o endpoint `POST /generate` que recebe os dados da proposta (ou ID do Firestore) e compila o PDF usando a mesma lógica do `SolarProposalPdfService`.
- Configurar o `Dockerfile` com imagem base `dart:stable-sdk` para rodar leve no Easypanel.

### 🔹 Passo 2: Subir o Serviço no Easypanel
- Criar um novo serviço no Easypanel chamado **`mavis-pdf`**.
- Configurar porta interna `8080`.
- Como ambos os serviços estão na mesma rede Docker interna do Easypanel, a comunicação entre o `mavis-bot` e o `mavis-pdf` será instantânea via rede local (`http://mavis-pdf:8080`).

### 🔹 Passo 3: Ajustar o `mavis-bot`
- No `mavis-bot`, ao receber a solicitação de proposta:
  1. Cria os registros no Firestore (`clients`, `products`, `proposals`).
  2. Faz a chamada HTTP interna para o `mavis-pdf`.
  3. Recebe o PDF compilado ou o link do Firebase Storage.
  4. Dispara o arquivo `.pdf` via Evolution API (`/message/sendMedia`) diretamente no WhatsApp do operador.

### 🔹 Passo 4: Validação & Checklist de Testes
- [ ] Teste de emissão de proposta completa via comando de voz ou texto no WhatsApp.
- [ ] Verificação do arquivo físico gerado no bucket `gs://solardino-aea02.appspot.com/propostas_mavis/`.
- [ ] Verificação da recepção do documento `.pdf` anexado no celular.
- [ ] Verificação do card atualizado no Kanban do Mavis CRM com o link do PDF.

---

## 📂 3. Dados de Armazenamento e Credenciais

- **Bucket Firebase Storage:** `solardino-aea02.appspot.com`
- **Estrutura de Pastas:** `propostas_mavis/{companyId}/{userId}/{proposalNumber}_proposta.pdf`
- **Projeto Firebase:** `mavis-crm-80885`
- **Instância Evolution API:** `mavis-ia`
- **Chave de API Evolution:** `mavis_secret_key_2026_solar_bot`
