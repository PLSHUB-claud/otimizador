@echo off
title Configurar Acesso Remoto
color 0b

:: Verifica se ja esta rodando como Administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ========================================================
    echo Solicitando permissoes de Administrador...
    echo Clique em 'SIM' na janela que vai aparecer.
    echo ========================================================
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
