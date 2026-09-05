#Requires -Version 5.1
<#
quantus-mining.ps1 - Set up and manage verified Quantus Planck testnet mining on Windows.

Native Windows twin of quantus-mining.sh. Same commands, same compatibility
manifest, same checksums, same hidden recovery-phrase prompt, same status
contract. Requires Windows 10/11 x64 and PowerShell 5.1 or later. No WSL.

Default working directory: $HOME\quantus-mining\
Config file: $HOME\quantus-mining\mining.conf (owner-only)

Usage:
  .\quantus-mining.ps1 mine
  .\quantus-mining.ps1 setup [-Force]
  .\quantus-mining.ps1 config show|set KEY VALUE
  .\quantus-mining.ps1 start
  .\quantus-mining.ps1 stop|restart
  .\quantus-mining.ps1 status|restart-check
  .\quantus-mining.ps1 uninstall [-Force]
  .\quantus-mining.ps1 help

If PowerShell refuses to run the file, it was downloaded with a web mark. Run:
  Unblock-File .\quantus-mining.ps1
or start it as:
  powershell -ExecutionPolicy Bypass -File .\quantus-mining.ps1 mine

Override directory: $env:QUANTUS_MINING_DIR = 'D:\path'; .\quantus-mining.ps1 ...
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Command = 'help',
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @(),
  [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths and constants
# ---------------------------------------------------------------------------

$script:ScriptName = 'quantus-mining.ps1'
$script:MiningDir = if ($env:QUANTUS_MINING_DIR) { $env:QUANTUS_MINING_DIR } else { Join-Path $HOME 'quantus-mining' }
$script:ConfigFile = Join-Path $script:MiningDir 'mining.conf'
$script:BinDir = Join-Path $script:MiningDir 'bin'
$script:LogDir = Join-Path $script:MiningDir 'logs'
$script:NodeBin = Join-Path $script:BinDir 'quantus-node.exe'
$script:MinerBin = Join-Path $script:BinDir 'quantus-miner.exe'
$script:NodePidFile = Join-Path $script:MiningDir 'node.pid'
$script:MinerPidFile = Join-Path $script:MiningDir 'miner.pid'
$script:NodeKeyPath = Join-Path $script:MiningDir 'node_key.p2p'
$script:InnerHashFile = Join-Path $script:MiningDir 'rewards-inner-hash'
$script:CompatibilityFile = Join-Path $script:MiningDir 'mining-compatibility.json'
$script:CompatibilityUrl = if ($env:QUANTUS_COMPATIBILITY_URL) { $env:QUANTUS_COMPATIBILITY_URL } else { 'https://docs.quantus.com/mining-compatibility.json' }

$script:ChainRepo = 'Quantus-Network/chain'
$script:MinerRepo = 'Quantus-Network/quantus-miner'
$script:EditableKeys = @('NODE_NAME', 'CPU_WORKERS', 'GPU_DEVICES', 'MINER_LISTEN_PORT')

# Only x64 Windows has published release assets. ARM64 Windows can run the
# x64 binaries under emulation, and the miner would still not see the GPU
# natively, so it is refused rather than half-supported.
$script:PlatformKey = 'WindowsX8664'
$script:NodeTarget = 'x86_64-pc-windows-msvc'
$script:MinerAsset = 'quantus-miner-windows-x86_64.exe'

$script:Manifest = @{}
$script:Config = @{}
# 'auth' or 'legacy', decided by probing both binaries' --help. Declared here so
# strict mode never sees it unset; every path that reads it runs the probe first.
$script:MinerProtocol = ''

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Fail([string]$Message) {
  [Console]::Error.WriteLine("Error: $Message")
  exit 1
}

function Info([string]$Message) { Write-Output $Message }

function Warn([string]$Message) { [Console]::Error.WriteLine("Warning: $Message") }

function Test-Platform {
  if (-not [Environment]::Is64BitOperatingSystem) {
    Fail 'Unsupported platform: 32-bit Windows. Use a 64-bit Windows 10/11 machine.'
  }
  $arch = $env:PROCESSOR_ARCHITECTURE
  if ($arch -ne 'AMD64') {
    Fail "Unsupported architecture: $arch. Quantus publishes Windows binaries for x64 only."
  }
}

function Ensure-Dirs {
  foreach ($d in @($script:MiningDir, $script:BinDir, $script:LogDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null }
  }
}

# Owner-only file, the Windows equivalent of chmod 600. Inheritance is
# removed first so the parent folder's Users entry does not leak through.
function Protect-File([string]$Path) {
  $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  & icacls $Path /inheritance:r /grant:r "${me}:(F)" | Out-Null
}

function Get-CpuCount {
  try { return [int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors } catch { return 4 }
}

function Get-DiscreteGpuPresent {
  # The miner skips integrated adapters by default when a discrete one exists,
  # so this only decides the default of GPU_DEVICES, not which device is used.
  try {
    $names = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join ' '
    return ($names -match 'NVIDIA|GeForce|Quadro|RTX|GTX|Radeon RX|Radeon Pro|Arc')
  } catch { return $false }
}

function Get-FileSha256([string]$Path) {
  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-Sha256([string]$Path, [string]$Expected) {
  $name = Split-Path $Path -Leaf
  if (-not $Expected -or $Expected -notmatch '^[0-9a-f]{64}$') {
    Fail "Invalid SHA-256 value for $name. No files were installed."
  }
  $actual = Get-FileSha256 $Path
  if ($actual -ne $Expected) {
    Remove-Item $Path -Force -ErrorAction SilentlyContinue
    Fail ("Checksum verification failed for {0}.`nExpected: {1}`nActual:   {2}`nThe file was not installed. Delete the download and retry." -f $name, $Expected, $actual)
  }
  Info "Verified SHA-256: $name"
}

function Assert-ReleaseUrl([string]$Url, [string]$Repo, [string]$Version) {
  $prefix = "https://github.com/$Repo/releases/download/$Version/"
  if (-not $Url.StartsWith($prefix)) {
    Fail "Compatibility manifest contains an unexpected download URL for $Repo. No files were installed."
  }
}

function Invoke-Download([string]$Url, [string]$OutFile) {
  # TLS 1.2 is not the default on older PowerShell 5.1 hosts.
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  try {
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
  } catch {
    Fail "Failed to download $Url. Check your connection and retry."
  }
}

# ---------------------------------------------------------------------------
# Compatibility manifest
# ---------------------------------------------------------------------------

function Read-ManifestString([hashtable]$Manifest, [string]$Key) {
  if (-not $Manifest.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace([string]$Manifest[$Key])) {
    Fail "Compatibility manifest is missing $Key. No files were installed."
  }
  return [string]$Manifest[$Key]
}

function Import-CompatibilityManifest([string]$Path) {
  if (-not (Test-Path $Path) -or (Get-Item $Path).Length -eq 0) {
    Fail "Compatibility manifest not found at $Path. Run: $script:ScriptName setup -Force"
  }
  $raw = Get-Content $Path -Raw
  try { $json = $raw | ConvertFrom-Json } catch { Fail 'Compatibility manifest is not valid JSON. No files were installed.' }
  $m = @{}
  foreach ($p in $json.PSObject.Properties) { $m[$p.Name] = [string]$p.Value }

  $status = Read-ManifestString $m 'status'
  if ($status -ne 'supported') {
    Fail "Mining compatibility status is '$status', not 'supported'. Nothing will be installed or started."
  }
  $m['_chain'] = Read-ManifestString $m 'networkId'
  $kind = Read-ManifestString $m 'networkKind'
  $token = Read-ManifestString $m 'tokenValue'
  $m['_nodeVersion'] = Read-ManifestString $m 'nodeVersion'
  $m['_minerVersion'] = Read-ManifestString $m 'minerVersion'
  $m['_minerProtocol'] = Read-ManifestString $m 'minerProtocol'
  $evidence = Read-ManifestString $m 'compatibilityEvidenceUrl'

  if ($m['_chain'] -ne 'planck' -or $kind -ne 'testnet' -or $token -ne 'none') {
    Fail 'This installer is restricted to the Planck testnet. The manifest requested a different network.'
  }
  if ($m['_minerProtocol'] -ne 'quantus-miner/2') {
    Fail "Unsupported miner protocol '$($m['_minerProtocol'])'. Nothing will be installed or started."
  }
  if (-not $evidence.StartsWith('https://github.com/Quantus-Network/quantus-miner/releases/tag/')) {
    Fail 'Compatibility evidence URL is not an official Quantus miner release.'
  }

  $m['_nodeUrl'] = Read-ManifestString $m "node$($script:PlatformKey)Url"
  $m['_nodeSha'] = Read-ManifestString $m "node$($script:PlatformKey)Sha256"
  $m['_minerUrl'] = Read-ManifestString $m "miner$($script:PlatformKey)Url"
  $m['_minerSha'] = Read-ManifestString $m "miner$($script:PlatformKey)Sha256"

  Assert-ReleaseUrl $m['_nodeUrl'] $script:ChainRepo $m['_nodeVersion']
  Assert-ReleaseUrl $m['_minerUrl'] $script:MinerRepo $m['_minerVersion']
  $expectedNodeAsset = "quantus-node-$($m['_nodeVersion'])-$($script:NodeTarget).zip"
  if ((Split-Path $m['_nodeUrl'] -Leaf) -ne $expectedNodeAsset) {
    Fail 'Node asset does not match windows/x64. No files were installed.'
  }
  if ((Split-Path $m['_minerUrl'] -Leaf) -ne $script:MinerAsset) {
    Fail 'Miner asset does not match windows/x64. No files were installed.'
  }
  $script:Manifest = $m
  return $m
}

function Get-CompatibilityManifest {
  $temp = "$($script:CompatibilityFile).download"
  Info 'Fetching the supported Planck release pair...'
  Invoke-Download $script:CompatibilityUrl $temp
  Import-CompatibilityManifest $temp | Out-Null
  Move-Item $temp $script:CompatibilityFile -Force
  Protect-File $script:CompatibilityFile
  Info "Supported pair: node $($script:Manifest['_nodeVersion']) + miner $($script:Manifest['_minerVersion']) ($($script:Manifest['_minerProtocol']))"
}

# ---------------------------------------------------------------------------
# Pair protocol probe. Same test the shell installer runs.
# ---------------------------------------------------------------------------

function Get-MinerProtocol([string]$NodeHelp, [string]$MinerHelp) {
  $nodeAuth = $NodeHelp.Contains('miner-auth-token-file')
  $minerAuth = $MinerHelp.Contains('auth-token-file') -and $MinerHelp.Contains('tls-cert-sha256-file')
  if ($nodeAuth -and $minerAuth) { return 'auth' }
  if (-not $nodeAuth -and -not $minerAuth) { return 'legacy' }
  Fail ("Incompatible node/miner pair for the miner protocol.`n  Node --miner-auth-token-file: {0}`n  Miner --auth-token-file / --tls-cert-sha256-file: {1}`n`nDo not mix a release that requires Ready {{ token }} (quantus-miner/2) with one that does not.`nRun {2} setup -Force to reinstall the supported pair from:`n  {3}" -f $nodeAuth, $minerAuth, $script:ScriptName, $script:CompatibilityUrl)
}

function Test-InstalledPair {
  if (-not (Test-Path $script:NodeBin)) { Fail "quantus-node not found at $($script:NodeBin)" }
  if (-not (Test-Path $script:MinerBin)) { Fail "quantus-miner not found at $($script:MinerBin)" }
  $nodeHelp = (& $script:NodeBin --help 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { Fail "Failed to probe quantus-node --help (exit $LASTEXITCODE)." }
  $minerHelp = (& $script:MinerBin serve --help 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { Fail "Failed to probe quantus-miner serve --help (exit $LASTEXITCODE)." }
  $script:MinerProtocol = Get-MinerProtocol $nodeHelp $minerHelp
  Info "Miner protocol: $($script:MinerProtocol)"
}

# ---------------------------------------------------------------------------
# Downloads
# ---------------------------------------------------------------------------

function Install-NodeBinary {
  $url = $script:Manifest['_nodeUrl']; $sha = $script:Manifest['_nodeSha']
  Info "Downloading quantus-node $($script:Manifest['_nodeVersion']) for $($script:NodeTarget)..."
  $temp = Join-Path ([IO.Path]::GetTempPath()) ("quantus-node-" + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $temp | Out-Null
  $zip = Join-Path $temp (Split-Path $url -Leaf)
  Invoke-Download $url $zip
  Assert-Sha256 $zip $sha
  Expand-Archive -Path $zip -DestinationPath $temp -Force
  $exe = Get-ChildItem $temp -Recurse -Filter 'quantus-node.exe' | Select-Object -First 1
  if (-not $exe) { Remove-Item $temp -Recurse -Force; Fail 'quantus-node.exe not found in archive' }
  Copy-Item $exe.FullName $script:NodeBin -Force
  Remove-Item $temp -Recurse -Force
  Info "Installed quantus-node to $($script:NodeBin)"
}

function Install-MinerBinary {
  $url = $script:Manifest['_minerUrl']; $sha = $script:Manifest['_minerSha']
  Info "Downloading quantus-miner $($script:Manifest['_minerVersion']) ($($script:MinerAsset))..."
  $temp = "$($script:MinerBin).download"
  Invoke-Download $url $temp
  Assert-Sha256 $temp $sha
  Move-Item $temp $script:MinerBin -Force
  Info "Installed quantus-miner to $($script:MinerBin)"
}

function Install-Binaries {
  Get-CompatibilityManifest
  Install-NodeBinary
  Install-MinerBinary
  Test-InstalledPair
  if ($script:MinerProtocol -ne 'auth') {
    Fail 'The downloaded binaries do not implement the manifest protocol quantus-miner/2. Nothing will be started.'
  }
}

# ---------------------------------------------------------------------------
# Wallet
# ---------------------------------------------------------------------------

function Read-WormholeOutput([string]$Output) {
  $addr = ($Output -split "`r?`n" | Where-Object { $_ -match '^\s*Address:\s*(\S+)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
  $hash = ($Output -split "`r?`n" | Where-Object { $_ -match '^\s*Inner [Hh]ash:\s*(\S+)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
  if (-not $hash) {
    $hash = ($Output -split "`r?`n" | Where-Object { $_ -match '^\s*inner_hash:\s*(\S+)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
  }
  if (-not $addr) { Fail 'Could not parse wormhole Address from keygen output' }
  if (-not $hash) { Fail 'Could not parse Inner Hash from keygen output' }
  return @{ Address = $addr; InnerHash = $hash }
}

function New-WormholeKeys {
  Write-Output ''
  Info 'Wallet step: enter your existing Quantus 24-word recovery phrase locally.'
  Info 'Input is hidden and is not written to disk, logs, command arguments, or network requests.'
  Info 'Never paste a recovery phrase into chat or a support ticket.'
  $secure = Read-Host -Prompt 'Recovery phrase' -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $phrase = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
  if ([string]::IsNullOrWhiteSpace($phrase)) { Fail 'Recovery phrase cannot be empty. Open your Quantus wallet backup and retry.' }

  # The phrase goes to the node on stdin only, never as an argument.
  $output = ($phrase | & $script:NodeBin key quantus --scheme wormhole --words 2>&1 | Out-String)
  $phrase = $null
  $keys = Read-WormholeOutput $output
  $output = $null

  Set-Content -Path $script:InnerHashFile -Value $keys.InnerHash -NoNewline -Encoding ascii
  Protect-File $script:InnerHashFile
  $script:Config['WORMHOLE_ADDRESS'] = $keys.Address

  Write-Output ''
  Info "Reward address: $($keys.Address)"
  Info 'Your recovery phrase was not saved. Keep your existing offline backup.'
}

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

function Set-ResourceDefaults {
  $cores = Get-CpuCount
  $workers = [Math]::Max(1, $cores - 2)
  if (Get-DiscreteGpuPresent) {
    $script:Config['GPU_DEVICES'] = '1'
    $script:Config['CPU_WORKERS'] = '0'
    Info 'Mining resources: one detected GPU, CPU reserved for the node.'
  } else {
    $script:Config['GPU_DEVICES'] = '0'
    $script:Config['CPU_WORKERS'] = [string]$workers
    Info "Mining resources: $workers CPU workers, two cores reserved when available."
  }
}

function Write-Config {
  $c = $script:Config
  if (-not $c.ContainsKey('CHAIN')) { $c['CHAIN'] = 'planck' }
  if (-not $c.ContainsKey('MINER_LISTEN_PORT')) { $c['MINER_LISTEN_PORT'] = '9833' }
  if (-not $c.ContainsKey('CPU_WORKERS')) { $c['CPU_WORKERS'] = '0' }
  if (-not $c.ContainsKey('GPU_DEVICES')) { $c['GPU_DEVICES'] = '0' }
  $lines = @(
    "# Quantus mining configuration - $($script:ConfigFile)",
    "# Generated by $($script:ScriptName) setup",
    '',
    'RUN_MODE=binary',
    "NODE_NAME=$($c['NODE_NAME'])",
    "WORMHOLE_ADDRESS=$($c['WORMHOLE_ADDRESS'])",
    'NODE_KEY_FILE=node_key.p2p',
    "CHAIN=$($c['CHAIN'])",
    "MINER_LISTEN_PORT=$($c['MINER_LISTEN_PORT'])",
    "CPU_WORKERS=$($c['CPU_WORKERS'])",
    "GPU_DEVICES=$($c['GPU_DEVICES'])",
    "NODE_VERSION=$($c['NODE_VERSION'])",
    "MINER_VERSION=$($c['MINER_VERSION'])",
    "MINER_PROTOCOL=$($c['MINER_PROTOCOL'])"
  )
  Set-Content -Path $script:ConfigFile -Value ($lines -join "`r`n") -Encoding ascii
  Protect-File $script:ConfigFile
  Info "Wrote config to $($script:ConfigFile)"
}

function Read-Config {
  if (-not (Test-Path $script:ConfigFile)) { Fail "Config not found at $($script:ConfigFile). Run: $($script:ScriptName) setup" }
  $c = @{}
  foreach ($line in Get-Content $script:ConfigFile) {
    if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
    $k, $v = $line -split '=', 2
    $c[$k.Trim()] = $v.Trim().Trim('"')
  }
  if (-not $c.ContainsKey('NODE_NAME')) { Fail 'NODE_NAME missing in config' }
  if (-not (Test-Path $script:InnerHashFile) -or (Get-Item $script:InnerHashFile).Length -eq 0) {
    Fail "Reward preimage file is missing. Re-run $($script:ScriptName) setup -Force and enter the phrase locally."
  }
  $c['_innerHash'] = (Get-Content $script:InnerHashFile -Raw).Trim()
  if (-not $c['_innerHash']) { Fail "Reward preimage file is empty. Re-run $($script:ScriptName) setup -Force." }
  foreach ($pair in @(@('CHAIN', 'planck'), @('MINER_LISTEN_PORT', '9833'), @('CPU_WORKERS', '0'), @('GPU_DEVICES', '0'), @('NODE_KEY_FILE', 'node_key.p2p'))) {
    if (-not $c.ContainsKey($pair[0])) { $c[$pair[0]] = $pair[1] }
  }
  $script:Config = $c
  return $c
}

# ---------------------------------------------------------------------------
# Processes
# ---------------------------------------------------------------------------

function Get-NodeDataPath {
  if ($env:QUANTUS_NODE_DATA_PATH) { return $env:QUANTUS_NODE_DATA_PATH }
  return Join-Path $env:LOCALAPPDATA 'quantus-node'
}

function Get-NodeChainDir { return Join-Path (Get-NodeDataPath) "chains\$($script:Config['CHAIN'])" }
function Get-MinerAuthTokenPath { return Join-Path (Get-NodeChainDir) 'miner-auth-token' }
function Get-MinerTlsPinPath { return Join-Path (Get-NodeChainDir) 'miner-tls-cert-sha256' }

function Read-PidFile([string]$Path) {
  if (Test-Path $Path) { return (Get-Content $Path -Raw).Trim() }
  return ''
}

function Test-ProcessAlive([string]$procId, [string]$ExpectedName = '') {
  if (-not $procId) { return $false }
  $p = Get-Process -Id ([int]$procId) -ErrorAction SilentlyContinue
  if (-not $p) { return $false }
  if ($ExpectedName -and $p.ProcessName -ne $ExpectedName) { return $false }
  return $true
}

function Stop-Tracked([string]$PidFile, [string]$ProcessName, [string]$Label) {
  $stopped = $false
  $procId = Read-PidFile $PidFile
  if (Test-ProcessAlive $procId $ProcessName) {
    Info "Stopping $Label (PID $procId)..."
    Stop-Process -Id ([int]$procId) -Force -ErrorAction SilentlyContinue
    $stopped = $true
  }
  # Any stray copy started from this install's bin dir is ours too.
  foreach ($p in Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
    try {
      if ($p.Path -and $p.Path.StartsWith($script:BinDir, [StringComparison]::OrdinalIgnoreCase)) {
        Info "Stopping $Label (PID $($p.Id))..."
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        $stopped = $true
      }
    } catch { }
  }
  Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
  return $stopped
}

function Test-MinerPortListening([int]$Port) {
  # QUIC is UDP. The TCP check is kept for parity with the shell installer.
  $udp = Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue
  if ($udp) { return $true }
  $tcp = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  return [bool]$tcp
}

function Test-StackRunning {
  if (Test-ProcessAlive (Read-PidFile $script:NodePidFile) 'quantus-node') { return $true }
  if (Test-ProcessAlive (Read-PidFile $script:MinerPidFile) 'quantus-miner') { return $true }
  return (Test-MinerPortListening ([int]$script:Config['MINER_LISTEN_PORT']))
}

function Get-NodeLaunchArgs {
  $c = $script:Config
  return @(
    '--name', $c['NODE_NAME'],
    '--validator',
    '--base-path', (Get-NodeDataPath),
    '--miner-listen-port', $c['MINER_LISTEN_PORT'],
    '--chain', $c['CHAIN'],
    '--node-key-file', (Join-Path $script:MiningDir $c['NODE_KEY_FILE']),
    '--rewards-inner-hash', $c['_innerHash'],
    '--max-blocks-per-request', '64',
    '--sync', 'full'
  )
}

function Get-MinerLaunchArgs {
  $c = $script:Config
  $launch = @(
    'serve',
    '--cpu-workers', $c['CPU_WORKERS'],
    '--gpu-devices', $c['GPU_DEVICES'],
    '--node-addr', "127.0.0.1:$($c['MINER_LISTEN_PORT'])"
  )
  if ($script:MinerProtocol -eq 'auth') {
    $token = Get-MinerAuthTokenPath; $pin = Get-MinerTlsPinPath
    if (-not (Test-Path $token)) { Fail "Miner auth token not found at $token. Start the node first and wait until it is listening." }
    if (-not (Test-Path $pin)) { Fail "Miner TLS pin not found at $pin. Start the node first and wait until it is listening." }
    $launch += @('--auth-token-file', $token, '--tls-cert-sha256-file', $pin)
  }
  return $launch
}

function Wait-ForMinerServer([int]$Port, [string]$NodeLog, [int]$Timeout = 120) {
  Info "Waiting for miner server on port $Port (up to ${Timeout}s)..."
  for ($i = 0; $i -lt $Timeout; $i++) {
    if ((Test-Path $NodeLog) -and (Select-String -Path $NodeLog -Pattern 'Miner server listening' -Quiet)) { return }
    if (Test-MinerPortListening $Port) { return }
    Start-Sleep 1
  }
  Fail "Timed out waiting for miner server on port $Port. Check $NodeLog"
}

function Wait-ForMinerAuthFiles([int]$Timeout = 30) {
  if ($script:MinerProtocol -ne 'auth') { return }
  Info "Waiting for miner auth files (up to ${Timeout}s)..."
  for ($i = 0; $i -lt $Timeout; $i++) {
    if ((Test-Path (Get-MinerAuthTokenPath)) -and (Test-Path (Get-MinerTlsPinPath))) { return }
    Start-Sleep 1
  }
  Fail ("Timed out waiting for miner auth files:`n  {0}`n  {1}`nStart the node first and wait until it is listening." -f (Get-MinerAuthTokenPath), (Get-MinerTlsPinPath))
}

function Start-Hidden([string]$Exe, [string[]]$Arguments, [string]$Log) {
  $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -RedirectStandardOutput "$Log.out" -RedirectStandardError $Log -WindowStyle Hidden -PassThru
  return $p
}

function Confirm-StartPrerequisites {
  Read-Config | Out-Null
  Ensure-Dirs
  Test-Platform
  Import-CompatibilityManifest $script:CompatibilityFile | Out-Null
  $c = $script:Config; $m = $script:Manifest
  if ($c['NODE_VERSION'] -ne $m['_nodeVersion'] -or $c['MINER_VERSION'] -ne $m['_minerVersion'] -or $c['CHAIN'] -ne $m['_chain']) {
    Fail ("Installed mining files do not match the supported manifest.`nInstalled: node {0} + miner {1} on {2}`nRequired:  node {3} + miner {4} on {5}`nRun: {6} setup -Force" -f $c['NODE_VERSION'], $c['MINER_VERSION'], $c['CHAIN'], $m['_nodeVersion'], $m['_minerVersion'], $m['_chain'], $script:ScriptName)
  }
  if (-not (Test-Path $script:NodeBin)) { Fail "quantus-node not found at $($script:NodeBin). Run: $($script:ScriptName) setup" }
  if (-not (Test-Path $script:MinerBin)) { Fail "quantus-miner not found at $($script:MinerBin). Run: $($script:ScriptName) setup" }
  $key = Join-Path $script:MiningDir $c['NODE_KEY_FILE']
  if (-not (Test-Path $key)) { Fail "Node key not found at $key. Run: $($script:ScriptName) setup" }
  Test-InstalledPair
}

# ---------------------------------------------------------------------------
# Status helpers
# ---------------------------------------------------------------------------

function Invoke-NodeRpc([string]$Method) {
  $body = '{"jsonrpc":"2.0","id":1,"method":"' + $Method + '","params":[]}'
  try {
    $r = Invoke-RestMethod -Uri 'http://127.0.0.1:9944' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 3
    return $r.result
  } catch { return $null }
}

function Hide-Secrets([string]$Text) {
  $t = $Text -replace '(?i)(recovery phrase|seed phrase|mnemonic|private key|inner hash|auth token)([=:]\s*|\s+)\S+', '$1: [redacted]'
  $t = $t -replace '0x[0-9a-fA-F]{64}', '[redacted-hex]'
  $t = $t -replace '[0-9a-fA-F]{64}', '[redacted-hex]'
  return $t
}

function Format-Eta([double]$Seconds) {
  if ($Seconds -lt 60) { return '{0:N0}s' -f $Seconds }
  if ($Seconds -lt 3600) { return '{0:N0} min' -f ($Seconds / 60) }
  return '{0:N1} h' -f ($Seconds / 3600)
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

function Invoke-Help {
  @"
$($script:ScriptName) - Set up and manage verified Quantus Planck testnet mining on Windows.

Working directory: $($script:MiningDir)
Config file:       $($script:ConfigFile)

Commands:
  mine                      Set up if needed, start in background, and show status
  setup [-Force]            Interactive setup: download binaries, generate keys, write config
  config show               Show non-secret configuration
  config set KEY VALUE      Update an editable config key
  start                     Start node + miner in the background
  stop                      Stop node, miner, and related helper processes
  restart                   Stop then start
  restart-check             Restart in background and verify both processes
  status                    Show a redacted mining readiness summary
  uninstall [-Force]        Stop processes and remove $($script:MiningDir) (config, keys, binaries, logs)
  help                      Show this help

Editable config keys: $($script:EditableKeys -join ' ')

Environment:
  QUANTUS_MINING_DIR        Override default working directory
  QUANTUS_NODE_DATA_PATH    Node --base-path (default: $env:LOCALAPPDATA\quantus-node)
  QUANTUS_COMPATIBILITY_URL Official compatibility manifest ($($script:CompatibilityUrl))

One-time Windows note:
  Windows Defender real-time scanning can stall chain sync on the node's
  database. If status shows peers but the block number is not moving, run this
  once in an elevated PowerShell (Run as administrator):
    Add-MpPreference -ExclusionPath "$(Get-NodeDataPath)"
"@ | Write-Output
}

function Invoke-Setup {
  Test-Platform
  Ensure-Dirs
  Info "Platform: windows / x64 ($($script:NodeTarget))"
  Info "Working directory: $($script:MiningDir)"

  if ((Test-Path $script:ConfigFile) -and -not $Force) {
    Warn "Config already exists at $($script:ConfigFile)"
    $confirm = Read-Host 'Overwrite existing setup? (y/N)'
    if ($confirm -notmatch '^(y|yes)$') { Info 'Setup cancelled.'; return }
  }

  Install-Binaries

  if (-not (Test-Path $script:NodeKeyPath)) {
    Info 'Generating node P2P identity...'
    & $script:NodeBin key generate-node-key --file $script:NodeKeyPath | Out-Null
  } else {
    Info "Using existing node key at $($script:NodeKeyPath)"
  }

  $host_ = ($env:COMPUTERNAME.ToLowerInvariant() -replace '[^a-z0-9-]', '')
  if ($host_.Length -gt 24) { $host_ = $host_.Substring(0, 24) }
  $script:Config['NODE_NAME'] = if ($host_) { "quantus-$host_" } else { 'quantus-miner' }
  Info "Node name: $($script:Config['NODE_NAME'])"

  New-WormholeKeys
  Set-ResourceDefaults
  $script:Config['NODE_VERSION'] = $script:Manifest['_nodeVersion']
  $script:Config['MINER_VERSION'] = $script:Manifest['_minerVersion']
  $script:Config['MINER_PROTOCOL'] = $script:MinerProtocol
  $script:Config['CHAIN'] = $script:Manifest['_chain']
  Write-Config

  Write-Output ''
  Info 'Setup complete.'
  Info "Start mining with: $($script:ScriptName) mine"
  Info 'Telemetry dashboard: https://telemetry.quantus.cat/'
  Info 'If sync later stalls with peers connected, see the Defender note in: quantus-mining.ps1 help'
}

function Invoke-Config([string[]]$Args) {
  $sub = if ($Args.Count -gt 0) { $Args[0] } else { '' }
  switch ($sub) {
    'show' {
      if (-not (Test-Path $script:ConfigFile)) { Fail "Config not found. Run: $($script:ScriptName) setup" }
      Get-Content $script:ConfigFile | Write-Output
    }
    'set' {
      if ($Args.Count -lt 3) { Fail "Usage: $($script:ScriptName) config set KEY VALUE" }
      $key = $Args[1]; $value = $Args[2]
      if ($script:EditableKeys -notcontains $key) { Fail "Key not editable via 'set': $key. Editable: $($script:EditableKeys -join ' ')" }
      Read-Config | Out-Null
      $script:Config[$key] = $value
      Write-Config
      Info "Updated $key=$value"
    }
    default { Fail "Usage: $($script:ScriptName) config show|set KEY VALUE" }
  }
}

function Invoke-Start {
  Confirm-StartPrerequisites
  if (Test-StackRunning) {
    Fail "Mining stack already running. Run: $($script:ScriptName) stop"
  }
  $nodeLog = Join-Path $script:LogDir 'node.log'
  $minerLog = Join-Path $script:LogDir 'miner.log'

  Info 'Starting quantus-node in background...'
  $node = Start-Hidden $script:NodeBin (Get-NodeLaunchArgs) $nodeLog
  Set-Content $script:NodePidFile $node.Id
  Info "Node started (PID $($node.Id)). Log: $nodeLog"

  Wait-ForMinerServer ([int]$script:Config['MINER_LISTEN_PORT']) $nodeLog 120
  Wait-ForMinerAuthFiles 30

  Info "Starting quantus-miner in background (log: $minerLog)..."
  $miner = Start-Hidden $script:MinerBin (Get-MinerLaunchArgs) $minerLog
  Start-Sleep 2
  if ($miner.HasExited) {
    Warn "Last lines from ${minerLog}:"
    Get-Content $minerLog -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { [Console]::Error.WriteLine($_) }
    Fail "Miner exited immediately. Check $minerLog"
  }
  Set-Content $script:MinerPidFile $miner.Id
  Info "Miner started (PID $($miner.Id))."

  Write-Output ''
  Info 'Mining stack running in background.'
  Info "Wait for full sync before expecting blocks (check $nodeLog or run: $($script:ScriptName) status)."
  Info "Telemetry: https://telemetry.quantus.cat/ (search for '$($script:Config['NODE_NAME'])')"
  Info "Stop with: $($script:ScriptName) stop"
}

function Invoke-Stop {
  $stopped = $false
  if (Test-Path $script:ConfigFile) { Read-Config | Out-Null }
  # Miner first, then node.
  if (Stop-Tracked $script:MinerPidFile 'quantus-miner' 'quantus-miner') { $stopped = $true }
  if (Stop-Tracked $script:NodePidFile 'quantus-node' 'quantus-node') { $stopped = $true }
  if ($stopped) { Info 'Mining stack stopped.' } else { Warn "No running quantus-node or quantus-miner processes found under $($script:MiningDir)." }
}

function Invoke-Status {
  if (-not (Test-Path $script:ConfigFile)) { Fail "Mining is not configured. Run: $($script:ScriptName) mine" }
  $c = Read-Config
  $nodeState = if (Test-ProcessAlive (Read-PidFile $script:NodePidFile) 'quantus-node') { 'Running' } else { 'Stopped' }
  $minerState = if (Test-ProcessAlive (Read-PidFile $script:MinerPidFile) 'quantus-miner') { 'Running' } else { 'Stopped' }

  $syncState = 'Unknown'; $syncDetail = ''
  $health = Invoke-NodeRpc 'system_health'
  if ($null -ne $health) {
    $syncState = if ($health.isSyncing) { 'Syncing' } else { 'Synced' }
    $peers = [int]$health.peers
    $s1 = Invoke-NodeRpc 'system_syncState'
    if ($null -ne $s1 -and $health.isSyncing) {
      $cur1 = [long]$s1.currentBlock; $high = [long]$s1.highestBlock
      Start-Sleep 5
      $s2 = Invoke-NodeRpc 'system_syncState'
      $cur2 = if ($null -ne $s2) { [long]$s2.currentBlock } else { $cur1 }
      $rate = ($cur2 - $cur1) / 5.0
      $pct = if ($high -gt 0) { 100.0 * $cur2 / $high } else { 0 }
      if ($rate -gt 0) {
        $syncDetail = ('block {0:N0} of {1:N0} ({2:N1}%), {3:N0} blocks/s, about {4} left, {5} peers' -f $cur2, $high, $pct, $rate, (Format-Eta (($high - $cur2) / $rate)), $peers)
      } elseif ($peers -gt 0) {
        $syncDetail = ('block {0:N0} of {1:N0} ({2:N1}%), NOT ADVANCING with {3} peers' -f $cur2, $high, $pct, $peers)
        $syncState = 'Stalled'
      } else {
        $syncDetail = ('block {0:N0} of {1:N0}, no peers yet' -f $cur2, $high)
      }
    } elseif (-not $health.isSyncing) {
      $syncDetail = "$peers peers"
    }
  }

  $hashRate = 'Waiting for miner output'; $latest = ''
  $minerLog = Join-Path $script:LogDir 'miner.log'
  if (Test-Path $minerLog) {
    $line = Select-String -Path $minerLog -Pattern 'hash.?rate|\d+(\.\d+)?\s*[kmgKMG]?H/s' | Select-Object -Last 1
    if ($line) { $latest = Hide-Secrets $line.Line; $hashRate = $latest }
  }

  $overall = 'STARTING'
  if ($nodeState -eq 'Running' -and $minerState -eq 'Running' -and $syncState -eq 'Synced' -and $latest) { $overall = 'MINING' }
  elseif ($nodeState -eq 'Stopped' -or $minerState -eq 'Stopped') { $overall = 'STOPPED' }

  @"

Quantus mining status
Overall:          $overall
Network:          Planck testnet (tokens have no monetary value)
Compatibility:    node $($c['NODE_VERSION']) + miner $($c['MINER_VERSION'])
Node:             $nodeState
Sync:             $syncState$(if ($syncDetail) { ", $syncDetail" })
Miner:            $minerState
Hash rate:        $hashRate
Reward address:   $($c['WORMHOLE_ADDRESS'])
Node name:        $($c['NODE_NAME'])
Telemetry:        https://telemetry.quantus.cat/ (search for $($c['NODE_NAME']))
Restart recovery: Run $($script:ScriptName) restart-check
"@ | Write-Output

  switch ($overall) {
    'MINING' { Info 'Success: the node is synced and the miner is reporting hash rate.' }
    'STOPPED' { Info "Recovery: run $($script:ScriptName) mine to start the verified pair." }
    default {
      if ($syncState -eq 'Stalled') {
        Info 'Recovery: sync has peers but is not advancing. Windows Defender is the usual cause. Run once, in an elevated PowerShell:'
        Info "  Add-MpPreference -ExclusionPath `"$(Get-NodeDataPath)`""
        Info "Then run: $($script:ScriptName) restart-check"
      } else {
        Info "Recovery: wait for sync, then run $($script:ScriptName) status again."
      }
    }
  }
}

function Invoke-Mine {
  if (-not (Test-Path $script:ConfigFile)) { Invoke-Setup }
  Read-Config | Out-Null
  if (-not (Test-StackRunning)) { Invoke-Start }
  Invoke-Status
}

function Invoke-RestartCheck {
  if (-not (Test-Path $script:ConfigFile)) { Fail "Mining is not configured. Run: $($script:ScriptName) mine" }
  Invoke-Stop
  Invoke-Start
  if ((Test-ProcessAlive (Read-PidFile $script:NodePidFile) 'quantus-node') -and (Test-ProcessAlive (Read-PidFile $script:MinerPidFile) 'quantus-miner')) {
    Info 'Restart recovery: PASSED'
    Invoke-Status
    return
  }
  Fail "Restart recovery failed. Run $($script:ScriptName) status, then apply the single recovery action shown."
}

function Invoke-Uninstall {
  $chainData = Get-NodeDataPath
  if (-not (Test-Path $script:MiningDir)) { Warn "Nothing to uninstall at $($script:MiningDir)."; return }
  if (-not $Force) {
    Write-Output ''
    Warn "This permanently removes $($script:MiningDir), including:"
    Write-Output '  - mining.conf (public settings and reward address)'
    Write-Output '  - rewards-inner-hash (owner-only reward preimage)'
    Write-Output '  - node_key.p2p'
    Write-Output '  - downloaded binaries and logs'
    Write-Output ''
    Warn 'Ensure your 24-word seed phrase is backed up before continuing.'
    $confirm = Read-Host 'Uninstall Quantus mining setup? (y/N)'
    if ($confirm -notmatch '^(y|yes)$') { Info 'Uninstall cancelled.'; return }
  }
  try { Invoke-Stop } catch { }
  Info "Removing $($script:MiningDir)..."
  Remove-Item $script:MiningDir -Recurse -Force
  Info 'Uninstall complete.'
  if (Test-Path $chainData) {
    Info "Chain sync data was not removed: $chainData"
    Info 'Delete it manually to reclaim disk space.'
  }
}

# ---------------------------------------------------------------------------
# Main. Dot-source the file to load the functions without running a command.
# ---------------------------------------------------------------------------

if ($MyInvocation.InvocationName -ne '.') {
  switch ($Command) {
    'mine' { Invoke-Mine }
    'setup' { Invoke-Setup }
    'config' { Invoke-Config $Rest }
    'start' { Invoke-Start }
    'stop' { Invoke-Stop }
    'restart' { Invoke-Stop; Invoke-Start }
    'restart-check' { Invoke-RestartCheck }
    'status' { Invoke-Status }
    'uninstall' { Invoke-Uninstall }
    { $_ -in 'help', '-h', '--help' } { Invoke-Help }
    default { Fail "Unknown command: $Command. Run: $($script:ScriptName) help" }
  }
}
