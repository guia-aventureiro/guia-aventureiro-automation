const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function resolveAdbPath() {
  const candidates = [
    process.env.ANDROID_ADB_PATH,
    process.env.ANDROID_HOME && path.join(process.env.ANDROID_HOME, 'platform-tools', 'adb.exe'),
    process.env.ANDROID_SDK_ROOT &&
      path.join(process.env.ANDROID_SDK_ROOT, 'platform-tools', 'adb.exe'),
    'C:\\Users\\conta\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe',
  ].filter(Boolean);

  const adbPath = candidates.find((candidate) => fs.existsSync(candidate));
  if (!adbPath) {
    throw new Error(
      'Não foi possível localizar o adb.exe. Defina ANDROID_ADB_PATH ou ANDROID_HOME.'
    );
  }

  return adbPath;
}

function runAdb(args, options = {}) {
  const serial = options.serial || process.env.ADB_SERIAL;
  const timeout = options.timeout || 20000;
  const adbArgs = serial ? ['-s', serial, ...args] : args;
  const adbPath = resolveAdbPath();

  return execFileSync(adbPath, adbArgs, {
    encoding: 'utf8',
    timeout,
    maxBuffer: 1024 * 1024 * 10,
  }).trim();
}

function ensureAdbAvailable() {
  try {
    runAdb(['version']);
    return true;
  } catch (error) {
    return false;
  }
}

function getConnectedDevices() {
  try {
    const output = runAdb(['devices']);
    return output
      .split('\n')
      .slice(1)
      .map((line) => line.trim().split(/\s+/))
      .filter(([serial, status]) => serial && status === 'device')
      .map(([serial]) => serial);
  } catch (error) {
    return [];
  }
}

function getPrimaryDevice() {
  if (process.env.ADB_SERIAL) {
    return process.env.ADB_SERIAL;
  }

  const devices = getConnectedDevices();
  return devices[0] || null;
}

function isAppInstalled(serial, packageName) {
  try {
    const output = runAdb(['shell', 'pm', 'list', 'packages', packageName], { serial });
    return output.includes(packageName);
  } catch (error) {
    return false;
  }
}

function clearAppData(serial, packageName) {
  return runAdb(['shell', 'pm', 'clear', packageName], { serial, timeout: 30000 });
}

function launchApp(serial, packageName) {
  return runAdb(
    ['shell', 'monkey', '-p', packageName, '-c', 'android.intent.category.LAUNCHER', '1'],
    { serial, timeout: 30000 }
  );
}

function dumpUi(serial) {
  runAdb(['shell', 'uiautomator', 'dump', '/sdcard/window_dump.xml'], { serial, timeout: 30000 });
  return runAdb(['exec-out', 'cat', '/sdcard/window_dump.xml'], { serial, timeout: 30000 });
}

function parseNodes(xml) {
  const nodes = [];
  const nodeRegex = /<node\s+([^>]*?)\s*\/?>/g;
  let match;

  while ((match = nodeRegex.exec(xml)) !== null) {
    const attrs = {};
    const attrRegex = /([\w-]+)="([^"]*)"/g;
    let attrMatch;

    while ((attrMatch = attrRegex.exec(match[1])) !== null) {
      attrs[attrMatch[1]] = attrMatch[2];
    }

    nodes.push(attrs);
  }

  return nodes;
}

function findNode(xml, matcher) {
  const nodes = parseNodes(xml);
  const candidates = Array.isArray(matcher) ? matcher : [matcher];

  return nodes.find((node) => {
    return candidates.some((candidate) => {
      if (!candidate) return false;
      return (
        node.text === candidate ||
        node['content-desc'] === candidate ||
        node['resource-id'] === candidate
      );
    });
  });
}

function getCenter(bounds) {
  if (!bounds) return null;
  const match = bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
  if (!match) return null;

  const left = Number(match[1]);
  const top = Number(match[2]);
  const right = Number(match[3]);
  const bottom = Number(match[4]);

  return {
    x: Math.round((left + right) / 2),
    y: Math.round((top + bottom) / 2),
  };
}

function tapBounds(serial, bounds) {
  const center = getCenter(bounds);
  if (!center) {
    throw new Error(`Não foi possível calcular o centro do bounds: ${bounds}`);
  }

  return runAdb(['shell', 'input', 'tap', String(center.x), String(center.y)], {
    serial,
    timeout: 15000,
  });
}

function inputText(serial, text) {
  return runAdb(['shell', 'input', 'text', text], { serial, timeout: 15000 });
}

function waitForNode(serial, matcher, timeoutMs = 15000, intervalMs = 1000) {
  const startedAt = Date.now();
  let lastXml = '';

  while (Date.now() - startedAt < timeoutMs) {
    try {
      lastXml = dumpUi(serial);
      const node = findNode(lastXml, matcher);
      if (node) return node;
    } catch (error) {
      // Ignora falhas transitórias ao dumpar a UI e tenta novamente.
    }

    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, intervalMs);
  }

  throw new Error(
    `Elemento não encontrado após ${timeoutMs}ms: ${JSON.stringify(matcher)}\n\nÚltimo XML:\n${lastXml}`
  );
}

module.exports = {
  runAdb,
  ensureAdbAvailable,
  getConnectedDevices,
  getPrimaryDevice,
  isAppInstalled,
  clearAppData,
  launchApp,
  dumpUi,
  findNode,
  waitForNode,
  tapBounds,
  inputText,
};
