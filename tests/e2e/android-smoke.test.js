const axios = require('axios');
const {
  ensureAdbAvailable,
  getPrimaryDevice,
  isAppInstalled,
  clearAppData,
  launchApp,
  waitForNode,
  findNode,
  tapBounds,
  inputText,
  dumpUi,
} = require('../helpers/androidE2E');

const RUN_ANDROID_E2E = process.env.RUN_ANDROID_E2E === 'true';
const describeIfAndroidE2E = RUN_ANDROID_E2E ? describe : describe.skip;

const API_URL = process.env.API_URL || 'http://localhost:3000';
const APP_PACKAGE = process.env.ANDROID_APP_PACKAGE || 'com.guiaaventureiro.app';
const PASSWORD = 'Senha123!';

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function createTestAccount() {
  const email = `e2e-${Date.now()}-${global.randomString(6)}@example.com`;
  const name = `Automacao ${global.randomName()}`;

  const response = await axios.post(
    `${API_URL}/api/auth/signup`,
    {
      name,
      email,
      password: PASSWORD,
      acceptedTerms: true,
    },
    {
      timeout: 20000,
    }
  );

  return {
    email,
    password: PASSWORD,
    name,
    userId: response.data?.user?._id,
  };
}

function tapByCandidate(serial, xml, candidates) {
  const node = findNode(xml, candidates);
  if (!node) {
    throw new Error(`Não encontrei nenhum destes elementos: ${candidates.join(', ')}`);
  }

  tapBounds(serial, node.bounds);
}

async function dismissCoachmarkIfPresent(serial) {
  try {
    const coachmarkDismiss = waitForNode(serial, ['Entendi!'], 5000);
    tapBounds(serial, coachmarkDismiss.bounds);
    await sleep(1200);
  } catch (error) {
    // Tooltip não apareceu nesta etapa.
  }
}

function checkDeviceState(xml) {
  if (xml.includes('Development Build') || xml.includes('DEVELOPMENT SERVERS')) {
    return {
      isLauncher: true,
      message:
        'Dispositivo preso no Expo Development Launcher.\n' +
        'Use um APK de teste sem dev-client e rode: npm run e2e:run',
    };
  }

  return { isLauncher: false };
}

describeIfAndroidE2E('Android smoke regression', () => {
  let serial;
  let credentials;

  beforeAll(async () => {
    if (!ensureAdbAvailable()) {
      throw new Error('adb não está disponível neste ambiente');
    }

    serial = getPrimaryDevice();
    if (!serial) {
      throw new Error('Nenhum dispositivo Android conectado via adb');
    }

    if (!isAppInstalled(serial, APP_PACKAGE)) {
      throw new Error(`App ${APP_PACKAGE} não está instalado no dispositivo ${serial}`);
    }

    credentials = await createTestAccount();
  });

  beforeEach(async () => {
    clearAppData(serial, APP_PACKAGE);
    launchApp(serial, APP_PACKAGE);
    await sleep(4000);

    const dump = dumpUi(serial);
    const state = checkDeviceState(dump);
    if (state.isLauncher) {
      throw new Error(state.message);
    }
  });

  it('abre onboarding, faz login e alcança as áreas principais', async () => {
    // Se o onboarding aparecer, pulamos logo na primeira tela.
    try {
      const onboardingSkip = waitForNode(serial, ['Pular'], 5000);
      tapBounds(serial, onboardingSkip.bounds);
      await sleep(2000);
    } catch (error) {
      // Segue para a tela de login caso o onboarding já esteja desabilitado.
    }

    const loginEmail = waitForNode(serial, ['login-email'], 10000);
    tapBounds(serial, loginEmail.bounds);
    inputText(serial, credentials.email);

    const loginPassword = waitForNode(serial, ['login-password'], 10000);
    tapBounds(serial, loginPassword.bounds);
    inputText(serial, credentials.password);

    const loginSubmit = waitForNode(serial, ['login-submit'], 10000);
    tapBounds(serial, loginSubmit.bounds);

    await sleep(5000);

    // Em contas novas pode surgir um tooltip de onboarding no dashboard.
    await dismissCoachmarkIfPresent(serial);

    // Deve chegar ao dashboard e exibir as tabs principais.
    waitForNode(serial, ['tab-dashboard', 'Roteiros'], 20000);
    waitForNode(serial, ['dashboard-create-itinerary'], 10000);

    // Navega até a aba Criar e valida que a tela de geração carregou.
    const generateTab = waitForNode(serial, ['tab-generate', 'Criar'], 10000);
    tapBounds(serial, generateTab.bounds);

    // Também pode surgir tooltip contextual da aba Criar.
    await dismissCoachmarkIfPresent(serial);

    waitForNode(serial, ['generate-destination'], 15000);
    waitForNode(serial, ['generate-start-date-input'], 15000);

    // Retorna ao dashboard para confirmar navegação entre abas.
    const dashboardTab = waitForNode(serial, ['tab-dashboard', 'Roteiros'], 10000);
    tapBounds(serial, dashboardTab.bounds);

    waitForNode(serial, ['dashboard-search-input'], 10000);
  }, 90000);
});
