import {describe, expect, test} from 'bun:test';
import {createHash} from 'node:crypto';
import {existsSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

const root = resolve(import.meta.dir, '..');
const manifestPath = resolve(root, 'static/mining-compatibility.json');
const scriptPath = resolve(root, 'static/scripts/quantus-mining.sh');
const scriptChecksumPath = resolve(
  root,
  'static/scripts/quantus-mining.sh.sha256',
);
const guidePath = resolve(root, 'docs/guides/mining.md');
const appGuidePath = resolve(root, 'docs/guides/miner-app.md');
const skillPath = resolve(root, 'static/skills/mining-skill.md');
const actionButtonsPath = resolve(
  root,
  'src/components/DocActionButtons/index.tsx',
);

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as Record<
  string,
  string
>;
const script = readFileSync(scriptPath, 'utf8');
const guide = readFileSync(guidePath, 'utf8');
const appGuide = readFileSync(appGuidePath, 'utf8');
const skill = readFileSync(skillPath, 'utf8');
const actionButtons = readFileSync(actionButtonsPath, 'utf8');

const bash = existsSync('C:/Program Files/Git/bin/bash.exe')
  ? 'C:/Program Files/Git/bin/bash.exe'
  : 'bash';
const shellScriptPath = scriptPath.replaceAll('\\', '/');
const shellManifestPath = manifestPath.replaceAll('\\', '/');

// --noprofile --norc: a developer's login profile must not leak into the
// captured output (a `clear` in .bash_profile prints an escape sequence that
// would otherwise land in stdout and fail exact-match assertions).
function runBash(body: string) {
  return spawnSync(bash, ['--noprofile', '--norc', '-c', body], {
    cwd: root,
    encoding: 'utf8',
    env: {...process.env, HOME: process.env.HOME ?? process.env.USERPROFILE},
  });
}

describe('mining compatibility manifest', () => {
  test('pins one supported mainnet pair with official evidence', () => {
    expect(manifest.schemaVersion).toBe('1');
    expect(manifest.status).toBe('supported');
    expect(manifest.networkId).toBe('mainnet');
    expect(manifest.networkKind).toBe('mainnet');
    expect(manifest.tokenValue).toBe('QTC');
    expect(manifest.nodeVersion).toBe('v1.0.1');
    expect(manifest.minerVersion).toBe('v4.2.0');
    expect(manifest.minerProtocol).toBe('quantus-miner/2');
    expect(manifest.compatibilityEvidenceUrl).toBe(
      'https://github.com/Quantus-Network/quantus-miner/releases/tag/v4.2.0',
    );
  });

  test('provides official URLs and SHA-256 digests for every asset', () => {
    const urlKeys = Object.keys(manifest).filter((key) => key.endsWith('Url'));
    expect(urlKeys.length).toBeGreaterThanOrEqual(10);

    for (const urlKey of urlKeys) {
      if (urlKey === 'compatibilityEvidenceUrl') continue;
      const shaKey = urlKey.replace(/Url$/, 'Sha256');
      expect(manifest[urlKey]).toMatch(
        /^https:\/\/github\.com\/Quantus-Network\/.+\/releases\/download\//,
      );
      expect(manifest[shaKey]).toMatch(/^[0-9a-f]{64}$/);
    }
  });
});

describe('guide, skill, and installer agreement', () => {
  test('uses the manifest pair everywhere and rejects floating latest links', () => {
    for (const content of [guide, skill]) {
      expect(content).toContain(manifest.nodeVersion);
      expect(content).toContain(manifest.minerVersion);
      expect(content).toContain(manifest.minerProtocol);
      expect(content).not.toContain('/releases/latest');
      expect(content).not.toContain('v0.9.0-endless-sky');
      expect(content).not.toContain('v3.3.1');
    }

    expect(script).not.toContain('fetch_latest_tag');
    expect(script).toContain('load_compatibility_manifest');
    expect(script).toContain('verify_sha256');
    expect(actionButtons).toContain("useBaseUrl('/mining-compatibility.json')");
    expect(actionButtons).toContain('compatibility.trim()');
  });

  test('keeps the visible command and AI workflow aligned', () => {
    for (const content of [guide, skill, script]) {
      expect(content).toContain('quantus-mining.sh mine');
      expect(content).toContain('quantus-mining.sh status');
      expect(content).toContain('restart-check');
    }
    expect(guide).toContain('quantus-mining.sh.sha256');
    expect(skill).toContain('Never use a pipe-to-shell command');
    expect(guide).not.toMatch(/curl[^\n|]*\|\s*(ba)?sh/);
  });

  test('publishes direct desktop assets while preserving preview limits', () => {
    expect(appGuide).not.toContain('draft: true');
    expect(appGuide).toContain('not the verified beginner path');
    expect(appGuide).toContain(manifest.desktopAppWindowsUrl);
    expect(appGuide).toContain(manifest.desktopAppMacosUrl);
    expect(appGuide).toContain(manifest.desktopAppLinuxUrl);
    expect(appGuide).toContain(manifest.desktopAppWindowsSha256);
    expect(appGuide).toContain(manifest.desktopAppMacosSha256);
    expect(appGuide).toContain(manifest.desktopAppLinuxSha256);
    expect(appGuide).toContain('Get-FileHash');
    expect(appGuide).toContain('shasum -a 256');
    expect(appGuide).toContain('sha256sum');
  });

  test('does not add forbidden launch claims or em dashes', () => {
    for (const content of [guide, appGuide, skill, script]) {
      expect(content).not.toContain('\u2014');
      expect(content).not.toMatch(/September 9|Sep(?:tember)?\.? 9/i);
    }
  });
});

describe('installer safety helpers', () => {
  test('passes shell syntax validation', () => {
    const result = runBash(`bash -n '${shellScriptPath}'`);
    expect(result.stderr).toBe('');
    expect(result.status).toBe(0);
  });

  test('maps supported platforms without a version choice', () => {
    const mac = runBash(
      `source '${shellScriptPath}'; uname() { if [ "\${1:-}" = "-s" ]; then echo Darwin; else echo arm64; fi; }; detect_platform; printf '%s' "$PLATFORM_KEY|$NODE_TARGET|$MINER_ASSET"`,
    );
    expect(mac.status).toBe(0);
    expect(mac.stdout).toBe(
      'DarwinArm64|aarch64-apple-darwin|quantus-miner-macos-aarch64',
    );

    const linux = runBash(
      `source '${shellScriptPath}'; uname() { if [ "\${1:-}" = "-s" ]; then echo Linux; else echo x86_64; fi; }; detect_platform; printf '%s' "$PLATFORM_KEY|$NODE_TARGET|$MINER_ASSET"`,
    );
    expect(linux.status).toBe(0);
    expect(linux.stdout).toBe(
      'LinuxX8664|x86_64-unknown-linux-gnu|quantus-miner-linux-x86_64',
    );
  });

  test('loads the pinned pair for the detected platform', () => {
    const result = runBash(
      `source '${shellScriptPath}'; PLATFORM_KEY=DarwinArm64; NODE_TARGET=aarch64-apple-darwin; MINER_ASSET=quantus-miner-macos-aarch64; load_compatibility_manifest '${shellManifestPath}'; printf '%s' "$CHAIN|$NODE_VERSION|$MINER_VERSION|$MINER_PROTOCOL"`,
    );
    expect(result.status).toBe(0);
    expect(result.stdout).toBe('mainnet|v1.0.1|v4.2.0|quantus-miner/2');
  });

  test('fails closed on a checksum mismatch', () => {
    const good = runBash(
      `source '${shellScriptPath}'; f=$(mktemp); printf hello > "$f"; verify_sha256 "$f" 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824`,
    );
    expect(good.status).toBe(0);
    expect(good.stdout).toContain('Verified SHA-256');

    const bad = runBash(
      `source '${shellScriptPath}'; f=$(mktemp); printf hello > "$f"; verify_sha256 "$f" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`,
    );
    expect(bad.status).not.toBe(0);
    expect(bad.stderr).toContain('Checksum verification failed');
    expect(bad.stderr).toContain('The file was not installed');
  });

  test('redacts secret-like log values', () => {
    const hex = 'a'.repeat(64);
    const result = runBash(
      `source '${shellScriptPath}'; printf '%s\\n' 'inner hash: 0x${hex} auth token=token123 mnemonic: alpha' | redact_sensitive_stream`,
    );
    expect(result.status).toBe(0);
    expect(result.stdout).toContain('[redacted]');
    expect(result.stdout).not.toContain(hex);
    expect(result.stdout).not.toContain('token123');
    expect(result.stdout).not.toContain('alpha');
  });

  test('keeps recovery material out of the public config', () => {
    const configBody = script.match(
      /cat > "\$CONFIG_FILE" <<EOF([\s\S]*?)\nEOF/,
    )?.[1];
    expect(configBody).toBeDefined();
    expect(configBody).not.toContain('INNER_HASH=');
    expect(script).not.toMatch(/echo\s+"?\$mnemonic/);
    expect(script).not.toContain('eval ');
  });

  test('publishes the checksum for the exact installer bytes', () => {
    const checksumLine = readFileSync(scriptChecksumPath, 'utf8').trim();
    const expected = createHash('sha256').update(script).digest('hex');
    expect(checksumLine).toBe(`${expected}  quantus-mining.sh`);
  });
});

const ps1Path = resolve(root, 'static/scripts/quantus-mining.ps1');
const ps1ChecksumPath = resolve(root, 'static/scripts/quantus-mining.ps1.sha256');
const ps1 = readFileSync(ps1Path, 'utf8');

// Windows PowerShell 5.1 ships with Windows; pwsh is the cross-platform build.
// The behaviour tests run on whichever exists and are skipped where neither
// does, so a Linux CI runner without pwsh still passes the static checks.
const powershell = ['pwsh', 'powershell'].find((exe) => {
  const probe = spawnSync(exe, ['-NoProfile', '-Command', '$PSVersionTable.PSVersion.Major'], {encoding: 'utf8'});
  return probe.status === 0;
});

function runPowerShell(body: string) {
  return spawnSync(powershell as string, ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', body], {
    cwd: root,
    encoding: 'utf8',
  });
}

describe('windows installer', () => {
  test('mirrors the shell installer contract', () => {
    for (const needle of ['mine', 'status', 'restart-check', 'setup', 'stop', 'uninstall']) {
      expect(ps1).toMatch(new RegExp(`'${needle}'\\s*\\{`));
    }
    expect(ps1).toContain('Import-CompatibilityManifest');
    expect(ps1).toContain('Assert-Sha256');
    expect(ps1).toContain('quantus-miner/2');
    expect(ps1).toContain("node$($script:PlatformKey)Url");
    expect(ps1).toContain("miner$($script:PlatformKey)Url");
    expect(ps1).not.toContain('/releases/latest');
    expect(ps1).not.toContain('Invoke-Expression');
    expect(ps1).not.toMatch(/\biex\b/);
    expect(ps1).not.toContain('—');
    expect(ps1).not.toMatch(/September 9|Sep(?:tember)?\.? 9/i);
  });

  test('uses the Windows assets the manifest publishes', () => {
    expect(manifest.nodeWindowsX8664Url).toMatch(/quantus-node-v1\.0\.1-x86_64-pc-windows-msvc\.zip$/);
    expect(manifest.minerWindowsX8664Url).toMatch(/quantus-miner-windows-x86_64\.exe$/);
    expect(ps1).toContain("'x86_64-pc-windows-msvc'");
    expect(ps1).toContain("'quantus-miner-windows-x86_64.exe'");
  });

  test('keeps the recovery phrase off the command line and out of the config', () => {
    expect(ps1).toContain('Read-Host -Prompt \'Recovery phrase\' -AsSecureString');
    expect(ps1).toMatch(/\$phrase \| & \$script:NodeBin key quantus --scheme wormhole --words/);
    const configBody = ps1.match(/\$lines = @\(([\s\S]*?)\n\s*\)/)?.[1];
    expect(configBody).toBeDefined();
    expect(configBody).not.toContain('INNER_HASH');
    expect(configBody).not.toContain('_innerHash');
  });

  test('guide and skill point Windows users at the PowerShell installer', () => {
    for (const content of [guide, skill]) {
      expect(content).toContain('quantus-mining.ps1 mine');
      expect(content).not.toContain('Add-MpPreference');
      expect(content).toContain('Do not disable antivirus protection');
    }
    expect(guide).toContain('quantus-mining.ps1.sha256');
    expect(guide).toContain('Unblock-File');
    expect(ps1).not.toContain('Add-MpPreference');
    expect(guide).not.toMatch(/Invoke-WebRequest[^\n]*\|\s*(iex|Invoke-Expression)/i);
  });

  test('publishes the checksum for the exact installer bytes', () => {
    const checksumLine = readFileSync(ps1ChecksumPath, 'utf8').trim();
    const expected = createHash('sha256').update(ps1).digest('hex');
    expect(checksumLine).toBe(`${expected}  quantus-mining.ps1`);
  });

  test.skipIf(!powershell)('parses without errors', () => {
    const result = runPowerShell(
      `$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile('${ps1Path.replaceAll('\\', '\\\\')}',[ref]$t,[ref]$e)|Out-Null;$e.Count`,
    );
    expect(result.status).toBe(0);
    expect(result.stdout.trim()).toBe('0');
  });

  test.skipIf(!powershell)('checks setup storage before downloads or wallet entry', () => {
    const load = `. '${ps1Path.replaceAll('\\', '\\\\')}'; `;
    const low = runPowerShell(load + 'function Get-AvailableStorageBytes { 99999999999L }; Test-SetupStorage');
    expect(low.status).not.toBe(0);
    expect(low.stderr).toContain('100 GB required');
    const enough = runPowerShell(load + 'function Get-AvailableStorageBytes { 100000000000L }; Test-SetupStorage');
    expect(enough.status).toBe(0);
    expect(enough.stdout).toContain('at least 100 GB');
    const setup = ps1.slice(ps1.indexOf('function Invoke-Setup'), ps1.indexOf('function Invoke-Config'));
    expect(setup.indexOf('Test-SetupStorage')).toBeLessThan(setup.indexOf('Ensure-Dirs'));
    expect(setup.indexOf('Test-SetupStorage')).toBeLessThan(setup.indexOf('Install-Binaries'));
    expect(setup.indexOf('Test-SetupStorage')).toBeLessThan(setup.indexOf('New-WormholeKeys'));
  }, 10_000);

  test.skipIf(!powershell)('loads the pinned pair, classifies protocols, fails closed, and redacts', () => {
    const load = `. '${ps1Path.replaceAll('\\', '\\\\')}'; `;
    const pair = runPowerShell(
      load + `$m = Import-CompatibilityManifest '${manifestPath.replaceAll('\\', '\\\\')}'; "$($m['_chain'])|$($m['_nodeVersion'])|$($m['_minerVersion'])|$($m['_minerProtocol'])"`,
    );
    expect(pair.status).toBe(0);
    expect(pair.stdout.trim()).toBe('mainnet|v1.0.1|v4.2.0|quantus-miner/2');

    const protocol = runPowerShell(
      load + `(Get-MinerProtocol 'x --miner-auth-token-file' 'y --auth-token-file --tls-cert-sha256-file') + '|' + (Get-MinerProtocol 'a' 'b')`,
    );
    expect(protocol.stdout.trim()).toBe('auth|legacy');

    const mixed = runPowerShell(load + `Get-MinerProtocol 'x --miner-auth-token-file' 'plain miner'`);
    expect(mixed.status).not.toBe(0);
    expect(mixed.stderr).toContain('Incompatible node/miner pair');

    const bad = runPowerShell(
      load + `$f = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($f, 'hello'); Assert-Sha256 $f ('a' * 64)`,
    );
    expect(bad.status).not.toBe(0);
    expect(bad.stderr).toContain('Checksum verification failed');
    expect(bad.stderr).toContain('The file was not installed');

    const hex = 'a'.repeat(64);
    const redact = runPowerShell(load + `Hide-Secrets 'inner hash: 0x${hex} auth token=token123 mnemonic: alpha'`);
    expect(redact.stdout).toContain('[redacted]');
    expect(redact.stdout).not.toContain(hex);
    expect(redact.stdout).not.toContain('token123');
    expect(redact.stdout).not.toContain('alpha');
  }, 20_000); // Five PowerShell startups can exceed Bun's default five seconds.
});

describe('mainnet repin', () => {
  test('never pairs a platform whose node release does not exist', () => {
    // node v1.0.1 publishes no x86_64-apple-darwin build.
    expect(manifest.nodeDarwinX8664Url).toBeUndefined();
    expect(manifest.minerDarwinX8664Url).toBeUndefined();
    const intelMac = runBash(
      `source '${shellScriptPath}'; PLATFORM_KEY=DarwinX8664; NODE_TARGET=x86_64-apple-darwin; MINER_ASSET=quantus-miner-macos-x86_64; OS=macos; ARCH=x86_64; load_compatibility_manifest '${shellManifestPath}'`,
    );
    expect(intelMac.status).not.toBe(0);
    expect(intelMac.stderr).toContain('has no build for macos/x86_64');
  });

  test('refuses a manifest for any other network', () => {
    const planck = runBash(
      `source '${shellScriptPath}'; PLATFORM_KEY=LinuxX8664; NODE_TARGET=x86_64-unknown-linux-gnu; MINER_ASSET=quantus-miner-linux-x86_64; f=$(mktemp); sed 's/"networkId": "mainnet"/"networkId": "planck"/' '${shellManifestPath}' > "$f"; load_compatibility_manifest "$f"`,
    );
    expect(planck.status).not.toBe(0);
    expect(planck.stderr).toContain('restricted to Quantus mainnet');
  });

  test('setup --force keeps the existing reward identity', () => {
    const result = spawnSync(bash, ['--noprofile', '--norc', resolve(root, 'scripts/test-quantus-mining.sh').replaceAll('\\', '/')], {
      cwd: root,
      encoding: 'utf8',
    });
    expect(result.stderr).toBe('');
    expect(result.stdout).toContain('ok: setup --force preserves existing reward identity');
    expect(result.status).toBe(0);
  });

  test('docs, skill and agent prompt describe mainnet, not the retired testnet', () => {
    const prompt = readFileSync(resolve(root, 'static/agent-setup/prompt.md'), 'utf8');
    for (const content of [guide, skill, prompt]) {
      expect(content).toMatch(/mainnet/i);
      expect(content).not.toMatch(/tokens have no monetary value/i);
    }
    expect(guide).toContain('## Coming from Planck');
    expect(guide).toContain('--force-authoring');
    expect(script).not.toContain('CHAIN:-planck');
    expect(ps1).not.toMatch(/'CHAIN', 'planck'/);
  });
});

describe('node name and sync truth', () => {
  test('shell refuses config values that would run code when the config is sourced', () => {
    const probe = (key: string, value: string) =>
      runBash(`source '${shellScriptPath}'; valid_config_value '${key}' '${value}' && echo ok || echo no`).stdout.trim();
    expect(probe('NODE_NAME', 'lee-quan-yew')).toBe('ok');
    expect(probe('NODE_NAME', '$(touch pwned)')).toBe('no');
    expect(probe('NODE_NAME', 'Has Space')).toBe('no');
    expect(probe('NODE_NAME', '-leading')).toBe('no');
    expect(probe('NODE_NAME', 'ab')).toBe('no');
    expect(probe('CPU_WORKERS', '4')).toBe('ok');
    expect(probe('CPU_WORKERS', '1; id')).toBe('no');
    expect(probe('MINER_LISTEN_PORT', '9833')).toBe('ok');
    expect(probe('MINER_LISTEN_PORT', '80')).toBe('no');
  });

  test('shell takes the default name without blocking when there is no terminal', () => {
    const r = runBash(`source '${shellScriptPath}'; hostname() { echo 'My_Laptop!'; }; choose_node_name </dev/null; printf '%s' "$NODE_NAME"`);
    expect(r.status).toBe(0);
    expect(r.stdout).toBe('quantus-mylaptop');
    const env = runBash(`source '${shellScriptPath}'; QUANTUS_NODE_NAME=lee-quan-yew choose_node_name </dev/null; printf '%s' "$NODE_NAME"`);
    expect(env.stdout).toBe('lee-quan-yew');
  });

  test('both installers ask for the public name and check block height before saying Synced', () => {
    expect(script).toContain('choose_node_name');
    expect(script).toContain('system_syncState');
    expect(ps1).toContain('Select-NodeName');
    expect(ps1).toMatch(/\$behind = /);
    expect(guide).toContain('shown publicly');
  });

  test.skipIf(!powershell)('PowerShell validates names and values the same way', () => {
    const load = `. '${ps1Path.replaceAll('\\', '\\\\')}'; `;
    const r = runPowerShell(
      load + `@((Test-NodeName 'lee-quan-yew'), (Test-NodeName 'Bad Name'), (Test-NodeName '-x-'), (Test-ConfigValue 'CPU_WORKERS' '1; id'), (Test-ConfigValue 'MINER_LISTEN_PORT' '9833')) -join ','`,
    );
    expect(r.stdout.trim()).toBe('True,False,False,False,True');
  });
});

describe('plain hash rate, remembered location, autostart', () => {
  test('shell averages recent searches into one plain rate and flags a stale miner', () => {
    const iso = (msAgo: number) => new Date(Date.now() - msAgo).toISOString().replace(/\.\d+Z$/, 'Z');
    const line = (ts: string, hashes: number, secs: number) =>
      `[${ts} INFO  miner_service] GPU worker 0 interrupted by new block: ${hashes} hashes in ${secs}s (x MH/s)`;
    // 300M in 10s and 60M in 2s: 360M / 12s = 30.0 MH/s, not the 30/30 of either line alone.
    const recent = [line(iso(60_000), 300000000, 10), line(iso(30_000), 60000000, 2)].join('\n');
    const fresh = runBash(`source '${shellScriptPath}'; f=$(mktemp); printf '%s\n' '${recent.replaceAll("'", "")}' > "$f"; hash_rate_summary "$f"; printf '%s|%s' "$HASH_RATE_TEXT" "$HASH_RATE_FRESH"`);
    expect(fresh.stdout).toBe('30.0 MH/s|true');
    const old = line(iso(20 * 60_000), 300000000, 10);
    const stale = runBash(`source '${shellScriptPath}'; f=$(mktemp); printf '%s\n' '${old}' > "$f"; hash_rate_summary "$f"; printf '%s|%s' "$HASH_RATE_TEXT" "$HASH_RATE_FRESH"`);
    expect(stale.stdout).toBe('no hashes in the last 3 min, miner is not working now|false');
  });

  test('shell remembers the install location and ignores unsafe entries', () => {
    const r = runBash(
      `d=$(mktemp -d); export XDG_CONFIG_HOME="$d/cfg"; mkdir -p "$d/cfg/quantus-mining" "$d/mine"; ` +
      `printf 'MINING_DIR=%s\nNODE_DATA_PATH=/data/$(id)\n' "$d/mine" > "$d/cfg/quantus-mining/location"; ` +
      `unset QUANTUS_MINING_DIR QUANTUS_NODE_DATA_PATH; source '${shellScriptPath}'; printf '%s|%s' "$MINING_DIR" "\${QUANTUS_NODE_DATA_PATH:-unset}" | sed "s#$d#D#g"`,
    );
    expect(r.status).toBe(0);
    expect(r.stdout).toBe('D/mine|unset');
  });

  test.skipIf(!powershell)('PowerShell averages recent searches and flags a stale miner', () => {
    const load = `. '${ps1Path.replaceAll('\\', '\\\\')}'; `;
    const r = runPowerShell(
      load +
      `$f=[IO.Path]::GetTempFileName(); $u=(Get-Date).ToUniversalTime(); ` +
      `function L($ago,$h,$s){ '[' + $u.AddSeconds(-$ago).ToString('yyyy-MM-ddTHH:mm:ss') + 'Z INFO  miner_service] GPU worker 0 interrupted by new block: ' + $h + ' hashes in ' + $s + 's (x MH/s)' } ` +
      `Set-Content $f @((L 60 300000000 10), (L 30 60000000 2)); $a = Get-HashRateSummary $f; ` +
      `Set-Content $f (L 1200 300000000 10); $b = Get-HashRateSummary $f; ` +
      `"$($a.Text)|$($a.Fresh)|$($b.Fresh)|$($b.Text -like '*not working now')"`,
    );
    expect(r.stdout.trim()).toBe('30.0 MH/s|True|False|True');
  });

  test.skipIf(!powershell)('PowerShell autostart writes and removes one per-user entry', () => {
    const key = 'HKCU:\\Software\\QuantusMiningTest' + Date.now();
    const load = `$env:QUANTUS_AUTOSTART_KEY='${key}'; $env:QUANTUS_MINING_DIR=[IO.Path]::Combine([IO.Path]::GetTempPath(), 'qm-autostart-' + [guid]::NewGuid()); New-Item -ItemType Directory -Force (Join-Path $env:QUANTUS_MINING_DIR 'logs') | Out-Null; Set-Content (Join-Path $env:QUANTUS_MINING_DIR 'mining.conf') 'NODE_NAME=x'; . '${ps1Path.replaceAll('\\', '\\\\')}'; `;
    const r = runPowerShell(
      load +
      `Invoke-Autostart @('on') | Out-Null; $v = Get-AutostartValue; Invoke-Autostart @('off') | Out-Null; $gone = -not (Get-AutostartValue); Remove-Item -LiteralPath '${key}' -Recurse -Force -ErrorAction SilentlyContinue; ` +
      `"$($v -like '*-WindowStyle Hidden*')|$($v -like '*quantus-mining.ps1*start*')|$gone"`,
    );
    expect(r.stdout.trim()).toBe('True|True|True');
  });

  test('guide documents autostart and not needing to repeat the install path', () => {
    expect(ps1).toContain("'autostart' { Invoke-Autostart");
    expect(guide).toContain('autostart');
  });
});

