#Requires -Version 5.1
<#
quantus-mining-app.ps1 - A plain window for Quantus mining on Windows.

For people who never open a terminal. Everything real is done by
quantus-mining.ps1 (the verified installer): this file only collects two
answers, runs the installer, and turns its status into plain words.

Start it by double-clicking "Start Quantus Mining.cmd" in the same folder.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Here = Split-Path -Parent $PSCommandPath
$script:PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$script:LocationFile = Join-Path $env:LOCALAPPDATA 'quantus-mining\location'

# Until docs.quantus.com publishes the manifest, a copy shipped in the same
# download is used. It arrived with the installer, so it carries the same trust.
$bundled = Join-Path $script:Here 'mining-compatibility.json'
if (-not $env:QUANTUS_COMPATIBILITY_URL -and (Test-Path $bundled)) {
  $env:QUANTUS_COMPATIBILITY_URL = ([Uri]$bundled).AbsoluteUri
}

# ---------------------------------------------------------------------------
# Where things are
# ---------------------------------------------------------------------------

function Get-InstallDir {
  if (Test-Path $script:LocationFile) {
    $dir = (Get-Content $script:LocationFile | Where-Object { $_ -like 'MINING_DIR=*' }) -replace '^MINING_DIR=', ''
    if ($dir -and (Test-Path (Join-Path $dir 'mining.conf'))) { return $dir }
  }
  $default = Join-Path $HOME 'quantus-mining'
  if (Test-Path (Join-Path $default 'mining.conf')) { return $default }
  return $null
}

function Get-Installer {
  $dir = Get-InstallDir
  if ($dir -and (Test-Path (Join-Path $dir 'quantus-mining.ps1'))) { return (Join-Path $dir 'quantus-mining.ps1') }
  $beside = Join-Path $script:Here 'quantus-mining.ps1'
  if (Test-Path $beside) { return $beside }
  return $null
}

# Runs one installer command in the background so the window never freezes.
function Start-InstallerJob([string[]]$Arguments) {
  Start-Job -ArgumentList $script:PowerShellExe, (Get-Installer), $env:QUANTUS_COMPATIBILITY_URL, $Arguments -ScriptBlock {
    param($ps, $installer, $url, $a)
    if ($url) { $env:QUANTUS_COMPATIBILITY_URL = $url }
    & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installer @a 2>&1 | Out-String
  }
}

# ---------------------------------------------------------------------------
# Plain words
# ---------------------------------------------------------------------------

function Get-Field([string]$Text, [string]$Name) {
  $m = [regex]::Match($Text, "(?m)^$Name\:\s*(.+)$")
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return ''
}

function ConvertTo-PlainStatus([string]$Text) {
  $overall = Get-Field $Text 'Overall'
  $sync = Get-Field $Text 'Sync'
  $rate = Get-Field $Text 'Hash rate'
  if ($overall -eq 'MINING') {
    return @{ Title = 'Mining'; Detail = "Speed: $rate. Rewards go to your Quantus Wallet app."; Color = [Drawing.Color]::FromArgb(22, 128, 60); Running = $true }
  }
  if ($overall -eq 'STOPPED') {
    return @{ Title = 'Not mining'; Detail = 'Press Start to begin.'; Color = [Drawing.Color]::FromArgb(90, 90, 90); Running = $false }
  }
  if ($sync -like 'Stalled*') {
    return @{ Title = 'Stuck'; Detail = 'Not catching up with the network. Check the internet, then restart the laptop if it stays like this.'; Color = [Drawing.Color]::FromArgb(180, 60, 20); Running = $true }
  }
  $pct = [regex]::Match($sync, '\((\d+(?:\.\d+)?)%\)')
  $left = [regex]::Match($sync, 'about (.+?) left')
  if ($pct.Success) {
    $detail = "Catching up with the network: $($pct.Groups[1].Value)%"
    if ($left.Success) { $detail += " (about $($left.Groups[1].Value) left)" }
    return @{ Title = 'Getting ready'; Detail = "$detail. Mining starts by itself."; Color = [Drawing.Color]::FromArgb(40, 90, 170); Running = $true }
  }
  if ($rate -like '*not working now*') {
    return @{ Title = 'Paused'; Detail = 'The miner stopped working. Press Stop, then Start.'; Color = [Drawing.Color]::FromArgb(180, 60, 20); Running = $true }
  }
  return @{ Title = 'Starting'; Detail = 'This takes about a minute.'; Color = [Drawing.Color]::FromArgb(40, 90, 170); Running = $true }
}


# ---------------------------------------------------------------------------
# Earnings: the reward address's real balance, read from this laptop's own node
# ---------------------------------------------------------------------------

# Base58 and BLAKE2b, needed to turn the qz... address into the chain's storage
# key. Kept as source text so the background job can compile the same code.
$script:ChainCodec = @'
using System;
using System.Numerics;
public static class QuantusCodec {
  const string Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  public static byte[] Base58Decode(string s) {
    BigInteger n = 0;
    foreach (char c in s) { int d = Alphabet.IndexOf(c); if (d < 0) throw new FormatException("not base58"); n = n * 58 + d; }
    byte[] le = n.ToByteArray(); Array.Reverse(le);
    int skip = 0; while (skip < le.Length - 1 && le[skip] == 0) skip++;
    int zeros = 0; while (zeros < s.Length && s[zeros] == '1') zeros++;
    byte[] r = new byte[zeros + le.Length - skip];
    Array.Copy(le, skip, r, zeros, le.Length - skip);
    return r;
  }
  static readonly ulong[] IV = { 0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL, 0x3c6ef372fe94f82bUL, 0xa54ff53a5f1d36f1UL, 0x510e527fade682d1UL, 0x9b05688c2b3e6c1fUL, 0x1f83d9abfb41bd6bUL, 0x5be0cd19137e2179UL };
  static readonly int[,] Sigma = {
    {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},{14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3},{11,8,12,0,5,2,15,13,10,14,3,6,7,1,9,4},
    {7,9,3,1,13,12,11,14,2,6,5,10,4,0,15,8},{9,0,5,7,2,4,10,15,14,1,11,12,6,8,3,13},{2,12,6,10,0,11,8,3,4,13,7,5,15,14,1,9},
    {12,5,1,15,14,13,4,10,0,7,6,3,9,2,8,11},{13,11,7,14,12,1,3,9,5,0,15,4,8,6,2,10},{6,15,14,9,11,3,0,8,12,2,13,7,1,4,10,5},
    {10,2,8,4,7,6,1,5,15,11,9,14,3,12,13,0} };
  static ulong Rot(ulong x, int n) { return (x >> n) | (x << (64 - n)); }
  public static byte[] Blake2b(byte[] data, int outLen) {
    ulong[] h = (ulong[])IV.Clone(); h[0] ^= 0x01010000UL ^ (ulong)outLen;
    ulong t = 0; int off = 0; int len = data.Length;
    do {
      byte[] block = new byte[128]; int take = Math.Min(128, len - off);
      Array.Copy(data, off, block, 0, take); off += take; t += (ulong)take;
      bool last = off >= len;
      ulong[] m = new ulong[16]; for (int i = 0; i < 16; i++) m[i] = BitConverter.ToUInt64(block, i * 8);
      ulong[] v = new ulong[16]; Array.Copy(h, v, 8); Array.Copy(IV, 0, v, 8, 8);
      v[12] ^= t; if (last) v[14] = ~v[14];
      for (int r = 0; r < 12; r++) {
        int[] idx = { 0,4,8,12, 1,5,9,13, 2,6,10,14, 3,7,11,15, 0,5,10,15, 1,6,11,12, 2,7,8,13, 3,4,9,14 };
        for (int g = 0; g < 8; g++) {
          int a = idx[g*4], b = idx[g*4+1], c = idx[g*4+2], d = idx[g*4+3];
          ulong x = m[Sigma[r % 10, 2*g]], y = m[Sigma[r % 10, 2*g+1]];
          v[a] = v[a] + v[b] + x; v[d] = Rot(v[d] ^ v[a], 32); v[c] = v[c] + v[d]; v[b] = Rot(v[b] ^ v[c], 24);
          v[a] = v[a] + v[b] + y; v[d] = Rot(v[d] ^ v[a], 16); v[c] = v[c] + v[d]; v[b] = Rot(v[b] ^ v[c], 63);
        }
      }
      for (int i = 0; i < 8; i++) h[i] ^= v[i] ^ v[i + 8];
      if (last) break;
    } while (true);
    byte[] outb = new byte[outLen];
    for (int i = 0; i < outLen; i++) outb[i] = (byte)(h[i / 8] >> (8 * (i % 8)));
    return outb;
  }
  static string Hex(byte[] b) { return BitConverter.ToString(b).Replace("-", "").ToLowerInvariant(); }
  // System.Account storage key for an SS58 address, or null if the checksum fails.
  public static string AccountKey(string address) {
    byte[] raw = Base58Decode(address);
    if (raw.Length != 35 && raw.Length != 36) return null;
    int prefix = raw.Length - 34;
    byte[] body = new byte[raw.Length - 2]; Array.Copy(raw, body, body.Length);
    byte[] pre = System.Text.Encoding.ASCII.GetBytes("SS58PRE");
    byte[] withPre = new byte[pre.Length + body.Length]; pre.CopyTo(withPre, 0); body.CopyTo(withPre, pre.Length);
    byte[] sum = Blake2b(withPre, 64);
    if (sum[0] != raw[raw.Length - 2] || sum[1] != raw[raw.Length - 1]) return null;
    byte[] acct = new byte[32]; Array.Copy(raw, prefix, acct, 0, 32);
    return "0x26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9" + Hex(Blake2b(acct, 16)) + Hex(acct);
  }
}
'@

# Runs in a background job: balance from the local node, price from CoinGecko.
$script:EarningsScript = {
  param($codec, $conf)
  $out = @{ Qtc = $null; Usd = $null }
  try {
    Add-Type -TypeDefinition $codec -ReferencedAssemblies System.Numerics -ErrorAction Stop
    $addr = ((Get-Content $conf) | Where-Object { $_ -like 'WORMHOLE_ADDRESS=*' }) -replace '^WORMHOLE_ADDRESS=', '' -replace '"', ''
    $key = [QuantusCodec]::AccountKey($addr.Trim())
    if ($key) {
      $body = '{"jsonrpc":"2.0","id":1,"method":"state_getStorage","params":["' + $key + '"]}'
      $v = (Invoke-RestMethod http://127.0.0.1:9944 -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 5).result
      # AccountInfo: nonce, consumers, providers, sufficients (4 x u32), then free balance as u128.
      if (-not $v) { $out.Qtc = 0.0 } else {
        $bytes = [byte[]]::new(16)
        for ($i = 0; $i -lt 16; $i++) { $bytes[$i] = [Convert]::ToByte($v.Substring(2 + (16 + $i) * 2, 2), 16) }
        $free = [Numerics.BigInteger]::new([byte[]]($bytes + [byte]0))
        $out.Qtc = [double]([decimal]$free / 1000000000000)
      }
    }
  } catch { }
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $out.Usd = [double](Invoke-RestMethod 'https://api.coingecko.com/api/v3/simple/price?ids=quantus&vs_currencies=usd' -TimeoutSec 6).quantus.usd
  } catch { }
  [pscustomobject]$out
}

function Format-Earnings($e) {
  $minerProc = Get-Process quantus-miner -ErrorAction SilentlyContinue | Select-Object -First 1
  $since = ''
  if ($minerProc) {
    $span = (Get-Date) - $minerProc.StartTime
    $since = if ($span.TotalHours -ge 1) { ' · Mining for {0} h {1} min' -f [int][math]::Floor($span.TotalHours), $span.Minutes } else { ' · Mining for {0} min' -f [int]$span.TotalMinutes }
  }
  if ($null -eq $e -or $null -eq $e.Qtc) { return "Earned: checking...$since" }
  $qtc = if ($e.Qtc -eq 0) { '0' } else { '{0:N4}' -f $e.Qtc }
  $usd = if ($null -ne $e.Usd) { ' ({0:C2})' -f ($e.Qtc * $e.Usd) } else { '' }
  return "Rewards wallet: $qtc QTC$usd$since"
}

function Get-CoolerSetting {
  $dir = Get-InstallDir
  if (-not $dir) { return $false }
  $line = (Get-Content (Join-Path $dir 'mining.conf')) | Where-Object { $_ -like 'GPU_THROTTLE_MS=*' }
  return ($line -and [int]($line -replace '^GPU_THROTTLE_MS=', '') -gt 0)
}

function Get-HeatWarning {
  $smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
  if (-not $smi) { return '' }
  try {
    $out = & $smi.Source --query-gpu=temperature.gpu,clocks_event_reasons.hw_thermal_slowdown,clocks_event_reasons.sw_thermal_slowdown --format=csv,noheader 2>$null
    if ($out -match 'Active') { return 'Your laptop is hot, so mining is slower. Raise the back of the laptop and keep the air vents clear.' }
  } catch { }
  return ''
}

function ConvertTo-PlainSetupLine([string]$Line) {
  switch -Regex ($Line) {
    '^Storage:' { return 'Checking there is enough space...' }
    'Downloading quantus-node' { return 'Downloading the Quantus software (1 of 2)...' }
    'Downloading quantus-miner' { return 'Downloading the Quantus software (2 of 2)...' }
    'Verified SHA-256' { return 'Checking the download is genuine...' }
    'Reward address:' { return 'Wallet connected.' }
    'Starting quantus-node' { return 'Starting...' }
    'Waiting for miner' { return 'Starting...' }
    'Miner started' { return 'Started.' }
  }
  return $null
}

function Test-MinerName([string]$Name) { return ($Name -cmatch '^[a-z0-9](?:[a-z0-9-]{1,30})[a-z0-9]$') }

# ---------------------------------------------------------------------------
# Window
# ---------------------------------------------------------------------------

$font = New-Object Drawing.Font('Segoe UI', 10)
$form = New-Object Windows.Forms.Form
$form.Text = 'Quantus Mining'
$form.Size = New-Object Drawing.Size(520, 500)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = $font
$form.BackColor = [Drawing.Color]::White

function New-Label([string]$Text, [int]$Y, [int]$Size = 10, [string]$Style = 'Regular', [int]$Height = 24) {
  $l = New-Object Windows.Forms.Label
  $l.Text = $Text
  $l.Location = New-Object Drawing.Point(28, $Y)
  $l.Size = New-Object Drawing.Size(450, $Height)
  $l.Font = New-Object Drawing.Font('Segoe UI', $Size, [Drawing.FontStyle]$Style)
  return $l
}

# ----- setup panel -----
$setup = New-Object Windows.Forms.Panel
$setup.Dock = 'Fill'

$setup.Controls.Add((New-Label 'Mine Quantus on this laptop' 20 16 'Bold' 34))
$setup.Controls.Add((New-Label 'Open the Quantus Wallet app on your phone and have your 24 secret words ready.' 60 10 'Regular' 42))

$setup.Controls.Add((New-Label 'Your 24 secret words' 108 10 'Bold'))
$words = New-Object Windows.Forms.TextBox
$words.Location = New-Object Drawing.Point(28, 134)
$words.Size = New-Object Drawing.Size(450, 28)
$words.UseSystemPasswordChar = $true
$setup.Controls.Add($words)

$show = New-Object Windows.Forms.CheckBox
$show.Text = 'Show the words while I type'
$show.Location = New-Object Drawing.Point(28, 166)
$show.Size = New-Object Drawing.Size(300, 24)
$show.Add_CheckedChanged({ $words.UseSystemPasswordChar = -not $show.Checked })
$setup.Controls.Add($show)

$setup.Controls.Add((New-Label 'The words stay on this laptop. Quantus never asks for them by message, email or phone call.' 192 9 'Regular' 36))

$setup.Controls.Add((New-Label 'Miner name (shown publicly, so not your real name)' 234 10 'Bold'))
$name = New-Object Windows.Forms.TextBox
$name.Location = New-Object Drawing.Point(28, 260)
$name.Size = New-Object Drawing.Size(450, 28)
$hostPart = ($env:COMPUTERNAME.ToLowerInvariant() -replace '[^a-z0-9-]', '').Trim('-')
$name.Text = if ($hostPart) { "quantus-$hostPart" } else { 'quantus-miner' }
$setup.Controls.Add($name)

$go = New-Object Windows.Forms.Button
$go.Text = 'Start mining'
$go.Location = New-Object Drawing.Point(28, 306)
$go.Size = New-Object Drawing.Size(450, 44)
$go.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$go.BackColor = [Drawing.Color]::FromArgb(255, 107, 53)
$go.ForeColor = [Drawing.Color]::White
$go.FlatStyle = 'Flat'
$setup.Controls.Add($go)

$progress = New-Label '' 360 10 'Regular' 40
$setup.Controls.Add($progress)

# ----- status panel -----
$status = New-Object Windows.Forms.Panel
$status.Dock = 'Fill'
$status.Visible = $false

$title = New-Label 'Checking...' 30 26 'Bold' 50
$status.Controls.Add($title)
$detail = New-Label '' 86 11 'Regular' 44
$status.Controls.Add($detail)
$earn = New-Label 'Earned: checking...' 134 11 'Bold' 26
$status.Controls.Add($earn)
$heat = New-Label '' 166 10 'Regular' 44
$heat.ForeColor = [Drawing.Color]::FromArgb(180, 60, 20)
$status.Controls.Add($heat)

$start = New-Object Windows.Forms.Button
$start.Text = 'Start'
$start.Location = New-Object Drawing.Point(28, 220)
$start.Size = New-Object Drawing.Size(215, 44)
$status.Controls.Add($start)

$stop = New-Object Windows.Forms.Button
$stop.Text = 'Stop'
$stop.Location = New-Object Drawing.Point(263, 220)
$stop.Size = New-Object Drawing.Size(215, 44)
$status.Controls.Add($stop)

$auto = New-Object Windows.Forms.CheckBox
$auto.Text = 'Start mining when I turn on the laptop'
$auto.Location = New-Object Drawing.Point(28, 280)
$auto.Size = New-Object Drawing.Size(450, 28)
$status.Controls.Add($auto)

$cooler = New-Object Windows.Forms.CheckBox
$cooler.Text = 'Run cooler (a little slower, easier on the laptop)'
$cooler.Location = New-Object Drawing.Point(28, 312)
$cooler.Size = New-Object Drawing.Size(450, 28)
$status.Controls.Add($cooler)

$status.Controls.Add((New-Label 'You can close this window. Mining keeps going.' 380 9 'Regular'))

$form.Controls.Add($status)
$form.Controls.Add($setup)

# ---------------------------------------------------------------------------
# Behaviour
# ---------------------------------------------------------------------------

$script:StatusJob = $null
$script:ActionJob = $null
$script:SetupProc = $null
$script:SetupLines = [Collections.ArrayList]::Synchronized((New-Object Collections.ArrayList))
$script:AutoLoaded = $false
$script:EarningsJob = $null
$script:Earnings = $null
$script:NextEarnings = [DateTime]::MinValue
# Pause between GPU batches when "Run cooler" is on, chosen by measurement.
$script:CoolerMs = '30'

function Show-Status {
  $setup.Visible = $false
  $status.Visible = $true
  if (-not $script:AutoLoaded) {
    $out = & $script:PowerShellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Get-Installer) autostart status 2>&1 | Out-String
    $auto.Checked = ($out -match 'Autostart: on')
    $cooler.Checked = Get-CoolerSetting
    $script:AutoLoaded = $true
  }
}

$cooler.Add_Click({
  $ms = if ($cooler.Checked) { $script:CoolerMs } else { '0' }
  $title.Text = 'Restarting'; $detail.Text = 'Applying the new setting. This takes about a minute.'
  $start.Enabled = $false; $stop.Enabled = $false
  $script:ActionJob = Start-Job -ArgumentList $script:PowerShellExe, (Get-Installer), $env:QUANTUS_COMPATIBILITY_URL, $ms -ScriptBlock {
    param($ps, $installer, $url, $ms)
    if ($url) { $env:QUANTUS_COMPATIBILITY_URL = $url }
    & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installer config set GPU_THROTTLE_MS $ms 2>&1 | Out-Null
    & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installer restart 2>&1 | Out-String
  }
})

$auto.Add_Click({
  $script:ActionJob = Start-InstallerJob @('autostart', $(if ($auto.Checked) { 'on' } else { 'off' }))
})

$start.Add_Click({
  $title.Text = 'Starting'; $detail.Text = 'This takes about a minute.'
  $start.Enabled = $false
  $script:ActionJob = Start-InstallerJob @('start')
})

$stop.Add_Click({
  $title.Text = 'Stopping...'; $detail.Text = ''
  $stop.Enabled = $false
  $script:ActionJob = Start-InstallerJob @('stop')
})

$go.Add_Click({
  $phrase = (($words.Text -split '\s+') | Where-Object { $_ }) -join ' '
  $count = ($phrase -split ' ').Count
  if (-not $phrase -or $count -ne 24) {
    [Windows.Forms.MessageBox]::Show("Please type all 24 secret words, with a space between each one. You typed $(if ($phrase) { $count } else { 0 }).", 'Quantus Mining') | Out-Null
    return
  }
  $miner = $name.Text.Trim().ToLowerInvariant()
  if (-not (Test-MinerName $miner)) {
    [Windows.Forms.MessageBox]::Show('Please use 3 to 32 lowercase letters, numbers and hyphens for the miner name.', 'Quantus Mining') | Out-Null
    return
  }
  $installer = Get-Installer
  if (-not $installer) {
    [Windows.Forms.MessageBox]::Show('quantus-mining.ps1 is missing. Keep all the downloaded files together in one folder.', 'Quantus Mining') | Out-Null
    return
  }

  $go.Enabled = $false; $words.Enabled = $false; $name.Enabled = $false
  $progress.Text = 'Getting started...'
  $script:SetupLines.Clear()

  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $script:PowerShellExe
  $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$installer`" mine"
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.EnvironmentVariables['QUANTUS_NODE_NAME'] = $miner
  if ($env:QUANTUS_COMPATIBILITY_URL) { $psi.EnvironmentVariables['QUANTUS_COMPATIBILITY_URL'] = $env:QUANTUS_COMPATIBILITY_URL }

  $proc = New-Object Diagnostics.Process
  $proc.StartInfo = $psi
  $handler = { if ($EventArgs.Data) { $Event.MessageData.Add($EventArgs.Data) | Out-Null } }
  Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $handler -MessageData $script:SetupLines | Out-Null
  Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action $handler -MessageData $script:SetupLines | Out-Null
  $proc.Start() | Out-Null
  $proc.BeginOutputReadLine()
  $proc.BeginErrorReadLine()
  # The phrase is written once to the installer's standard input and dropped.
  $proc.StandardInput.WriteLine($phrase)
  $proc.StandardInput.Close()
  $phrase = $null
  $words.Text = ''
  $script:SetupProc = $proc
})

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 2000
$script:NextStatus = [DateTime]::MinValue
$timer.Add_Tick({
  # Setup in progress
  if ($script:SetupProc) {
    foreach ($line in @($script:SetupLines.ToArray())) {
      $plain = ConvertTo-PlainSetupLine $line
      if ($plain) { $progress.Text = $plain }
    }
    if ($script:SetupProc.HasExited) {
      $code = $script:SetupProc.ExitCode
      $script:SetupProc = $null
      Get-EventSubscriber | Unregister-Event
      if ($code -eq 0) {
        & $script:PowerShellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Get-Installer) autostart on 2>&1 | Out-Null
        Install-Shortcut
        Show-Status
        $script:NextStatus = [DateTime]::MinValue
      } else {
        $err = @($script:SetupLines.ToArray()) | Where-Object { $_ -like 'Error:*' } | Select-Object -Last 1
        $msg = if ($err) { $err -replace '^Error:\s*', '' } else { 'Setup did not finish.' }
        [Windows.Forms.MessageBox]::Show("Mining could not start.`n`n$msg", 'Quantus Mining') | Out-Null
        $progress.Text = ''
        $go.Enabled = $true; $words.Enabled = $true; $name.Enabled = $true
      }
    }
    return
  }

  if (-not $status.Visible) { return }

  if ($script:ActionJob -and $script:ActionJob.State -ne 'Running') {
    Receive-Job $script:ActionJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $script:ActionJob -Force
    $script:ActionJob = $null
    $start.Enabled = $true; $stop.Enabled = $true
    $script:NextStatus = [DateTime]::MinValue
  }

  if ($script:StatusJob -and $script:StatusJob.State -ne 'Running') {
    $text = (Receive-Job $script:StatusJob -ErrorAction SilentlyContinue | Out-String)
    Remove-Job $script:StatusJob -Force
    $script:StatusJob = $null
    $p = ConvertTo-PlainStatus $text
    $title.Text = $p.Title
    $title.ForeColor = $p.Color
    $detail.Text = $p.Detail
    $heat.Text = Get-HeatWarning
    $earn.Text = Format-Earnings $script:Earnings
    if (-not $script:ActionJob) { $start.Enabled = -not $p.Running; $stop.Enabled = $p.Running }
  }

  if (-not $script:StatusJob -and -not $script:ActionJob -and (Get-Date) -ge $script:NextStatus) {
    $script:StatusJob = Start-InstallerJob @('status')
    $script:NextStatus = (Get-Date).AddSeconds(15)
  }

  if ($script:EarningsJob -and $script:EarningsJob.State -ne 'Running') {
    $r = Receive-Job $script:EarningsJob -ErrorAction SilentlyContinue | Select-Object -Last 1
    Remove-Job $script:EarningsJob -Force
    $script:EarningsJob = $null
    if ($r) { $script:Earnings = $r; $earn.Text = Format-Earnings $r }
  }
  if (-not $script:EarningsJob -and (Get-Date) -ge $script:NextEarnings) {
    $conf = Join-Path (Get-InstallDir) 'mining.conf'
    $script:EarningsJob = Start-Job -ScriptBlock $script:EarningsScript -ArgumentList $script:ChainCodec, $conf
    $script:NextEarnings = (Get-Date).AddMinutes(1)
  }
})

# A desktop icon that opens this window, pointing at the copy kept beside the
# install so it survives the download folder being cleaned out.
function Install-Shortcut {
  $dir = Get-InstallDir
  if (-not $dir) { return }
  foreach ($f in @('quantus-mining-app.ps1', 'mining-compatibility.json')) {
    $src = Join-Path $script:Here $f
    if ((Test-Path $src) -and ([IO.Path]::GetFullPath($src) -ne [IO.Path]::GetFullPath((Join-Path $dir $f)))) { Copy-Item -LiteralPath $src -Destination $dir -Force }
  }
  $shell = New-Object -ComObject WScript.Shell
  $link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Quantus Mining.lnk'))
  $link.TargetPath = $script:PowerShellExe
  $link.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $dir 'quantus-mining-app.ps1')`""
  $link.WorkingDirectory = $dir
  $link.Description = 'Quantus Mining'
  $icon = Join-Path $dir 'bin\quantus-miner.exe'
  if (Test-Path $icon) { $link.IconLocation = "$icon,0" }
  $link.Save()
}

if (Get-InstallDir) { Show-Status }
$timer.Start()
[void]$form.ShowDialog()
$timer.Stop()
Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
