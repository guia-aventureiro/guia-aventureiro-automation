<!-- markdownlint-disable -->

# 🤖 Automação - Guia Aventureiro

Scripts e ferramentas organizadas para gerenciamento de usuários, assinaturas, banco de dados e testes.

---

## 📁 Estrutura Organizada

```
automation/
├── user-management/           # 👤 Gerenciamento de usuários e assinaturas
│   ├── check-subscription.js      # Verifica status de assinatura
│   ├── upgrade-premium-native.js  # Upgrade para Premium
│   ├── downgrade-free.js          # Downgrade para Free
│   ├── manual-upgrade.js          # Upgrade manual via CLI
│   ├── cancel-subscription.js     # Cancelar assinatura
│   ├── list-users.js              # Listar usuários do sistema
│   └── update-ai-limit.js         # Atualizar limites de IA
│
├── database/                  # 💾 Scripts de banco de dados
│   ├── database.js               # Operações e estatísticas do BD
│   └── sync-counters.js          # Sincronizar contadores
│
├── scripts/                   # 📱 Scripts auxiliares
│   ├── itineraries.js            # Gerenciamento de roteiros
│   └── user.js                   # Operações de usuário
│
├── helpers/                   # 🛠️ Módulos compartilhados
│   ├── database.js               # Conexão MongoDB
│   ├── cloudinary.js             # Operações Cloudinary
│   ├── user-operations.js        # Funções de usuário
│   └── queries.js                # Queries reutilizáveis
│
├── tests/                     # 🧪 Testes Jest (16+ suites)
│   ├── auth.test.js
│   ├── itinerary.test.js
│   ├── budget.test.js
│   ├── subscriptions.test.js
│   └── ...outros testes
│
├── screenshots/               # 📸 Screenshots do app
│
├── test-upgrade.js            # 🧪 Teste de upgrade Premium
├── test-monthly-limit.js      # 🧪 Teste de limites mensais
├── test-subscription-limits.js # 🧪 Teste completo de limites
├── test-orphan-prevention.js  # 🧪 Teste de validação de dados
├── help.js                    # ❓ Ajuda geral
└── jest.config.js             # ⚙️ Configuração Jest
```

---

## 🚀 Comandos Úteis

### 👤 Gerenciamento de Usuários

```bash
# Verificar assinatura de um usuário
node user-management/check-subscription.js

# Fazer upgrade para Premium
node user-management/upgrade-premium-native.js

# Downgrade para Free (resetar assinatura)
node user-management/downgrade-free.js

# Upgrade manual via CLI
node user-management/manual-upgrade.js

# Cancelar assinatura
node user-management/cancel-subscription.js

# Listar todos os usuários
node user-management/list-users.js

# Atualizar limites de IA
node user-management/update-ai-limit.js
```

### 💾 Banco de Dados

```bash
# Ver estatísticas e operações do banco
node database/database.js

# Sincronizar contadores
node database/sync-counters.js
```

### 📋 Scripts Auxiliares

```bash
# Gerenciar roteiros
node scripts/itineraries.js

# Operações de usuário
node scripts/user.js --email usuario@email.com
```

### 🧪 Testes de Assinatura

```bash
# Teste de upgrade
node test-upgrade.js

# Teste de limites mensais
node test-monthly-limit.js

# Teste completo de limites de assinatura
node test-subscription-limits.js

# Teste de prevenção de órfãos
node test-orphan-prevention.js
```

### 🧪 Executar Testes Jest

```bash
# Todos os testes
npm test

# Testes específicos
npm test auth
npm test itinerary
npm test subscriptions

# Com coverage
npm test -- --coverage
```

### 📱 E2E Testing (Android Device)

End-to-end regression tests run on a physical Android device via ADB.

**Prerequisites:**

- Android device connected via USB or Wi-Fi ADB
- Backend API running locally (`npm run start` in `/backend`)
- Device must not be in Expo dev-client mode (uses release APK)

**Quick Start:**

```bash
# Full workflow: build APK → install → run tests
.\scripts\run-e2e.ps1

# Or individual steps:
# 1. Build E2E APK (generates clean release without dev-client overlay)
.\scripts\build-e2e-apk.ps1 -Install

# 2. Run smoke tests (after APK is installed)
npm run e2e:android
```

**Workflow Details:**

The `run-e2e.ps1` script automates the complete testing flow:

1. **Build**: Uses `expo prebuild` to generate native Android project, then Gradle to build release APK
2. **Install**: Deploys APK to connected device (does not affect dev-client for development)
3. **Test**: Runs Jest E2E suite that exercises login → dashboard → generate flow

The generated APK is a **release build without Expo overlay**, so E2E tests can interact with actual app UI.
Development work can continue normally with the dev-client in a separate terminal.

**Individual Scripts:**

- `scripts/build-e2e-apk.ps1` - Build release APK for testing
- `scripts/run-e2e.ps1` - Complete workflow (build + install + test)
- `npm run e2e:android` - Run tests (assumes APK already installed)

**Device Connection:**

```bash
# USB connection (auto-detected)
adb devices

# Wi-Fi connection setup
adb pair <device-ip>:<port> <pair-code>
adb connect <device-ip>:<port>
adb devices
```

## 📖 Ajuda

Para ver opções detalhadas de cada script:

```bash
node help.js
```

---

## ⚙️ Configuração

Certifique-se de ter o arquivo `.env` configurado na pasta `automation/` com:

```env
MONGODB_URI=sua_connection_string
STRIPE_SECRET_KEY=sua_chave_secreta
CLOUDINARY_CLOUD_NAME=seu_cloud_name
CLOUDINARY_API_KEY=sua_api_key
CLOUDINARY_API_SECRET=seu_api_secret
```

---

## 🔧 Manutenção

Scripts organizados em pastas temáticas para facilitar manutenção e localização. Arquivos de teste obsoletos foram removidos, mantendo apenas os essenciais e funcionais.
