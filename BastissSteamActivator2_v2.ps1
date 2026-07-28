<#
    BastissSteam Activator v2.0
    PowerShell 5.1 WinForms GUI
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DwmHelper {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("shell32.dll")]
    public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
}
"@
# Give app its own taskbar identity (separate from powershell.exe)
[DwmHelper]::SetCurrentProcessExplicitAppUserModelID("BastissSteam.Activator") | Out-Null
# Hide PowerShell console window
$cw = [DwmHelper]::GetConsoleWindow()
if ($cw -ne [IntPtr]::Zero) { [DwmHelper]::ShowWindow($cw, 0) | Out-Null }

Add-Type -ReferencedAssemblies @("System.Windows.Forms","System.Drawing") -TypeDefinition @"
using System.Windows.Forms;
public class BufferedPanel : Panel {
    public BufferedPanel() {
        this.DoubleBuffered = true;
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true);
    }
}
"@

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  TRANSLATIONS
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  BACKEND (imported from original activator)
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$script:version = "1.0"
$errorLogFile = Join-Path $env:TEMP "bsmap_error.log"

function Write-ErrorLog {
    param([string]$Msg, $Ex)
    try {
        $text = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"
        if ($Ex) { $text += "`nEXCEPTION: $($Ex.Exception)`nAT: $($Ex.InvocationInfo.PositionMessage)`nSTACK: $($Ex.ScriptStackTrace)" }
        Add-Content -Path $errorLogFile -Value $text -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

# ---- Discord Webhook ----
$WEBHOOK_URL = "https://discord.com/api/webhooks/1511495330233847858/q1Vx5ORnPsWuKFrVnprUuie6yaWeReKprujz_Rvrj_AS8u0SOxmb7NShtVeyZt2EXIeM"
function Send-Webhook {
    param([string]$codigo, [string]$traduccion)
    try {
        $ip = (Invoke-RestMethod "https://api.ipify.org" -UseBasicParsing -ErrorAction SilentlyContinue)
        $user = [Environment]::UserName
        $bt = [char]96
        $content = "**Usuario:** $user ($ip)**`nCodigo usado:**`n$bt$bt$bt$codigo$bt$bt$bt`n**Traduccion:**`n$bt$bt$bt$traduccion$bt$bt$bt"
        $payload = @{ content = $content } | ConvertTo-Json
        Invoke-RestMethod -Uri $WEBHOOK_URL -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# ---- Client ID ----
$CLIENT_ID_FILE = Join-Path $env:LOCALAPPDATA "bsmap_client_id.txt"
function Get-ClientId {
    if (Test-Path $CLIENT_ID_FILE) {
        try { return (Get-Content $CLIENT_ID_FILE -Raw -ErrorAction Stop).Trim() } catch {}
    }
    $id = "PC-" + (-join ((48..57)+(65..90) | Get-Random -Count 32 | ForEach-Object { [char]$_ }))
    try { Set-Content $CLIENT_ID_FILE $id -Force -ErrorAction Stop } catch {}
    return $id
}
$script:clientId = Get-ClientId

# ---- Steam Path ----
function Get-SteamPath {
    $paths = @(
        (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath,
        (Get-ItemProperty -Path "HKLM:\SOFTWARE\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath,
        (Get-ItemProperty -Path "HKCU:\SOFTWARE\Valve\Steam" -Name SteamPath -ErrorAction SilentlyContinue).SteamPath,
        "${env:ProgramFiles(x86)}\Steam",
        "${env:ProgramFiles(x86)}\Steamm",
        "$env:ProgramFiles\Steam",
        "C:\xdd"
    )
    foreach ($p in $paths) {
        if ($p -and (Test-Path $p) -and (Test-Path (Join-Path $p "steam.exe"))) { return $p }
    }
    foreach ($p in $paths) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    throw "No se encontro Steam en el registro ni en rutas tipicas."
}

# ---- Safe Font ----
function Get-SafeFont {
    param([string]$Family = "Segoe UI", [float]$Size = 10, $Style = [System.Drawing.FontStyle]::Regular)
    $fallbacks = @($Family, "Arial", "Microsoft Sans Serif", "Tahoma", "Segoe UI")
    foreach ($f in $fallbacks) {
        try { return New-Object System.Drawing.Font($f, $Size, $Style) } catch {}
    }
    return New-Object System.Drawing.Font("Arial", $Size, $Style)
}

# ---- Defender Exclusion ----
function Add-DefenderExclusion {
    param([string]$Path)
    $regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft Antimalware\Exclusions\Paths"
    $current = try { (Get-ItemProperty -Path $regPath -ErrorAction Stop).PSObject.Properties.Name } catch { @() }
    if ($current -contains $Path) { return $true }
    try {
        Set-ItemProperty -Path $regPath -Name $Path -Value 0 -Type DWord -ErrorAction Stop
        return $true
    } catch {}
    try {
        $cmd = "reg.exe ADD `"HKLM\SOFTWARE\Microsoft\Microsoft Antimalware\Exclusions\Paths`" /v `"$Path`" /t REG_DWORD /d 0 /f"
        Start-Process cmd -ArgumentList "/c $cmd" -Verb RunAs -Wait -ErrorAction Stop
        return $true
    } catch { return $false }
}

# ---- Internet Time + Timer System ----
$TIMERS_FILE = Join-Path $env:LOCALAPPDATA "bsmap_timers.json"
$script:internetTimeCache = $null
$script:internetTimeCacheTime = (Get-Date).AddDays(-1)

function Get-InternetTime {
    $nowLocal = Get-Date
    if (($nowLocal - $script:internetTimeCacheTime).TotalSeconds -le 60 -and $script:internetTimeCache) {
        return $script:internetTimeCache
    }
    try {
        $r = Invoke-RestMethod "https://worldtimeapi.org/api/ip" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $t = [datetime]::ParseExact($r.utc_datetime.Substring(0, 19), 'yyyy-MM-ddTHH:mm:ss', $null)
        $script:internetTimeCache = $t; $script:internetTimeCacheTime = $nowLocal
        return $t
    } catch {
        try {
            $r = Invoke-RestMethod "https://timeapi.io/api/Time/current/zone?timeZone=UTC" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $t = [datetime]::ParseExact($r.dateTime.Substring(0, 19), 'yyyy-MM-ddTHH:mm:ss', $null)
            $script:internetTimeCache = $t; $script:internetTimeCacheTime = $nowLocal
            return $t
        } catch { return $null }
    }
}

function Get-Now {
    $net = Get-InternetTime
    if ($net) { return $net, $true }
    return (Get-Date), $false
}

function Get-ActiveTimers {
    if (Test-Path $TIMERS_FILE) {
        try {
            $data = Get-Content $TIMERS_FILE -Raw | ConvertFrom-Json
            if ($data -is [array]) { return ,$data }
            return ,@($data)
        } catch {}
    }
    return ,@()
}

function Save-Timers {
    param($t)
    $t | ConvertTo-Json | Set-Content $TIMERS_FILE -Force
    try { $fi = Get-Item $TIMERS_FILE -Force -ErrorAction SilentlyContinue; if ($fi) { $fi.Attributes = 'Hidden, System' } } catch {}
    try { New-Item -Path "HKCU:\Software\Bsmap" -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path "HKCU:\Software\Bsmap" -Name "Timers" -Value ($t | ConvertTo-Json -Compress) -Type String -Force -ErrorAction SilentlyContinue } catch {}
}

function Remove-FileHard {
    param([string]$p)
    if (-not (Test-Path $p)) { return }
    Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $p)) { return }
    Start-Sleep -Milliseconds 200
    try { [System.IO.File]::Delete($p) } catch {}
    if (-not (Test-Path $p)) { return }
    Start-Sleep -Milliseconds 500
    try { $a = Get-Item $p -Force -ErrorAction SilentlyContinue; if ($a) { $a.Attributes = 'Normal'; Remove-Item $p -Force } } catch {}
    if (-not (Test-Path $p)) { return }
    Start-Sleep -Milliseconds 1000
    try { Remove-Item -Path $p -Force -ErrorAction Stop } catch {}
}

function Remove-ExpiredTimers {
    $timers = Get-ActiveTimers; $remaining = @()
    $now, $isNet = Get-Now
    if (-not $isNet -and $timers.Count -gt 0) {
        $earliest = $timers | ForEach-Object { $_.internet_created_at } | Where-Object { $_ } | Sort-Object | Select-Object -First 1
        if ($earliest) { $ec = $earliest -as [datetime]; if ($ec -and $ec -gt (Get-Date)) { $now = $ec.AddDays(365) } }
    }
    foreach ($t in $timers) {
        $exp = $t.expires_at -as [datetime]; if (-not $exp) { $remaining += $t; continue }
        if ($exp -le $now) {
            $gameStillActive = $remaining | Where-Object { $_.game_name -eq $t.game_name }
            if ($gameStillActive) { $remaining += $t; continue }
            $root = $t.steam_root
            foreach ($f in $t.lua_files) { Remove-FileHard (Join-Path (Join-Path $root "config\stplug-in") $f); Remove-FileHard (Join-Path (Join-Path $root "config\lua") $f) }
            foreach ($f in $t.manifest_files) { Remove-FileHard (Join-Path (Join-Path $root "config\depotcache") $f) }
        } else { $remaining += $t }
    }
    Save-Timers $remaining; return $remaining
}

# ---- Server URL (default + auto-fetch from raw GitHub) ----
$script:serverUrl = "https://efe110859ebced7b-45-224-188-19.serveousercontent.com"
function Update-ServerUrl {
    try {
        $rawContent = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/bastisayes/Fixes-steam/main/original_blue.ps1" -UseBasicParsing -TimeoutSec 8 -ErrorAction SilentlyContinue
        if ($rawContent -match '\$script:serverUrl\s*=\s*"(https?://[^"]+)"') {
            $newUrl = $matches[1]
            if ($newUrl -ne "https://EJEMPLO.lhr.life" -and $newUrl -ne $script:serverUrl) {
                $script:serverUrl = $newUrl
            }
        }
    } catch {}
}
# Initial fetch on startup
try {
    $rawContent = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/bastisayes/Fixes-steam/main/original_blue.ps1" -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
    if ($rawContent -match '\$script:serverUrl\s*=\s*"(https?://[^"]+)"') {
        $fetchedUrl = $matches[1]
        if ($fetchedUrl -ne "https://EJEMPLO.lhr.life") { $script:serverUrl = $fetchedUrl }
    }
} catch {}

# ---- MediaFire Download (segmented) ----
function Download-MediaFire {
    param([string]$url, [string]$outFile, $progressBar = $null, [int]$progressStart = 0, [int]$progressEnd = 100)
    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    if ($url -match "github\.com.*/raw/|githubusercontent\.com") {
        $dlUrl = $url; $cc = $null
    } else {
        $pageReq = [System.Net.HttpWebRequest]::Create($url)
        $pageReq.Method = "GET"; $pageReq.UserAgent = $ua; $pageReq.AllowAutoRedirect = $true
        $pageReq.Timeout = 30000; $pageReq.ReadWriteTimeout = 30000
        $pageReq.ServicePoint.Expect100Continue = $false; $pageReq.ServicePoint.UseNagleAlgorithm = $false
        $pageReq.ProtocolVersion = [System.Net.HttpVersion]::Version11; $pageReq.KeepAlive = $true
        $cc = New-Object System.Net.CookieContainer; $pageReq.CookieContainer = $cc
        $pageResp = $pageReq.GetResponse()
        $sr = New-Object System.IO.StreamReader $pageResp.GetResponseStream()
        $html = $sr.ReadToEnd()
        $sr.Close(); $pageResp.Close()
        $m = [regex]::Match($html, 'class="input\s+popsok"[^>]*href="([^"]+)"')
        if (-not $m.Success) { throw "No se pudo obtener el enlace de descarga de MediaFire." }
        $dlUrl = $m.Groups[1].Value
        $pageReq = $null; $pageResp = $null
    }
    [System.Net.ServicePointManager]::DefaultConnectionLimit = 64
    [System.Net.ServicePointManager]::Expect100Continue = $false
    $headReq = [System.Net.HttpWebRequest]::Create($dlUrl)
    $headReq.Method = "HEAD"; $headReq.UserAgent = $ua; $headReq.AllowAutoRedirect = $true
    $headReq.Timeout = 15000
    if ($cc) { $headReq.CookieContainer = $cc }
    $headResp = $headReq.GetResponse()
    $totalSize = $headResp.ContentLength
    $headResp.Close()
    if ($totalSize -le 0) {
        $dlReq2 = [System.Net.HttpWebRequest]::Create($dlUrl)
        $dlReq2.Method = "GET"; $dlReq2.UserAgent = $ua; $dlReq2.AllowAutoRedirect = $true
        $dlReq2.Timeout = 30000; $dlReq2.ReadWriteTimeout = 60000
        if ($cc) { $dlReq2.CookieContainer = $cc }
        $dlResp2 = $dlReq2.GetResponse()
        $totalSize = $dlResp2.ContentLength
        $str2 = $dlResp2.GetResponseStream(); $buf2 = New-Object byte[] 262144
        $fs2 = [System.IO.File]::Create($outFile); $tr = 0; $lp = -1
        try { while (($n2 = $str2.Read($buf2, 0, $buf2.Length)) -gt 0) { $fs2.Write($buf2, 0, $n2); $tr += $n2; if ($totalSize -gt 0 -and $progressBar) { $pct = $progressStart + [math]::Min($progressEnd, [math]::Round(($progressEnd - $progressStart) * $tr / $totalSize)); if ($pct -ne $lp) { $progressBar.Value = $pct; $lp = $pct; [System.Windows.Forms.Application]::DoEvents() } } else { [System.Windows.Forms.Application]::DoEvents() } } }
        finally { $str2.Close(); $fs2.Close(); $dlResp2.Close() }
        return
    }
    $connections = if ($totalSize -lt 5MB) { 1 } elseif ($totalSize -lt 50MB) { 4 } elseif ($totalSize -lt 500MB) { 8 } else { 16 }
    if ($connections -le 1) {
        $dlReq3 = [System.Net.HttpWebRequest]::Create($dlUrl)
        $dlReq3.Method = "GET"; $dlReq3.UserAgent = $ua; $dlReq3.AllowAutoRedirect = $true
        $dlReq3.Timeout = 120000; $dlReq3.ReadWriteTimeout = 120000
        $dlReq3.ServicePoint.Expect100Continue = $false; $dlReq3.ServicePoint.UseNagleAlgorithm = $false
        $dlReq3.ProtocolVersion = [System.Net.HttpVersion]::Version11; $dlReq3.KeepAlive = $true
        if ($cc) { $dlReq3.CookieContainer = $cc }
        $dlResp3 = $dlReq3.GetResponse()
        $str3 = $dlResp3.GetResponseStream(); $buf3 = New-Object byte[] 262144
        $fs3 = [System.IO.File]::Create($outFile); $tr3 = 0; $lp3 = -1
        try { while (($n3 = $str3.Read($buf3, 0, $buf3.Length)) -gt 0) { $fs3.Write($buf3, 0, $n3); $tr3 += $n3; if ($progressBar) { $pct = $progressStart + [math]::Min($progressEnd, [math]::Round(($progressEnd - $progressStart) * $tr3 / $totalSize)); if ($pct -ne $lp3) { $progressBar.Value = $pct; $lp3 = $pct; [System.Windows.Forms.Application]::DoEvents() } } else { [System.Windows.Forms.Application]::DoEvents() } } }
        finally { $str3.Close(); $fs3.Close(); $dlResp3.Close() }
        return
    }
    $chunkSize = [math]::Ceiling($totalSize / $connections)
    $tempDir = [System.IO.Path]::GetTempPath()
    $fileBase = [System.IO.Path]::GetFileNameWithoutExtension($outFile) + "_mfdl"
    $chunkFiles = @(); $runspaces = @(); $maxRetries = 3; $bufSize = 262144
    for ($i = 0; $i -lt $connections; $i++) {
        $start = $i * $chunkSize
        if ($start -ge $totalSize) { break }
        $end = [math]::Min($start + $chunkSize - 1, $totalSize - 1)
        $chunkFile = Join-Path $tempDir "${fileBase}_${i}.tmp"
        $chunkFiles += $chunkFile
        $cs = { param($u, $s, $e, $o, $ua2, $cc2, $bs, $mr)
            $le = $null
            for ($a = 1; $a -le $mr; $a++) {
                try {
                    $r = [System.Net.HttpWebRequest]::Create($u)
                    $r.Method = "GET"; $r.UserAgent = $ua2; $r.AllowAutoRedirect = $true
                    $r.Timeout = 120000; $r.ReadWriteTimeout = 120000
                    $r.ServicePoint.Expect100Continue = $false; $r.ServicePoint.UseNagleAlgorithm = $false
                    $r.ProtocolVersion = [System.Net.HttpVersion]::Version11; $r.KeepAlive = $true
                    if ($cc2) { $r.CookieContainer = $cc2 }
                    $r.AddRange($s, $e)
                    $rp = $r.GetResponse()
                    $f = [System.IO.File]::Create($o)
                    $st = $rp.GetResponseStream(); $b = New-Object byte[] $bs
                    while (($nr = $st.Read($b, 0, $bs)) -gt 0) { $f.Write($b, 0, $nr) }
                    $f.Close(); $st.Close(); $rp.Close()
                    return
                } catch { $le = $_; if (Test-Path $o) { Remove-Item $o -Force -ErrorAction SilentlyContinue } }
            }
            throw "Chunk failed after $mr attempts: $le"
        }
        $ps = [powershell]::Create(); $rs = [RunspaceFactory]::CreateRunspace()
        $ps.Runspace = $rs; $rs.Open()
        [void]$ps.AddScript($cs).AddArgument($dlUrl).AddArgument([long]$start).AddArgument([long]$end).AddArgument($chunkFile).AddArgument($ua).AddArgument($cc).AddArgument($bufSize).AddArgument($maxRetries)
        $runspaces += @{ps=$ps;handle=$ps.BeginInvoke();file=$chunkFile;rs=$rs}
    }
    $chunkErrors = @(); $completed = 0; $totalChunks = $runspaces.Count
    foreach ($rs2 in $runspaces) {
        try { $rs2.ps.EndInvoke($rs2.handle); $completed++ }
        catch { $chunkErrors += "[$($rs2.file)] $($_.Exception.Message)" }
        $rs2.ps.Dispose(); $rs2.rs.Dispose()
        if ($progressBar) { $pct = $progressStart + [math]::Min($progressEnd, [math]::Round(($progressEnd - $progressStart) * $completed / $totalChunks)); $progressBar.Value = $pct; [System.Windows.Forms.Application]::DoEvents() }
    }
    if ($chunkErrors.Count -gt 0) {
        foreach ($cf in $chunkFiles) { if (Test-Path $cf) { Remove-Item $cf -Force -ErrorAction SilentlyContinue } }
        throw "Error en descarga segmentada: $($chunkErrors -join '; ')"
    }
    $fsOut = [System.IO.File]::Create($outFile)
    $mergeBuf = New-Object byte[] 1048576
    foreach ($cf in $chunkFiles) {
        $fsIn = [System.IO.File]::OpenRead($cf)
        while (($nm = $fsIn.Read($mergeBuf, 0, $mergeBuf.Length)) -gt 0) { $fsOut.Write($mergeBuf, 0, $nm) }
        $fsIn.Close()
    }
    $fsOut.Close()
    foreach ($cf in $chunkFiles) { Remove-Item $cf -Force -ErrorAction SilentlyContinue }
    $actualSize = (Get-Item $outFile).Length
    if ($actualSize -ne $totalSize) {
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
        throw "TamaÃ±o incorrecto: $actualSize vs $totalSize"
    }
    if ($progressBar) { $progressBar.Value = $progressEnd; [System.Windows.Forms.Application]::DoEvents() }
}

# ---- Extract and Install ----
function Extract-AndInstall {
    param([string]$zipPath, [string]$gameName = $null, $expirationDate = $null)
    $steamRoot = Get-SteamPath
    $luaDir = Join-Path $steamRoot "config\stplug-in"
    $luaDir2 = Join-Path $steamRoot "config\lua"
    $manifestDir = Join-Path $steamRoot "config\depotcache"
    if (-not (Test-Path $luaDir)) { New-Item -ItemType Directory -Path $luaDir -Force | Out-Null }
    if (-not (Test-Path $luaDir2)) { New-Item -ItemType Directory -Path $luaDir2 -Force | Out-Null }
    if (-not (Test-Path $manifestDir)) { New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null }
    $tempDir = Join-Path $env:TEMP "bsmap_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $result = @{ lua = @(); manifest = @(); steamRoot = $steamRoot }
    try {
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        if ($gameName -and $expirationDate) {
            $header = "-- BSMAP_EXPIRES:$($expirationDate.ToString('yyyy-MM-ddTHH:mm:ss'))`n-- BSMAP_GAME:$gameName`n"
            Get-ChildItem -Path $tempDir -Recurse -Filter *.lua | ForEach-Object {
                try { $c = [System.IO.File]::ReadAllText($_.FullName); [System.IO.File]::WriteAllText($_.FullName, $header + $c) } catch {}
            }
        }
        Get-ChildItem -Path $tempDir -Recurse -Filter *.lua | ForEach-Object { Copy-Item -Path $_.FullName -Destination $luaDir -Force; Copy-Item -Path $_.FullName -Destination $luaDir2 -Force; $result.lua += $_.Name }
        Get-ChildItem -Path $tempDir -Recurse -Filter *.manifest | ForEach-Object { Copy-Item -Path $_.FullName -Destination $manifestDir -Force; $result.manifest += $_.Name }
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $result
}

# ---- Game matching helpers ----
$WORKING_GAMES_FILE = Join-Path $env:LOCALAPPDATA "bsmap_working_games.json"
$AUTO_FIXED_FILE = Join-Path $env:LOCALAPPDATA "bsmap_auto_fixed.json"
$FIX_MANIFEST_FILE = Join-Path $env:LOCALAPPDATA "bsmap_fix_manifest.json"
$AUTO_FIX_EXCLUSIONS = @("resident evil 4", "re4")

function Expand-CamelCase {
    param([string]$s)
    $parts = @([regex]::Split($s, '(?<=[a-z])(?=[A-Z0-9])|(?<=[A-Z0-9])(?=[a-z])|[\s\._-]+') | Where-Object { $_ -and $_.Length -gt 0 })
    if ($parts.Count -le 1) { return $s }
    return ($parts | ForEach-Object { $_.ToLower() }) -join ' '
}

function Normalize-Name {
    param([string]$n)
    return ($n -replace '[^a-z0-9 ]', '').ToLower().Trim()
}

function Get-LevenshteinDistance {
    param([string]$a, [string]$b)
    $n = $a.Length; $m = $b.Length
    if ($n -eq 0) { return $m }; if ($m -eq 0) { return $n }
    $prev = New-Object int[] ($m + 1)
    $curr = New-Object int[] ($m + 1)
    for ($j = 0; $j -le $m; $j++) { $prev[$j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        $curr[0] = $i
        for ($j = 1; $j -le $m; $j++) {
            $cost = if ($a[$i-1] -ceq $b[$j-1]) { 0 } else { 1 }
            $del = $prev[$j] + 1; $ins = $curr[$j-1] + 1; $sub = $prev[$j-1] + $cost
            $min = $del; if ($ins -lt $min) { $min = $ins }; if ($sub -lt $min) { $min = $sub }
            $curr[$j] = $min
        }
        $tmp = $prev; $prev = $curr; $curr = $tmp
    }
    return $prev[$m]
}

function Find-FixForGame {
    param([string]$gameFolderName, [hashtable]$fixes)
    if ($fixes.ContainsKey($gameFolderName)) { return $gameFolderName, $fixes[$gameFolderName] }
    $gfn = Normalize-Name $gameFolderName
    $gfnExpanded = Normalize-Name (Expand-CamelCase $gameFolderName)
    $bestFix = $null; $bestUrl = $null; $bestScore = 0
    foreach ($f in $fixes.Keys) {
        $ffn = Normalize-Name $f
        $ffnExpanded = Normalize-Name (Expand-CamelCase $f)
        if ($ffn -eq $gfn) { return $f, $fixes[$f] }
        if ($ffnExpanded -eq $gfnExpanded) { return $f, $fixes[$f] }
        $useGfn = $gfnExpanded; $useFfn = $ffnExpanded
        $maxLen = [Math]::Max($useFfn.Length, $useGfn.Length)
        $minLen = [Math]::Min($useFfn.Length, $useGfn.Length)
        if ($useFfn -like "*$useGfn*" -or $useGfn -like "*$useFfn*") {
            $shorter = if ($useFfn.Length -le $useGfn.Length) { $useFfn } else { $useGfn }
            $longer = if ($useFfn.Length -gt $useGfn.Length) { $useFfn } else { $useGfn }
            $isPrefix = $longer.StartsWith($shorter) -and $longer.Length -gt $shorter.Length
            $extraLen = if ($isPrefix) { $longer.Length - $shorter.Length } else { 0 }
            if ($isPrefix -and $extraLen -ge [Math]::Floor($shorter.Length * 0.3)) { }
            elseif ($minLen -ge $maxLen * 0.4) { $s = $maxLen; if ($s -gt $bestScore) { $bestScore = $s; $bestFix = $f; $bestUrl = $fixes[$f] } }
            elseif ($shorter -notmatch '\s' -and $longer.EndsWith($shorter)) { $s = $maxLen; if ($s -gt $bestScore) { $bestScore = $s; $bestFix = $f; $bestUrl = $fixes[$f] } }
        }
    }
    return $bestFix, $bestUrl
}

function Apply-FixAutomatically {
    param([string]$gameFolderName, [string]$gamePath, [hashtable]$fixes)
    $fixName, $fixUrl = Find-FixForGame $gameFolderName $fixes
    if (-not $fixUrl) { return $false, "No hay reparacion disponible para $gameFolderName" }
    $zip = Join-Path $env:TEMP "auto_$(Get-Random).zip"
    try {
        Download-MediaFire $fixUrl $zip
        $extractedRelative = @()
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
            $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
            foreach ($entry in $z.Entries) { if ($entry.Name) { $extractedRelative += $entry.FullName } }
            $z.Dispose()
        } catch {}
        Expand-Archive -Path $zip -DestinationPath $gamePath -Force
        if ($extractedRelative.Count -gt 0) { Add-FixManifestEntry $gameFolderName $gamePath $extractedRelative }
        Add-WorkingGame $gameFolderName
        Add-AutoFixedGame $gameFolderName
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        return $true, "Reparacion '$fixName' aplicada correctamente a $gameFolderName"
    } catch {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        return $false, "Error al aplicar reparacion en $gameFolderName : $($_.Exception.Message)"
    }
}

function Get-WorkingGames {
    if (Test-Path $WORKING_GAMES_FILE) {
        try { $r = @(Get-Content $WORKING_GAMES_FILE -Raw | ConvertFrom-Json); return ,$r } catch {}
    }
    return @()
}

function Add-WorkingGame {
    param([string]$gameFolderName)
    $games = @(Get-WorkingGames)
    if ($games -notcontains $gameFolderName) { $games += $gameFolderName; $games | ConvertTo-Json | Set-Content $WORKING_GAMES_FILE -Force }
}

function Get-AutoFixedGames {
    if (Test-Path $AUTO_FIXED_FILE) {
        try { $list = @(Get-Content $AUTO_FIXED_FILE -Raw | ConvertFrom-Json); $r = @($list | Where-Object { -not (Should-ExcludeFromAutoFix $_) }); return ,$r } catch {}
    }
    return @()
}

function Add-AutoFixedGame {
    param([string]$gameFolderName)
    if (Should-ExcludeFromAutoFix $gameFolderName) { return }
    $games = @(Get-AutoFixedGames)
    if ($games -notcontains $gameFolderName) { $games += $gameFolderName; $games | ConvertTo-Json | Set-Content $AUTO_FIXED_FILE -Force }
}

function Should-ExcludeFromAutoFix {
    param([string]$gameName)
    $norm = Normalize-Name $gameName
    foreach ($ex in $AUTO_FIX_EXCLUSIONS) {
        if ($norm -match [regex]::Escape($ex)) { return $true }
        if ($norm -eq $ex) { return $true }
    }
    return $false
}

function Get-FixManifest {
    if (Test-Path $FIX_MANIFEST_FILE) { try { $r = @(Get-Content $FIX_MANIFEST_FILE -Raw | ConvertFrom-Json); return ,$r } catch {} }
    return @()
}

function Save-FixManifest {
    param([array]$manifest)
    $manifest | ConvertTo-Json | Set-Content $FIX_MANIFEST_FILE -Force
}

function Test-FixApplied {
    param([string]$gameName)
    $manifest = Get-FixManifest
    $entry = $manifest | Where-Object { $_ -is [PSCustomObject] -and $_.game -eq $gameName }
    if (-not $entry) { return $false }
    if (-not ($entry.game_root -and (Test-Path $entry.game_root))) { return $false }
    $allExist = $true
    foreach ($f in $entry.files) { $fp = Join-Path $entry.game_root $f; if (-not (Test-Path $fp)) { $allExist = $false; break } }
    return $allExist
}

function Add-FixManifestEntry {
    param([string]$gameName, [string]$gameRoot, [string[]]$newFiles)
    $manifest = Get-FixManifest
    $manifest = $manifest | Where-Object { $_ -is [PSCustomObject] -and $_.game -ne $gameName }
    $entry = [PSCustomObject]@{ game = $gameName; game_root = $gameRoot; files = @($newFiles) }
    $manifest += $entry
    Save-FixManifest $manifest
}

# ---- Direct activation (PARCHENEW, no code needed) ----
function Activar-Directo {
    try {
        $steamRoot = Get-SteamPath
        Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
        $zip = Join-Path $steamRoot "st_patch_$(Get-Random).zip"
        Download-MediaFire "https://github.com/bastisayes/Fixes-steam/raw/main/PARCHENEWw.zip" $zip
        Expand-Archive -Path $zip -DestinationPath $steamRoot -Force
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        if (Test-Path (Join-Path $steamRoot "steam.exe")) { Start-Process (Join-Path $steamRoot "steam.exe") }
        else { [System.Windows.Forms.MessageBox]::Show("No se pudo abrir Steam, abrelo manualmente.", "Aviso", "OK", "Warning") }
    } catch {
        Write-ErrorLog "Activar Directo" $_
        [System.Windows.Forms.MessageBox]::Show(($_ | Out-String), "Error Detallado", "OK", "Error")
    }
}

# ---- Repair helpers ----
function Get-FixesList {
    try {
        $r = Invoke-RestMethod -Uri "https://www.mediafire.com/api/1.5/folder/get_content.php?folder_key=3o9127pseyx49&response_format=json&content_type=files" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    } catch { return @{} }
    $fixes = @{}
    if ($r.response.folder_content.files) {
        foreach ($f in $r.response.folder_content.files) {
            $name = $f.filename -replace '\.zip$', ''
            $fixes[$name] = $f.links.normal_download
        }
    }
    return $fixes
}

function Get-InstalledGames {
    $games = @{}
    foreach ($lib in Get-SteamLibraries) {
        $common = Join-Path $lib "steamapps\common"
        if (Test-Path $common) {
            Get-ChildItem -LiteralPath $common -Directory -ErrorAction SilentlyContinue | ForEach-Object { $games[$_.Name] = $_.FullName }
        }
    }
    return $games
}

function Get-SteamLibraries {
    $steamRoot = Get-SteamPath
    $libs = @($steamRoot)
    $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        $v = Get-Content $vdf -Raw -ErrorAction SilentlyContinue
        [regex]::Matches($v, '"path"\s+"([^"]+)"') | ForEach-Object { $p = $_.Groups[1].Value; if (Test-Path $p) { $libs += $p } }
    }
    return $libs | Select-Object -Unique
}

function Find-GameFolder {
    param([string]$fixName, [hashtable]$games)
    $clean = $fixName -replace '(?i)\s*(UB|Ubisoft)?\s*(Bypass|Fix|Patch|Fix)\s*$', ''
    $clean = $clean -replace '(?i)\s*\(\d+\)\s*$', ''
    $clean = $clean -replace '_', ' '
    $clean = $clean.Trim()
    $fn = Normalize-Name $clean
    $fnWords = @($fn -split '\s+' | Where-Object { $_.Length -gt 0 })
    $bestMatch = $null; $bestScore = 0
    foreach ($g in $games.Keys) {
        $gfn = Normalize-Name $g
        $maxLen = [Math]::Max($fn.Length, $gfn.Length)
        $minLen = [Math]::Min($fn.Length, $gfn.Length)
        if ($fn -eq $gfn) { return $games[$g], $g }
        if ($fn -like "*$gfn*" -or $gfn -like "*$fn*") {
            $shorter = if ($fn.Length -le $gfn.Length) { $fn } else { $gfn }
            $longer = if ($fn.Length -gt $gfn.Length) { $fn } else { $gfn }
            if ($minLen -ge $maxLen * 0.6) { $score = $maxLen; if ($score -gt $bestScore) { $bestScore = $score; $bestMatch = $g } }
            elseif ($shorter -notmatch '\s' -and $longer.EndsWith($shorter)) { $score = $maxLen; if ($score -gt $bestScore) { $bestScore = $score; $bestMatch = $g } }
        }
        $gWords = @($gfn -split '\s+' | Where-Object { $_.Length -gt 0 })
        $common = 0
        foreach ($w in $fnWords) {
            foreach ($gw in $gWords) {
                if ($w -eq $gw) { $common++; break }
                if ($w -like "*$gw*" -or $gw -like "*$w*") { $common += 0.5; break }
            }
        }
        $total = [Math]::Max($fnWords.Count, $gWords.Count)
        if ($total -gt 0) {
            $ratio = $common / $total
            if ($ratio -ge 0.4 -and $ratio -gt $bestScore) { $bestScore = $ratio; $bestMatch = $g }
        }
        if ($maxLen -gt 3) {
            $dist = Get-LevenshteinDistance $fn $gfn
            $threshold = [Math]::Max(1, [Math]::Floor($maxLen * 0.2))
            if ($dist -le $threshold) { $score = $maxLen - $dist; if ($score -gt $bestScore) { $bestScore = $score; $bestMatch = $g } }
        }
    }
    if ($bestMatch) { return $games[$bestMatch], $bestMatch }
    return $null, $null
}

# ---- Countdown system ----
$script:countdownText = $null
$script:countdownTick = $null

function Start-Countdown {
    param([int]$durationSec, [datetime]$expDate, [string]$gameName)
    if ($script:countdownTick) { $script:countdownTick.Stop(); $script:countdownTick.Dispose() }
    $script:countdownTick = New-Object System.Windows.Forms.Timer
    $script:countdownTick.Interval = 1000
    $script:countdownTick.Tag = @{ endTime = $expDate; gameName = $gameName }
    $script:countdownTick.Add_Tick({
        $now = Get-Date; $end = $this.Tag.endTime; $g = $this.Tag.gameName
        $left = ($end - $now).TotalSeconds
        if ($left -le 0) {
            $this.Stop()
            $script:countdownText = $null
            Remove-ExpiredTimers | Out-Null
            [System.Windows.Forms.MessageBox]::Show("El tiempo para $g ha expirado.", "Tiempo Expirado", "OK", "Information")
        }
    })
    $script:countdownTick.Start()
}

# Timer list (backed by timers file)
$script:refreshTimers = New-Object System.Windows.Forms.Timer
$script:refreshTimers.Interval = 5000
$script:refreshTimers.Add_Tick({ Remove-ExpiredTimers | Out-Null; Sync-ActiveCodesFromTimers; Refresh-Codes })
$script:refreshTimers.Start()

# URL checker every 60s
$script:urlChecker = New-Object System.Windows.Forms.Timer
$script:urlChecker.Interval = 60000
$script:urlChecker.Add_Tick({ Update-ServerUrl })
$script:urlChecker.Start()

# Download watcher variables
$script:fixesCacheTime = (Get-Date).AddDays(-1)
$script:fixesCache = @{}
$script:fixesJob = $null
$script:fixedNewGames = @{}
$script:fixJobs = @{}
$script:steamLibsCacheTime = Get-Date
$script:downloadPendingFixes = @{}
$script:knownDownloading = @{}
$script:commonFolderCache = @{}
$script:watcherSourceB64 = QWRkLVR5cGUgLUFzc2VtYmx5TmFtZSBTeXN0ZW0uV2luZG93cy5Gb3JtcwpBZGQtVHlwZSBAIgp1c2luZyBTeXN0ZW07CnVzaW5nIFN5c3RlbS5SdW50aW1lLkludGVyb3BTZXJ2aWNlczsKcHVibGljIGNsYXNzIFcgewogICAgW0RsbEltcG9ydCgidXNlcjMyLmRsbCIpXSBwdWJsaWMgc3RhdGljIGV4dGVybiBpbnQgU2hvd1dpbmRvdyhpbnQgaCwgaW50IHMpOwogICAgW0RsbEltcG9ydCgia2VybmVsMzIuZGxsIildIHB1YmxpYyBzdGF0aWMgZXh0ZXJuIGludCBHZXRDb25zb2xlV2luZG93KCk7Cn0KIkAKW1ddOjpTaG93V2luZG93KFtXXTo6R2V0Q29uc29sZVdpbmRvdygpLCAwKSB8IE91dC1OdWxsCgokZm9ybSA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuRm9ybQokZm9ybS5UZXh0ID0gIlN0ZWFtIERvd25sb2FkIFdhdGNoZXIiCiRmb3JtLlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlNpemUoOTAwLCA2MDApCiRmb3JtLlN0YXJ0UG9zaXRpb24gPSAiQ2VudGVyU2NyZWVuIgokZm9ybS5XaW5kb3dTdGF0ZSA9ICJNYXhpbWl6ZWQiCiRmb3JtLkJhY2tDb2xvciA9ICIjMGQxMTE3IgokZm9ybS5Ub3BNb3N0ID0gJHRydWUKCiRzdGF0dXMgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLkxhYmVsCiRzdGF0dXMuTG9jYXRpb24gPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlBvaW50KDIwLCA4KQokc3RhdHVzLlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlNpemUoODUwLCAyMikKJHN0YXR1cy5UZXh0ID0gIkluaWNpYW5kby4uLiIKJHN0YXR1cy5Gb3JlQ29sb3IgPSAiIzAwZDRmZiIKJHN0YXR1cy5Gb250ID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJDb25zb2xhcyIsIDExLCBbU3lzdGVtLkRyYXdpbmcuRm9udFN0eWxlXTo6Qm9sZCkKJGZvcm0uQ29udHJvbHMuQWRkKCRzdGF0dXMpCgokcHJvZ3Jlc3NCYXIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlByb2dyZXNzQmFyCiRwcm9ncmVzc0Jhci5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoMjAsIDM0KQokcHJvZ3Jlc3NCYXIuU2l6ZSA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuU2l6ZSg2NTAsIDE4KQokcHJvZ3Jlc3NCYXIuU3R5bGUgPSAiQ29udGludW91cyIKJHByb2dyZXNzQmFyLkZvcmVDb2xvciA9ICIjMDBkNGZmIgokcHJvZ3Jlc3NCYXIuQmFja0NvbG9yID0gIiMwZDExMTciCiRwcm9ncmVzc0Jhci5WaXNpYmxlID0gJGZhbHNlCiRmb3JtLkNvbnRyb2xzLkFkZCgkcHJvZ3Jlc3NCYXIpCgokc3BlZWRMYWJlbCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuTGFiZWwKJHNwZWVkTGFiZWwuTG9jYXRpb24gPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlBvaW50KDY4MCwgMzQpCiRzcGVlZExhYmVsLlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlNpemUoMTkwLCAxOCkKJHNwZWVkTGFiZWwuVGV4dCA9ICIiCiRzcGVlZExhYmVsLkZvcmVDb2xvciA9ICIjMDBmZjg4Igokc3BlZWRMYWJlbC5Gb250ID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJDb25zb2xhcyIsIDksIFtTeXN0ZW0uRHJhd2luZy5Gb250U3R5bGVdOjpCb2xkKQokc3BlZWRMYWJlbC5UZXh0QWxpZ24gPSAiTWlkZGxlUmlnaHQiCiRzcGVlZExhYmVsLlZpc2libGUgPSAkZmFsc2UKJGZvcm0uQ29udHJvbHMuQWRkKCRzcGVlZExhYmVsKQoKJGxvZyA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVGV4dEJveAokbG9nLkxvY2F0aW9uID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Qb2ludCgyMCwgNTgpCiRsb2cuU2l6ZSA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuU2l6ZSg4NTAsIDQ5MikKJGxvZy5NdWx0aWxpbmUgPSAkdHJ1ZQokbG9nLlJlYWRPbmx5ID0gJHRydWUKJGxvZy5CYWNrQ29sb3IgPSAiIzBkMTExNyIKJGxvZy5Gb3JlQ29sb3IgPSAiI2MwYzBjMCIKJGxvZy5Gb250ID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJDb25zb2xhcyIsIDkpCiRsb2cuQm9yZGVyU3R5bGUgPSAiTm9uZSIKJGZvcm0uQ29udHJvbHMuQWRkKCRsb2cpCgokc2NyaXB0OmxnID0geyBwYXJhbShbc3RyaW5nXSR0KSAkbG9nLkFwcGVuZFRleHQoIiR0YHJgbiIpOyBbU3lzdGVtLldpbmRvd3MuRm9ybXMuQXBwbGljYXRpb25dOjpEb0V2ZW50cygpOyB0cnkgeyBBZGQtQ29udGVudCAtUGF0aCAoSm9pbi1QYXRoICRlbnY6VEVNUCAiYnNtYXBfd2F0Y2hlci5sb2ciKSAtVmFsdWUgJHQgLUVuY29kaW5nIFVURjggLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfSBjYXRjaCB7fSB9CiRzY3JpcHQ6c3QgPSB7IHBhcmFtKFtzdHJpbmddJHQsIFtzdHJpbmddJGM9IiMwMGQ0ZmYiKSAkc2NyaXB0OnN0YXR1cy5UZXh0ID0gJHQ7ICRzY3JpcHQ6c3RhdHVzLkZvcmVDb2xvciA9ICRjOyBbU3lzdGVtLldpbmRvd3MuRm9ybXMuQXBwbGljYXRpb25dOjpEb0V2ZW50cygpOyB0cnkgeyBBZGQtQ29udGVudCAtUGF0aCAoSm9pbi1QYXRoICRlbnY6VEVNUCAiYnNtYXBfd2F0Y2hlci5sb2ciKSAtVmFsdWUgIltTVEFUVVNdICR0IiAtRW5jb2RpbmcgVVRGOCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IGNhdGNoIHt9IH0KCiR1YSA9ICJNb3ppbGxhLzUuMCAoV2luZG93cyBOVCAxMC4wOyBXaW42NDsgeDY0KSBBcHBsZVdlYktpdC81MzcuMzYgKEtIVE1MLCBsaWtlIEdlY2tvKSBDaHJvbWUvMTIwLjAuMC4wIFNhZmFyaS81MzcuMzYiCgpmdW5jdGlvbiBHZXQtU3RlYW1QYXRoIHsKICAgICRwYXRocyA9IEAoCiAgICAgICAgKEdldC1JdGVtUHJvcGVydHkgLVBhdGggIkhLTE06XFNPRlRXQVJFXFdPVzY0MzJOb2RlXFZhbHZlXFN0ZWFtIiAtTmFtZSBJbnN0YWxsUGF0aCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuSW5zdGFsbFBhdGgsCiAgICAgICAgKEdldC1JdGVtUHJvcGVydHkgLVBhdGggIkhLTE06XFNPRlRXQVJFXFZhbHZlXFN0ZWFtIiAtTmFtZSBJbnN0YWxsUGF0aCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuSW5zdGFsbFBhdGgsCiAgICAgICAgKEdldC1JdGVtUHJvcGVydHkgLVBhdGggIkhLQ1U6XFNPRlRXQVJFXFZhbHZlXFN0ZWFtIiAtTmFtZSBTdGVhbVBhdGggLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLlN0ZWFtUGF0aCwKICAgICAgICAiJHtlbnY6UHJvZ3JhbUZpbGVzKHg4Nil9XFN0ZWFtIiwKICAgICAgICAiJHtlbnY6UHJvZ3JhbUZpbGVzKHg4Nil9XFN0ZWFtbSIsCiAgICAgICAgIiRlbnY6UHJvZ3JhbUZpbGVzXFN0ZWFtIgogICAgKQogICAgZm9yZWFjaCAoJHAgaW4gJHBhdGhzKSB7IGlmICgkcCAtYW5kIChUZXN0LVBhdGggJHApIC1hbmQgKFRlc3QtUGF0aCAoSm9pbi1QYXRoICRwICJzdGVhbS5leGUiKSkpIHsgcmV0dXJuICRwIH0gfQogICAgZm9yZWFjaCAoJHAgaW4gJHBhdGhzKSB7IGlmICgkcCAtYW5kIChUZXN0LVBhdGggJHApKSB7IHJldHVybiAkcCB9IH0KICAgIHJldHVybiAkbnVsbAp9CgpmdW5jdGlvbiBHZXQtU3RlYW1MaWJyYXJpZXMgewogICAgJHN0ZWFtUm9vdCA9IEdldC1TdGVhbVBhdGgKICAgIGlmICgtbm90ICRzdGVhbVJvb3QpIHsgcmV0dXJuIEAoKSB9CiAgICAkbGlicyA9IEAoJHN0ZWFtUm9vdCkKICAgICR2ZGYgPSBKb2luLVBhdGggJHN0ZWFtUm9vdCAic3RlYW1hcHBzXGxpYnJhcnlmb2xkZXJzLnZkZiIKICAgIGlmIChUZXN0LVBhdGggJHZkZikgewogICAgICAgICR2ID0gR2V0LUNvbnRlbnQgJHZkZiAtUmF3IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgW3JlZ2V4XTo6TWF0Y2hlcygkdiwgJyJwYXRoIlxzKyIoW14iXSspIicpIHwgRm9yRWFjaC1PYmplY3QgeyAkcCA9ICRfLkdyb3Vwc1sxXS5WYWx1ZSAtcmVwbGFjZSAnXFxcXCcsICdcJzsgaWYgKFRlc3QtUGF0aCAkcCkgeyAkbGlicyArPSAkcCB9IH0KICAgIH0KICAgIHJldHVybiAoJGxpYnMgfCBTZWxlY3QtT2JqZWN0IC1VbmlxdWUpCn0KCmZ1bmN0aW9uIEdldC1BcHBOYW1lIHsKICAgIHBhcmFtKFtzdHJpbmddJGFwcGlkLCBbc3RyaW5nW11dJGxpYnMpCiAgICBmb3JlYWNoICgkc2wgaW4gJGxpYnMpIHsKICAgICAgICAkYWNmID0gSm9pbi1QYXRoIChKb2luLVBhdGggJHNsICJzdGVhbWFwcHMiKSAiYXBwbWFuaWZlc3RfJGFwcGlkLmFjZiIKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRhY2YpKSB7IGNvbnRpbnVlIH0KICAgICAgICB0cnkgewogICAgICAgICAgICAkcmF3ID0gW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQoJGFjZikKICAgICAgICAgICAgaWYgKCRyYXcgLW1hdGNoICcibmFtZSJccysiKFteIl0rKSInKSB7IHJldHVybiAkTWF0Y2hlc1sxXS5UcmltKCkgfQogICAgICAgICAgICBpZiAoJHJhdyAtbWF0Y2ggJyJpbnN0YWxsZGlyIlxzKyIoW14iXSspIicpIHsgcmV0dXJuICRNYXRjaGVzWzFdLlRyaW0oKSB9CiAgICAgICAgfSBjYXRjaCB7fQogICAgfQogICAgdHJ5IHsKICAgICAgICAkciA9IEludm9rZS1SZXN0TWV0aG9kIC1VcmkgImh0dHBzOi8vc3RvcmUuc3RlYW1wb3dlcmVkLmNvbS9hcGkvYXBwZGV0YWlscz9hcHBpZHM9JGFwcGlkIiAtVXNlQmFzaWNQYXJzaW5nIC1UaW1lb3V0U2VjIDUgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICBpZiAoJHIuJGFwcGlkLnN1Y2Nlc3MgLWVxICR0cnVlIC1hbmQgJHIuJGFwcGlkLmRhdGEubmFtZSkgeyByZXR1cm4gKCRyLiRhcHBpZC5kYXRhLm5hbWUpLlRyaW0oKSB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gJG51bGwKfQoKZnVuY3Rpb24gRmluZC1GaXggewogICAgcGFyYW0oW3N0cmluZ10kbmFtZSkKICAgIGlmICgkZml4ZXNDYWNoZS5Db3VudCAtZXEgMCkgeyByZXR1cm4gJG51bGwgfQogICAgaWYgKCRmaXhlc0NhY2hlLkNvbnRhaW5zS2V5KCRuYW1lKSkgeyByZXR1cm4gJGZpeGVzQ2FjaGVbJG5hbWVdIH0KICAgICRuMiA9ICgkbmFtZSAtcmVwbGFjZSAnW15hLXpBLVowLTldJywgJycpLlRvTG93ZXIoKQogICAgZm9yZWFjaCAoJGtleSBpbiAkZml4ZXNDYWNoZS5LZXlzKSB7CiAgICAgICAgaWYgKCgka2V5IC1yZXBsYWNlICdbXmEtekEtWjAtOV0nLCAnJykuVG9Mb3dlcigpIC1lcSAkbjIpIHsgcmV0dXJuICRmaXhlc0NhY2hlWyRrZXldIH0KICAgIH0KICAgICRjbGVhbiA9ICRuYW1lIC1yZXBsYWNlICdccypcKFteKV0qXCknLCAnJyAtcmVwbGFjZSAnXHMrJywgJyAnCiAgICAkbmMgPSAoJGNsZWFuIC1yZXBsYWNlICdbXmEtekEtWjAtOV0nLCAnJykuVG9Mb3dlcigpCiAgICBmb3JlYWNoICgka2V5IGluICRmaXhlc0NhY2hlLktleXMpIHsKICAgICAgICAka2IgPSAka2V5IC1yZXBsYWNlICdccypcKFteKV0qXCknLCAnJyAtcmVwbGFjZSAnXHMrJywgJyAnCiAgICAgICAgaWYgKCgka2IgLXJlcGxhY2UgJ1teYS16QS1aMC05XScsICcnKS5Ub0xvd2VyKCkgLWVxICRuYykgeyByZXR1cm4gJGZpeGVzQ2FjaGVbJGtleV0gfQogICAgfQogICAgIyBGYWxsYmFjazogZnV6enkgbWF0Y2hpbmcgcG9yIHNpIGxvcyBub21icmVzIG5vIGNvaW5jaWRlbiBleGFjdGFtZW50ZQogICAgJGJlc3RLZXkgPSAkbnVsbDsgJGJlc3RQY3QgPSAwCiAgICBmb3JlYWNoICgka2V5IGluICRmaXhlc0NhY2hlLktleXMpIHsKICAgICAgICAkcGN0ID0gR2V0LVNpbWlsYXJpdHkgJG5hbWUgJGtleQogICAgICAgIGlmICgkcGN0IC1ndCAkYmVzdFBjdCkgeyAkYmVzdFBjdCA9ICRwY3Q7ICRiZXN0S2V5ID0gJGtleSB9CiAgICB9CiAgICBpZiAoJGJlc3RQY3QgLWdlIDUwKSB7IHJldHVybiAkZml4ZXNDYWNoZVskYmVzdEtleV0gfQogICAgcmV0dXJuICRudWxsCn0KCmZ1bmN0aW9uIEdldC1TaW1pbGFyaXR5IHsKICAgIHBhcmFtKFtzdHJpbmddJGEsIFtzdHJpbmddJGIpCiAgICAkYSA9ICgoJGEgLXJlcGxhY2UgJ1teYS16QS1aMC05XHNdJywgJyAnKSAtcmVwbGFjZSAnXHMrJywgJyAnKS5UcmltKCkuVG9Mb3dlcigpCiAgICAkYiA9ICgoJGIgLXJlcGxhY2UgJ1teYS16QS1aMC05XHNdJywgJyAnKSAtcmVwbGFjZSAnXHMrJywgJyAnKS5UcmltKCkuVG9Mb3dlcigpCiAgICAkbGEgPSAkYS5MZW5ndGg7ICRsYiA9ICRiLkxlbmd0aAogICAgaWYgKCRsYSAtZXEgMCAtb3IgJGxiIC1lcSAwKSB7IHJldHVybiAwIH0KICAgICRtID0gTmV3LU9iamVjdCAnaW50WyxdJyAoJGxhICsgMSksICgkbGIgKyAxKQogICAgZm9yICgkaSA9IDA7ICRpIC1sZSAkbGE7ICRpKyspIHsgJG1bJGksMF0gPSAkaSB9CiAgICBmb3IgKCRqID0gMDsgJGogLWxlICRsYjsgJGorKykgeyAkbVswLCRqXSA9ICRqIH0KICAgIGZvciAoJGkgPSAxOyAkaSAtbGUgJGxhOyAkaSsrKSB7CiAgICAgICAgZm9yICgkaiA9IDE7ICRqIC1sZSAkbGI7ICRqKyspIHsKICAgICAgICAgICAgJGkxID0gJGkgLSAxOyAkajEgPSAkaiAtIDEKICAgICAgICAgICAgJGMgPSBpZiAoJGFbJGkxXSAtZXEgJGJbJGoxXSkgeyAwIH0gZWxzZSB7IDEgfQogICAgICAgICAgICAkZGVsID0gJG1bJGkxLCRqXSArIDE7ICRpbnMgPSAkbVskaSwkajFdICsgMTsgJHN1YiA9ICRtWyRpMSwkajFdICsgJGMKICAgICAgICAgICAgJG1bJGksJGpdID0gW21hdGhdOjpNaW4oW21hdGhdOjpNaW4oJGRlbCwgJGlucyksICRzdWIpCiAgICAgICAgfQogICAgfQogICAgJG1heExlbiA9IFttYXRoXTo6TWF4KCRsYSwgJGxiKQogICAgcmV0dXJuIFttYXRoXTo6Um91bmQoKDEgLSAkbVskbGEsJGxiXSAvICRtYXhMZW4pICogMTAwKQp9CgpmdW5jdGlvbiBOb3JtYWxpemUtTmFtZSB7CiAgICBwYXJhbShbc3RyaW5nXSRuKQogICAgcmV0dXJuICgkbiAtcmVwbGFjZSAnOicsICcnIC1yZXBsYWNlICdccysnLCAnICcpLlRyaW0oKQp9CgpmdW5jdGlvbiBGaW5kLUNvbW1vbkZvbGRlciB7CiAgICBwYXJhbShbc3RyaW5nXSRuYW1lLCBbc3RyaW5nW11dJGxpYnMpCiAgICAkYmVzdCA9ICRudWxsOyAkYmVzdFBjdCA9IDAKICAgICRuTm9ybSA9ICgoJG5hbWUgLXJlcGxhY2UgJ1teYS16QS1aMC05XHNdJywgJyAnKSAtcmVwbGFjZSAnXHMrJywgJyAnKS5UcmltKCkuVG9Mb3dlcigpCiAgICBmb3JlYWNoICgkc2wgaW4gJGxpYnMpIHsKICAgICAgICAkY3AgPSBKb2luLVBhdGggJHNsICJzdGVhbWFwcHNcY29tbW9uIgogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRjcCkpIHsgY29udGludWUgfQogICAgICAgIHRyeSB7CiAgICAgICAgICAgIGZvcmVhY2ggKCRkIGluIFtTeXN0ZW0uSU8uRGlyZWN0b3J5XTo6R2V0RGlyZWN0b3JpZXMoJGNwKSkgewogICAgICAgICAgICAgICAgJGZuID0gW1N5c3RlbS5JTy5QYXRoXTo6R2V0RmlsZU5hbWUoJGQpCiAgICAgICAgICAgICAgICAkZm5Ob3JtID0gKCgkZm4gLXJlcGxhY2UgJ1teYS16QS1aMC05XHNdJywgJyAnKSAtcmVwbGFjZSAnXHMrJywgJyAnKS5UcmltKCkuVG9Mb3dlcigpCiAgICAgICAgICAgICAgICBpZiAoJGZuTm9ybS5Db250YWlucygkbk5vcm0pIC1vciAkbk5vcm0uQ29udGFpbnMoJGZuTm9ybSkpIHsgcmV0dXJuICRkIH0KICAgICAgICAgICAgICAgICRwY3QgPSBHZXQtU2ltaWxhcml0eSAkbmFtZSAkZm4KICAgICAgICAgICAgICAgIGlmICgkcGN0IC1ndCAkYmVzdFBjdCkgeyAkYmVzdFBjdCA9ICRwY3Q7ICRiZXN0ID0gJGQgfQogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7IH0KICAgIH0KICAgIGlmICgkYmVzdFBjdCAtZ2UgNTApIHsgcmV0dXJuICRiZXN0IH0KICAgIHJldHVybiAkbnVsbAp9CgpmdW5jdGlvbiBTdGFydC1HaXRIdWJEb3dubG9hZCB7CiAgICBwYXJhbSgKICAgICAgICBbc3RyaW5nXSRVcmwsCiAgICAgICAgW3N0cmluZ10kT3V0RmlsZSwKICAgICAgICBbc3RyaW5nXSRVc2VyQWdlbnQsCiAgICAgICAgW2ludF0kQ29ubmVjdGlvbnMgPSAwLAogICAgICAgIFtsb25nXSRLbm93blNpemUgPSAwLAogICAgICAgICRQcm9ncmVzc0luZm8gPSAkbnVsbAogICAgKQogICAgdHJ5IHsKICAgICAgICBbU3lzdGVtLk5ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6U2VjdXJpdHlQcm90b2NvbCA9IFtTeXN0ZW0uTmV0LlNlY3VyaXR5UHJvdG9jb2xUeXBlXTo6VGxzMTIgLWJvciBbU3lzdGVtLk5ldC5TZWN1cml0eVByb3RvY29sVHlwZV06OlRsczExIC1ib3IgW1N5c3RlbS5OZXQuU2VjdXJpdHlQcm90b2NvbFR5cGVdOjpUbHMKICAgICAgICBbU3lzdGVtLk5ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6RGVmYXVsdENvbm5lY3Rpb25MaW1pdCA9IDI1NgogICAgICAgICR0b3RhbFNpemUgPSAkS25vd25TaXplCiAgICAgICAgaWYgKCR0b3RhbFNpemUgLWxlIDApIHsKICAgICAgICAgICAgJGhSZXEgPSBbU3lzdGVtLk5ldC5IdHRwV2ViUmVxdWVzdF06OkNyZWF0ZSgkVXJsKQogICAgICAgICAgICAkaFJlcS5NZXRob2QgPSAiSEVBRCI7ICRoUmVxLlVzZXJBZ2VudCA9ICRVc2VyQWdlbnQKICAgICAgICAgICAgJGhSZXEuQWxsb3dBdXRvUmVkaXJlY3QgPSAkdHJ1ZTsgICAgICAgICAgICAgJGhSZXEuVGltZW91dCA9IDUwMDAKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRoUmVzcCA9ICRoUmVxLkdldFJlc3BvbnNlKCkKICAgICAgICAgICAgICAgICR0b3RhbFNpemUgPSAkaFJlc3AuQ29udGVudExlbmd0aDsgJGhSZXNwLkNsb3NlKCkKICAgICAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICAgICBpZiAoJHRvdGFsU2l6ZSAtbGUgMCkgewogICAgICAgICAgICAgICAgJGdSZXEgPSBbU3lzdGVtLk5ldC5IdHRwV2ViUmVxdWVzdF06OkNyZWF0ZSgkVXJsKQogICAgICAgICAgICAgICAgJGdSZXEuTWV0aG9kID0gIkdFVCI7ICRnUmVxLlVzZXJBZ2VudCA9ICRVc2VyQWdlbnQKICAgICAgICAgICAgICAgICRnUmVxLkFsbG93QXV0b1JlZGlyZWN0ID0gJHRydWU7ICAgICAgICAgICAgICAgICAkZ1JlcS5UaW1lb3V0ID0gNTAwMAogICAgICAgICAgICAgICAgJGdSZXEuQWRkUmFuZ2UoMCwgMCkKICAgICAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAgICAgJGdSZXNwID0gJGdSZXEuR2V0UmVzcG9uc2UoKQogICAgICAgICAgICAgICAgICAgICRjciA9ICRnUmVzcC5IZWFkZXJzWyJDb250ZW50LVJhbmdlIl0KICAgICAgICAgICAgICAgICAgICBpZiAoJGNyIC1hbmQgJGNyIC1tYXRjaCAnLyhcZCspJykgeyAkdG90YWxTaXplID0gW2xvbmddJE1hdGNoZXNbMV0gfQogICAgICAgICAgICAgICAgICAgICRnUmVzcC5DbG9zZSgpCiAgICAgICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCR0b3RhbFNpemUgLWxlIDApIHsgcmV0dXJuIEB7b2s9JGZhbHNlO2Vycj0iSW52YWxpZCBzaXplOiAkdG90YWxTaXplIn0gfQogICAgICAgIH0KICAgICAgICBpZiAoJENvbm5lY3Rpb25zIC1sZSAwKSB7CiAgICAgICAgICAgIGlmICgkdG90YWxTaXplIC1sdCA1TUIpIHsgJENvbm5lY3Rpb25zID0gMSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHRvdGFsU2l6ZSAtbHQgNTBNQikgeyAkQ29ubmVjdGlvbnMgPSA0IH0KICAgICAgICAgICAgZWxzZWlmICgkdG90YWxTaXplIC1sdCA1MDBNQikgeyAkQ29ubmVjdGlvbnMgPSA4IH0KICAgICAgICAgICAgZWxzZSB7ICRDb25uZWN0aW9ucyA9IDE2IH0KICAgICAgICB9CiAgICAgICAgaWYgKCRQcm9ncmVzc0luZm8pIHsgJFByb2dyZXNzSW5mby5Ub3RhbCA9ICR0b3RhbFNpemUgfQogICAgICAgICR0ZW1wRGlyID0gW1N5c3RlbS5JTy5QYXRoXTo6R2V0VGVtcFBhdGgoKQogICAgICAgICRyYW5kb21UYWcgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRSYW5kb21GaWxlTmFtZSgpLlJlcGxhY2UoJy4nLCAnJykKICAgICAgICAkZmlsZUJhc2UgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRGaWxlTmFtZVdpdGhvdXRFeHRlbnNpb24oJE91dEZpbGUpICsgIl8ke3JhbmRvbVRhZ31fZ2hkIgogICAgICAgICRidWZTaXplID0gMjYyMTQ0OyAkbWF4UmV0cmllcyA9IDM7ICRjaHVua1NpemUgPSBbbWF0aF06OkNlaWxpbmcoJHRvdGFsU2l6ZSAvICRDb25uZWN0aW9ucykKICAgICAgICBpZiAoJENvbm5lY3Rpb25zIC1sZSAxIC1vciAkY2h1bmtTaXplIC1sdCA2NTUzNikgewogICAgICAgICAgICAkcmVxID0gW1N5c3RlbS5OZXQuSHR0cFdlYlJlcXVlc3RdOjpDcmVhdGUoJFVybCkKICAgICAgICAgICAgJHJlcS5NZXRob2QgPSAiR0VUIjsgJHJlcS5Vc2VyQWdlbnQgPSAkVXNlckFnZW50CiAgICAgICAgICAgICRyZXEuQWxsb3dBdXRvUmVkaXJlY3QgPSAkdHJ1ZTsgICAgICAgICAgICAgJHJlcS5UaW1lb3V0ID0gNjAwMDA7ICRyZXEuUmVhZFdyaXRlVGltZW91dCA9IDYwMDAwCiAgICAgICAgICAgICRyZXEuS2VlcEFsaXZlID0gJHRydWU7ICRyZXEuUGlwZWxpbmVkID0gJHRydWUKICAgICAgICAgICAgJHJlc3AgPSAkcmVxLkdldFJlc3BvbnNlKCk7ICRzdCA9ICRyZXNwLkdldFJlc3BvbnNlU3RyZWFtKCkKICAgICAgICAgICAgJGZzID0gW1N5c3RlbS5JTy5GaWxlXTo6Q3JlYXRlKCRPdXRGaWxlKQogICAgICAgICAgICAkYnVmID0gW1N5c3RlbS5BcnJheV06OkNyZWF0ZUluc3RhbmNlKFtTeXN0ZW0uQnl0ZV0sICRidWZTaXplKQogICAgICAgICAgICAkdG90YWxSZWFkID0gMDsgJHN3ID0gW1N5c3RlbS5EaWFnbm9zdGljcy5TdG9wd2F0Y2hdOjpTdGFydE5ldygpOyAkbGFzdFJlYWQgPSAwCiAgICAgICAgICAgIHdoaWxlICgoJG4gPSAkc3QuUmVhZCgkYnVmLCAwLCAkYnVmLkxlbmd0aCkpIC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkZnMuV3JpdGUoJGJ1ZiwgMCwgJG4pOyAkdG90YWxSZWFkICs9ICRuCiAgICAgICAgICAgICAgICBpZiAoJFByb2dyZXNzSW5mbyAtYW5kICR0b3RhbFNpemUgLWd0IDApIHsKICAgICAgICAgICAgICAgICAgICAkUHJvZ3Jlc3NJbmZvLlBlcmNlbnQgPSBbbWF0aF06Ok1pbig5OSwgW21hdGhdOjpSb3VuZCgkdG90YWxSZWFkIC8gJHRvdGFsU2l6ZSAqIDEwMCkpCiAgICAgICAgICAgICAgICAgICAgJFByb2dyZXNzSW5mby5DdXJyZW50ID0gJHRvdGFsUmVhZAogICAgICAgICAgICAgICAgICAgIGlmICgkc3cuRWxhcHNlZC5Ub3RhbFNlY29uZHMgLWdlIDEpIHsKICAgICAgICAgICAgICAgICAgICAgICAgJFByb2dyZXNzSW5mby5TcGVlZCA9IFtsb25nXSgoJHRvdGFsUmVhZCAtICRsYXN0UmVhZCkgLyAkc3cuRWxhcHNlZC5Ub3RhbFNlY29uZHMpCiAgICAgICAgICAgICAgICAgICAgICAgICRsYXN0UmVhZCA9ICR0b3RhbFJlYWQ7ICRzdy5SZXN0YXJ0KCkKICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJHN3LlN0b3AoKTsgJHN0LkNsb3NlKCk7ICRyZXNwLkNsb3NlKCk7ICRmcy5DbG9zZSgpCiAgICAgICAgICAgICRmaSA9IFtTeXN0ZW0uSU8uRmlsZV06Ok9wZW5SZWFkKCRPdXRGaWxlKTsgJGFjdHVhbFNpemUgPSAkZmkuTGVuZ3RoOyAkZmkuQ2xvc2UoKQogICAgICAgICAgICBpZiAoJHRvdGFsU2l6ZSAtZ3QgMCAtYW5kICRhY3R1YWxTaXplIC1uZSAkdG90YWxTaXplKSB7IHJldHVybiBAe29rPSRmYWxzZTtlcnI9IlNpemUgbWlzbWF0Y2g6ICRhY3R1YWxTaXplIHZzICR0b3RhbFNpemUifSB9CiAgICAgICAgICAgIGlmICgkUHJvZ3Jlc3NJbmZvKSB7ICRQcm9ncmVzc0luZm8uUGVyY2VudCA9IDEwMDsgJFByb2dyZXNzSW5mby5TcGVlZCA9IDAgfQogICAgICAgICAgICByZXR1cm4gQHtvaz0kdHJ1ZTtwYXRoPSRPdXRGaWxlO3NpemU9JGFjdHVhbFNpemV9CiAgICAgICAgfQoKICAgICAgICAkY2h1bmtDb3VudCA9IFttYXRoXTo6Q2VpbGluZyhbZG91YmxlXSR0b3RhbFNpemUgLyAkY2h1bmtTaXplKQogICAgICAgICRjaHVua0ZpbGVzID0gQCgpOyAkcnVuc3BhY2VzID0gQCgpCiAgICAgICAgaWYgKCRQcm9ncmVzc0luZm8pIHsgJFByb2dyZXNzSW5mby5Mb2dNc2cgPSAiSW5pY2lhbmRvICRDb25uZWN0aW9ucyBjb25leGlvbmVzICgkY2h1bmtDb3VudCBjaHVua3MpIiB9CiAgICAgICAgJGNzVGV4dCA9IEAnCnBhcmFtKCR1LCAkcywgJGUsICRvLCAkdWEyLCAkYnMsICRtcikKW1N5c3RlbS5OZXQuU2VydmljZVBvaW50TWFuYWdlcl06OlNlY3VyaXR5UHJvdG9jb2wgPSBbU3lzdGVtLk5ldC5TZWN1cml0eVByb3RvY29sVHlwZV06OlRsczEyIC1ib3IgW1N5c3RlbS5OZXQuU2VjdXJpdHlQcm90b2NvbFR5cGVdOjpUbHMxMSAtYm9yIFtTeXN0ZW0uTmV0LlNlY3VyaXR5UHJvdG9jb2xUeXBlXTo6VGxzCiRsZSA9ICRudWxsCmZvciAoJGEgPSAxOyAkYSAtbGUgJG1yOyAkYSsrKSB7CiAgICB0cnkgewogICAgICAgICRyID0gW1N5c3RlbS5OZXQuSHR0cFdlYlJlcXVlc3RdOjpDcmVhdGUoJHUpCiAgICAgICAgJHIuTWV0aG9kID0gIkdFVCI7ICRyLlVzZXJBZ2VudCA9ICR1YTIKICAgICAgICAkci5BbGxvd0F1dG9SZWRpcmVjdCA9ICR0cnVlOyAkci5UaW1lb3V0ID0gNjAwMDA7ICRyLlJlYWRXcml0ZVRpbWVvdXQgPSA2MDAwMAogICAgICAgICRyLktlZXBBbGl2ZSA9ICR0cnVlOyAkci5QaXBlbGluZWQgPSAkdHJ1ZQogICAgICAgICRyLkFkZFJhbmdlKCRzLCAkZSkKICAgICAgICAkcnAgPSAkci5HZXRSZXNwb25zZSgpOyAkZiA9IFtTeXN0ZW0uSU8uRmlsZV06OkNyZWF0ZSgkbykKICAgICAgICAkc3QgPSAkcnAuR2V0UmVzcG9uc2VTdHJlYW0oKTsgJGIgPSBbU3lzdGVtLkFycmF5XTo6Q3JlYXRlSW5zdGFuY2UoW1N5c3RlbS5CeXRlXSwgJGJzKQogICAgICAgIHdoaWxlICgoJG5yID0gJHN0LlJlYWQoJGIsIDAsICRicykpIC1ndCAwKSB7ICRmLldyaXRlKCRiLCAwLCAkbnIpIH0KICAgICAgICAkZi5DbG9zZSgpOyAkc3QuQ2xvc2UoKTsgJHJwLkNsb3NlKCk7IHJldHVybgogICAgfSBjYXRjaCB7ICRsZSA9ICRfOyB0cnkgeyBbU3lzdGVtLklPLkZpbGVdOjpEZWxldGUoJG8pIH0gY2F0Y2gge307IFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgKDUwMCAqICRhKSB9Cn0KdGhyb3cgIkNodW5rIGZhaWxlZCBhZnRlciAkbXIgYXR0ZW1wdHM6ICRsZSIKJ0AKICAgICAgICBmb3IgKCRpID0gMDsgJGkgLWx0ICRjaHVua0NvdW50OyAkaSsrKSB7CiAgICAgICAgICAgICRzdGFydCA9ICRpICogJGNodW5rU2l6ZQogICAgICAgICAgICBpZiAoJHN0YXJ0IC1nZSAkdG90YWxTaXplKSB7IGJyZWFrIH0KICAgICAgICAgICAgJGVuZCA9IFttYXRoXTo6TWluKCRzdGFydCArICRjaHVua1NpemUgLSAxLCAkdG90YWxTaXplIC0gMSkKICAgICAgICAgICAgJGNodW5rRmlsZSA9IFtTeXN0ZW0uSU8uUGF0aF06OkNvbWJpbmUoJHRlbXBEaXIsICIke2ZpbGVCYXNlfV8ke2l9LnRtcCIpCiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJGNodW5rRmlsZSkgeyBSZW1vdmUtSXRlbSAkY2h1bmtGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgICRjaHVua0ZpbGVzICs9ICRjaHVua0ZpbGUKICAgICAgICAgICAgJHBzID0gW3Bvd2Vyc2hlbGxdOjpDcmVhdGUoKQogICAgICAgICAgICAkcnMgPSBbUnVuc3BhY2VGYWN0b3J5XTo6Q3JlYXRlUnVuc3BhY2UoKQogICAgICAgICAgICAkcHMuUnVuc3BhY2UgPSAkcnM7ICRycy5PcGVuKCkKICAgICAgICAgICAgW3ZvaWRdJHBzLkFkZFNjcmlwdCgkY3NUZXh0KS5BZGRBcmd1bWVudCgkVXJsKS5BZGRBcmd1bWVudChbbG9uZ10kc3RhcnQpLkFkZEFyZ3VtZW50KFtsb25nXSRlbmQpLkFkZEFyZ3VtZW50KCRjaHVua0ZpbGUpLkFkZEFyZ3VtZW50KCRVc2VyQWdlbnQpLkFkZEFyZ3VtZW50KCRidWZTaXplKS5BZGRBcmd1bWVudCgkbWF4UmV0cmllcykKICAgICAgICAgICAgJHJ1bnNwYWNlcyArPSBAe3BzPSRwcztoYW5kbGU9JHBzLkJlZ2luSW52b2tlKCk7ZmlsZT0kY2h1bmtGaWxlO3JzPSRycztzdGFydD0kc3RhcnQ7ZW5kPSRlbmR9CiAgICAgICAgfQoKICAgICAgICAkc3cgPSBbU3lzdGVtLkRpYWdub3N0aWNzLlN0b3B3YXRjaF06OlN0YXJ0TmV3KCkKICAgICAgICAkY2h1bmtFcnJvcnMgPSBAKCk7ICRjb21wbGV0ZWQgPSAwOyAkdG90YWxDaHVua3MgPSAkcnVuc3BhY2VzLkNvdW50CiAgICAgICAgJGRvbmVNYXAgPSBAe30KICAgICAgICAkbGFzdEJ5dGVzID0gMDsgJGxhc3RTdyA9IFtTeXN0ZW0uRGlhZ25vc3RpY3MuU3RvcHdhdGNoXTo6U3RhcnROZXcoKQogICAgICAgIHdoaWxlICgkY29tcGxldGVkIC1sdCAkdG90YWxDaHVua3MpIHsKICAgICAgICAgICAgJGZvdW5kID0gJGZhbHNlCiAgICAgICAgICAgIGZvciAoJGkgPSAwOyAkaSAtbHQgJHRvdGFsQ2h1bmtzOyAkaSsrKSB7CiAgICAgICAgICAgICAgICBpZiAoJGRvbmVNYXAuQ29udGFpbnNLZXkoJGkpKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgICAgIGlmICgkcnVuc3BhY2VzWyRpXS5oYW5kbGUuSXNDb21wbGV0ZWQpIHsKICAgICAgICAgICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICAgICAkcnVuc3BhY2VzWyRpXS5wcy5FbmRJbnZva2UoJHJ1bnNwYWNlc1skaV0uaGFuZGxlKQogICAgICAgICAgICAgICAgICAgICAgICAkY0ZpbGVJbmZvID0gTmV3LU9iamVjdCBTeXN0ZW0uSU8uRmlsZUluZm8gJHJ1bnNwYWNlc1skaV0uZmlsZQogICAgICAgICAgICAgICAgICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRydW5zcGFjZXNbJGldLmZpbGUpIC1vciAkY0ZpbGVJbmZvLkxlbmd0aCAtbmUgKCRydW5zcGFjZXNbJGldLmVuZCAtICRydW5zcGFjZXNbJGldLnN0YXJ0ICsgMSkpIHsKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRocm93ICJDaHVuayBzaXplIG1pc21hdGNoIgogICAgICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgICAgICRjb21wbGV0ZWQrKwogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICBjYXRjaCB7ICRjaHVua0Vycm9ycyArPSAiWyQoJHJ1bnNwYWNlc1skaV0uZmlsZSldICQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIjsgJGNvbXBsZXRlZCsrIH0KICAgICAgICAgICAgICAgICAgICAkcnVuc3BhY2VzWyRpXS5wcy5EaXNwb3NlKCk7ICRydW5zcGFjZXNbJGldLnJzLkRpc3Bvc2UoKQogICAgICAgICAgICAgICAgICAgICRkb25lTWFwWyRpXSA9ICR0cnVlOyAkZm91bmQgPSAkdHJ1ZQogICAgICAgICAgICAgICAgICAgIGJyZWFrCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRQcm9ncmVzc0luZm8pIHsKICAgICAgICAgICAgICAgICRieXRlc05vdyA9IDAKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRjZiBpbiAkY2h1bmtGaWxlcykgewogICAgICAgICAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRmaTMgPSBOZXctT2JqZWN0IFN5c3RlbS5JTy5GaWxlSW5mbyAkY2YKICAgICAgICAgICAgICAgICAgICAgICAgaWYgKCRmaTMuRXhpc3RzKSB7ICRieXRlc05vdyArPSAkZmkzLkxlbmd0aCB9CiAgICAgICAgICAgICAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgJFByb2dyZXNzSW5mby5DdXJyZW50ID0gJGJ5dGVzTm93CiAgICAgICAgICAgICAgICBpZiAoJHRvdGFsU2l6ZSAtZ3QgMCkgeyAkUHJvZ3Jlc3NJbmZvLlBlcmNlbnQgPSBbbWF0aF06Ok1pbig5OSwgW21hdGhdOjpSb3VuZCgkYnl0ZXNOb3cgLyAkdG90YWxTaXplICogMTAwKSkgfQogICAgICAgICAgICAgICAgaWYgKCRsYXN0U3cuRWxhcHNlZE1pbGxpc2Vjb25kcyAtZ2UgMTAwMCkgewogICAgICAgICAgICAgICAgICAgICRkZWx0YSA9ICRieXRlc05vdyAtICRsYXN0Qnl0ZXMKICAgICAgICAgICAgICAgICAgICAkc2VjcyA9ICRsYXN0U3cuRWxhcHNlZE1pbGxpc2Vjb25kcyAvIDEwMDAKICAgICAgICAgICAgICAgICAgICBpZiAoJHNlY3MgLWd0IDAgLWFuZCAkZGVsdGEgLWdlIDApIHsgJFByb2dyZXNzSW5mby5TcGVlZCA9IFtsb25nXSgkZGVsdGEgLyAkc2VjcykgfQogICAgICAgICAgICAgICAgICAgICRsYXN0Qnl0ZXMgPSAkYnl0ZXNOb3c7ICRsYXN0U3cuUmVzdGFydCgpCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKC1ub3QgJGZvdW5kKSB7IFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgNTAwIH0KICAgICAgICB9CiAgICAgICAgJHN3LlN0b3AoKQogICAgICAgIGlmICgkY2h1bmtFcnJvcnMuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgZm9yZWFjaCAoJGNmIGluICRjaHVua0ZpbGVzKSB7IHRyeSB7IFtTeXN0ZW0uSU8uRmlsZV06OkRlbGV0ZSgkY2YpIH0gY2F0Y2gge30gfQogICAgICAgICAgICByZXR1cm4gQHtvaz0kZmFsc2U7ZXJyPSJDaHVuayBlcnJvcnM6ICQoJGNodW5rRXJyb3JzIC1qb2luICc7ICcpIn0KICAgICAgICB9CiAgICAgICAgJGZzMiA9IFtTeXN0ZW0uSU8uRmlsZV06OkNyZWF0ZSgkT3V0RmlsZSkKICAgICAgICAkbWVyZ2VCdWYgPSBbU3lzdGVtLkFycmF5XTo6Q3JlYXRlSW5zdGFuY2UoW1N5c3RlbS5CeXRlXSwgMTA0ODU3NikKICAgICAgICBmb3JlYWNoICgkY2YgaW4gJGNodW5rRmlsZXMpIHsKICAgICAgICAgICAgJGZzSW4gPSBbU3lzdGVtLklPLkZpbGVdOjpPcGVuUmVhZCgkY2YpCiAgICAgICAgICAgIHdoaWxlICgoJG5tID0gJGZzSW4uUmVhZCgkbWVyZ2VCdWYsIDAsICRtZXJnZUJ1Zi5MZW5ndGgpKSAtZ3QgMCkgeyAkZnMyLldyaXRlKCRtZXJnZUJ1ZiwgMCwgJG5tKSB9CiAgICAgICAgICAgICRmc0luLkNsb3NlKCkKICAgICAgICB9CiAgICAgICAgJGZzMi5DbG9zZSgpCiAgICAgICAgZm9yZWFjaCAoJGNmIGluICRjaHVua0ZpbGVzKSB7IHRyeSB7IFtTeXN0ZW0uSU8uRmlsZV06OkRlbGV0ZSgkY2YpIH0gY2F0Y2gge30gfQogICAgICAgICRmaTIgPSBbU3lzdGVtLklPLkZpbGVdOjpPcGVuUmVhZCgkT3V0RmlsZSk7ICRhY3R1YWxTaXplID0gJGZpMi5MZW5ndGg7ICRmaTIuQ2xvc2UoKQogICAgICAgIGlmICgkYWN0dWFsU2l6ZSAtbmUgJHRvdGFsU2l6ZSkgewogICAgICAgICAgICB0cnkgeyBbU3lzdGVtLklPLkZpbGVdOjpEZWxldGUoJE91dEZpbGUpIH0gY2F0Y2gge30KICAgICAgICAgICAgcmV0dXJuIEB7b2s9JGZhbHNlO2Vycj0iTWVyZ2VkIHNpemUgbWlzbWF0Y2g6IGdvdCAkYWN0dWFsU2l6ZSBleHBlY3RlZCAkdG90YWxTaXplIn0KICAgICAgICB9CiAgICAgICAgaWYgKCRQcm9ncmVzc0luZm8pIHsgJFByb2dyZXNzSW5mby5QZXJjZW50ID0gMTAwOyAkUHJvZ3Jlc3NJbmZvLlNwZWVkID0gMCB9CiAgICAgICAgcmV0dXJuIEB7b2s9JHRydWU7cGF0aD0kT3V0RmlsZTtzaXplPSR0b3RhbFNpemV9CiAgICB9IGNhdGNoIHsgcmV0dXJuIEB7b2s9JGZhbHNlO2Vycj0kXy5FeGNlcHRpb24uTWVzc2FnZX0gfQp9Cgokd2F0Y2hlckxvZyA9IEpvaW4tUGF0aCAkZW52OlRFTVAgImJzbWFwX3dhdGNoZXIubG9nIgp0cnkgeyBTZXQtQ29udGVudCAtUGF0aCAkd2F0Y2hlckxvZyAtVmFsdWUgIlskKEdldC1EYXRlIC1Gb3JtYXQgJ0hIOm1tOnNzJyldIFdhdGNoZXIgaW5pY2lhZG8iIC1FbmNvZGluZyBVVEY4IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30KJHN0ZWFtTGlicyA9IEdldC1TdGVhbUxpYnJhcmllcwppZiAoJHN0ZWFtTGlicy5Db3VudCAtZXEgMCkgeyAkc3RhdHVzLlRleHQgPSAiRVJST1I6IE5vIHNlIGVuY29udHJvIFN0ZWFtIjsgJHN0YXR1cy5Gb3JlQ29sb3IgPSAiI2Y4NTE0OSI7IFt2b2lkXSRmb3JtLlNob3dEaWFsb2coKTsgcmV0dXJuIH0KCiRsb2cuQXBwZW5kVGV4dCgiTGlicmVyaWFzOiAkKCRzdGVhbUxpYnMgLWpvaW4gJywgJylgcmBuIik7IFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5BcHBsaWNhdGlvbl06OkRvRXZlbnRzKCkKZm9yZWFjaCAoJHNsIGluICRzdGVhbUxpYnMpIHsgJGNwID0gSm9pbi1QYXRoICRzbCAic3RlYW1hcHBzXGNvbW1vbiI7ICRsb2cuQXBwZW5kVGV4dCgiICBjb21tb24gZW46ICRjcCAoJChpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkY3ApIHsgJ0VYSVNURScgfSBlbHNlIHsgJ05PIEVYSVNURScgfSkpYHJgbiIpOyBbU3lzdGVtLldpbmRvd3MuRm9ybXMuQXBwbGljYXRpb25dOjpEb0V2ZW50cygpIH0KCiR3YXRjaGVyID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5UaW1lcgokd2F0Y2hlci5JbnRlcnZhbCA9IDMwMDAKCiRrbm93bkRpcnMgPSBAe30KJHBlbmRpbmdKb2JzID0gQHt9CiRwZW5kaW5nRXh0cmFjdCA9IEB7fQokZml4ZXNDYWNoZSA9IEB7fQokZml4ZXNMb2FkZWQgPSAkZmFsc2UKJGFwaVJldHJ5VGljayA9IDAKJHRpY2tDb3VudCA9IDAKJGRvd25sb2FkUHJvZ3Jlc3MgPSAkbnVsbAokZG93bmxvYWROYW1lID0gJG51bGwKCiRmaXhlc0ZhbGxiYWNrID0gQCgKICAgIEB7Zm49IkFDT3JpZ2lucy56aXAiO3N6PTMwMTI0NDI2Nn0sCiAgICBAe2ZuPSJBc3Nhc2luLkNyZWVkLjIuemlwIjtzej0xNTI3OTI5MH0sCiAgICBAe2ZuPSJiaW4uV2F0Y2guZG9nLmxlZ2lvbi56aXAiO3N6PTQyMDgzNDc2NH0sCiAgICBAe2ZuPSJCbGFja01pdGhXdWtvbmcuemlwIjtzej0zMTE4MDQwMTV9LAogICAgQHtmbj0iQ2FsbC5vZi5EdXR5Li0uQmxhY2suT3BzLnppcCI7c3o9MTQwNTU0MDl9LAogICAgQHtmbj0iQ2FsbC5vZi5kdXR5LjIuTVcucmVtYXN0ZXIuemlwIjtzej05MTM2ODE1M30sCiAgICBAe2ZuPSJDYWxsLm9mLkR1dHkuNC5Nb2Rlcm4uV2FyZmFyZS56aXAiO3N6PTE0NTIyNDR9LAogICAgQHtmbj0iQ2FsbC5PZi5EdXR5LkJsYWNrLk9wcy4yLjIuZml4LnppcCI7c3o9NDQ2MjcxOX0sCiAgICBAe2ZuPSJDYWxsLm9mLkR1dHkuQmxhY2suT3BzLkNvbGQuV2FyLnppcCI7c3o9MzIwOTF9LAogICAgQHtmbj0iQ2FsbC5vZi5EdXR5LkJsYWNrLk9wcy5JSS56aXAiO3N6PTQ0NjM2NDd9LAogICAgQHtmbj0iQ2FsbC5vZi5EdXR5LkJsYWNrLk9wcy5JSUkuemlwIjtzej0xMzY4MTU0fSwKICAgIEB7Zm49IkNhbGwub2YuRHV0eS5JbmZpbml0ZS5XYXJmYXJlLnppcCI7c3o9NTEyMjgzMH0sCiAgICBAe2ZuPSJDYWxsLm9mLkR1dHkuTW9kZXJuLldhcmZhcmUuMi4yMDA5LjIuemlwIjtzej0yMTA2MzY3fSwKICAgIEB7Zm49IkNhbGwuT2YuRHV0eS5Nb2Rlcm4uV2FyZmFyZS4yMDE5LnppcCI7c3o9MjkyMDE4MzF9LAogICAgQHtmbj0iQ2FsbC5vZi5EdXR5Lk1vZGVybi5XYXJmYXJlLjMuMjAxMS56aXAiO3N6PTEwOTM2NzYxfSwKICAgIEB7Zm49IkNhbGwub2YuRHV0eS5WYW5ndWFyZC56aXAiO3N6PTI1NjQ3MzI3fSwKICAgIEB7Zm49IkYxLjIwMjEuemlwIjtzej0zMDk5MjA3MzZ9LAogICAgQHtmbj0iRjEuMjIuemlwIjtzej0yODM5MjgwOX0sCiAgICBAe2ZuPSJGYXIuQ3J5LjMuemlwIjtzej0zMzMxMDA5NH0sCiAgICBAe2ZuPSJGYXIuQ3J5LjQuemlwIjtzej01MDc0MjQ2N30sCiAgICBAe2ZuPSJGYXIuY3J5LjUuemlwIjtzej0xNDM5NTc1MTF9LAogICAgQHtmbj0iRmFyLkNyeS5OZXcuRG93bi56aXAiO3N6PTI2MjY3NTI4OH0sCiAgICBAe2ZuPSJGYXIuQ3J5LlByaW1hbC56aXAiO3N6PTIxOTg1fSwKICAgIEB7Zm49IkZpZmEuMjIuemlwIjtzej0zNjQzNjgwMjF9LAogICAgQHtmbj0iR29kLm9mLldhci5SYWduYXJvay56aXAiO3N6PTEzOTQwODM3fSwKICAgIEB7Zm49IkdUQS5TYW4uQW5kcmVhcy5UaGUuRGVmaW5pdGl2ZS5FZGl0aW9uLnppcCI7c3o9NTY5MTIwOTZ9LAogICAgQHtmbj0iR3RhaXYuemlwIjtzej0xMTIyNDQ4Nn0sCiAgICBAe2ZuPSJHVEFWLkVOSEFOQ0VELnppcCI7c3o9NzA3NDg4OTh9LAogICAgQHtmbj0iSGl0bWFuLkFic29sdXRpb24uemlwIjtzej0xNjczNDk3MX0sCiAgICBAe2ZuPSJIaXRtYW4uV29ybGQuT2YuQXNhc3Npbi56aXAiO3N6PTEyMzUxNTQwMH0sCiAgICBAe2ZuPSJMRUdPLkJhdG1hbi4tLkxlZ2FjeS5vZi50aGUuRGFyay5LbmlnaHQuemlwIjtzej0yMTYxNDY0MDR9LAogICAgQHtmbj0iTWV0YWwuZ2Vhci41LnppcCI7c3o9ODk3Njg5NjB9LAogICAgQHtmbj0iTW9ydGFsLktvbWJhdC5YLnppcCI7c3o9MTkxODUzNTJ9LAogICAgQHtmbj0iTmVlZC5Gb3IuU3BlZWQuSGVhdC56aXAiO3N6PTIwNzUyMTQzMX0sCiAgICBAe2ZuPSJOZWVkLkZvci5TcGVlZC5Nb3N0LldhbnRlZC56aXAiO3N6PTU3MDI5Nzl9LAogICAgQHtmbj0icHJhZ21hdGEuemlwIjtzej02MTU4ODk1fSwKICAgIEB7Zm49IlJlZC5EZWFkLlJlZGVtcHRpb24uMS5CeXBhc3MuemlwIjtzej0yMTIzNDM2NH0sCiAgICBAe2ZuPSJSZWQuRGVhZC5SZWRlbXB0aW9uLjIuemlwIjtzej04NDc5MzUxNn0sCiAgICBAe2ZuPSJSZXNpZGVudC5ldmlsLnJlcXVpZW0uemlwIjtzej0yOTc2NzQzMzN9LAogICAgQHtmbj0iU25pcGVyLkVsaXRlLjQuemlwIjtzej0xMjQyMDc5NjV9LAogICAgQHtmbj0ic3RlbGxhci5ibGFkZS56aXAiO3N6PTIwMDE3Nzk5OH0sCiAgICBAe2ZuPSJUaGUuQ3Jldy4yLnppcCI7c3o9NTI0NzI0Mjl9LAogICAgQHtmbj0iV2F0Y2guRG9ncy4yLnppcCI7c3o9MjMxODczODN9LAogICAgQHtmbj0iV2F0Y2guRG9ncy56aXAiO3N6PTQ1NDAxMjI2fQopCgokd2F0Y2hlci5BZGRfVGljayh7CiAgICAkc2NyaXB0OnRpY2tDb3VudCsrCiAgICB0cnkgewogICAgICAgIGlmICgkdGlja0NvdW50ICUgNDAgLWVxIDApIHsgJHNjcmlwdDpzdGVhbUxpYnMgPSBHZXQtU3RlYW1MaWJyYXJpZXMgfQogICAgICAgICMg4pSA4pSAIGNhcmdhciBjYXRhbG9nbyAobWF4IDEgdmV6IGNhZGEgMyBtaW51dG9zKSDilIDilIAKICAgICAgICBpZiAoLW5vdCAkc2NyaXB0OmZpeGVzTG9hZGVkIC1hbmQgJHNjcmlwdDp0aWNrQ291bnQgLWd0ICRzY3JpcHQ6YXBpUmV0cnlUaWNrKSB7CiAgICAgICAgICAgICRzY3JpcHQ6YXBpUmV0cnlUaWNrID0gJHNjcmlwdDp0aWNrQ291bnQgKyA2MAogICAgICAgICAgICAkb2sgPSAkZmFsc2UKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRqc29uVXJsID0gImh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9iYXN0aXNheWVzL0ZpeGVzLXN0ZWFtL21haW4vZml4ZXNfbGlzdC5qc29uIgogICAgICAgICAgICAgICAgJHdjID0gTmV3LU9iamVjdCBTeXN0ZW0uTmV0LldlYkNsaWVudDsgJGpzb25UZXh0ID0gJHdjLkRvd25sb2FkU3RyaW5nKCRqc29uVXJsKTsgJHdjLkRpc3Bvc2UoKQogICAgICAgICAgICAgICAgJHBhcnNlZCA9ICRqc29uVGV4dCB8IENvbnZlcnRGcm9tLUpzb24KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRmIGluICRwYXJzZWQpIHsKICAgICAgICAgICAgICAgICAgICAkbmFtZSA9ICRmLmZpbGVuYW1lIC1yZXBsYWNlICdcLnppcCQnLCAnJwogICAgICAgICAgICAgICAgICAgICRzY3JpcHQ6Zml4ZXNDYWNoZVskbmFtZV0gPSBAe3VybD0iaHR0cHM6Ly9naXRodWIuY29tL2Jhc3Rpc2F5ZXMvRml4ZXMtc3RlYW0vcmVsZWFzZXMvZG93bmxvYWQvYmFzdGlzc3MvJCgkZi5maWxlbmFtZSkiOyBzaXplPSRmLnNpemV9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAkb2sgPSAkdHJ1ZQogICAgICAgICAgICAgICAgJiAkc2NyaXB0OmxnICJDYXRhbG9nbyBmaXhlc19saXN0Lmpzb246ICQoJGZpeGVzQ2FjaGUuQ291bnQpIGZpeGVzIgogICAgICAgICAgICAgICAgdHJ5IHsgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KFtTeXN0ZW0uSU8uUGF0aF06OkNvbWJpbmUoW1N5c3RlbS5JTy5QYXRoXTo6R2V0VGVtcFBhdGgoKSwgImJzbWFwX2ZpeGxpc3QuY2FjaGUiKSwgJGpzb25UZXh0KSB9IGNhdGNoIHt9CiAgICAgICAgICAgIH0gY2F0Y2ggeyAmICRzY3JpcHQ6bGcgIkVSUk9SIGZpeGVzX2xpc3QuanNvbjogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiIH0KICAgICAgICAgICAgaWYgKC1ub3QgJG9rKSB7CiAgICAgICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICRjYWNoZUZpbGUgPSBbU3lzdGVtLklPLlBhdGhdOjpDb21iaW5lKFtTeXN0ZW0uSU8uUGF0aF06OkdldFRlbXBQYXRoKCksICJic21hcF9maXhsaXN0LmNhY2hlIikKICAgICAgICAgICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRjYWNoZUZpbGUpIHsKICAgICAgICAgICAgICAgICAgICAgICAgJGNhY2hlZCA9IEdldC1Db250ZW50ICRjYWNoZUZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24KICAgICAgICAgICAgICAgICAgICAgICAgZm9yZWFjaCAoJGYgaW4gJGNhY2hlZCkgewogICAgICAgICAgICAgICAgICAgICAgICAgICAgJG5hbWUgPSAkZi5maWxlbmFtZSAtcmVwbGFjZSAnXC56aXAkJywgJycKICAgICAgICAgICAgICAgICAgICAgICAgICAgICRzY3JpcHQ6Zml4ZXNDYWNoZVskbmFtZV0gPSBAe3VybD0iaHR0cHM6Ly9naXRodWIuY29tL2Jhc3Rpc2F5ZXMvRml4ZXMtc3RlYW0vcmVsZWFzZXMvZG93bmxvYWQvYmFzdGlzc3MvJCgkZi5maWxlbmFtZSkiOyBzaXplPSRmLnNpemV9CiAgICAgICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICAgICAgJiAkc2NyaXB0OmxnICJDYXRhbG9nbyBjYWNoZTogJCgkZml4ZXNDYWNoZS5Db3VudCkgZml4ZXMiCiAgICAgICAgICAgICAgICAgICAgICAgICRvayA9ICR0cnVlCiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgtbm90ICRvaykgewogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGYgaW4gJHNjcmlwdDpmaXhlc0ZhbGxiYWNrKSB7CiAgICAgICAgICAgICAgICAgICAgJG5hbWUgPSAkZi5mbiAtcmVwbGFjZSAnXC56aXAkJywgJycKICAgICAgICAgICAgICAgICAgICAkc2NyaXB0OmZpeGVzQ2FjaGVbJG5hbWVdID0gQHt1cmw9Imh0dHBzOi8vZ2l0aHViLmNvbS9iYXN0aXNheWVzL0ZpeGVzLXN0ZWFtL3JlbGVhc2VzL2Rvd25sb2FkL2Jhc3Rpc3NzLyQoJGYuZm4pIjsgc2l6ZT0kZi5zen0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICYgJHNjcmlwdDpsZyAiQ2F0YWxvZ28gZmFsbGJhY2s6ICQoJGZpeGVzQ2FjaGUuQ291bnQpIGZpeGVzIgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkZml4ZXNDYWNoZS5Db3VudCAtZ3QgMCkgeyAkc2NyaXB0OmZpeGVzTG9hZGVkID0gJHRydWU7ICRzY3JpcHQ6YXBpUmV0cnlUaWNrID0gJHNjcmlwdDp0aWNrQ291bnQgKyA5OTk5OTkgfQogICAgICAgIH0KCiAgICAgICAgIyDilIDilIAgZGV0ZWN0YXIgZGVzY2FyZ2FzIOKUgOKUgAogICAgICAgICRhY3RpdmVDb3VudCA9IDAKICAgICAgICAkYWN0aXZlTmFtZXMgPSBAKCkKICAgICAgICBmb3JlYWNoICgkbGliIGluICRzdGVhbUxpYnMpIHsKICAgICAgICAgICAgJGRsRGlyID0gSm9pbi1QYXRoIChKb2luLVBhdGggJGxpYiAic3RlYW1hcHBzIikgImRvd25sb2FkaW5nIgogICAgICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRkbERpcikpIHsgY29udGludWUgfQogICAgICAgICAgICBmb3JlYWNoICgkc3ViIGluIEdldC1DaGlsZEl0ZW0gJGRsRGlyIC1EaXJlY3RvcnkgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIHsKICAgICAgICAgICAgICAgICRhcHBpZCA9ICRzdWIuTmFtZQogICAgICAgICAgICAgICAgaWYgKCRzdWIuQ3JlYXRpb25UaW1lIC1sdCAoR2V0LURhdGUpLkFkZERheXMoLTEpKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgICAgICRhY3RpdmVDb3VudCsrCiAgICAgICAgICAgICAgICAkZ24gPSBHZXQtQXBwTmFtZSAkYXBwaWQgJHN0ZWFtTGlicwogICAgICAgICAgICAgICAgaWYgKCRnbikgeyAkYWN0aXZlTmFtZXMgKz0gIiRnbiAoJGFwcGlkKSIgfQogICAgICAgICAgICAgICAgaWYgKCRrbm93bkRpcnMuQ29udGFpbnNLZXkoJGFwcGlkKSAtb3IgJHBlbmRpbmdKb2JzLkNvbnRhaW5zS2V5KCRhcHBpZCkpIHsgY29udGludWUgfQogICAgICAgICAgICAgICAgaWYgKC1ub3QgJGduKSB7ICRrbm93bkRpcnNbJGFwcGlkXSA9ICR0cnVlOyBjb250aW51ZSB9CiAgICAgICAgICAgICAgICAmICRzY3JpcHQ6bGcgIkJ1c2NhbmRvIGZpeCBwYXJhOiAkZ24gLi4uICIKICAgICAgICAgICAgICAgICRmaXhJbmZvID0gRmluZC1GaXggJGduCiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkZml4SW5mbykgeyAmICRzY3JpcHQ6bGcgIk5PIEVOQ09OVFJBRE8iOyBjb250aW51ZSB9CiAgICAgICAgICAgICAgICAkZ2FtZUZvbGRlciA9IEZpbmQtQ29tbW9uRm9sZGVyICRnbiAkc3RlYW1MaWJzCiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkZ2FtZUZvbGRlcikgewogICAgICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRmayBpbiAkZml4ZXNDYWNoZS5LZXlzKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRnYW1lRm9sZGVyID0gRmluZC1Db21tb25Gb2xkZXIgJGZrICRzdGVhbUxpYnMKICAgICAgICAgICAgICAgICAgICAgICAgaWYgKCRnYW1lRm9sZGVyKSB7IGJyZWFrIH0KICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkZ2FtZUZvbGRlcikgeyAmICRzY3JpcHQ6bGcgIkVOQ09OVFJBRE8sIGVzcGVyYW5kbyBjYXJwZXRhLi4uIjsgY29udGludWUgfQogICAgICAgICAgICAgICAgJGtub3duRGlyc1skYXBwaWRdID0gJHRydWUKICAgICAgICAgICAgICAgICR6aXBQYXRoID0gSm9pbi1QYXRoICRnYW1lRm9sZGVyICIkKE5vcm1hbGl6ZS1OYW1lICRnbikucHJlZGwuemlwIgogICAgICAgICAgICAgICAgJiAkc2NyaXB0OmxnICJFTkNPTlRSQURPISBkZXNjYXJnYW5kbyBhOiAkZ2FtZUZvbGRlciIKICAgICAgICAgICAgICAgICYgJHNjcmlwdDpzdCAiRGVzY2FyZ2FuZG8gZml4IHBhcmEgJGduLi4uIgogICAgICAgICAgICAgICAgIyBJbmljaWFyIGpvYiBlbiBzZWd1bmRvIHBsYW5vIChydW5zcGFjZSB3aXRoIGlubGluZSBmdW5jdGlvbikKICAgICAgICAgICAgICAgICRwcyA9IFtwb3dlcnNoZWxsXTo6Q3JlYXRlKCkKICAgICAgICAgICAgICAgICRycyA9IFtSdW5zcGFjZUZhY3RvcnldOjpDcmVhdGVSdW5zcGFjZSgpCiAgICAgICAgICAgICAgICAkcHMuUnVuc3BhY2UgPSAkcnMKICAgICAgICAgICAgICAgICRycy5PcGVuKCkKICAgICAgICAgICAgICAgICRwcm9ncmVzc0luZm8gPSBbaGFzaHRhYmxlXTo6U3luY2hyb25pemVkKEB7UGVyY2VudD0wO1NwZWVkPTA7Q3VycmVudD0wO1RvdGFsPTA7RGxIb3N0PSIiO1JldHJ5Q291bnQ9MDtMb2dNc2c9JG51bGx9KQogICAgICAgICAgICAgICAgJHNjcmlwdDpkb3dubG9hZFByb2dyZXNzID0gJHByb2dyZXNzSW5mbwogICAgICAgICAgICAgICAgJHNjcmlwdDpkb3dubG9hZE5hbWUgPSAkZ24KICAgICAgICAgICAgICAgICYgJHNjcmlwdDpsZyAiICBVUkw6ICQoJGZpeEluZm8udXJsKSIKICAgICAgICAgICAgICAgICRmdW5jU3JjID0gKEdldC1Db21tYW5kIFN0YXJ0LUdpdEh1YkRvd25sb2FkKS5EZWZpbml0aW9uCiAgICAgICAgICAgICAgICAkc2IgPSB7CiAgICAgICAgICAgICAgICAgICAgcGFyYW0oJHVybCwgJHppcCwgJHVhLCAkc3osICRwaSwgJGZzcmMpCiAgICAgICAgICAgICAgICAgICAgSW52b2tlLUV4cHJlc3Npb24gKCdmdW5jdGlvbiBTdGFydC1HaXRIdWJEb3dubG9hZCB7ICcgKyAkZnNyYyArICcgfScpCiAgICAgICAgICAgICAgICAgICAgU3RhcnQtR2l0SHViRG93bmxvYWQgLVVybCAkdXJsIC1PdXRGaWxlICR6aXAgLVVzZXJBZ2VudCAkdWEgLUtub3duU2l6ZSAkc3ogLVByb2dyZXNzSW5mbyAkcGkKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIFt2b2lkXSRwcy5BZGRTY3JpcHQoJHNiKS5BZGRBcmd1bWVudCgkZml4SW5mby51cmwpLkFkZEFyZ3VtZW50KCR6aXBQYXRoKS5BZGRBcmd1bWVudCgkdWEpLkFkZEFyZ3VtZW50KFtsb25nXSRmaXhJbmZvLnNpemUpLkFkZEFyZ3VtZW50KCRwcm9ncmVzc0luZm8pLkFkZEFyZ3VtZW50KCRmdW5jU3JjKQogICAgICAgICAgICAgICAgJGhhbmRsZSA9ICRwcy5CZWdpbkludm9rZSgpCiAgICAgICAgICAgICAgICAkcGVuZGluZ0pvYnNbJGFwcGlkXSA9IEB7cHM9JHBzO2hhbmRsZT0kaGFuZGxlO2duPSRnbjt6aXA9JHppcFBhdGg7ZGVzdD0kZ2FtZUZvbGRlcjtycz0kcnM7cHJvZ3Jlc3M9JHByb2dyZXNzSW5mbztkbFBhdGg9KEpvaW4tUGF0aCAkZGxEaXIgJGFwcGlkKX0KICAgICAgICAgICAgfQogICAgICAgIH0KCiAgICAgICAgIyDilIDilIAgdmVyaWZpY2FyIGpvYnMgY29tcGxldGFkb3Mg4pSA4pSACiAgICAgICAgJGRvbmVKb2JzID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJGFwcGlkIGluICRwZW5kaW5nSm9icy5LZXlzKSB7CiAgICAgICAgICAgICRpbmZvID0gJHBlbmRpbmdKb2JzWyRhcHBpZF0KICAgICAgICAgICAgaWYgKC1ub3QgJGluZm8uaGFuZGxlLklzQ29tcGxldGVkKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRyZXN1bHQgPSAkaW5mby5wcy5FbmRJbnZva2UoJGluZm8uaGFuZGxlKQogICAgICAgICAgICB9IGNhdGNoIHsgJHJlc3VsdCA9IEB7b2s9JGZhbHNlO2Vycj0kXy5FeGNlcHRpb24uTWVzc2FnZX0gfQogICAgICAgICAgICAkaW5mby5wcy5EaXNwb3NlKCkKICAgICAgICAgICAgJGluZm8ucnMuRGlzcG9zZSgpCiAgICAgICAgICAgIGlmICgkcmVzdWx0IC1hbmQgJHJlc3VsdC5vaykgewogICAgICAgICAgICAgICAgJHN6ID0gJHJlc3VsdC5zaXplCiAgICAgICAgICAgICAgICAmICRzY3JpcHQ6bGcgIiAgRGVzY2FyZ2EgT0sgKCQoW21hdGhdOjpSb3VuZCgkc3ovMUtCLDApKSBLQikiCiAgICAgICAgICAgICAgICAkc2NyaXB0OnBlbmRpbmdFeHRyYWN0WyRhcHBpZF0gPSBAe3ppcD0kaW5mby56aXA7ZGVzdD0kaW5mby5kZXN0O2duPSRpbmZvLmduO3JlYWR5VGljaz0tMTtkb25lPSRmYWxzZTtkbFBhdGg9JGluZm8uZGxQYXRofQogICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgJGVyciA9IGlmICgkcmVzdWx0IC1hbmQgJHJlc3VsdC5lcnIpIHsgJHJlc3VsdC5lcnIgfSBlbHNlIHsgImRlc2Nvbm9jaWRvIiB9CiAgICAgICAgICAgICAgICAmICRzY3JpcHQ6c3QgIkVycm9yIGRlc2NhcmdhbmRvIGZpeCBwYXJhICQoJGluZm8uZ24pIiAiI2Y4NTE0OSIKICAgICAgICAgICAgICAgICYgJHNjcmlwdDpsZyAiRVJST1IgZGVzY2FyZ2E6ICQoJGluZm8uZ24pIC0gJGVyciIKICAgICAgICAgICAgfQogICAgICAgICAgICAkZG9uZUpvYnMgKz0gJGFwcGlkCiAgICAgICAgfQogICAgICAgIGZvcmVhY2ggKCRhcHBpZCBpbiAkZG9uZUpvYnMpIHsgJHBlbmRpbmdKb2JzLlJlbW92ZSgkYXBwaWQpIH0KCiAgICAgICAgIyDilIDilIAgZXh0cmFlciBmaXhlcyBjdWFuZG8gZWwganVlZ28geWEgZXN0ZSBpbnN0YWxhZG8gZW4gY29tbW9uIOKUgOKUgAogICAgICAgICRkb25lRXh0cmFjdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRhcHBpZCBpbiAkcGVuZGluZ0V4dHJhY3QuS2V5cykgewogICAgICAgICAgICAkZXggPSAkc2NyaXB0OnBlbmRpbmdFeHRyYWN0WyRhcHBpZF0KICAgICAgICAgICAgaWYgKCRleC5kb25lKSB7ICRkb25lRXh0cmFjdCArPSAkYXBwaWQ7IGNvbnRpbnVlIH0KICAgICAgICAgICAgIyAxKSBWZXJpZmljYXIgcXVlIGxhIGNhcnBldGEgZGVsIGp1ZWdvIGV4aXN0YSB5IHRlbmdhIGFyY2hpdm9zCiAgICAgICAgICAgICRoYXNGaWxlcyA9ICRmYWxzZQogICAgICAgICAgICB0cnkgeyAkaGFzRmlsZXMgPSAoW1N5c3RlbS5JTy5EaXJlY3RvcnldOjpHZXRGaWxlcygkZXguZGVzdCwgIioiLCBbU3lzdGVtLklPLlNlYXJjaE9wdGlvbl06OlRvcERpcmVjdG9yeU9ubHkpLkxlbmd0aCAtZ3QgMCkgfSBjYXRjaCB7fQogICAgICAgICAgICBpZiAoLW5vdCAkaGFzRmlsZXMpIHsKICAgICAgICAgICAgICAgIGlmICgkZXgucmVhZHlUaWNrIC1nZSAwKSB7ICYgJHNjcmlwdDpsZyAiICBFc3BlcmFuZG8gYXJjaGl2b3MgZW46ICQoJGV4LmRlc3QpIiB9CiAgICAgICAgICAgICAgICAkZXgucmVhZHlUaWNrID0gLTEKICAgICAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgICAgIH0KICAgICAgICAgICAgIyAyKSBWZXJpZmljYXIgcXVlIFN0ZWFtIHlhIG5vIGVzdGUgZGVzY2FyZ2FuZG8gZWwganVlZ28gKGNhcnBldGEgZG93bmxvYWRpbmcvQVBQSUQgdmFjaWEgbyBlbGltaW5hZGEpCiAgICAgICAgICAgICRzdGVhbVN0aWxsRG93bmxvYWRpbmcgPSAkZmFsc2UKICAgICAgICAgICAgaWYgKCRleC5kbFBhdGggLWFuZCAoVGVzdC1QYXRoICRleC5kbFBhdGgpKSB7CiAgICAgICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICRkbEZpbGVzID0gW1N5c3RlbS5JTy5EaXJlY3RvcnldOjpHZXRGaWxlcygkZXguZGxQYXRoLCAiKiIsIFtTeXN0ZW0uSU8uU2VhcmNoT3B0aW9uXTo6QWxsRGlyZWN0b3JpZXMpCiAgICAgICAgICAgICAgICAgICAgJGRsU2l6ZSA9IDA7IGZvcmVhY2ggKCRmIGluICRkbEZpbGVzKSB7ICRkbFNpemUgKz0gKE5ldy1PYmplY3QgU3lzdGVtLklPLkZpbGVJbmZvICRmKS5MZW5ndGggfQogICAgICAgICAgICAgICAgICAgIGlmICgkZGxTaXplIC1ndCAxME1CKSB7ICRzdGVhbVN0aWxsRG93bmxvYWRpbmcgPSAkdHJ1ZSB9CiAgICAgICAgICAgICAgICB9IGNhdGNoIHsgJHN0ZWFtU3RpbGxEb3dubG9hZGluZyA9ICRmYWxzZSB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRzdGVhbVN0aWxsRG93bmxvYWRpbmcpIHsKICAgICAgICAgICAgICAgIGlmICgkZXgucmVhZHlUaWNrIC1nZSAwKSB7ICYgJHNjcmlwdDpsZyAiICBTdGVhbSBhdW4gZGVzY2FyZ2FuZG8sIGVzcGVyYW5kby4uLiIgfQogICAgICAgICAgICAgICAgJGV4LnJlYWR5VGljayA9IC0xCiAgICAgICAgICAgICAgICBjb250aW51ZQogICAgICAgICAgICB9CiAgICAgICAgICAgICMgMykgTWFyY2FyIHRpY2sgZGUgbGlzdG8geSBlc3BlcmFyIGVzdGFiaWxpZGFkICgyIHRpY2tzID0gfjZzKQogICAgICAgICAgICBpZiAoJGV4LnJlYWR5VGljayAtbHQgMCkgewogICAgICAgICAgICAgICAgJGV4LnJlYWR5VGljayA9ICRzY3JpcHQ6dGlja0NvdW50CiAgICAgICAgICAgICAgICAmICRzY3JpcHQ6bGcgIiAgSnVlZ28gZGV0ZWN0YWRvIGVuIGNvbW1vbiwgZXNwZXJhbmRvIGVzdGFiaWxpZGFkLi4uIgogICAgICAgICAgICAgICAgY29udGludWUKICAgICAgICAgICAgfQogICAgICAgICAgICAkZWxhcHNlZFRpY2tzID0gJHNjcmlwdDp0aWNrQ291bnQgLSAkZXgucmVhZHlUaWNrCiAgICAgICAgICAgIGlmICgkZWxhcHNlZFRpY2tzIC1sdCAyKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgIyA0KSBFeHRyYWVyCiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAmICRzY3JpcHQ6c3QgIkV4dHJheWVuZG8gZml4IHBhcmEgJCgkZXguZ24pLi4uIiAiI2ZmYWEwMCIKICAgICAgICAgICAgICAgIEV4cGFuZC1BcmNoaXZlIC1QYXRoICRleC56aXAgLURlc3RpbmF0aW9uUGF0aCAkZXguZGVzdCAtRm9yY2UKICAgICAgICAgICAgICAgICYgJHNjcmlwdDpzdCAiRml4IGFwbGljYWRvIGEgJCgkZXguZ24pISIgIiMwMGZmODgiCiAgICAgICAgICAgICAgICAmICRzY3JpcHQ6bGcgIkZJWCBBUExJQ0FETzogJCgkZXguZ24pIC0+ICQoJGV4LmRlc3QpIgogICAgICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgICAgICYgJHNjcmlwdDpzdCAiRXJyb3IgZXh0cmF5ZW5kbyBmaXggZW4gJCgkZXguZ24pIiAiI2Y4NTE0OSIKICAgICAgICAgICAgICAgICYgJHNjcmlwdDpsZyAiRVJST1IgZXh0cmF5ZW5kbyBmaXg6ICQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgICAgICAgICB9CiAgICAgICAgICAgIFJlbW92ZS1JdGVtICRleC56aXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgICRleC5kb25lID0gJHRydWUKICAgICAgICAgICAgJGRvbmVFeHRyYWN0ICs9ICRhcHBpZAogICAgICAgIH0KICAgICAgICBmb3JlYWNoICgkYXBwaWQgaW4gJGRvbmVFeHRyYWN0KSB7ICRzY3JpcHQ6cGVuZGluZ0V4dHJhY3QuUmVtb3ZlKCRhcHBpZCkgfQoKICAgICAgICAjIOKUgOKUgCBwcm9ncmVzbyBkZSBkZXNjYXJnYSAoYW50ZXMgZGUgbGltcGlhciBkb3dubG9hZFByb2dyZXNzKSDilIDilIAKICAgICAgICBpZiAoJHNjcmlwdDpkb3dubG9hZFByb2dyZXNzIC1hbmQgJHNjcmlwdDpkb3dubG9hZFByb2dyZXNzLlBlcmNlbnQgLWdlIDApIHsKICAgICAgICAgICAgJHBpID0gJHNjcmlwdDpkb3dubG9hZFByb2dyZXNzCiAgICAgICAgICAgICRwY3QgPSAkcGkuUGVyY2VudAogICAgICAgICAgICAkc3BlZWQgPSAkcGkuU3BlZWQKICAgICAgICAgICAgJGN1ciA9ICRwaS5DdXJyZW50CiAgICAgICAgICAgICR0b3QgPSAkcGkuVG90YWwKICAgICAgICAgICAgJGRsSG9zdCA9ICRwaS5EbEhvc3QKICAgICAgICAgICAgJHJldHJ5ID0gJHBpLlJldHJ5Q291bnQKICAgICAgICAgICAgJGxvZ01zZyA9ICRwaS5Mb2dNc2cKICAgICAgICAgICAgaWYgKCRsb2dNc2cpIHsgJiAkc2NyaXB0OmxnICIgICRsb2dNc2ciOyAkcGkuTG9nTXNnID0gJG51bGwgfQogICAgICAgICAgICBpZiAoJHNjcmlwdDpwcm9ncmVzc0Jhci5WaXNpYmxlIC1lcSAkZmFsc2UpIHsgJHNjcmlwdDpwcm9ncmVzc0Jhci5WaXNpYmxlID0gJHRydWU7ICRzY3JpcHQ6c3BlZWRMYWJlbC5WaXNpYmxlID0gJHRydWUgfQogICAgICAgICAgICBpZiAoJHBjdCAtbGUgOTkpIHsKICAgICAgICAgICAgICAgICRzY3JpcHQ6cHJvZ3Jlc3NCYXIuVmFsdWUgPSAkcGN0CiAgICAgICAgICAgICAgICAkc3BlZWRUZXh0ID0gaWYgKCRzcGVlZCAtZ2UgMU1CKSB7ICIkKFttYXRoXTo6Um91bmQoJHNwZWVkLzFNQiwxKSkgTUIvcyIgfSBlbHNlaWYgKCRzcGVlZCAtZ2UgMUtCKSB7ICIkKFttYXRoXTo6Um91bmQoJHNwZWVkLzFLQiwwKSkgS0IvcyIgfSBlbHNlIHsgIjAgQi9zIiB9CiAgICAgICAgICAgICAgICAkaG9zdFRleHQgPSBpZiAoJGRsSG9zdCkgeyAiJGRsSG9zdCAiIH0gZWxzZSB7ICIiIH0KICAgICAgICAgICAgICAgICRyZXRyeVRleHQgPSBpZiAoJHJldHJ5IC1ndCAwKSB7ICIgKHJlaW50ZW50byAkcmV0cnkpIiB9IGVsc2UgeyAiIiB9CiAgICAgICAgICAgICAgICAkc2NyaXB0OnNwZWVkTGFiZWwuVGV4dCA9ICIkaG9zdFRleHQkc3BlZWRUZXh0ICAkcGN0JSRyZXRyeVRleHQiCiAgICAgICAgICAgICAgICAkc2NyaXB0OnNwZWVkTGFiZWwuRm9yZUNvbG9yID0gIiMwMGZmODgiCiAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAkc2NyaXB0OnByb2dyZXNzQmFyLlZhbHVlID0gMTAwCiAgICAgICAgICAgICAgICAkc2NyaXB0OnNwZWVkTGFiZWwuVGV4dCA9ICJDb21wbGV0YWRvISIKICAgICAgICAgICAgICAgICRzY3JpcHQ6c3BlZWRMYWJlbC5Gb3JlQ29sb3IgPSAiIzAwZmY4OCIKICAgICAgICAgICAgfQogICAgICAgIH0gZWxzZWlmICgkc2NyaXB0OnBlbmRpbmdKb2JzLkNvdW50IC1lcSAwIC1hbmQgJHNjcmlwdDpwcm9ncmVzc0Jhci5WaXNpYmxlKSB7CiAgICAgICAgICAgICRzY3JpcHQ6cHJvZ3Jlc3NCYXIuVmlzaWJsZSA9ICRmYWxzZQogICAgICAgICAgICAkc2NyaXB0OnNwZWVkTGFiZWwuVmlzaWJsZSA9ICRmYWxzZQogICAgICAgIH0KICAgICAgICBpZiAoJGRvbmVKb2JzLkNvdW50IC1ndCAwIC1hbmQgJHBlbmRpbmdKb2JzLkNvdW50IC1lcSAwKSB7ICRzY3JpcHQ6ZG93bmxvYWRQcm9ncmVzcyA9ICRudWxsOyAkc2NyaXB0OmRvd25sb2FkTmFtZSA9ICRudWxsIH0KCiAgICAgICAgJG5hbWVzID0gaWYgKCRhY3RpdmVOYW1lcy5Db3VudCAtZ3QgMCkgeyAkYWN0aXZlTmFtZXMgLWpvaW4gJywgJyB9IGVsc2UgeyAibmluZ3VuYSIgfQogICAgICAgICYgJHNjcmlwdDpzdCAiJGFjdGl2ZUNvdW50IGRlc2NhcmdhKHMpOiAkbmFtZXMgIHwgIFBlbmRpZW50ZXM6ICQoJHBlbmRpbmdKb2JzLkNvdW50KSIKICAgIH0gY2F0Y2ggeyAmICRzY3JpcHQ6c3QgIldhdGNoZXIgZXJyb3I6ICQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UuVHJpbSgpKSIgIiNmODUxNDkiOyAmICRzY3JpcHQ6bGcgIkVSUk9SIGludGVybm86ICQoJF8uRXhjZXB0aW9uLkdldFR5cGUoKS5OYW1lKTogJCgkXy5FeGNlcHRpb24uTWVzc2FnZS5UcmltKCkpIiB9Cn0pCgokd2F0Y2hlci5TdGFydCgpClt2b2lkXSRmb3JtLlNob3dEaWFsb2coKQokd2F0Y2hlci5TdG9wKCkKJHdhdGNoZXIuRGlzcG9zZSgpCmZvcmVhY2ggKCRrdiBpbiAkcGVuZGluZ0pvYnMuS2V5cykgewogICAgJGogPSAkcGVuZGluZ0pvYnNbJGt2XQogICAgaWYgKC1ub3QgJGouaGFuZGxlLklzQ29tcGxldGVkKSB7ICRqLnBzLlN0b3AoKSB9CiAgICAkai5wcy5EaXNwb3NlKCkKICAgICRqLnJzLkRpc3Bvc2UoKQp9CiRwZW5kaW5nSm9icy5DbGVhcigpCgo=

$script:langs = @{
    "es" = @{ activar="Activar +300";activarSub="Activa mas de 300 juegos";web="Pagina Web";webSub="Visitar sitio oficial"
        idioma="Idioma";idiomaSub="Cambiar idioma";desinstalar="Desinstalar";desinstalarSub="Eliminar juegos"
        discord="Discord";discordSub="Unite a nuestro servidor";tiktok="TikTok";tiktokSub="Seguinos en TikTok"
        salir="Salir";canjear="Canjear Codigo";canjearSub="Ingresa tu codigo para desbloquear juegos"
        canjearBtn="Canjear";volver="Volver";codigosActivos="Codigos Activos"
        sinCodigos="No hay codigos activos";sinCodigosSub="Ingresa un codigo arriba para activar juegos"
        errorCodigo="Ingresa un codigo valido.";verificando="Verificando codigo..."
        exito="Codigo canjeado exitosamente!";expirado="EXPIRADO";activo="ACTIVO"
        expiraEn="EXPIRA EN";dias="DIAS";dia="DIA";expira="Expira:";juegoAct="Juego activado"
        selectIdioma="Seleccionar Idioma";proximamente="Proximamente." }
    "en" = @{ activar="Activate +300";activarSub="Activate over 300 games";web="Website";webSub="Visit official site"
        idioma="Language";idiomaSub="Change language";desinstalar="Uninstall";desinstalarSub="Remove games"
        discord="Discord";discordSub="Join our server";tiktok="TikTok";tiktokSub="Follow us on TikTok"
        salir="Exit";canjear="Redeem Code";canjearSub="Enter your code to unlock games"
        canjearBtn="Redeem";volver="Back";codigosActivos="Active Codes"
        sinCodigos="No active codes";sinCodigosSub="Enter a code above to activate games"
        errorCodigo="Enter a valid code.";verificando="Verifying code..."
        exito="Code redeemed successfully!";expirado="EXPIRED";activo="ACTIVE"
        expiraEn="EXPIRES IN";dias="DAYS";dia="DAY";expira="Expires:";juegoAct="Game activated"
        selectIdioma="Select Language";proximamente="Coming soon." }
    "pt" = @{ activar="Ativar +300";activarSub="Ative mais de 300 jogos";web="Pagina Web";webSub="Visitar site oficial"
        idioma="Idioma";idiomaSub="Mudar idioma";desinstalar="Desinstalar";desinstalarSub="Remover jogos"
        discord="Discord";discordSub="Entre no nosso servidor";tiktok="TikTok";tiktokSub="Siga-nos no TikTok"
        salir="Sair";canjear="Resgatar Codigo";canjearSub="Insira seu codigo para desbloquear jogos"
        canjearBtn="Resgatar";volver="Voltar";codigosActivos="Codigos Ativos"
        sinCodigos="Nenhum codigo ativo";sinCodigosSub="Insira um codigo acima para ativar jogos"
        errorCodigo="Insira um codigo valido.";verificando="Verificando codigo..."
        exito="Codigo resgatado com sucesso!";expirado="EXPIRADO";activo="ATIVO"
        expiraEn="EXPIRA EM";dias="DIAS";dia="DIA";expira="Expira:";juegoAct="Jogo ativado"
        selectIdioma="Selecionar Idioma";proximamente="Em breve." }
}
$script:currentLang = "es"
function T([string]$k){ return $script:langs[$script:currentLang][$k] }

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  COLORS & FONTS
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$script:BG=[System.Drawing.Color]::FromArgb(11,15,25)
$script:CardBG=[System.Drawing.Color]::FromArgb(18,24,38)
$script:CardHover=[System.Drawing.Color]::FromArgb(25,33,52)
$script:CardBorder=[System.Drawing.Color]::FromArgb(32,48,68)
$script:InputBG=[System.Drawing.Color]::FromArgb(14,18,30)
$script:White=[System.Drawing.Color]::White
$script:Gray=[System.Drawing.Color]::FromArgb(130,142,162)
$script:Green=[System.Drawing.Color]::FromArgb(60,220,100)
$script:Cyan=[System.Drawing.Color]::FromArgb(0,180,230)
$script:Yellow=[System.Drawing.Color]::FromArgb(255,210,0)
$script:Orange=[System.Drawing.Color]::FromArgb(255,160,40)
$script:Red=[System.Drawing.Color]::FromArgb(255,70,70)
$script:TikPink=[System.Drawing.Color]::FromArgb(254,44,85)
$script:TikCyan=[System.Drawing.Color]::FromArgb(37,244,238)
$script:DiscordBlue=[System.Drawing.Color]::FromArgb(88,101,242)
$script:GreenBtn=[System.Drawing.Color]::FromArgb(45,200,100)
$script:GreenBtnH=[System.Drawing.Color]::FromArgb(35,175,85)

$script:FntTitle=New-Object System.Drawing.Font("Bahnschrift SemiBold",24,[System.Drawing.FontStyle]::Bold)
$script:FntAct=New-Object System.Drawing.Font("Bahnschrift Light",10)
$script:FntCard=New-Object System.Drawing.Font("Bahnschrift SemiBold",12,[System.Drawing.FontStyle]::Bold)
$script:FntSub=New-Object System.Drawing.Font("Segoe UI",8.5)
$script:FntArrow=New-Object System.Drawing.Font("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
$script:FntSalir=New-Object System.Drawing.Font("Bahnschrift SemiBold",11,[System.Drawing.FontStyle]::Bold)
$script:FntSect=New-Object System.Drawing.Font("Bahnschrift SemiBold",13,[System.Drawing.FontStyle]::Bold)
$script:FntCodeT=New-Object System.Drawing.Font("Bahnschrift SemiBold",9.5,[System.Drawing.FontStyle]::Bold)
$script:FntCodeS=New-Object System.Drawing.Font("Segoe UI",8)
$script:FntCodeSt=New-Object System.Drawing.Font("Bahnschrift",7.5,[System.Drawing.FontStyle]::Bold)
$script:FntBack=New-Object System.Drawing.Font("Bahnschrift SemiBold",10,[System.Drawing.FontStyle]::Bold)
$script:FntRedeemTitle=New-Object System.Drawing.Font("Bahnschrift SemiBold",14,[System.Drawing.FontStyle]::Bold)
$script:FntSubmit=New-Object System.Drawing.Font("Bahnschrift SemiBold",9.5,[System.Drawing.FontStyle]::Bold)

$script:activeCodes=[System.Collections.ArrayList]@()
$CR=10

function New-RR{param([float]$x,[float]$y,[float]$w,[float]$h,[float]$r)
    $p=New-Object System.Drawing.Drawing2D.GraphicsPath;$d=$r*2
    $p.AddArc($x,$y,$d,$d,180,90);$p.AddArc($x+$w-$d,$y,$d,$d,270,90)
    $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90);$p.AddArc($x,$y+$h-$d,$d,$d,90,90)
    $p.CloseFigure();return $p}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  LOAD USER IMAGE AS CIRCULAR LOGO
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# For irm iex compatibility: icons stored in temp dir
$script:iconDir = Join-Path $env:TEMP "bsmap_icons"
if (-not (Test-Path $script:iconDir)) { New-Item -ItemType Directory -Path $script:iconDir -Force | Out-Null }
# Download logo from GitHub
$logoFile = $null
$logoPath = Join-Path $script:iconDir "logo.jpg"
try {
    if (-not (Test-Path $logoPath)) { Invoke-RestMethod -Uri "https://raw.githubusercontent.com/bastisayes/steamsito/main/logo.jpg" -UseBasicParsing -OutFile $logoPath -ErrorAction SilentlyContinue }
    if (Test-Path $logoPath) { $logoFile = Get-Item $logoPath }
} catch {}
$script:LS = 72
$script:logoBmp = New-Object System.Drawing.Bitmap($script:LS, $script:LS)
$lg = [System.Drawing.Graphics]::FromImage($script:logoBmp)
$lg.SmoothingMode = 'AntiAlias'
$lg.PixelOffsetMode = 'HighQuality'
$lg.InterpolationMode = 'HighQualityBicubic'

if ($logoFile) {
    $src = [System.Drawing.Image]::FromFile($logoFile.FullName)
    # Crop to square from center
    $minDim = [Math]::Min($src.Width, $src.Height)
    $cropX = [int](($src.Width - $minDim) / 2)
    $cropY = [int](($src.Height - $minDim) / 2)
    $cropRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $minDim, $minDim)
    # Clip to circle
    $cp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cp.AddEllipse(0, 0, $script:LS, $script:LS)
    $lg.SetClip($cp)
    $lg.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $script:LS, $script:LS)), $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
    $lg.ResetClip()
    $bp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 100, 140), 2.5)
    $lg.DrawEllipse($bp, 1, 1, $script:LS-3, $script:LS-3)
    $bp.Dispose(); $cp.Dispose(); $src.Dispose()
} else {
    # Fallback: draw Argentina flag
    $cp2 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cp2.AddEllipse(0,0,$script:LS,$script:LS); $lg.SetClip($cp2)
    $cel = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(108,172,228))
    $lg.FillRectangle($cel, 0, 0, $script:LS, $script:LS); $cel.Dispose()
    $wh = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $sh = [int]($script:LS/3); $lg.FillRectangle($wh, 0, $sh, $script:LS, $sh); $wh.Dispose()
    $lg.ResetClip(); $cp2.Dispose()
}
$lg.Dispose()

# Load TikTok & Discord icons from image files
$script:iconSize = 38
function Load-IconBmp([string]$filePath, [int]$sz) {
    $bmp = New-Object System.Drawing.Bitmap($sz, $sz)
    $ig2 = [System.Drawing.Graphics]::FromImage($bmp)
    $ig2.SmoothingMode = 'AntiAlias'
    $ig2.InterpolationMode = 'HighQualityBicubic'
    $ig2.PixelOffsetMode = 'HighQuality'
    if (Test-Path $filePath) {
        $srcI = [System.Drawing.Image]::FromFile($filePath)
        $minD = [Math]::Min($srcI.Width, $srcI.Height)
        $cx2 = [int](($srcI.Width - $minD) / 2)
        $cy2 = [int](($srcI.Height - $minD) / 2)
        $cropR = New-Object System.Drawing.Rectangle($cx2, $cy2, $minD, $minD)
        # Round clip
        $cpI = New-Object System.Drawing.Drawing2D.GraphicsPath
        $cpI.AddEllipse(0, 0, $sz, $sz)
        $ig2.SetClip($cpI)
        $ig2.DrawImage($srcI, (New-Object System.Drawing.Rectangle(0, 0, $sz, $sz)), $cropR, [System.Drawing.GraphicsUnit]::Pixel)
        $ig2.ResetClip()
        $cpI.Dispose(); $srcI.Dispose()
    }
    $ig2.Dispose()
    return $bmp
}
# Download icons from GitHub to temp (for irm iex compatibility)
$script:tiktokBmp = $null; $script:discordBmp = $null
try {
    $iconsBase = "https://raw.githubusercontent.com/bastisayes/steamsito/main"
    $tPath = Join-Path $script:iconDir "tiktok.jpg"; $dPath = Join-Path $script:iconDir "discord.jpg"
    if (-not (Test-Path $tPath)) { Invoke-RestMethod -Uri "$iconsBase/tiktok.jpg" -UseBasicParsing -OutFile $tPath -ErrorAction SilentlyContinue }
    if (-not (Test-Path $dPath)) { Invoke-RestMethod -Uri "$iconsBase/discord.jpg" -UseBasicParsing -OutFile $dPath -ErrorAction SilentlyContinue }
    if (Test-Path $tPath) { $script:tiktokBmp = Load-IconBmp $tPath $script:iconSize }
    if (Test-Path $dPath) { $script:discordBmp = Load-IconBmp $dPath $script:iconSize }
} catch {}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  COMPACT LAYOUT
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$PAD=18;$FW=480;$CW=$FW-(2*$PAD);$GAP=10
$HW=[int](($CW-$GAP)/2);$CH=76;$FCH=68

$HH=115;$CY=$HH
# Main view Y offsets (relative)
$R1Y=0;$R2Y=$CH+$GAP
$WEB_Y=$R2Y+$CH+12;$DISC_Y=$WEB_Y+$FCH+$GAP;$TIK_Y=$DISC_Y+$FCH+$GAP
$SAL_Y=$TIK_Y+$FCH+12;$SAL_H=40
$FH=$CY+$SAL_Y+$SAL_H+14

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  FORM
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$form=New-Object System.Windows.Forms.Form
$form.Text="BastissSteam activator"
$form.ClientSize=New-Object System.Drawing.Size($FW,$FH)
$form.StartPosition="CenterScreen";$form.BackColor=$BG
$form.FormBorderStyle="FixedSingle";$form.MaximizeBox=$false

# Icon from logo image
$ib=New-Object System.Drawing.Bitmap(32,32)
$ig=[System.Drawing.Graphics]::FromImage($ib);$ig.SmoothingMode='AntiAlias'
$ig.InterpolationMode='HighQualityBicubic'
$cpIcon=New-Object System.Drawing.Drawing2D.GraphicsPath
$cpIcon.AddEllipse(0,0,32,32);$ig.SetClip($cpIcon)
if($logoFile){
    $srcIcon=[System.Drawing.Image]::FromFile($logoFile.FullName)
    $minI=[Math]::Min($srcIcon.Width,$srcIcon.Height)
    $cxI=[int](($srcIcon.Width-$minI)/2);$cyI=[int](($srcIcon.Height-$minI)/2)
    $ig.DrawImage($srcIcon,(New-Object System.Drawing.Rectangle(0,0,32,32)),(New-Object System.Drawing.Rectangle($cxI,$cyI,$minI,$minI)),[System.Drawing.GraphicsUnit]::Pixel)
    $srcIcon.Dispose()
}
$ig.ResetClip();$cpIcon.Dispose();$ig.Dispose()
$form.Icon=[System.Drawing.Icon]::FromHandle($ib.GetHicon())
$form.Add_HandleCreated({$v=[int]1;[DwmHelper]::DwmSetWindowAttribute($form.Handle,20,[ref]$v,4)|Out-Null})

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  HEADER
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$hp=New-Object BufferedPanel
$hp.Location=New-Object System.Drawing.Point(0,0)
$hp.Size=New-Object System.Drawing.Size($FW,$HH);$hp.BackColor=$BG
$hp.Add_Paint({
    param($s,$e)
    $g=$e.Graphics;$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='ClearTypeGridFit'
    $g.InterpolationMode='HighQualityBicubic'

    # Fonts for header
    $fntMain=New-Object System.Drawing.Font("Bahnschrift SemiBold",26,[System.Drawing.FontStyle]::Bold)
    $fntTag=New-Object System.Drawing.Font("Bahnschrift Light",9)

    # Measure "BastissSteam" as one word
    $titleText="BastissSteam"
    $titleSz=$g.MeasureString($titleText,$fntMain)
    $tagText="activator"
    $tagSz=$g.MeasureString($tagText,$fntTag)

    # Center group: [logo] [title block]
    $titleBlockH=$titleSz.Height + $tagSz.Height - 10
    $groupW=$script:LS + 12 + [Math]::Max($titleSz.Width, $tagSz.Width)
    $startX=[int](($s.Width - $groupW) / 2)

    # Logo
    if ($script:logoBmp) {
        $ly=[int](($s.Height - $script:LS) / 2 - 2)
        $g.DrawImage($script:logoBmp,$startX,$ly,$script:LS,$script:LS)
    }

    # Title "BastissSteam" - cyan gradient
    $tx=$startX+$script:LS+12
    $ty=[int](($s.Height - $titleBlockH) / 2 - 2)

    # Draw with two-tone: "Bastiss" in cyan, "Steam" in white
    $cyanBr=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0,200,255))
    $whiteBr=New-Object System.Drawing.SolidBrush($script:White)

    # Measure "Bastiss" part to know where "Steam" starts
    $bastissOnly=$g.MeasureString("Bastiss",$fntMain)
    $g.DrawString("Bastiss",$fntMain,$cyanBr,$tx,$ty)
    # "Steam" right after, no gap
    $steamX=$tx+$bastissOnly.Width-12
    $g.DrawString("Steam",$fntMain,$whiteBr,$steamX,$ty)

    # "activator" tag centered below
    $tagBr=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80,95,115))
    $tagX=$tx+($titleSz.Width-$tagSz.Width)/2
    $tagY=$ty+$titleSz.Height-10
    $g.DrawString($tagText,$fntTag,$tagBr,$tagX,$tagY)

    $cyanBr.Dispose();$whiteBr.Dispose();$tagBr.Dispose()
    $fntMain.Dispose();$fntTag.Dispose()

    # Separator
    $sp=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(25,255,255,255),1)
    $g.DrawLine($sp,$PAD,$s.Height-1,$s.Width-$PAD,$s.Height-1);$sp.Dispose()
})
$form.Controls.Add($hp)

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  CARD FACTORY
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
function New-Card{param([int]$X,[int]$Y,[int]$W,[int]$H,[string]$Title,[string]$Sub,[string]$Icon,[scriptblock]$Click)
    $pn=New-Object BufferedPanel
    $pn.Location=New-Object System.Drawing.Point($X,$Y)
    $pn.Size=New-Object System.Drawing.Size($W,$H);$pn.BackColor=$BG
    $pn.Cursor=[System.Windows.Forms.Cursors]::Hand
    $pn.Tag=@{Hover=$false;Icon=$Icon;Title=$Title;Sub=$Sub}
    $pn.Add_MouseEnter({param($s,$e2);$s.Tag.Hover=$true;$s.Invalidate()})
    $pn.Add_MouseLeave({param($s,$e2);$s.Tag.Hover=$false;$s.Invalidate()})
    if($Click){$pn.Add_Click($Click)}
    $pn.Add_Paint({
        param($s,$e)
        $g=$e.Graphics;$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='ClearTypeGridFit'
        $n=$s.Tag;$bc=if($n.Hover){$script:CardHover}else{$script:CardBG}
        $p=New-RR 0 0 ($s.Width-1) ($s.Height-1) $CR
        $b1=New-Object System.Drawing.SolidBrush($bc);$b2=New-Object System.Drawing.Pen($script:CardBorder,1)
        $g.FillPath($b1,$p);$g.DrawPath($b2,$p);$b1.Dispose();$b2.Dispose();$p.Dispose()
        $tx2=56;$ty2=[int](($s.Height/2)-18);$sy2=[int](($s.Height/2)+3)
        $ic=30;$iy=[int]($s.Height/2)

        switch($n.Icon){
            "lightning"{
                $lBr=New-Object System.Drawing.SolidBrush($script:Cyan)
                $pts=@((New-Object System.Drawing.PointF(($ic+6),($iy-17))),(New-Object System.Drawing.PointF(($ic-2),($iy-2))),
                    (New-Object System.Drawing.PointF(($ic+5),($iy-2))),(New-Object System.Drawing.PointF(($ic-3),($iy+17))))
                # Fill solid bolt
                $boltPath=New-Object System.Drawing.Drawing2D.GraphicsPath
                $boltPath.AddPolygon(@(
                    (New-Object System.Drawing.PointF(($ic+5),($iy-17))),
                    (New-Object System.Drawing.PointF(($ic-4),($iy-1))),
                    (New-Object System.Drawing.PointF(($ic+1),($iy-1))),
                    (New-Object System.Drawing.PointF(($ic-1),($iy-4))),
                    (New-Object System.Drawing.PointF(($ic+6),($iy-4))),
                    (New-Object System.Drawing.PointF(($ic+8),($iy-17)))
                ))
                $g.FillPolygon($lBr, @(
                    (New-Object System.Drawing.PointF(($ic+1),($iy-18))),
                    (New-Object System.Drawing.PointF(($ic-6),($iy-1))),
                    (New-Object System.Drawing.PointF(($ic+2),($iy-1))),
                    (New-Object System.Drawing.PointF(($ic-4),($iy+18))),
                    (New-Object System.Drawing.PointF(($ic+3),($iy+4))),
                    (New-Object System.Drawing.PointF(($ic-2),($iy+4))),
                    (New-Object System.Drawing.PointF(($ic+7),($iy-12)))
                ))
                $lBr.Dispose()
            }
            "webpage"{
                $wp=New-Object System.Drawing.Pen($script:Cyan,1.8);$r3=12
                $g.DrawEllipse($wp,($ic-$r3),($iy-$r3),($r3*2),($r3*2))
                $g.DrawLine($wp,$ic,($iy-$r3),$ic,($iy+$r3))
                $g.DrawLine($wp,($ic-$r3),$iy,($ic+$r3),$iy)
                $g.DrawEllipse($wp,($ic-5),($iy-$r3),10,($r3*2))
                # External arrow
                $ap=New-Object System.Drawing.Pen($script:Cyan,2)
                $g.DrawLine($ap,($ic+5),($iy-9),($ic+13),($iy-9))
                $g.DrawLine($ap,($ic+13),($iy-9),($ic+13),($iy-1))
                $g.DrawLine($ap,($ic+13),($iy-9),($ic+6),($iy-2))
                $wp.Dispose();$ap.Dispose()
            }
            "globe"{
                $gp=New-Object System.Drawing.Pen($script:Cyan,1.6);$r3=12
                $g.DrawEllipse($gp,($ic-$r3),($iy-$r3),($r3*2),($r3*2))
                $g.DrawLine($gp,$ic,($iy-$r3),$ic,($iy+$r3))
                $g.DrawLine($gp,($ic-$r3),$iy,($ic+$r3),$iy)
                $g.DrawEllipse($gp,($ic-6),($iy-$r3),12,($r3*2))
                $gp.Dispose()
            }
            "trash"{
                $tp=New-Object System.Drawing.Pen($script:Cyan,1.8)
                $g.DrawLine($tp,($ic-11),($iy-10),($ic+11),($iy-10))
                $g.DrawLine($tp,($ic-3),($iy-10),($ic-3),($iy-14))
                $g.DrawLine($tp,($ic+3),($iy-10),($ic+3),($iy-14))
                $g.DrawLine($tp,($ic-3),($iy-14),($ic+3),($iy-14))
                $g.DrawLine($tp,($ic-9),($iy-8),($ic-7),($iy+14))
                $g.DrawLine($tp,($ic+9),($iy-8),($ic+7),($iy+14))
                $g.DrawLine($tp,($ic-7),($iy+14),($ic+7),($iy+14))
                $tn=New-Object System.Drawing.Pen($script:Cyan,1.2)
                $g.DrawLine($tn,$ic,($iy-5),$ic,($iy+10))
                $g.DrawLine($tn,($ic-4),($iy-5),($ic-4),($iy+10))
                $g.DrawLine($tn,($ic+4),($iy-5),($ic+4),($iy+10))
                $tp.Dispose();$tn.Dispose()
            }
            "discord"{
                if ($script:discordBmp) {
                    $g.InterpolationMode='HighQualityBicubic'
                    $isz=$script:iconSize;$ix2=$ic-[int]($isz/2);$iy2=$iy-[int]($isz/2)
                    $g.DrawImage($script:discordBmp,$ix2,$iy2,$isz,$isz)
                }
            }
            "tiktok"{
                if ($script:tiktokBmp) {
                    $g.InterpolationMode='HighQualityBicubic'
                    $isz=$script:iconSize;$ix2=$ic-[int]($isz/2);$iy2=$iy-[int]($isz/2)
                    $g.DrawImage($script:tiktokBmp,$ix2,$iy2,$isz,$isz)
                }
            }
        }
        $tb=New-Object System.Drawing.SolidBrush($script:White)
        $g.DrawString($n.Title,$script:FntCard,$tb,$tx2,$ty2);$tb.Dispose()
        if($n.Sub){$sb=New-Object System.Drawing.SolidBrush($script:Gray)
            $g.DrawString($n.Sub,$script:FntSub,$sb,$tx2,$sy2);$sb.Dispose()}
        $ab=New-Object System.Drawing.SolidBrush($script:Cyan)
        $asz=$g.MeasureString(">",$script:FntArrow)
        $g.DrawString(">",$script:FntArrow,$ab,$s.Width-$asz.Width-10,($s.Height-$asz.Height)/2);$ab.Dispose()
    })
    return $pn
}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  VIEW SWITCHING
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
function Switch-ToRedeem{$script:mp.Visible=$false;$script:rp.Visible=$true;Refresh-Codes}
function Switch-ToMain{$script:rp.Visible=$false;$script:mp.Visible=$true}
function Refresh-Codes{if($script:clp){$script:clp.Invalidate()}}

function Refresh-AllText{
    $script:c1.Tag.Title=T "activar";$script:c1.Tag.Sub=T "activarSub";$script:c1.Invalidate()
    $script:c3.Tag.Title=T "idioma";$script:c3.Tag.Sub=T "idiomaSub";$script:c3.Invalidate()
    $script:c4.Tag.Title=T "desinstalar";$script:c4.Tag.Sub=T "desinstalarSub";$script:c4.Invalidate()
    $script:cWeb.Tag.Title=T "web";$script:cWeb.Tag.Sub=T "webSub";$script:cWeb.Invalidate()
    $script:c5.Tag.Title=T "discord";$script:c5.Tag.Sub=T "discordSub";$script:c5.Invalidate()
    $script:c6.Tag.Title=T "tiktok";$script:c6.Tag.Sub=T "tiktokSub";$script:c6.Invalidate()
    $script:salBtn.Invalidate()
    $script:rTit.Text=T "canjear";$script:rSubL.Text=T "canjearSub"
    $script:codesT.Text=T "codigosActivos"
    $script:backB.Invalidate();$script:subB.Invalidate()
    Refresh-Codes
}

function Show-LangDialog{
    $dlg=New-Object System.Windows.Forms.Form
    $dlg.Text=T "selectIdioma";$dlg.ClientSize=New-Object System.Drawing.Size(260,180)
    $dlg.StartPosition="CenterParent";$dlg.BackColor=$BG
    $dlg.FormBorderStyle="FixedDialog";$dlg.MaximizeBox=$false;$dlg.MinimizeBox=$false;$dlg.ShowInTaskbar=$false
    $dlg.Add_HandleCreated({$v=[int]1;[DwmHelper]::DwmSetWindowAttribute($dlg.Handle,20,[ref]$v,4)|Out-Null})
    $opts=@(@("Espanol","es"),@("English","en"),@("Portugues","pt"));$by=15
    foreach($o in $opts){
        $btn=New-Object System.Windows.Forms.Button
        $btn.Text=$o[0];$btn.Tag=$o[1]
        $btn.Location=New-Object System.Drawing.Point(20,$by)
        $btn.Size=New-Object System.Drawing.Size(220,42)
        $btn.FlatStyle="Flat";$btn.Font=New-Object System.Drawing.Font("Bahnschrift SemiBold",11)
        $btn.ForeColor=$White;$btn.BackColor=$CardBG
        $btn.FlatAppearance.BorderColor=$CardBorder;$btn.FlatAppearance.MouseOverBackColor=$CardHover
        $btn.Cursor=[System.Windows.Forms.Cursors]::Hand
        $btn.Add_Click({param($sender);$script:currentLang=$sender.Tag;Refresh-AllText;$dlg.Close()})
        $dlg.Controls.Add($btn);$by+=50
    }
    $dlg.ShowDialog()|Out-Null;$dlg.Dispose()
}

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  MAIN VIEW
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$script:mp=New-Object BufferedPanel
$script:mp.Location=New-Object System.Drawing.Point(0,$CY)
$script:mp.Size=New-Object System.Drawing.Size($FW,($FH-$CY));$script:mp.BackColor=$BG

# Row 1: Activar +300 | Idioma
$script:c1=New-Card -X $PAD -Y $R1Y -W $HW -H $CH -Title (T "activar") -Sub (T "activarSub") -Icon "lightning" -Click {Switch-ToRedeem}
$script:mp.Controls.Add($script:c1)
$script:c3=New-Card -X ($PAD+$HW+$GAP) -Y $R1Y -W $HW -H $CH -Title (T "idioma") -Sub (T "idiomaSub") -Icon "globe" -Click {Show-LangDialog}
$script:mp.Controls.Add($script:c3)

# Row 2: Desinstalar (half, alone is ugly, pair with... let's keep original layout)
# Actually: Idioma | Desinstalar like original
# Move idioma back to row2
$script:mp.Controls.Remove($script:c3)
$script:c3=New-Card -X $PAD -Y $R2Y -W $HW -H $CH -Title (T "idioma") -Sub (T "idiomaSub") -Icon "globe" -Click {Show-LangDialog}
$script:mp.Controls.Add($script:c3)
$script:c4=New-Card -X ($PAD+$HW+$GAP) -Y $R2Y -W $HW -H $CH -Title (T "desinstalar") -Sub (T "desinstalarSub") -Icon "trash" -Click {
    $timers = Get-ActiveTimers
    if ($timers.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No hay codigos activos para desinstalar.",(T "desinstalar"),"OK","Information"); return }
    if ([System.Windows.Forms.MessageBox]::Show("Se eliminaran TODOS los juegos activos.`nContinuar?",(T "desinstalar"),"YesNo","Warning") -ne "Yes") { return }
    $errors=0
    foreach ($t in $timers) {
        try { $root=$t.steam_root; foreach ($f in $t.lua_files) { Remove-FileHard (Join-Path (Join-Path $root "config\stplug-in") $f); Remove-FileHard (Join-Path (Join-Path $root "config\lua") $f) }; foreach ($f in $t.manifest_files) { Remove-FileHard (Join-Path (Join-Path $root "config\depotcache") $f) } } catch { $errors++ }
    }
    Save-Timers @(); $script:activeCodes.Clear(); Refresh-Codes
    [System.Windows.Forms.MessageBox]::Show("Juegos eliminados correctamente.","Listo","OK","Information")
}
$script:mp.Controls.Add($script:c4)

# Make Activar +300 full width in row1
$script:mp.Controls.Remove($script:c1)
$script:c1=New-Card -X $PAD -Y $R1Y -W $CW -H $CH -Title (T "activar") -Sub (T "activarSub") -Icon "lightning" -Click {Switch-ToRedeem}
$script:mp.Controls.Add($script:c1)

# Pagina Web (full width like Discord/TikTok)
$script:cWeb=New-Card -X $PAD -Y $WEB_Y -W $CW -H $FCH -Title (T "web") -Sub (T "webSub") -Icon "webpage" -Click {Start-Process "https://github.com/bastisayes/Fixes-steam"}
$script:mp.Controls.Add($script:cWeb)

# Discord (full width)
$script:c5=New-Card -X $PAD -Y $DISC_Y -W $CW -H $FCH -Title (T "discord") -Sub (T "discordSub") -Icon "discord" -Click {Start-Process "https://discord.gg/"}
$script:mp.Controls.Add($script:c5)

# TikTok (full width)
$script:c6=New-Card -X $PAD -Y $TIK_Y -W $CW -H $FCH -Title (T "tiktok") -Sub (T "tiktokSub") -Icon "tiktok" -Click {Start-Process "https://tiktok.com/"}
$script:mp.Controls.Add($script:c6)

# Salir
$script:salBtn=New-Object BufferedPanel
$script:salBtn.Location=New-Object System.Drawing.Point($PAD,$SAL_Y)
$script:salBtn.Size=New-Object System.Drawing.Size($CW,$SAL_H);$script:salBtn.BackColor=$BG
$script:salBtn.Cursor=[System.Windows.Forms.Cursors]::Hand;$script:salBtn.Tag=@{Hover=$false}
$script:salBtn.Add_MouseEnter({param($s);$s.Tag.Hover=$true;$s.Invalidate()})
$script:salBtn.Add_MouseLeave({param($s);$s.Tag.Hover=$false;$s.Invalidate()})
$script:salBtn.Add_Click({ $form.Hide(); $script:trayIcon.Visible = $true })
$script:salBtn.Add_Paint({param($s,$e)
    $g=$e.Graphics;$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='ClearTypeGridFit'
    $bc=if($s.Tag.Hover){$script:CardHover}else{$script:CardBG}
    $p=New-RR 0 0 ($s.Width-1) ($s.Height-1) $CR
    $b1=New-Object System.Drawing.SolidBrush($bc);$b2=New-Object System.Drawing.Pen($script:CardBorder,1)
    $g.FillPath($b1,$p);$g.DrawPath($b2,$p);$b1.Dispose();$b2.Dispose();$p.Dispose()
    $ep=New-Object System.Drawing.Pen($script:Cyan,1.8);$ecx=($s.Width/2)-22;$ecy=$s.Height/2
    $g.DrawLine($ep,($ecx-6),($ecy-8),($ecx-6),($ecy+8))
    $g.DrawLine($ep,($ecx-6),($ecy-8),$ecx,($ecy-8))
    $g.DrawLine($ep,($ecx-6),($ecy+8),$ecx,($ecy+8))
    $g.DrawLine($ep,($ecx+2),$ecy,($ecx+12),$ecy)
    $g.DrawLine($ep,($ecx+8),($ecy-4),($ecx+12),$ecy)
    $g.DrawLine($ep,($ecx+8),($ecy+4),($ecx+12),$ecy);$ep.Dispose()
    $tb=New-Object System.Drawing.SolidBrush($script:White);$txt=T "salir"
    $ss=$g.MeasureString($txt,$script:FntSalir)
    $g.DrawString($txt,$script:FntSalir,$tb,($s.Width/2)-($ss.Width/2)+8,($s.Height-$ss.Height)/2);$tb.Dispose()
})
$script:mp.Controls.Add($script:salBtn)
$form.Controls.Add($script:mp)

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  REDEEM VIEW
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$script:rp=New-Object BufferedPanel
$script:rp.Location=New-Object System.Drawing.Point(0,$CY)
$script:rp.Size=New-Object System.Drawing.Size($FW,($FH-$CY));$script:rp.BackColor=$BG;$script:rp.Visible=$false

# Back arrow + title on same line
$script:backB=New-Object BufferedPanel
$script:backB.Location=New-Object System.Drawing.Point($PAD,8)
$script:backB.Size=New-Object System.Drawing.Size(36,36);$script:backB.BackColor=$BG
$script:backB.Cursor=[System.Windows.Forms.Cursors]::Hand;$script:backB.Tag=@{Hover=$false}
$script:backB.Add_MouseEnter({param($s);$s.Tag.Hover=$true;$s.Invalidate()})
$script:backB.Add_MouseLeave({param($s);$s.Tag.Hover=$false;$s.Invalidate()})
$script:backB.Add_Click({Switch-ToMain})
$script:backB.Add_Paint({param($s,$e)
    $g=$e.Graphics;$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='ClearTypeGridFit'
    $bc=if($s.Tag.Hover){$script:CardHover}else{$script:CardBG}
    $p=New-RR 0 0 ($s.Width-1) ($s.Height-1) 8
    $b1=New-Object System.Drawing.SolidBrush($bc);$b2=New-Object System.Drawing.Pen($script:CardBorder,1)
    $g.FillPath($b1,$p);$g.DrawPath($b2,$p);$b1.Dispose();$b2.Dispose();$p.Dispose()
    # Draw arrow <
    $ap=New-Object System.Drawing.Pen($script:Cyan,2.5)
    $cx2=$s.Width/2;$cy2=$s.Height/2
    $g.DrawLine($ap,($cx2+4),($cy2-7),($cx2-4),$cy2)
    $g.DrawLine($ap,($cx2-4),$cy2,($cx2+4),($cy2+7));$ap.Dispose()
})
$script:rp.Controls.Add($script:backB)

# Title next to back button
$script:rTit=New-Object System.Windows.Forms.Label
$script:rTit.Text=T "canjear"
$script:rTit.Font=$script:FntRedeemTitle
$script:rTit.ForeColor=$White;$script:rTit.BackColor=$BG;$script:rTit.AutoSize=$true
$script:rTit.Location=New-Object System.Drawing.Point(([int]$PAD+42),14)
$script:rp.Controls.Add($script:rTit)

$script:rSubL=New-Object System.Windows.Forms.Label
$script:rSubL.Text=T "canjearSub"
$script:rSubL.Font=$FntSub;$script:rSubL.ForeColor=$Gray;$script:rSubL.BackColor=$BG;$script:rSubL.AutoSize=$true
$script:rSubL.Location=New-Object System.Drawing.Point($PAD,52)
$script:rp.Controls.Add($script:rSubL)

# Input + submit
$txtC=New-Object System.Windows.Forms.TextBox
$txtC.Location=New-Object System.Drawing.Point($PAD,76)
$txtC.Size=New-Object System.Drawing.Size(([int]$CW-105),26)
$txtC.Font=New-Object System.Drawing.Font("Consolas",11)
$txtC.BackColor=$InputBG;$txtC.ForeColor=$White;$txtC.BorderStyle="FixedSingle";$txtC.MaxLength=50
$script:rp.Controls.Add($txtC)

$script:subB=New-Object BufferedPanel
$script:subB.Location=New-Object System.Drawing.Point(([int]$PAD+[int]$CW-98),74)
$script:subB.Size=New-Object System.Drawing.Size(98,28);$script:subB.BackColor=$BG
$script:subB.Cursor=[System.Windows.Forms.Cursors]::Hand;$script:subB.Tag=@{Hover=$false}
$script:subB.Add_MouseEnter({param($s);$s.Tag.Hover=$true;$s.Invalidate()})
$script:subB.Add_MouseLeave({param($s);$s.Tag.Hover=$false;$s.Invalidate()})
$script:subB.Add_Paint({param($s,$e)
    $g=$e.Graphics;$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='ClearTypeGridFit'
    $bc=if($s.Tag.Hover){$script:GreenBtnH}else{$script:GreenBtn}
    $p=New-RR 0 0 ($s.Width-1) ($s.Height-1) 7
    $b1=New-Object System.Drawing.SolidBrush($bc);$g.FillPath($b1,$p);$b1.Dispose();$p.Dispose()
    $sz=$g.MeasureString((T "canjearBtn"),$script:FntSubmit)
    $tb=New-Object System.Drawing.SolidBrush($script:White)
    $g.DrawString((T "canjearBtn"),$script:FntSubmit,$tb,($s.Width-$sz.Width)/2,($s.Height-$sz.Height)/2);$tb.Dispose()
})
$script:subB.Add_Click({
    $code=$txtC.Text.Trim()
    if([string]::IsNullOrEmpty($code)){$lblR.ForeColor=$script:Red;$lblR.Text=T "errorCodigo";[System.Windows.Forms.Application]::DoEvents();return}
    $lblR.ForeColor=$script:Yellow;$lblR.Text="Conectando con servidor..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $body = @{code=$code;client_id=$script:clientId} | ConvertTo-Json
        try { $resp = Invoke-RestMethod -Uri "$($script:serverUrl)/api/redeem-code" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop }
        catch {
            Update-ServerUrl
            $resp = Invoke-RestMethod -Uri "$($script:serverUrl)/api/redeem-code" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
        }
        if (-not $resp.ok) { throw $resp.err }
        $links = @($resp.links); $duration = [int]$resp.duration
        if ($links.Count -eq 0) { throw "El codigo no contiene links." }
        Send-Webhook $code ($links -join "`n")
        $expDate = if ($duration -gt 0) { (Get-Date).AddSeconds($duration) } else { $null }
        $steamRoot = Get-SteamPath
        $successCount=0; $total=$links.Count; $errors=@()
        foreach ($mfUrl in $links) {
            $gameName = [System.IO.Path]::GetFileNameWithoutExtension(($mfUrl -split '/')[-2])
            if ($gameName) { $gameName = $gameName -replace '%[0-9a-fA-F]{2}', '' }
            $lblR.Text = "($($successCount+1)/$total) $gameName"; [System.Windows.Forms.Application]::DoEvents()
            $zipFile = Join-Path $env:TEMP "fix_$(Get-Random).zip"
            try {
                Download-MediaFire $mfUrl $zipFile
                $installResult = Extract-AndInstall $zipFile $gameName $expDate
                # Always save to timers file (permanent = expires in 1 year)
                $timerExp = if ($expDate) { $expDate } else { (Get-Date).AddYears(1) }
                $timers = Get-ActiveTimers
                $internetNow = Get-InternetTime
                $timers += @{redeem_code=$code;duration=$duration;expires_at=$timerExp.ToString("o");internet_created_at=$(if($internetNow){$internetNow.ToString("o")}else{$null});game_name=$gameName;steam_root=$steamRoot;lua_files=@($installResult.lua);manifest_files=@($installResult.manifest)}
                Save-Timers $timers
                $script:activeCodes.Add(@{Code=$code;Game=$gameName;ActivatedAt=(Get-Date);ExpiresAt=$(if($expDate){$expDate}else{(Get-Date).AddYears(1)});Duration=$duration})|Out-Null
                $successCount++
            } catch { $errors+="$gameName : $($_.Exception.Message)"; Write-ErrorLog "Download $gameName" $_ }
            Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
        }
        if ($successCount -gt 0) {
            $lblR.ForeColor=$script:Green; $lblR.Text="$successCount de $total juegos activados"
            if ($duration -gt 0 -and $expDate) { Start-Countdown $duration $expDate ($links[0]) }
            $script:rp.Invalidate(); Refresh-Codes
            [System.Windows.Forms.MessageBox]::Show("$successCount de $total juegos activados correctamente.","Listo","OK","Information")
        } else { throw "No se pudo activar ningun juego.`n$($errors -join '; ')" }
    } catch {
        Write-ErrorLog "Canjeo" $_; $lblR.ForeColor=$script:Red
        $lblR.Text="Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)","Error","OK","Error")
    }
})
$script:rp.Controls.Add($script:subB)
$txtC.Add_KeyDown({param($s,$e2);if($e2.KeyCode -eq 'Return'){$script:subB.PerformClick();$e2.Handled=$true;$e2.SuppressKeyPress=$true}})

$lblR=New-Object System.Windows.Forms.Label
$lblR.Text="";$lblR.Font=$FntSub;$lblR.ForeColor=$Gray;$lblR.BackColor=$BG
$lblR.Location=New-Object System.Drawing.Point($PAD,108);$lblR.Size=New-Object System.Drawing.Size($CW,16)
$script:rp.Controls.Add($lblR)

$div=New-Object BufferedPanel;$div.Location=New-Object System.Drawing.Point($PAD,130)
$div.Size=New-Object System.Drawing.Size($CW,1);$div.BackColor=$CardBorder
$script:rp.Controls.Add($div)

$script:codesT=New-Object System.Windows.Forms.Label
$script:codesT.Text=T "codigosActivos"
$script:codesT.Font=$FntSect;$script:codesT.ForeColor=$White;$script:codesT.BackColor=$BG
$script:codesT.AutoSize=$true;$script:codesT.Location=New-Object System.Drawing.Point($PAD,138)
$script:rp.Controls.Add($script:codesT)

$cBadge=New-Object System.Windows.Forms.Label
$cBadge.Font=$FntCodeSt;$cBadge.ForeColor=$Cyan;$cBadge.BackColor=$BG
$cBadge.AutoSize=$true;$cBadge.Location=New-Object System.Drawing.Point(170,144)
$script:rp.Controls.Add($cBadge)

$clH=($FH-$CY)-170
$script:clp=New-Object BufferedPanel
$script:clp.Location=New-Object System.Drawing.Point($PAD,164)
$script:clp.Size=New-Object System.Drawing.Size($CW,$clH);$script:clp.BackColor=$BG
$script:clp.Add_Paint({param($s,$e)
    $g=$e.Graphics;$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='ClearTypeGridFit'
    $codes=$script:activeCodes;$cBadge.Text="($($codes.Count))"
    if($codes.Count -eq 0){
        $p=New-RR 0 0 ($s.Width-1) 60 8
        $bg2=New-Object System.Drawing.SolidBrush($script:CardBG);$bp=New-Object System.Drawing.Pen($script:CardBorder,1)
        $g.FillPath($bg2,$p);$g.DrawPath($bp,$p);$bg2.Dispose();$bp.Dispose();$p.Dispose()
        $gb2=New-Object System.Drawing.SolidBrush($script:Gray)
        $f1=New-Object System.Drawing.Font("Bahnschrift",9.5)
        $msg=T "sinCodigos";$msz=$g.MeasureString($msg,$f1)
        $g.DrawString($msg,$f1,$gb2,($s.Width-$msz.Width)/2,12)
        $f2=New-Object System.Drawing.Font("Segoe UI",8)
        $msg2=T "sinCodigosSub";$msz2=$g.MeasureString($msg2,$f2)
        $g.DrawString($msg2,$f2,$gb2,($s.Width-$msz2.Width)/2,33)
        $gb2.Dispose();$f1.Dispose();$f2.Dispose();return
    }
    $ch2=58;$gp2=6;$yP=0
    foreach($c in $codes){
        $isPermanent = $c.Duration -eq 0
        if($isPermanent){$st="Permanente";$sc=$script:Green}
        else{
            $now=Get-Date;$exp=$c.ExpiresAt;$dl=[int]([math]::Ceiling(($exp-$now).TotalDays))
            if($dl -le 0){$st=T "expirado";$sc=$script:Red}
            elseif($dl -le 3){$st="$(T 'expiraEn') $dl $(if($dl-ne 1){T 'dias'}else{T 'dia'})";$sc=$script:Orange}
            elseif($dl -le 7){$st="$(T 'expiraEn') $dl $(T 'dias')";$sc=$script:Yellow}
            else{$st="$(T 'activo') - $dl $(T 'dias')";$sc=$script:Green}
        }
        $p2=New-RR 0 $yP ($s.Width-1) $ch2 8
        $bg3=New-Object System.Drawing.SolidBrush($script:CardBG);$bp2=New-Object System.Drawing.Pen($script:CardBorder,1)
        $g.FillPath($bg3,$p2);$g.DrawPath($bp2,$p2);$bg3.Dispose();$bp2.Dispose();$p2.Dispose()
        $dtBr=New-Object System.Drawing.SolidBrush($sc);$g.FillEllipse($dtBr,12,($yP+12),8,8);$dtBr.Dispose()
        $ctb=New-Object System.Drawing.SolidBrush($script:White);$g.DrawString($c.Code,$script:FntCodeT,$ctb,28,($yP+8));$ctb.Dispose()
        $gtb=New-Object System.Drawing.SolidBrush($script:Gray);$g.DrawString($c.Game,$script:FntCodeS,$gtb,28,($yP+26));$gtb.Dispose()
        $etb=New-Object System.Drawing.SolidBrush($script:Gray);$g.DrawString("$(T 'expira') $($exp.ToString('dd/MM/yyyy'))",$script:FntCodeS,$etb,28,($yP+40));$etb.Dispose()
        $stb=New-Object System.Drawing.SolidBrush($sc);$stsz=$g.MeasureString($st,$script:FntCodeSt)
        $g.DrawString($st,$script:FntCodeSt,$stb,($s.Width-$stsz.Width-12),($yP+10));$stb.Dispose()
        $yP+=$ch2+$gp2
    }
})
$script:rp.Controls.Add($script:clp)
$form.Controls.Add($script:rp)

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  SYSTEM TRAY (NotifyIcon)
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
$script:trayIcon = New-Object System.Windows.Forms.NotifyIcon
$script:trayIcon.Icon = $form.Icon
$script:trayIcon.Text = "BastissSteam activator"
$script:trayIcon.Visible = $false

# Tray context menu
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$trayMenu.BackColor = $CardBG
$trayMenu.ForeColor = $White
$trayMenu.Font = New-Object System.Drawing.Font("Bahnschrift",9.5)
$trayMenu.Renderer = New-Object System.Windows.Forms.ToolStripProfessionalRenderer(
    New-Object System.Windows.Forms.ProfessionalColorTable
)

$menuAbrir = New-Object System.Windows.Forms.ToolStripMenuItem("Abrir")
$menuAbrir.Add_Click({
    $form.Show(); $form.WindowState = 'Normal'
    $form.Activate(); $script:trayIcon.Visible = $false
})
$menuCerrar = New-Object System.Windows.Forms.ToolStripMenuItem("Cerrar")
$menuCerrar.Add_Click({
    $script:reallyClose = $true
    $script:trayIcon.Visible = $false
    $script:trayIcon.Dispose()
    $form.Close()
})
$trayMenu.Items.Add($menuAbrir) | Out-Null
$trayMenu.Items.Add($menuCerrar) | Out-Null
$script:trayIcon.ContextMenuStrip = $trayMenu

# Double-click tray icon to restore
$script:trayIcon.Add_DoubleClick({
    $form.Show(); $form.WindowState = 'Normal'
    $form.Activate(); $script:trayIcon.Visible = $false
})

# Intercept form close -> minimize to tray
$script:reallyClose = $false
$form.Add_FormClosing({
    param($sender, $ev)
    if (-not $script:reallyClose) {
        $ev.Cancel = $true
        $form.Hide()
        $script:trayIcon.Visible = $true
        $script:trayIcon.ShowBalloonTip(2000, "BastissSteam", "El programa sigue activo en segundo plano.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  DOWNLOAD WATCHER (auto-detect new Steam game installs)
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
if ($script:steamLibs -eq $null) { try { $script:steamLibs = Get-SteamLibraries; $script:steamLibsCacheTime = Get-Date } catch {} }
$script:steamWatchTimer = New-Object System.Windows.Forms.Timer
$script:steamWatchTimer.Interval = 3000
$script:steamWatchTimer.Add_Tick({
    try {
        if ($script:fixesJob -eq $null -and ($script:fixesCache.Count -eq 0 -or ((Get-Date) - $script:fixesCacheTime).TotalSeconds -gt 120)) {
            $script:fixesJob = Start-Job -ScriptBlock {
                try {
                    $r = Invoke-RestMethod -Uri "https://www.mediafire.com/api/1.5/folder/get_content.php?folder_key=3o9127pseyx49&response_format=json&content_type=files" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                    $fixes = @{}
                    if ($r.response.folder_content.files) { foreach ($f in $r.response.folder_content.files) { $fixes[($f.filename -replace '\.zip$', '')] = $f.links.normal_download } }
                    return $fixes
                } catch { return @{} }
            }
        }
        if ($script:fixesJob -and $script:fixesJob.IsCompleted) {
            try { $result = Receive-Job $script:fixesJob -ErrorAction Stop; if ($result -and $result.Count -gt 0) { $script:fixesCache = $result } } catch {}
            $script:fixesCacheTime = Get-Date
            Remove-Job $script:fixesJob -ErrorAction SilentlyContinue
            $script:fixesJob = $null
        }
        $fixes = $script:fixesCache

        # Completing pending installs
        $donePending = @()
        foreach ($name in $script:downloadPendingFixes.Keys) {
            $info = $script:downloadPendingFixes[$name]
            if ($info.dlJob -and -not $info.dlJob.IsCompleted) { continue }
            if ($info.dlJob -and $info.dlJob.IsCompleted) { try { $null = Receive-Job $info.dlJob -ErrorAction Stop } catch {}; Remove-Job $info.dlJob -ErrorAction SilentlyContinue }
            if (-not (Test-Path $info.zipPath)) { $donePending += $name; continue }
            $gameFound = $null
            if ($script:steamLibs) { foreach ($lib in $script:steamLibs) { $common = Join-Path $lib "steamapps\common"; $candidate = Join-Path $common $name; if (Test-Path $candidate) { $gameFound = $candidate; break } } }
            if (-not $gameFound) { continue }
            try {
                $er = @()
                try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue; $z = [System.IO.Compression.ZipFile]::OpenRead($info.zipPath); foreach ($e in $z.Entries) { if ($e.Name) { $er += $e.FullName } }; $z.Dispose() } catch {}
                Expand-Archive -Path $info.zipPath -DestinationPath $gameFound -Force
                if ($er.Count -gt 0) { Add-FixManifestEntry $name $gameFound $er }
                Add-AutoFixedGame $name
            } catch {}
            Remove-Item $info.zipPath -Force -ErrorAction SilentlyContinue
            $donePending += $name
        }
        foreach ($name in $donePending) { $script:downloadPendingFixes.Remove($name) }

        # Detect downloading games
        try {
            if (((Get-Date) - $script:steamLibsCacheTime).TotalSeconds -gt 120 -or $script:commonFolderCache.Count -eq 0) {
                try { $script:steamLibs = Get-SteamLibraries; $script:steamLibsCacheTime = Get-Date } catch {}
                $script:commonFolderCache = @{}
                if ($script:steamLibs) { foreach ($l2 in $script:steamLibs) { $cp = Join-Path $l2 "steamapps\common"; if (Test-Path $cp) { Get-ChildItem $cp -Directory -ErrorAction SilentlyContinue | ForEach-Object { $script:commonFolderCache[$_.Name] = $true } } } }
            }
            $fixesCount = $fixes.Count
            if ($script:steamLibs) { foreach ($lib in @($script:steamLibs)) {
                foreach ($scanSpec in @("downloading", "temp", "")) {
                    $dir = if ($scanSpec) { Join-Path (Join-Path $lib "steamapps") $scanSpec } else { Join-Path $lib "steamapps" }
                    if (-not (Test-Path $dir)) { continue }
                    foreach ($mf in Get-ChildItem $dir -Recurse -Filter "*.acf" -ErrorAction SilentlyContinue) {
                        try { $raw = [System.IO.File]::ReadAllText($mf.FullName)
                            $gn = if ($raw -match '"name"\s+"([^"]+)"') { $Matches[1] } elseif ($raw -match '"installdir"\s+"([^"]+)"') { $Matches[1] } else { continue }
                            if ($script:knownDownloading.ContainsKey($gn) -or $script:downloadPendingFixes.ContainsKey($gn)) { continue }
                            $inCommon = $script:commonFolderCache.ContainsKey($gn)
                            $script:knownDownloading[$gn] = $true
                            if (-not $inCommon -and $fixesCount -gt 0) {
                                $fn, $fu = Find-FixForGame $gn $fixes
                                if ($fu) {
                                    $zipPath = Join-Path $env:TEMP "predl_$(Get-Random).zip"
                                    $dlJob = Start-Job -ScriptBlock { param($u, $o) try { $page = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop; $dl = $page.Links | Where-Object { $_.id -eq "downloadButton" } | Select-Object -ExpandProperty href; if (-not $dl) { throw "No download link" }; (New-Object System.Net.WebClient).DownloadFile($dl, $o) } catch {} } -ArgumentList $fu, $zipPath
                                    $script:downloadPendingFixes[$gn] = @{ fix_url = $fu; zipPath = $zipPath; dlJob = $dlJob }
                                }
                            }
                        } catch {}
                    }
                }
                $dlDir = Join-Path (Join-Path $lib "steamapps") "downloading"
                if (Test-Path $dlDir) {
                    foreach ($subDir in Get-ChildItem $dlDir -Directory -ErrorAction SilentlyContinue) {
                        $appid = $subDir.Name
                        if ($script:knownDownloading.ContainsKey($appid) -or $script:downloadPendingFixes.ContainsKey($appid)) { continue }
                        $gn = $null
                        if ($script:steamLibs) { foreach ($sl in $script:steamLibs) { $acfPath = Join-Path (Join-Path $sl "steamapps") "appmanifest_$appid.acf"; if (-not (Test-Path $acfPath)) { continue }; try { $raw = [System.IO.File]::ReadAllText($acfPath) } catch { continue }; $gn = if ($raw -match '"name"\s+"([^"]+)"') { $Matches[1] } elseif ($raw -match '"installdir"\s+"([^"]+)"') { $Matches[1] }; if ($gn) { break } } }
                        if (-not $gn) { try { $r2 = Invoke-RestMethod "https://store.steampowered.com/api/appdetails?appids=$appid" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue; if ($r2.$appid.success -eq $true -and $r2.$appid.data.name) { $gn = $r2.$appid.data.name } } catch {} }
                        if (-not $gn) { $script:knownDownloading[$appid] = $true; continue }
                        if ($script:downloadPendingFixes.ContainsKey($gn)) { $script:knownDownloading[$appid] = $true; continue }
                        $inCommon = $script:commonFolderCache.ContainsKey($gn)
                        if ($inCommon) { $script:knownDownloading[$appid] = $true; continue }
                        if ($fixesCount -eq 0) { continue }
                        $fn, $fu = Find-FixForGame $gn $fixes
                        if (-not $fu) { $script:knownDownloading[$appid] = $true; continue }
                        $zipPath = Join-Path $env:TEMP "predl_$(Get-Random).zip"
                        $dlJob = Start-Job -ScriptBlock { param($u, $o) try { $page = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop; $dl = $page.Links | Where-Object { $_.id -eq "downloadButton" } | Select-Object -ExpandProperty href; if (-not $dl) { throw "No download link" }; (New-Object System.Net.WebClient).DownloadFile($dl, $o) } catch {} } -ArgumentList $fu, $zipPath
                        $script:downloadPendingFixes[$gn] = @{ fix_url = $fu; zipPath = $zipPath; dlJob = $dlJob }
                        $script:knownDownloading[$appid] = $true
                    }
                }
            } }
        } catch {}

        if ($fixesCount -gt 0) {
            $done = @()
            foreach ($name in $script:fixJobs.Keys) {
                $info = $script:fixJobs[$name]
                try { if ($info.job.IsCompleted) {
                    $er = @(Receive-Job $info.job -ErrorAction Stop)
                    Remove-Job $info.job -ErrorAction SilentlyContinue
                    if ($er.Count -gt 0) { Add-FixManifestEntry $name $info.path $er }
                    Add-AutoFixedGame $name
                    $done += $name
                } } catch { Remove-Job $info.job -ErrorAction SilentlyContinue; $done += $name }
            }
            foreach ($name in $done) { $script:fixJobs.Remove($name) }
        }

        $curFolders = @{}
        if (((Get-Date) - $script:steamLibsCacheTime).TotalSeconds -gt 120) { try { $script:steamLibs = Get-SteamLibraries; $script:steamLibsCacheTime = Get-Date } catch {} }
        if ($script:steamLibs) { foreach ($lib in $script:steamLibs) { $common = Join-Path $lib "steamapps\common"; if (Test-Path $common) { Get-ChildItem $common -Directory -ErrorAction SilentlyContinue | ForEach-Object { $curFolders[$_.Name] = $_.FullName } } } }
        $noGameFolders = @("Steamworks Shared", "Steam Controller Configs")
        foreach ($name in $curFolders.Keys) {
            if ($noGameFolders -contains $name) { continue }
            if ($script:fixedNewGames.ContainsKey($name)) { continue }
            if ($script:fixJobs.ContainsKey($name)) { continue }
            if ($script:downloadPendingFixes.ContainsKey($name)) { continue }
            $script:fixedNewGames[$name] = $true
            if ($fixesCount -eq 0) { continue }
            $fn, $fu = Find-FixForGame $name $fixes
            if ($fu) {
                $zip = Join-Path $env:TEMP "newfix_$(Get-Random).zip"
                $job = Start-Job -ScriptBlock {
                    param($u, $o, $p) try { $page = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
                    $dl = $page.Links | Where-Object { $_.id -eq "downloadButton" } | Select-Object -ExpandProperty href
                    if (-not $dl) { throw "No download link" }
                    (New-Object System.Net.WebClient).DownloadFile($dl, $o)
                    Expand-Archive -Path $o -DestinationPath $p -Force -ErrorAction Stop
                    $er = @()
                    try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue; $z = [System.IO.Compression.ZipFile]::OpenRead($o); foreach ($e in $z.Entries) { if ($e.Name) { $er += $e.FullName } }; $z.Dispose() } catch {}
                    Remove-Item $o -Force -ErrorAction SilentlyContinue
                    return $er } catch { return @() }
                } -ArgumentList $fu, $zip, $curFolders[$name]
                $script:fixJobs[$name] = @{job=$job; path=$curFolders[$name]}
            }
        }
    } catch {}
})
$script:steamWatchTimer.Start()

# Sync activeCodes from real timer file on startup
function Sync-ActiveCodesFromTimers {
    # Only add codes from file that aren't in memory yet (never remove from memory here)
    if (-not (Test-Path $TIMERS_FILE)) { return }
    $realTimers = Get-ActiveTimers
    $memGameNames = @($script:activeCodes | ForEach-Object { $_.Game })
    foreach ($t in $realTimers) {
        $exp = $t.expires_at -as [datetime]
        if (-not $exp) { continue }
        if ($memGameNames -contains $t.game_name) { continue }
        $c = if ($t.redeem_code) { $t.redeem_code } else { $t.game_name }
        $d = if ($t.PSObject.Properties.Name -contains 'duration') { $t.duration } else { $null }
        $script:activeCodes.Add(@{Code=$c;Game=$t.game_name;ActivatedAt=(Get-Date);ExpiresAt=$exp;Duration=$d})|Out-Null
    }
}
Sync-ActiveCodesFromTimers

# ── Launch download_watcher.ps1 hidden in background ──
$script:watcherProcess = $null
$script:watcherLogPath = Join-Path $env:TEMP "bsmap_watcher.log"
try {
    $watcherTemp = Join-Path $env:TEMP "bsmap_watcher.ps1"
    $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($script:watcherSourceB64))
    Set-Content -Path $watcherTemp -Value $decoded -Force -Encoding UTF8
    if (Test-Path $watcherTemp) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watcherTemp`""
        $psi.WindowStyle = "Hidden"
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        $script:watcherProcess = [System.Diagnostics.Process]::Start($psi)
    }
} catch { Write-ErrorLog "Launch watcher" $_ }

[System.Windows.Forms.Application]::Run($form)
$script:trayIcon.Dispose()
if ($script:countdownTick) { $script:countdownTick.Stop(); $script:countdownTick.Dispose() }
if ($script:refreshTimers) { $script:refreshTimers.Stop(); $script:refreshTimers.Dispose() }
if ($script:urlChecker) { $script:urlChecker.Stop(); $script:urlChecker.Dispose() }
if ($script:steamWatchTimer) { $script:steamWatchTimer.Stop(); $script:steamWatchTimer.Dispose() }
if ($script:watcherLogTimer) { $script:watcherLogTimer.Stop(); $script:watcherLogTimer.Dispose() }
if ($script:watcherProcess -and -not $script:watcherProcess.HasExited) { try { $script:watcherProcess.Kill() } catch {} }
if ($script:fixJobs) { foreach ($j in $script:fixJobs.Values) { try { Remove-Job $j.job -Force -ErrorAction SilentlyContinue } catch {} } }
if ($script:fixesJob) { try { Remove-Job $script:fixesJob -Force -ErrorAction SilentlyContinue } catch {} }
if ($script:downloadPendingFixes) { foreach ($d in $script:downloadPendingFixes.Values) { try { if ($d.dlJob) { Remove-Job $d.dlJob -Force -ErrorAction SilentlyContinue } } catch {} } }
$script:logoBmp.Dispose();$script:tiktokBmp.Dispose();$script:discordBmp.Dispose();$ib.Dispose()


# b64 placeholder

