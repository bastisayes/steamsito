param([int]$Port = 9876)
$ErrorActionPreference = "Continue"
$srvPort = $Port
$startLog = Join-Path $env:LOCALAPPDATA "BastissSteam\server_start.log"
try { Add-Content $startLog "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INICIO port=$srvPort payload=$($MyInvocation.MyCommand.Path)" -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
$jsonDb = Join-Path $PSScriptRoot "codes.json"
$script:pubUrl = "http://127.0.0.1:$srvPort"
$script:urlCache = Join-Path $env:TEMP "bsmap_current_url.txt"
$script:ghKey = ""
try {
    $tokFile = Join-Path $PSScriptRoot "gh_token.txt"
    if (-not (Test-Path $tokFile)) { $tokFile = Join-Path $env:LOCALAPPDATA "BastissSteam\gh_token.txt" }
    if (Test-Path $tokFile) { $script:ghKey = (Get-Content $tokFile -Raw).Trim() }
} catch {}
$script:ghRepo = "bastisayes/Fixes-steam"
$script:ghFile = "original_blue.ps1"
if (-not (Test-Path $jsonDb)) { Set-Content $jsonDb '{"codes":{},"redemptions":[]}' -Encoding UTF8 }
function Load-Db {
    try { return Get-Content $jsonDb -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return @{codes=@{};redemptions=@()} }
}
function Save-Db { param($d); try { $d | ConvertTo-Json -Depth 10 | Set-Content $jsonDb -Encoding UTF8 } catch {} }
function Get-MachineId {
    try { return (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop).UUID }
    catch { try { return (Get-CimInstance Win32_BIOS).SerialNumber.Trim() } catch {} }
    return "UNKNOWN"
}
$pageHtml = @'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Canje de Codigos - Fixes Steam</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',Arial,sans-serif;background:#0a0e14;color:#e6e6e6;min-height:100vh}
.container{max-width:860px;margin:0 auto;padding:24px}
.header{text-align:center;margin-bottom:28px}
.header h1{color:#00d4ff;font-size:30px;font-weight:800}
.panel{background:#141a23;border:1px solid #252c36;border-radius:10px;padding:28px}
.form-group{margin-bottom:18px}
label{display:block;margin-bottom:6px;color:#6a737d;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.8px}
input,textarea,select{width:100%;padding:11px 14px;background:#0a0e14;border:1px solid #252c36;border-radius:8px;color:#e6e6e6;font-size:14px}
.btn{padding:11px 22px;border:none;border-radius:8px;font-size:14px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;gap:6px}
.btn-primary{background:#00d4ff;color:#0a0e14}
.btn-danger{background:#f85149;color:#fff}
.btn-success{background:#00ff88;color:#0a0e14}
.btn-sm{padding:7px 14px;font-size:12px}
.btn-ghost{background:#252c36;color:#e6e6e6}
.msg{padding:13px 18px;border-radius:8px;margin-bottom:18px;font-size:14px;display:none}
.msg.error{display:block;background:#2d1b1b;border:1px solid #f85149;color:#f85149}
.msg.success{display:block;background:#1b2d1b;border:1px solid #00ff88;color:#00ff88}
.section-title{color:#00d4ff;font-size:16px;font-weight:700;margin-bottom:16px;padding-bottom:8px;border-bottom:2px solid #252c36}
.codes-grid{display:grid;gap:10px}
.code-card{background:#0a0e14;border:1px solid #252c36;border-radius:8px;padding:14px 18px}
.code-card .code{color:#00d4ff;font-family:Consolas,monospace;font-size:15px;font-weight:700}
.code-card .meta{color:#6a737d;font-size:12px;margin-top:5px}
.code-card .links-list{margin-top:8px;font-size:12px}
.code-card .links-list a{color:#00ff88;text-decoration:none;display:block;padding:3px 0;word-break:break-all}
.code-card .redeemed-list{color:#6a737d;font-size:11px;margin-top:6px}
.code-card .card-actions{margin-top:10px;display:flex;gap:6px;flex-wrap:wrap}
.status-used{color:#00ff88;font-weight:600}
.status-full{color:#f85149;font-weight:600}
.status-available{color:#00d4ff;font-weight:600}
.footer{text-align:center;color:#252c36;font-size:12px;margin-top:32px;padding:16px;border-top:1px solid #252c36}
#pubUrlBox{word-break:break-all;padding:10px 14px;background:#0f1520;border:1px solid #00d4ff33;border-radius:8px;font-size:13px;margin-top:12px}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>Canje de Codigos</h1>
<p>Fixes Steam</p>
<div id="pubUrlBox">
<span style="color:#6a737d">URL publica:</span>
<span style="color:#00ff88;font-family:Consolas;font-weight:700;user-select:all" id="pubUrlSpan">__PUBLIC_URL__</span>
<button class="btn btn-sm btn-primary" style="margin-left:8px" onclick="copyPubUrl()">Copiar</button>
</div>
<div style="margin-top:8px;background:#0f1520;border:1px solid #252c36;border-radius:8px;padding:8px 14px;font-size:12px;color:#6a737d">
Activar: <span style="color:#00ff88">irm https://raw.githubusercontent.com/bastisayes/steamsito/main/BastissSteamActivator2.ps1 | iex</span>
</div>
</div>
<div class="panel">
<div id="adminMsg" class="msg"></div>
<div class="section-title">Crear codigo</div>
<div class="form-group">
<label>Codigo (vacio = auto)</label>
<input type="text" id="newCode" placeholder="XVSX-VXHA-ASDA-XDASD" maxlength="50" onkeyup="this.value=this.value.toUpperCase()" autocomplete="off">
</div>
<div class="form-group">
<label>Nombre del usuario</label>
<input type="text" id="userName" placeholder="cliente / nombre (opcional)" maxlength="50" autocomplete="off">
</div>
<div class="form-group">
<label>Usos maximos</label>
<input type="number" id="maxUses" value="1" min="1" max="999">
</div>
<div class="form-group">
<label>Duracion</label>
<div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
<input type="number" id="durD" value="0" min="0" style="width:55px;text-align:center" oninput="calcDur()">d
<input type="number" id="durH" value="1" min="0" style="width:55px;text-align:center" oninput="calcDur()">h
<input type="number" id="durM" value="0" min="0" style="width:55px;text-align:center" oninput="calcDur()">m
<input type="number" id="durS" value="0" min="0" style="width:55px;text-align:center" oninput="calcDur()">s
<input type="hidden" id="duration" value="3600">
<span id="durTotal" style="color:#00d4ff;font-size:12px">= 1 hora</span>
</div>
<div style="margin-top:8px;display:flex;gap:6px;flex-wrap:wrap">
<button class="btn btn-sm btn-ghost" onclick="pickDur(0,1,0,0)">1h</button>
<button class="btn btn-sm btn-ghost" onclick="pickDur(0,8,0,0)">8h</button>
<button class="btn btn-sm btn-ghost" onclick="pickDur(1,0,0,0)">1d</button>
<button class="btn btn-sm btn-ghost" onclick="pickDur(7,0,0,0)">7d</button>
<button class="btn btn-sm btn-ghost" onclick="pickDur(30,0,0,0)">30d</button>
<button class="btn btn-sm btn-ghost" onclick="pickDur(0,0,0,0)">Perm</button>
</div>
</div>
<div class="form-group">
<label>Links</label>
<div id="linksContainer"></div>
<button class="btn btn-sm btn-primary" onclick="addLink()">+ Link</button>
</div>
<button class="btn btn-success" onclick="createCode()">Crear Codigo</button>
<button class="btn btn-primary" onclick="create14LotesCode()">Crear codigo con 14 lotes</button>
<div id="createdCodeDisplay" style="display:none;margin-top:12px;padding:14px;background:#0a0e14;border:2px solid #00ff88;border-radius:8px;text-align:center">
<div style="color:#00ff88;font-size:13px;font-weight:700;margin-bottom:6px">CODIGO CREADO</div>
<div style="color:#fff;font-size:22px;font-weight:700;font-family:Consolas;letter-spacing:2px" id="createdCodeText"></div>
<button class="btn btn-sm btn-primary" style="margin-top:8px" onclick="copyCreatedCode()">Copiar codigo</button>
</div>
<hr style="border:none;border-top:2px solid #252c36;margin:24px 0">
<div class="section-title">Codigos existentes</div>
<div id="codesList"><p style="color:#6a737d;text-align:center;padding:20px">Cargando...</p></div>
</div>
<div class="footer">Servidor PowerShell &bull; localhost.run Tunnel &bull; <span id="status">Conectado</span></div>
</div>
<script>
function calcDur(){const d=+document.getElementById('durD').value||0,h=+document.getElementById('durH').value||0,m=+document.getElementById('durM').value||0,s=+document.getElementById('durS').value||0;const t=d*86400+h*3600+m*60+s;document.getElementById('duration').value=t;const e=document.getElementById('durTotal');e.textContent=t?t+'s':'Perm'}
function pickDur(d,h,m,s){document.getElementById('durD').value=d;document.getElementById('durH').value=h;document.getElementById('durM').value=m;document.getElementById('durS').value=s;calcDur()}
calcDur();loadCodes();
function copyPubUrl(){const t=document.getElementById('pubUrlSpan').textContent;navigator.clipboard.writeText(t).catch(()=>{const ta=document.createElement('textarea');ta.value=t;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta)})}
function showMsg(id,text,type){const e=document.getElementById(id);e.className='msg '+type;e.textContent=text;e.style.display='block';if(type==='success')setTimeout(()=>e.style.display='none',5000)}
function addLink(v){v=v||'';const c=document.getElementById('linksContainer');const d=document.createElement('div');d.style='margin-bottom:6px';d.innerHTML='<input type="text" placeholder="https://www.mediafire.com/file/..." value="'+v.replace(/"/g,'"')+'" style="width:85%;padding:8px;background:#0a0e14;border:1px solid #252c36;border-radius:6px;color:#e6e6e6"><button onclick="this.parentElement.remove()" style="background:#f8514933;color:#f85149;border:none;border-radius:4px;padding:4px 10px;margin-left:6px;cursor:pointer">X</button>';c.appendChild(d)}
function getLinks(){return Array.from(document.querySelectorAll('#linksContainer input')).map(i=>i.value.trim()).filter(v=>v)}
function fmtDur(secs){if(secs<=0)return'Permanente';const d=Math.floor(secs/86400),h=Math.floor((secs%86400)/3600),m=Math.floor((secs%3600)/60),s=secs%60;let r=[];if(d)r.push(d+'d');if(h)r.push(h+'h');if(m)r.push(m+'m');if(s)r.push(s+'s');return r.join(' ')}
function genCode(){const r=()=>Math.random().toString(36).substring(2,6).toUpperCase();return r()+'-'+r()+'-'+r()+'-'+r()}
async function createCode(){const code=document.getElementById('newCode').value.trim().toUpperCase()||genCode();const maxUses=+document.getElementById('maxUses').value||1;const duration=+document.getElementById('duration').value||0;const name=document.getElementById('userName').value.trim();const links=getLinks();if(links.length===0){showMsg('adminMsg','Agrega al menos un link','error');return}
const res=await fetch('/api/create-code',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code,max_uses:maxUses,links,duration,name})});const data=await res.json();if(data.ok){showMsg('adminMsg','Codigo creado: '+code,'success');document.getElementById('newCode').value='';document.getElementById('userName').value='';document.getElementById('createdCodeText').textContent=code;document.getElementById('createdCodeDisplay').style.display='block';loadCodes()}else{showMsg('adminMsg',data.err,'error')}}
async function create14LotesCode(){document.getElementById('newCode').value='';document.getElementById('maxUses').value=1;pickDur(30,0,0,0);document.getElementById('linksContainer').innerHTML='';for(let i=1;i<=14;i++){addLink('https://raw.githubusercontent.com/bastisayes/Fixes-steam/main/lotes/lote%20'+i+'.zip')}window.scrollTo({top:0,behavior:'smooth'})}function copyCreatedCode(){const t=document.getElementById('createdCodeText').textContent;navigator.clipboard.writeText(t).catch(()=>{const ta=document.createElement('textarea');ta.value=t;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta)})}
function copyExistingCode(code){navigator.clipboard.writeText(code).catch(()=>{const ta=document.createElement('textarea');ta.value=code;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta)});showMsg('adminMsg','Codigo copiado: '+code,'success')}
async function loadCodes(){try{const res=await fetch('/api/codes');const data=await res.json();const list=document.getElementById('codesList');if(!data.codes||Object.keys(data.codes).length===0){list.innerHTML='<p style="color:#6a737d;text-align:center;padding:20px">No hay codigos todavia</p>';return}
let html='<div class="codes-grid">';const sorted=Object.entries(data.codes).sort((a,b)=>(b[1].pinned?1:0)-(a[1].pinned?1:0));for(const[code,info]of sorted){const sc=info.used_count>=info.max_uses?'status-full':(info.used_count>0?'status-used':'status-available');const st=info.used_count>=info.max_uses?'AGOTADO':(info.used_count+'/'+info.max_uses+' usos');html+='<div class="code-card"><div class="code" style="display:flex;align-items:center;gap:8px"><span>'+(info.pinned?'&#128204; ':'')+code+'</span><button class="btn btn-sm btn-primary" onclick="copyExistingCode(\''+code.replace(/'/g,"\\'")+'\')">Copiar</button></div><div class="meta">Usos: <span class="'+sc+'">'+st+'</span> &bull; Duracion: '+fmtDur(info.duration)+'</div><div class="links-list">'+info.links.map(l=>'<a href="'+l+'" target="_blank">'+l+'</a>').join('')+'</div><div class="redeemed-list">IDs: '+(info.redeemed_by&&info.redeemed_by.length?info.redeemed_by.join(', '):'ninguno')+'</div><div class="card-actions">'
html+='<button class="btn btn-sm btn-ghost" onclick="pinCode(\''+code.replace(/'/g,"\\'")+'\')">'+(info.pinned?'Desfijar':'Fijar')+'</button>'
html+='<button class="btn btn-sm btn-primary" onclick="dupCode(\''+code.replace(/'/g,"\\'")+'\')">Duplicar</button>'
html+='<button class="btn btn-sm btn-ghost" onclick="renewCode(\''+code.replace(/'/g,"\\'")+'\')">Renovar</button>'
if(info.redeemed_by&&info.redeemed_by.length>0){html+='<button class="btn btn-sm btn-danger" onclick="showRemPc(\''+code.replace(/'/g,"\\'")+'\',[\''+info.redeemed_by.join("','")+'\'])">Remover PC</button>'}
html+='<button class="btn btn-sm btn-danger" onclick="delCode(\''+code.replace(/'/g,"\\'")+'\')">Eliminar</button>'
html+='</div></div>'}
html+='</div>';list.innerHTML=html}catch(e){document.getElementById('codesList').innerHTML='<p style="color:#f85149">Error: '+e.message+'</p>'}}
async function delCode(code){if(!confirm('Eliminar codigo '+code+'?'))return;const res=await fetch('/api/delete-code',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code})});const data=await res.json();if(data.ok){showMsg('adminMsg','Codigo eliminado: '+code,'success');loadCodes()}else{showMsg('adminMsg',data.err,'error')}}
async function pinCode(code){const res=await fetch('/api/pin-code',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code})});const data=await res.json();if(data.ok){showMsg('adminMsg',data.pinned?'Fijado: '+code:'Desfijado: '+code,'success');loadCodes()}else{showMsg('adminMsg',data.err,'error')}}
async function renewCode(code){if(!confirm('Renovar codigo '+code+'?'))return;const res=await fetch('/api/renew-code',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code})});const data=await res.json();if(data.ok){showMsg('adminMsg','Renovado: '+code,'success');loadCodes()}else{showMsg('adminMsg',data.err,'error')}}
function dupCode(code){fetch('/api/codes').then(r=>r.json()).then(data=>{const info=data.codes[code];if(!info)return;document.getElementById('newCode').value='';document.getElementById('maxUses').value=info.max_uses;const d=info.duration||0;document.getElementById('durD').value=Math.floor(d/86400);document.getElementById('durH').value=Math.floor((d%86400)/3600);document.getElementById('durM').value=Math.floor((d%3600)/60);document.getElementById('durS').value=d%60;calcDur();document.getElementById('linksContainer').innerHTML='';info.links.forEach(l=>addLink(l));window.scrollTo({top:0,behavior:'smooth'})})}
function showRemPc(code,ids){const o=document.createElement('div');o.style.cssText='position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.7);z-index:100;display:flex;align-items:center;justify-content:center';let h='<div style="background:#141a23;border:1px solid #252c36;border-radius:10px;padding:24px;max-width:400px;width:90%"><h3 style="color:#00d4ff;margin-bottom:16px">Remover PC de: '+code+'</h3>';ids.forEach(id=>{h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:8px 12px;background:#0a0e14;border:1px solid #252c36;border-radius:6px;margin-bottom:6px"><span style="color:#e6e6e6;font-family:Consolas;font-size:12px">'+id+'</span><button class="btn btn-sm btn-danger" onclick="remPc(\''+code.replace(/'/g,"\\'")+'\',\''+id+'\',this)">X</button></div>'})
h+='<button class="btn btn-sm btn-ghost" style="margin-top:12px;width:100%" onclick="this.closest(\'div[style*=fixed]\').remove()">Cerrar</button></div>';o.innerHTML=h;o.onclick=e=>{if(e.target===o)o.remove()};document.body.appendChild(o)}
async function remPc(code,cid,btn){const res=await fetch('/api/remove-redeemed',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code,client_id:cid})});const data=await res.json();if(data.ok){btn.parentElement.remove();showMsg('adminMsg',cid+' removido','success');loadCodes()}else{showMsg('adminMsg',data.err,'error')}}
</script>
</body>
</html>
'@
# Kill old tunnels (ssh + cloudflared)
try { & taskkill /F /T /IM ssh.exe 2>&1 | Out-Null } catch {}
try { & taskkill /F /T /IM cloudflared.exe 2>&1 | Out-Null } catch {}
Start-Sleep -Milliseconds 800
# Start cloudflare tunnel (no account, auto-assigned *.trycloudflare.com URL)
$cfLog = Join-Path $env:TEMP "cf_tunnel_bsmap.log"
$cfPath = Join-Path $PSScriptRoot "cloudflared.exe"
$script:cfCmdPid = $null
$script:lastCfStart = [datetime]::MinValue
$script:lastUrlPushed = ""
function Start-Tunnel {
    try {
        Remove-Item $cfLog -Force -ErrorAction SilentlyContinue
        New-Item $cfLog -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
        $cfPsi = New-Object System.Diagnostics.ProcessStartInfo
        $cfPsi.FileName = "cmd.exe"
        $cfPsi.Arguments = '/c ""' + $cfPath + '" tunnel --url http://127.0.0.1:' + $srvPort + ' --no-autoupdate > "' + $cfLog + '" 2>&1"'
        $cfPsi.UseShellExecute = $false
        $cfPsi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($cfPsi)
        if ($p) { $script:cfCmdPid = $p.Id; $script:lastCfStart = [datetime]::UtcNow }
    } catch {}
}
Start-Tunnel
# TCP Listener (IPv4-only)
$tcpListener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $srvPort)
$tcpListener.Start(100)
function Send-HttpResponse {
    param($client, [string]$body, [string]$contentType = "text/html; charset=utf-8", [int]$statusCode = 200)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $statusLine = "HTTP/1.1 $statusCode OK`r`n"
    $headers = "Content-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`n`r`n"
    $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($statusLine + $headers)
    try { $stream = $client.GetStream(); $stream.Write($responseBytes, 0, $responseBytes.Length); $stream.Write($bytes, 0, $bytes.Length); $stream.Flush() } catch {} finally { try { $client.Close() } catch {} }
}
function Read-HttpRequest {
    param($client)
    try {
        $stream = $client.GetStream(); $stream.ReadTimeout = 3000; $stream.WriteTimeout = 3000
        $buf = New-Object byte[] 65536; $totalRead = 0; $headerEnd = -1; $rawStr = ""
        $readDeadline = [datetime]::UtcNow.AddSeconds(5)
        do {
            if ($totalRead -ge $buf.Length) { break }
            if ([datetime]::UtcNow -gt $readDeadline) { return $null }
            $n = $stream.Read($buf, $totalRead, $buf.Length - $totalRead)
            if ($n -le 0) { break }
            $totalRead += $n
            $rawStr = [System.Text.Encoding]::ASCII.GetString($buf, 0, $totalRead)
            $headerEnd = $rawStr.IndexOf("`r`n`r`n")
        } while ($headerEnd -lt 0 -and $totalRead -lt 65536)
        if ($headerEnd -lt 0) { return $null }
        $requestLine = ($rawStr.Substring(0, $headerEnd) -split "`r`n")[0]
        $bodyLen = 0
        $headers = $rawStr.Substring(0, $headerEnd) -split "`r`n"
        foreach ($h in $headers) { if ($h -match "^Content-Length:\s*(\d+)") { $bodyLen = [int]$Matches[1] } }
        $body = ""
        if ($bodyLen -gt 0) {
            $bodyStart = $headerEnd + 4
            $bodyEnd = $bodyStart + $bodyLen
            if ($totalRead -ge $bodyEnd) { $body = [System.Text.Encoding]::UTF8.GetString($buf, $bodyStart, $bodyLen) }
            else {
                $need = $bodyEnd - $totalRead
                while ($need -gt 0 -and [datetime]::UtcNow -le $readDeadline) {
                    $r = $stream.Read($buf, $totalRead, $need)
                    if ($r -le 0) { break }
                    $totalRead += $r; $need -= $r
                }
                $body = [System.Text.Encoding]::UTF8.GetString($buf, $bodyStart, $bodyLen)
            }
        }
        return @{ Method = ($requestLine -split ' ')[0]; Path = ($requestLine -split ' ')[1]; Body = $body }
    } catch { return $null }
}
function Read-Body {
    param($client, [int]$contentLength)
    try {
        $stream = $client.GetStream()
        $body = New-Object byte[] $contentLength
        $totalRead = 0
        $readDeadline = [datetime]::UtcNow.AddSeconds(5)
        do {
            if ([datetime]::UtcNow -gt $readDeadline) { return "" }
            $n = $stream.Read($body, $totalRead, $contentLength - $totalRead)
            if ($n -le 0) { break }
            $totalRead += $n
        } while ($totalRead -lt $contentLength)
        return [System.Text.Encoding]::UTF8.GetString($body, 0, $totalRead)
    } catch { return "" }
}
function Monitor-Url {
    try {
        $out = Get-Content $cfLog -Raw -ErrorAction SilentlyContinue
        if (-not $out) { return }
        $matches = [regex]::Matches($out, 'https://[a-zA-Z0-9-]+\.trycloudflare\.com')
        if ($matches.Count -gt 0) {
            $newUrl = $matches[$matches.Count - 1].Value
            $script:lastUrlSeen = [datetime]::UtcNow
            if ($newUrl -ne $script:pubUrl) {
                $script:pubUrl = $newUrl
                Set-Content $script:urlCache $newUrl -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}
function Push-UrlToGitHub {
    param([string]$newUrl)
    try {
        if ($newUrl -eq $script:lastUrlPushed) { return }
        $b64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($newUrl))
        $body = @{message = "URL update"; content = $b64} | ConvertTo-Json -Compress
        $existing = Invoke-RestMethod -Uri "https://api.github.com/repos/$script:ghRepo/contents/current_url.txt" -Headers @{Authorization = "token $script:ghKey"} -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($existing.sha) { $body = @{message = "URL update"; content = $b64; sha = $existing.sha} | ConvertTo-Json -Compress }
        $null = Invoke-RestMethod -Uri "https://api.github.com/repos/$script:ghRepo/contents/current_url.txt" -Method Put -Headers @{Authorization = "token $script:ghKey"} -Body $body -ContentType "application/json" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $script:lastUrlPushed = $newUrl
    } catch {}
}
$lastUrlCheck = [datetime]::MinValue
$lastGhPush = [datetime]::MinValue
$script:lastUrlSeen = [datetime]::UtcNow
while ($true) {
    if (-not $tcpListener.Server.Poll(500000, [System.Net.Sockets.SelectMode]::SelectRead)) {
        # Monitor URL from SSH log every 500ms
        Monitor-Url
        # Push to GitHub every 5 seconds if URL changed
        $now = [datetime]::UtcNow
        if (($now - $lastGhPush).TotalSeconds -ge 5) {
            $lastGhPush = $now
            if ($script:pubUrl -match "^https://") { Push-UrlToGitHub $script:pubUrl }
        }
        # Check cloudflared zombie every 30 seconds: solo reiniciar si el proceso no existe
        # o si no publico una URL en los ultimos 3 minutos (Get-NetTCPConnection puede dar falsos negativos)
        if (($now - $script:lastCfStart).TotalSeconds -gt 30) {
            $cfProcs = @(Get-Process cloudflared -ErrorAction SilentlyContinue)
            $lastUrl = if ($script:lastUrlPushed) { $script:lastUrlPushed } else { $script:pubUrl }
            $urlAge = if ($lastUrl) { ($now - $script:lastUrlSeen).TotalSeconds } else { 9999 }
            if ($cfProcs.Count -eq 0 -or $urlAge -gt 180) {
                try { & taskkill /F /T /IM cloudflared.exe 2>&1 | Out-Null } catch {}
                Start-Tunnel
            }
        }
        continue
    }
    try { $client = $tcpListener.AcceptTcpClient() } catch { continue }
    try {
        $req = Read-HttpRequest $client
        if (-not $req) { Send-HttpResponse $client '{"ok":false}' "application/json" 400; continue }
        $path = $req.Path
        # GET / - serve panel HTML
        if ($path -eq "/" -or $path -eq "/index.html") {
            Send-HttpResponse $client ($pageHtml -replace '__PUBLIC_URL__', $script:pubUrl)
            continue
        }
        # GET /api/codes - list all codes
        if ($path -eq "/api/codes") {
            $d = Load-Db
            $body = @{ok=$true;codes=$d.codes} | ConvertTo-Json -Depth 10
            Send-HttpResponse $client $body "application/json; charset=utf-8"
            continue
        }
        # POST endpoints - need body
        if ($path -in @("/api/create-code","/api/redeem-code","/api/delete-code","/api/pin-code","/api/renew-code","/api/remove-redeemed")) {
            $rawBody = $req.Body
            if (-not $rawBody) {
                $contentLength = 0
                try {
                    $stream = $client.GetStream()
                    $buf = New-Object byte[] 65536
                    $totalRead = 0
                    $headerEnd = -1
                    $rawStr = ""
                    $readDeadline = [datetime]::UtcNow.AddSeconds(3)
                    do {
                        if ([datetime]::UtcNow -gt $readDeadline) { break }
                        $n = $stream.Read($buf, $totalRead, $buf.Length - $totalRead)
                        if ($n -le 0) { break }
                        $totalRead += $n
                        $rawStr = [System.Text.Encoding]::ASCII.GetString($buf, 0, $totalRead)
                        $headerEnd = $rawStr.IndexOf("`r`n`r`n")
                    } while ($headerEnd -lt 0 -and $totalRead -lt 65536)
                    if ($headerEnd -ge 0) {
                        $headers = $rawStr.Substring(0, $headerEnd) -split "`r`n"
                        foreach ($h in $headers) { if ($h -match "^Content-Length:\s*(\d+)") { $contentLength = [int]$Matches[1] } }
                        if ($contentLength -gt 0) {
                            $bodyStart = $headerEnd + 4
                            $alreadyRead = $totalRead - $bodyStart
                            $rawBody = [System.Text.Encoding]::UTF8.GetString($buf, $bodyStart, $alreadyRead)
                            $need = $contentLength - $alreadyRead
                            while ($need -gt 0 -and [datetime]::UtcNow -le $readDeadline) {
                                $r = $stream.Read($buf, $totalRead, $need)
                                if ($r -le 0) { break }
                                $totalRead += $r; $need -= $r
                                $rawBody = [System.Text.Encoding]::UTF8.GetString($buf, $bodyStart, $totalRead - $bodyStart)
                            }
                        }
                    }
                } catch {}
            }
            try { $bodyData = $rawBody | ConvertFrom-Json } catch { $bodyData = $null }
            $respBody = '{"ok":false,"err":"Invalid"}'
            if ($path -eq "/api/create-code" -and $bodyData) {
                $d = Load-Db
                $code = $bodyData.code.ToUpper().Trim()
                if ($d.codes.$code) {
                    $respBody = @{ok=$false;err="Ya existe"} | ConvertTo-Json
                } else {
                    $d.codes | Add-Member NoteProperty $code @{links=@($bodyData.links);max_uses=[int]$bodyData.max_uses;duration=[int]$bodyData.duration;used_count=0;redeemed_by=@();pinned=$false}
                    Save-Db $d
                    $respBody = @{ok=$true} | ConvertTo-Json
                }
            } elseif ($path -eq "/api/redeem-code" -and $bodyData) {
                $d = Load-Db
                $code = $bodyData.code.ToUpper().Trim()
                $cid = $bodyData.client_id
                if (-not $d.codes.$code) {
                    $respBody = @{ok=$false;err="Codigo invalido"} | ConvertTo-Json
                } else {
                    $info = $d.codes.$code
                    if ($info.used_count -ge $info.max_uses) {
                        $respBody = @{ok=$false;err="Agotado ($($info.used_count)/$($info.max_uses))"} | ConvertTo-Json
                    } else {
                        $info.used_count++
                        if ($cid -and -not ($info.redeemed_by -contains $cid)) { $info.redeemed_by += $cid }
                        Save-Db $d
                        $respBody = @{ok=$true;links=@($info.links);duration=[int]$info.duration} | ConvertTo-Json
                    }
                }
            } elseif ($path -eq "/api/delete-code" -and $bodyData) {
                $d = Load-Db
                $code = $bodyData.code.ToUpper().Trim()
                if ($d.codes.$code) { $d.codes.PSObject.Properties.Remove($code); Save-Db $d; $respBody = @{ok=$true} | ConvertTo-Json }
                else { $respBody = @{ok=$false;err="No encontrado"} | ConvertTo-Json }
            } elseif ($path -eq "/api/pin-code" -and $bodyData) {
                $d = Load-Db
                $code = $bodyData.code.ToUpper().Trim()
                if ($d.codes.$code) {
                    $current = [bool]$d.codes.$code.pinned
                    $d.codes.$code | Add-Member NoteProperty pinned (-not $current) -Force
                    Save-Db $d
                    $respBody = @{ok=$true;pinned=(-not $current)} | ConvertTo-Json
                } else { $respBody = @{ok=$false;err="No encontrado"} | ConvertTo-Json }
            } elseif ($path -eq "/api/renew-code" -and $bodyData) {
                $d = Load-Db
                $code = $bodyData.code.ToUpper().Trim()
                if ($d.codes.$code) {
                    $d.codes.$code.used_count = 0
                    $d.codes.$code.redeemed_by = @()
                    Save-Db $d
                    $respBody = @{ok=$true} | ConvertTo-Json
                } else { $respBody = @{ok=$false;err="No encontrado"} | ConvertTo-Json }
            } elseif ($path -eq "/api/remove-redeemed" -and $bodyData) {
                $d = Load-Db
                $code = $bodyData.code.ToUpper().Trim()
                $cid = $bodyData.client_id
                if ($d.codes.$code) {
                    $info = $d.codes.$code
                    if ($info.redeemed_by -contains $cid) {
                        $info.redeemed_by = @($info.redeemed_by | Where-Object { $_ -ne $cid })
                        if ($info.used_count -gt 0) { $info.used_count-- }
                        Save-Db $d
                        $respBody = @{ok=$true} | ConvertTo-Json
                    } else { $respBody = @{ok=$false;err="Esa PC no canjeo este codigo"} | ConvertTo-Json }
                } else { $respBody = @{ok=$false;err="No encontrado"} | ConvertTo-Json }
            }
            Send-HttpResponse $client $respBody "application/json; charset=utf-8"
            continue
        }
        # 404
        Send-HttpResponse $client '{"ok":false}' "application/json" 404
    } catch {}
}
