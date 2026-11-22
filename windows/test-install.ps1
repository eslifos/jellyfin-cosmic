param([Parameter(Mandatory)][string]$Setup)
# Installs on the build machine, checks that the service answers, and uninstalls.
$ErrorActionPreference = 'Stop'

$p = Start-Process $Setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "El instalador terminó con $($p.ExitCode)" }

$ok = $false
foreach ($i in 1..60) {
    try {
        if ((Invoke-RestMethod 'http://127.0.0.1:8096/health' -TimeoutSec 3) -eq 'Healthy') { $ok = $true; break }
    } catch {
        Write-Verbose 'Todavía no responde'
    }
    Start-Sleep -Seconds 3
}
if (-not $ok) {
    Get-ChildItem "$env:ProgramData\JellyfinCosmic\service-log" -ErrorAction SilentlyContinue | Get-Content -Tail 40
    throw 'El servicio no respondió'
}
if ((Invoke-WebRequest 'http://127.0.0.1:8096/web/index.html' -UseBasicParsing).StatusCode -ne 200) { throw 'La web no respondió' }
if ((Get-Service JellyfinCosmic).StartType -ne 'Automatic') { throw 'El servicio no inicia con Windows' }

$uninstaller = Join-Path $env:ProgramFiles 'Jellyfin Cosmic\unins000.exe'
$u = Start-Process $uninstaller -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
if ($u.ExitCode -ne 0) { throw "El desinstalador terminó con $($u.ExitCode)" }
if (-not (Test-Path "$env:ProgramData\JellyfinCosmic\data")) { throw 'Desinstalar borró los datos' }
Write-Output 'Instalación correcta'
