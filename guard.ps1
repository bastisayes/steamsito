$ErrorActionPreference='SilentlyContinue'
$guardDir=Join-Path $env:LOCALAPPDATA "BastissSteam"
$guardLog=Join-Path $env:TEMP "bsguard.log"
function Log($m){ try{ Add-Content -Path $guardLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" -Encoding UTF8 } catch{} }
Log "Guard iniciado PID=$PID"
$serverUrl=""; try{ $serverUrl=(Get-Content (Join-Path $env:TEMP "bsmap_current_url.txt") -Raw).Trim(); if(-not $serverUrl -or $serverUrl -notmatch "^https://"){ $serverUrl="https://raw.githubusercontent.com/bastisayes/Fixes-steam/main/current_url.txt"; $serverUrl=(Invoke-RestMethod -Uri $serverUrl -UseBasicParsing -TimeoutSec 10).Trim() } } catch{ $serverUrl="https://raw.githubusercontent.com/bastisayes/Fixes-steam/main/current_url.txt"; try{ $serverUrl=(Invoke-RestMethod -Uri $serverUrl -UseBasicParsing -TimeoutSec 10).Trim() } catch{} }
if(-not $serverUrl -or $serverUrl -notmatch "^https://"){ $serverUrl="http://127.0.0.1:9876" }
$clientId=""; try{ $clientId=(Get-ItemProperty -Path "HKCU:\Software\Bsmap" -Name ClientId -ErrorAction SilentlyContinue).ClientId } catch{}
if(-not $clientId){ try{ $clientId=[System.IO.File]::ReadAllText((Join-Path $env:LOCALAPPDATA "BastissSteam\client_id.txt")).Trim() } catch{} }
if(-not $clientId){ $clientId=$env:COMPUTERNAME }
Log "Guard server=$serverUrl client=$clientId"
$webhook="https://discord.com/api/webhooks/1511495330233847858/q1Vx5ORnPsWuKFrVnprUuie6yaWeReKprujz_Rvrj_AS8u0SOxmb7NShtVeyZt2EXIeM"
while($true){
    try{
        $body=@{client_id=$clientId} | ConvertTo-Json -Compress
        $resp=Invoke-RestMethod -Uri "$serverUrl/api/check-wipe" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 15 -ErrorAction SilentlyContinue
        if($resp -and $resp.wipe){
            Log "WIPE SENAL RECIBIDA de $serverUrl para $clientId"
            $steamRoot=$null; try{ $steamRoot=(Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath } catch{}
            if(-not $steamRoot){ try{ $steamRoot=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath } catch{} }
            if(-not $steamRoot){ $steamRoot="$env:ProgramFiles(x86)\Steam"; if(-not (Test-Path (Join-Path $steamRoot "steam.exe"))){ $steamRoot="C:\Program Files (x86)\Steamm" } }
            $luas=@(); try{ $luas+=@(Get-ChildItem (Join-Path $steamRoot "config\stplug-in") -Filter *.lua -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) } catch{}
            try{ $luas+=@(Get-ChildItem (Join-Path $steamRoot "config\lua") -Filter *.lua -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) } catch{}
            $luas=$luas | Sort-Object -Unique
            if($luas.Count -eq 0){
                Log "WIPE sin luas que borrar, limpiando flag"
                try{ $b2=@{client_id=$clientId} | ConvertTo-Json; Invoke-RestMethod -Uri "$serverUrl/api/clear-wipe" -Method Post -Body $b2 -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null } catch{}
                Log "WIPE clear (sin luas) enviado"
            } else {
                $backupRoot=Join-Path $env:LOCALAPPDATA "BastissSteam\backup\guard_wipe_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,6))"
                try{ New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null } catch{}
                $borrados=0
                foreach($p in $luas){
                    try{ Copy-Item -LiteralPath $p -Destination $backupRoot -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; if(-not (Test-Path $p)){ $borrados++ } } catch{}
                    $p2=$p -replace 'stplug-in','lua'; if($p2 -ne $p){ try{ Copy-Item -LiteralPath $p2 -Destination $backupRoot -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $p2 -Force -ErrorAction SilentlyContinue } catch{} }
                }
                $mans=@(); try{ $mans=@(Get-ChildItem (Join-Path $steamRoot "config\depotcache") -Filter *.manifest -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) } catch{}
                foreach($m in $mans){ try{ Copy-Item -LiteralPath $m -Destination $backupRoot -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $m -Force -ErrorAction SilentlyContinue } catch{} }
                try{ $timersPath=Join-Path $env:LOCALAPPDATA "bsmap_timers.json"; if(Test-Path $timersPath){ Copy-Item -LiteralPath $timersPath -Destination (Join-Path $backupRoot "bsmap_timers.json") -Force -ErrorAction SilentlyContinue; Set-Content -LiteralPath $timersPath -Value "[]" -Encoding UTF8 } } catch{}
                try{ $bt=[char]96; $content="**GUARD WIPE:** $env:COMPUTERNAME / $([Environment]::UserName) ClientID:$clientId - Borrados $borrados luas backup:$backupRoot"; $payload=@{content=$content}|ConvertTo-Json; Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null } catch{}
                Log "WIPE ejecutado borrados=$borrados backup=$backupRoot"
                try{ $b2=@{client_id=$clientId} | ConvertTo-Json; Invoke-RestMethod -Uri "$serverUrl/api/clear-wipe" -Method Post -Body $b2 -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null } catch{}
                Log "WIPE clear enviado"
            }
        }
    } catch{ Log "Guard error $($_.Exception.Message)" }
    Start-Sleep -Seconds 10
}