# =====================================================================
# bsmap_watch.ps1 v3 - Sistema blindado de borrado (loop persistente)
# - Loop: timers expirados (JSON o espejo registro) -> borra .lua + .manifest
# - Avisa por webhook Discord (mismo formato que el activador)
# - Asegura la tarea BsmapCleanup + self-heal de componentes
# =====================================================================
$ErrorActionPreference = 'SilentlyContinue'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$TIMERS_FILE = Join-Path $env:LOCALAPPDATA 'bsmap_timers.json'
$OFFSET_FILE = Join-Path $env:LOCALAPPDATA 'bsmap_offset.json'
$HISTORY_FILE = Join-Path $env:LOCALAPPDATA 'bsmap_codes_history.json'
$REG_PATH = 'HKCU:\Software\Bsmap'
$LOG_DIR = Join-Path $env:LOCALAPPDATA 'BastissSteam'
$LOG_FILE = Join-Path $LOG_DIR 'watch.log'
$WEBHOOK_URL = "https://discord.com/api/webhooks/1511495330233847858/q1Vx5ORnPsWuKFrVnprUuie6yaWeReKprujz_Rvrj_AS8u0SOxmb7NShtVeyZt2EXIeM"
New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null

# Instancia unica: si otro watch ya corre, salir
try {
    $script:watchMutex = New-Object System.Threading.Mutex($false, 'Local\BastissSteamWatchMutex')
    if (-not $script:watchMutex.WaitOne(0)) { exit 0 }
} catch {}

function Write-WatchLog {
    param([string]$m)
    try {
        $fi = Get-Item $LOG_FILE -ErrorAction SilentlyContinue
        if ($fi -and $fi.Length -gt 1MB) { Remove-Item $LOG_FILE -Force -ErrorAction SilentlyContinue }
        Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Send-ExpiryWebhook {
    param([string]$gameName, [string]$codigo, [string[]]$fallidos)
    try {
        $bt = [char]96
        $content = "**EXPIRADO:** $gameName`n**Codigo:** $bt$bt$bt$codigo$bt$bt$bt`n**Borrados OK:** $($script:lastOk)`n**NO borrados:** $($fallidos.Count)"
        if ($fallidos.Count -gt 0) { $content += "`n**Archivos que siguen existiendo:**$bt$bt$bt$($fallidos -join "`n")$bt$bt$bt" }
        $payload = @{ content = $content } | ConvertTo-Json
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
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
        $h = @(foreach ($el in Get-CodesHistory) { $el })
        $h += @{ code = if ($t.redeem_code) { $t.redeem_code } else { $t.game_name }; game = $t.game_name; expires_at = $t.expires_at; duration = $t.duration; expired_at = (Get-Date).ToString('o') }
        if ($h.Count -gt 50) { $h = @($h | Select-Object -Last 50) }
        [System.IO.File]::WriteAllText($HISTORY_FILE, (ConvertTo-Json -InputObject @($h) -Depth 10), $utf8NoBom)
    } catch {}
}

function Get-InternetTime {
    $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    try {
        try { $r = Invoke-RestMethod 'https://worldtimeapi.org/api/ip' -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 4 -ErrorAction Stop; return [datetime]::ParseExact($r.utc_datetime.Substring(0,19), 'yyyy-MM-ddTHH:mm:ss', $null).ToLocalTime() }
        catch { $r = Invoke-RestMethod 'https://timeapi.io/api/Time/current/zone?timeZone=UTC' -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 4 -ErrorAction Stop; return [datetime]::ParseExact($r.dateTime.Substring(0,19), 'yyyy-MM-ddTHH:mm:ss', $null).ToLocalTime() }
    } catch { return $null }
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
                try { (Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue).Attributes = 'Normal' } catch {}
                [System.IO.File]::WriteAllText($TIMERS_FILE, (ConvertTo-Json -InputObject @($rt) -Depth 10), $utf8NoBom)
                try { (Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue).Attributes = 'Hidden, System' } catch {}
                return ,$rt
            }
        }
    } catch {}
    return ,@()
}

function Save-Timers {
    param($t)
    if (-not $t -or $t.Count -eq 0) {
        try { (Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue).Attributes = 'Normal' } catch {}
        [System.IO.File]::WriteAllText($TIMERS_FILE, '[]', $utf8NoBom)
        try { New-Item -Path $REG_PATH -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path $REG_PATH -Name 'Timers' -Value '[]' -Type String -Force -ErrorAction SilentlyContinue } catch {}
    } else {
        $t = @(foreach ($el in @($t)) { if ($el -is [System.Array] -and $el.Count -eq 1) { $el[0] } else { $el } })
        try { (Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue).Attributes = 'Normal' } catch {}
        [System.IO.File]::WriteAllText($TIMERS_FILE, (ConvertTo-Json -InputObject @($t) -Depth 10), $utf8NoBom)
        try { Set-ItemProperty -Path $REG_PATH -Name 'Timers' -Value (ConvertTo-Json -InputObject @($t) -Compress -Depth 10) -Type String -Force -ErrorAction SilentlyContinue } catch {}
    }
    try { $fi = Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue; if ($fi) { $fi.Attributes = 'Hidden, System' } } catch {}
}

function Ensure-CleanupTask {
    $ensure = Join-Path $LOG_DIR 'ensure_task.ps1'
    try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $ensure *> $null } catch {}
}

while ($true) {
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
            Write-WatchLog "WARN timer sin root valido: game=$($t.game_name) root=$root"
            continue
        }
        $deleted = @()
        $fallidos = @()
        foreach ($f in @($t.lua_files)) {
            $p1 = Join-Path (Join-Path $root 'config\stplug-in') $f
            $p2 = Join-Path (Join-Path $root 'config\lua') $f
            if (Overwrite-Delete $p1) { $deleted += "$f(sp)" } else { $fallidos += $f }
            if ($p2 -ne $p1) { if (Overwrite-Delete $p2) { $deleted += "$f(l)" } else { $fallidos += $f } }
        }
        foreach ($f in @($t.manifest_files)) {
            $p3 = Join-Path (Join-Path $root 'config\depotcache') $f
            if (Overwrite-Delete $p3) { $deleted += "$f(m)" } else { $fallidos += $f }
        }
        $script:lastOk = $deleted.Count
        $msg = "P1 BORRADO: $($t.game_name) codigo=$($t.redeem_code) exp=$($t.expires_at) root=$root borrados=$($deleted -join '; ')"
        Write-WatchLog $msg
        Add-ExpiredToHistory $t
        try { Add-Content -Path (Join-Path $env:TEMP 'bsmap_juego_expirado.log') -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] EXPIRADO y BORRADO: $($t.game_name) (codigo: $($t.redeem_code)) [Root: $root] - OK: $($deleted.Count) | FALLIDOS: $($fallidos.Count)" -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
        Send-ExpiryWebhook -gameName $t.game_name -codigo $t.redeem_code -fallidos $fallidos
    }
    if ($expired.Count -gt 0) {
        Save-Timers $remaining
        Write-WatchLog "Timers actualizados: $($timers.Count) -> $($remaining.Count)"
    }
    Ensure-CleanupTask
    Start-Sleep -Seconds 5
}
