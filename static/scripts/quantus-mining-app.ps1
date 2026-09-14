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
$form.Size = New-Object Drawing.Size(520, 440)
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
$detail = New-Label '' 86 11 'Regular' 60
$status.Controls.Add($detail)
$heat = New-Label '' 150 10 'Regular' 44
$heat.ForeColor = [Drawing.Color]::FromArgb(180, 60, 20)
$status.Controls.Add($heat)

$start = New-Object Windows.Forms.Button
$start.Text = 'Start'
$start.Location = New-Object Drawing.Point(28, 214)
$start.Size = New-Object Drawing.Size(215, 44)
$status.Controls.Add($start)

$stop = New-Object Windows.Forms.Button
$stop.Text = 'Stop'
$stop.Location = New-Object Drawing.Point(263, 214)
$stop.Size = New-Object Drawing.Size(215, 44)
$status.Controls.Add($stop)

$auto = New-Object Windows.Forms.CheckBox
$auto.Text = 'Start mining when I turn on the laptop'
$auto.Location = New-Object Drawing.Point(28, 276)
$auto.Size = New-Object Drawing.Size(450, 28)
$status.Controls.Add($auto)

$status.Controls.Add((New-Label 'You can close this window. Mining keeps going.' 330 9 'Regular'))

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

function Show-Status {
  $setup.Visible = $false
  $status.Visible = $true
  if (-not $script:AutoLoaded) {
    $out = & $script:PowerShellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Get-Installer) autostart status 2>&1 | Out-String
    $auto.Checked = ($out -match 'Autostart: on')
    $script:AutoLoaded = $true
  }
}

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
    if (-not $script:ActionJob) { $start.Enabled = -not $p.Running; $stop.Enabled = $p.Running }
  }

  if (-not $script:StatusJob -and -not $script:ActionJob -and (Get-Date) -ge $script:NextStatus) {
    $script:StatusJob = Start-InstallerJob @('status')
    $script:NextStatus = (Get-Date).AddSeconds(15)
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
