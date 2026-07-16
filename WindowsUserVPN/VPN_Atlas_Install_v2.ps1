#requires -Version 5.1
#requires -RunAsAdministrator

<#+
.SYNOPSIS
    Importe le tunnel WireGuard Atlas dans le client WireGuard Windows.

.DESCRIPTION
    À exécuter après VPN_Atlas_Config.ps1 et après création du peer dans OPNsense.
    L'adresse VPN doit être unique pour chaque collaborateur.

.EXAMPLE
    .\VPN_Atlas_Install_v2.ps1 -Address '10.60.0.3/32' -TunnelName 'atlas-alice'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^10\.60\.0\.(?:[2-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])/32$')]
    [string]$Address,

    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$TunnelName = 'atlas-vpn',

    [ValidatePattern('^[A-Za-z0-9+/]{43}=$')]
    [string]$ServerPublicKey = 'AQALQ0aS69w50iA2jJGWfL5KZo7aZGaLe2ahR/XzuRg=',

    [ValidatePattern('^[^:]+:\d+$')]
    [string]$Endpoint = '51.75.38.225:51820',

    [ValidatePattern('^\d{1,3}(?:\.\d{1,3}){3}$')]
    [string]$DnsServer = '10.90.0.10',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$AtlasDirectory = Join-Path $env:LOCALAPPDATA 'AtlasAccess'
$PrivateKeyPath = Join-Path $AtlasDirectory 'wireguard-private.key'

$WireGuardDirectory = Join-Path $env:ProgramFiles 'WireGuard'
$WireGuardExe = Join-Path $WireGuardDirectory 'wireguard.exe'
$ConfigurationDirectory = Join-Path $WireGuardDirectory 'Data\Configurations'

$StagingFile = Join-Path $env:TEMP "$TunnelName.conf"
$ImportedFile = Join-Path $ConfigurationDirectory "$TunnelName.conf"
$EncryptedFile = Join-Path $ConfigurationDirectory "$TunnelName.conf.dpapi"

if (-not (Test-Path $WireGuardExe)) {
    throw "WireGuard Windows est introuvable : $WireGuardExe"
}

if (-not (Test-Path $PrivateKeyPath)) {
    throw @"
La clé privée WireGuard est introuvable :
$PrivateKeyPath

Exécutez d'abord VPN_Atlas_Config.ps1.
"@
}

$PrivateKey = (Get-Content $PrivateKeyPath -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($PrivateKey)) {
    throw 'La clé privée WireGuard est vide.'
}

$ManagerService = Get-Service -Name 'WireGuardManager' -ErrorAction SilentlyContinue
if ($null -eq $ManagerService) {
    & $WireGuardExe /installmanagerservice
    if ($LASTEXITCODE -ne 0) {
        throw "Impossible d'installer le service WireGuard Manager."
    }
    Start-Sleep -Seconds 2
}

$ManagerService = Get-Service -Name 'WireGuardManager' -ErrorAction Stop
if ($ManagerService.Status -ne 'Running') {
    Start-Service -Name 'WireGuardManager'
    Start-Sleep -Seconds 2
}

New-Item -ItemType Directory -Path $ConfigurationDirectory -Force | Out-Null

if ((Test-Path $ImportedFile) -or (Test-Path $EncryptedFile)) {
    if (-not $Force) {
        throw @"
Un tunnel nommé '$TunnelName' existe déjà.
Relancez avec -Force uniquement si vous voulez le remplacer.
"@
    }

    Remove-Item -Path $ImportedFile, $EncryptedFile -Force -ErrorAction SilentlyContinue
}

$Configuration = @"
[Interface]
PrivateKey = $PrivateKey
Address = $Address
DNS = $DnsServer

[Peer]
PublicKey = $ServerPublicKey
Endpoint = $Endpoint
AllowedIPs = 10.20.0.0/24, 10.30.0.0/24, 10.60.0.0/24, 10.90.0.0/24
PersistentKeepalive = 25
"@

try {
    [IO.File]::WriteAllText(
        $StagingFile,
        $Configuration,
        [Text.UTF8Encoding]::new($false)
    )

    Copy-Item -Path $StagingFile -Destination $ImportedFile -Force

    Write-Host 'Attente de l’import sécurisé par WireGuard Manager...' -ForegroundColor Cyan

    $Imported = $false
    for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
        if (Test-Path $EncryptedFile) {
            $Imported = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if (-not $Imported) {
        throw "Le fichier chiffré n'a pas été créé : $EncryptedFile"
    }
}
finally {
    Remove-Item -Path $StagingFile -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Tunnel WireGuard Atlas importé.' -ForegroundColor Green
Write-Host "Nom      : $TunnelName"
Write-Host "Adresse  : $Address"
Write-Host "Endpoint : $Endpoint"
Write-Host ''
Write-Host 'Ouvrez WireGuard, activez le tunnel, puis testez :' -ForegroundColor Cyan
Write-Host '  ping 10.60.0.1'
Write-Host '  ping 10.90.0.10'
Write-Host '  Resolve-DnsName mail01.atlas.local -Server 10.90.0.10'
Write-Host '  Test-NetConnection mail01.atlas.local -Port 22'
