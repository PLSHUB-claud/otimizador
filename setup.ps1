# ==============================================================================
# Script de Automacao: OpenSSH Server + Tailscale no Windows
# ==============================================================================

# 1. Verificar se esta rodando como Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " ERRO: Voce PRECISA rodar o PowerShell como Administrador!" -ForegroundColor Yellow
    Write-Host " Feche essa janela, clique com botao direito no PowerShell" -ForegroundColor Yellow
    Write-Host " ou no arquivo run.bat e escolha 'Executar como Administrador'." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Red
    Read-Host "Pressione ENTER para fechar..."
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       INICIANDO CONFIGURACAO AUTOMATICA DO SERVIDOR       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 2. Instalar OpenSSH Server
Write-Host "`n=== [1/5] Verificando e instalando OpenSSH Server ===" -ForegroundColor Cyan
$sshCapability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
if ($sshCapability.State -ne 'Installed') {
    Write-Host "Instalando recurso OpenSSH Server..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
} else {
    Write-Host "OpenSSH Server ja esta instalado." -ForegroundColor Green
}

# 3. Iniciar servico SSHD e colocar em Automatico
Write-Host "`n=== [2/5] Configurando e iniciando o servico SSH ===" -ForegroundColor Cyan
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd

# 4. Configurar Firewall
Write-Host "`n=== [3/5] Liberando porta 22 no Firewall do Windows ===" -ForegroundColor Cyan
if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH SSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Host "Regra de firewall criada com sucesso." -ForegroundColor Green
} else {
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True | Out-Null
    Write-Host "Regra de firewall ja existe e esta ativa." -ForegroundColor Green
}

# 5. Instalar Tailscale
Write-Host "`n=== [4/5] Instalando / Verificando Tailscale ===" -ForegroundColor Cyan
$tailscaleExe = "C:\Program Files\Tailscale\tailscale.exe"

if (-not (Test-Path $tailscaleExe)) {
    $altCmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($altCmd) {
        $tailscaleExe = $altCmd.Source
    }
}

if (-not (Test-Path $tailscaleExe)) {
    Write-Host "Instalando Tailscale..." -ForegroundColor Yellow
    $hasWinget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($hasWinget) {
        winget install --id Tailscale.Tailscale --exact --accept-package-agreements --accept-source-agreements --silent
        Start-Sleep -Seconds 6
    }
    
    # Se ainda nao encontrar, baixa direto do site oficial
    if (-not (Test-Path $tailscaleExe)) {
        Write-Host "Baixando instalador oficial do Tailscale..." -ForegroundColor Yellow
        $installerPath = "$env:TEMP\tailscale-setup.exe"
        Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" -OutFile $installerPath
        Start-Process -FilePath $installerPath -ArgumentList "/quiet /install" -Wait
        Start-Sleep -Seconds 6
    }
}

# 6. Conectar Tailscale
if (Test-Path $tailscaleExe) {
    Write-Host "Iniciando conexao do Tailscale com SSH habilitado..." -ForegroundColor Cyan
    & $tailscaleExe up --ssh --operator=$env:USERNAME
} else {
    Write-Warning "Tailscale instalado. Se a janela nao abriu, procure Tailscale no Menu Iniciar."
}

# 7. Configurar Chaves Publicas SSH
Write-Host "`n=== [5/5] Configurando Chaves SSH e Permissoes ===" -ForegroundColor Cyan

$sshKeys = @(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwe7ftDRXOft6jm4mr/8dY5AFwDqghp50+FJ25/lNnj eliza@DESKTOP-N7QP8DV",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOHT9HYZVVRCkOvP3bLrZ1Z5a/81WFz7O9rFlJonvcAL hermes-ghufa@192.168.100.232"
)

# Chaves no perfil do usuario (~/.ssh/authorized_keys)
$userSshDir = Join-Path -Path $env:USERPROFILE -ChildPath ".ssh"
$userAuthKeys = Join-Path -Path $userSshDir -ChildPath "authorized_keys"

if (-not (Test-Path $userSshDir)) {
    New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null
}

$currentUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

foreach ($key in $sshKeys) {
    if (-not (Test-Path $userAuthKeys) -or -not (Get-Content $userAuthKeys -ErrorAction SilentlyContinue | Select-String -SimpleMatch $key)) {
        Add-Content -Path $userAuthKeys -Value $key -Encoding UTF8
    }
}

# Permissoes estritas: apenas o usuario atual e SYSTEM
icacls.exe $userAuthKeys /inheritance:r /grant "*S-1-5-18:(F)" /grant "$($currentUserSid):(F)" | Out-Null

# Chaves no grupo de Administradores (C:\ProgramData\ssh\administrators_authorized_keys)
$programDataSsh = "$env:ProgramData\ssh"
if (-not (Test-Path $programDataSsh)) {
    New-Item -ItemType Directory -Path $programDataSsh -Force | Out-Null
}
$adminAuthKeys = "$programDataSsh\administrators_authorized_keys"

foreach ($key in $sshKeys) {
    if (-not (Test-Path $adminAuthKeys) -or -not (Get-Content $adminAuthKeys -ErrorAction SilentlyContinue | Select-String -SimpleMatch $key)) {
        Add-Content -Path $adminAuthKeys -Value $key -Encoding UTF8
    }
}

# Permissoes estritas: SYSTEM e BUILTIN\Administrators via SID (idioma independente)
icacls.exe $adminAuthKeys /inheritance:r /grant "*S-1-5-18:(F)" /grant "*S-1-5-32-544:(F)" | Out-Null

# Reinicia servico para recarregar autorizacoes
Restart-Service sshd

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "          CONFIGURACAO CONCLUIDA COM SUCESSO!             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "COPIE AS DUAS LINHAS ABAIXO E ENVIE PARA QUEM TE PEDIU:" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------"
Write-Host "Usuario:      $env:USERNAME" -ForegroundColor Cyan

$tailscaleIp = ""
if (Test-Path $tailscaleExe) {
    try {
        $tailscaleIp = (& $tailscaleExe ip -4 2>$null).Trim()
    } catch {}
}

if ($tailscaleIp) {
    Write-Host "IP Tailscale: $tailscaleIp" -ForegroundColor Cyan
} else {
    Write-Host "IP Tailscale: (Veja o IP no icone do Tailscale perto do relogio)" -ForegroundColor Yellow
}
Write-Host "----------------------------------------------------------"
Write-Host ""
Write-Host "Pronto! Pode fechar esta janela." -ForegroundColor Green
Write-Host "Pressione qualquer tecla para sair..."
[void][System.Console]::ReadKey()
