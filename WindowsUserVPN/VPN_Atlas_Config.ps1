#requires -Version 5.1

<#
.SYNOPSIS
    Prépare les accès d'un collaborateur au projet Helpdesk Atlas.

.DESCRIPTION
    - Installe OpenSSH Client si nécessaire.
    - Installe WireGuard depuis le site officiel si nécessaire.
    - Génère une paire de clés SSH Ed25519.
    - Génère une paire de clés WireGuard.
    - Crée un rapport contenant uniquement les clés publiques.
    - Prépare le fichier de configuration SSH Windows.

    Le script ne transmet et n'affiche jamais les clés privées.

.EXAMPLE
    PowerShell administrateur :
    Set-ExecutionPolicy -Scope Process Bypass
    .\Initialize-AtlasAccess.ps1 -AtlasUser "alice"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z][a-z0-9._-]{1,31}$')]
    [string]$AtlasUser
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-Administrator)) {
    throw @"
Ce script doit être lancé dans PowerShell en tant qu'administrateur.

Clic droit sur PowerShell
→ Exécuter en tant qu'administrateur
"@
}

$SshDirectory = Join-Path $env:USERPROFILE '.ssh'
$AtlasDirectory = Join-Path $env:LOCALAPPDATA 'AtlasAccess'

$SshPrivateKey = Join-Path $SshDirectory 'id_ed25519_atlas'
$SshPublicKey = "${SshPrivateKey}.pub"

$WireGuardPrivateKey = Join-Path $AtlasDirectory 'wireguard-private.key'
$WireGuardPublicKey = Join-Path $AtlasDirectory 'wireguard-public.key'

$PublicKeysReport = Join-Path (
    [Environment]::GetFolderPath('Desktop')
) "atlas-public-keys-$AtlasUser.txt"

Write-Step "Création des répertoires locaux"

New-Item `
    -ItemType Directory `
    -Path $SshDirectory `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $AtlasDirectory `
    -Force | Out-Null

# -------------------------------------------------------------------
# OpenSSH Client
# -------------------------------------------------------------------

Write-Step "Vérification du client OpenSSH"

$OpenSshCapability = Get-WindowsCapability `
    -Online `
    -Name 'OpenSSH.Client~~~~0.0.1.0'

if ($OpenSshCapability.State -ne 'Installed') {
    Write-Host "Installation d'OpenSSH Client..."

    Add-WindowsCapability `
        -Online `
        -Name 'OpenSSH.Client~~~~0.0.1.0' | Out-Null
}

$SshKeygen = Get-Command 'ssh-keygen.exe' -ErrorAction Stop

Write-Host "OpenSSH disponible : $($SshKeygen.Source)"

# -------------------------------------------------------------------
# Clé SSH
# -------------------------------------------------------------------

Write-Step "Génération de la clé SSH"

if (Test-Path $SshPrivateKey) {
    Write-Host "Une clé SSH Atlas existe déjà :"
    Write-Host $SshPrivateKey
    Write-Host "Elle est conservée."
}
else {
    Write-Host "Choisissez une phrase de passe lorsque celle-ci est demandée."
    Write-Host "Ne laissez pas la phrase de passe vide."
    Write-Host ""

    & $SshKeygen.Source `
        -t ed25519 `
        -a 100 `
        -f $SshPrivateKey `
        -C "$AtlasUser@helpdesk-atlas"

    if ($LASTEXITCODE -ne 0) {
        throw "La génération de la clé SSH a échoué."
    }
}

if (-not (Test-Path $SshPublicKey)) {
    throw "La clé publique SSH n'a pas été créée."
}

# -------------------------------------------------------------------
# WireGuard
# -------------------------------------------------------------------

Write-Step "Vérification de WireGuard"

$WireGuardDirectory = Join-Path $env:ProgramFiles 'WireGuard'
$WireGuardExe = Join-Path $WireGuardDirectory 'wireguard.exe'
$WgExe = Join-Path $WireGuardDirectory 'wg.exe'

if (-not (Test-Path $WgExe)) {
    Write-Host "WireGuard n'est pas installé."
    Write-Host "Téléchargement de l'installateur officiel..."

    $InstallerPath = Join-Path $env:TEMP 'wireguard-installer.exe'
    $InstallerUri = 'https://download.wireguard.com/windows-client/wireguard-installer.exe'

    Invoke-WebRequest `
        -Uri $InstallerUri `
        -OutFile $InstallerPath `
        -UseBasicParsing

    $Signature = Get-AuthenticodeSignature $InstallerPath

    if ($Signature.Status -ne 'Valid') {
        Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue

        throw "La signature numérique de l'installateur WireGuard n'est pas valide."
    }

    Write-Host "Signature de l'installateur vérifiée."
    Write-Host "Lancement de l'installation..."

    $Process = Start-Process `
        -FilePath $InstallerPath `
        -Wait `
        -PassThru

    Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue

    if ($Process.ExitCode -ne 0) {
        throw "L'installation de WireGuard a retourné le code $($Process.ExitCode)."
    }
}

if (-not (Test-Path $WgExe)) {
    throw @"
WireGuard semble installé, mais wg.exe est introuvable ici :

$WgExe

Fermez puis relancez PowerShell et réexécutez le script.
"@
}

Write-Host "WireGuard disponible : $WgExe"

# -------------------------------------------------------------------
# Clé WireGuard
# -------------------------------------------------------------------

Write-Step "Génération de la clé WireGuard"

if (
    (Test-Path $WireGuardPrivateKey) -and
    (Test-Path $WireGuardPublicKey)
) {
    Write-Host "Une paire de clés WireGuard Atlas existe déjà."
    Write-Host "Elle est conservée."
}
else {
    $PrivateKeyValue = (& $WgExe genkey).Trim()

    if ([string]::IsNullOrWhiteSpace($PrivateKeyValue)) {
        throw "La génération de la clé privée WireGuard a échoué."
    }

    $PublicKeyValue = (
        $PrivateKeyValue |
            & $WgExe pubkey
    ).Trim()

    if ([string]::IsNullOrWhiteSpace($PublicKeyValue)) {
        throw "La génération de la clé publique WireGuard a échoué."
    }

    [IO.File]::WriteAllText(
        $WireGuardPrivateKey,
        $PrivateKeyValue,
        [Text.UTF8Encoding]::new($false)
    )

    [IO.File]::WriteAllText(
        $WireGuardPublicKey,
        $PublicKeyValue,
        [Text.UTF8Encoding]::new($false)
    )
}

# -------------------------------------------------------------------
# Configuration SSH
# -------------------------------------------------------------------

Write-Step "Préparation de la configuration SSH"

$SshConfigPath = Join-Path $SshDirectory 'config'
$Marker = "# BEGIN HELPDESK-ATLAS"

$SshConfigBlock = @"

# BEGIN HELPDESK-ATLAS
Host atlas-mail
    HostName mail01.atlas.local
    User $AtlasUser
    IdentityFile ~/.ssh/id_ed25519_atlas
    IdentitiesOnly yes

Host atlas-glpi
    HostName glpi01.atlas.local
    User $AtlasUser
    IdentityFile ~/.ssh/id_ed25519_atlas
    IdentitiesOnly yes

Host atlas-db
    HostName db01.atlas.local
    User $AtlasUser
    IdentityFile ~/.ssh/id_ed25519_atlas
    IdentitiesOnly yes

Host atlas-zabbix
    HostName zbx01.atlas.local
    User $AtlasUser
    IdentityFile ~/.ssh/id_ed25519_atlas
    IdentitiesOnly yes
# END HELPDESK-ATLAS
"@

if (
    (Test-Path $SshConfigPath) -and
    (Select-String -Path $SshConfigPath -SimpleMatch $Marker -Quiet)
) {
    Write-Host "La configuration SSH Atlas existe déjà."
}
else {
    Add-Content `
        -Path $SshConfigPath `
        -Value $SshConfigBlock `
        -Encoding UTF8

    Write-Host "Configuration ajoutée dans :"
    Write-Host $SshConfigPath
}

# -------------------------------------------------------------------
# Rapport public
# -------------------------------------------------------------------

Write-Step "Création du rapport des clés publiques"

$SshPublicKeyValue = (
    Get-Content $SshPublicKey -Raw
).Trim()

$WireGuardPublicKeyValue = (
    Get-Content $WireGuardPublicKey -Raw
).Trim()

$PublicReport = @"
HELPDESK ATLAS — CLÉS PUBLIQUES

Utilisateur souhaité :
$AtlasUser

Clé publique SSH :
$SshPublicKeyValue

Clé publique WireGuard :
$WireGuardPublicKeyValue
"@

Set-Content `
    -Path $PublicKeysReport `
    -Value $PublicReport `
    -Encoding UTF8

$PublicReport | Set-Clipboard

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Préparation terminée" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Le rapport public se trouve ici :"
Write-Host $PublicKeysReport -ForegroundColor Yellow
Write-Host ""
Write-Host "Il a également été copié dans le presse-papiers."
Write-Host ""
Write-Host "À transmettre à l'administrateur Atlas :"
Write-Host "  - le fichier atlas-public-keys-$AtlasUser.txt"
Write-Host ""
Write-Host "À ne jamais transmettre :"
Write-Host "  - $SshPrivateKey"
Write-Host "  - $WireGuardPrivateKey"
Write-Host ""
Write-Host "Le tunnel WireGuard sera configuré après attribution de l'adresse VPN."