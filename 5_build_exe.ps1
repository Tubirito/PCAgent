# ============================================================
#  BUILD DO PC AGENT - Gera o PCAgent.exe
#  Execute como Administrador no PowerShell
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    BUILD DO PC AGENT - GERADOR .EXE   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Verifica Python ---
Write-Host "[1/5] Verificando Python..." -ForegroundColor Yellow
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  ERRO: Python nao encontrado!" -ForegroundColor Red
    Write-Host "  Instale em: https://python.org/downloads" -ForegroundColor Red
    Write-Host "  OBRIGATORIO: marque 'Add Python to PATH' durante a instalacao!" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Pressione Enter para sair"
    exit 1
}
Write-Host "      Python encontrado: $(python --version)" -ForegroundColor Green

# --- Instala dependencias ---
Write-Host ""
Write-Host "[2/5] Instalando dependencias..." -ForegroundColor Yellow
pip install requests psutil schedule flask flask-cors pyinstaller --quiet
Write-Host "      Dependencias instaladas!" -ForegroundColor Green

# --- Cria pasta de build ---
Write-Host ""
Write-Host "[3/5] Preparando arquivos..." -ForegroundColor Yellow

$buildDir = "$PSScriptRoot\build_temp"
$distDir  = "$PSScriptRoot\dist"

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
New-Item -ItemType Directory -Path $distDir  -Force | Out-Null

# Copia o agente para a pasta de build
Copy-Item "$PSScriptRoot\2_agente_ia.py" "$buildDir\agente_ia.py" -Force

# Cria o launcher que inicia agente + abre o navegador automaticamente
$launcherCode = @'
"""
PCAgent Launcher
Inicia o agente Flask e abre a interface no navegador automaticamente
"""
import threading
import time
import os
import sys
import webbrowser
import subprocess

def open_browser():
    time.sleep(2)
    # Tenta abrir a interface HTML que esta na mesma pasta do exe
    exe_dir = os.path.dirname(sys.executable if getattr(sys, "frozen", False) else __file__)
    html_path = os.path.join(exe_dir, "3_interface_web.html")
    if os.path.exists(html_path):
        webbrowser.open("file:///" + html_path.replace("\\", "/"))
    else:
        webbrowser.open("http://localhost:5000")

if __name__ == "__main__":
    threading.Thread(target=open_browser, daemon=True).start()
    
    # Inicia o agente Flask
    import agente_ia
    agente_ia.app.run(host="127.0.0.1", port=5000, debug=False)
'@

$launcherCode | Out-File -FilePath "$buildDir\launcher.py" -Encoding utf8

Write-Host "      Arquivos preparados!" -ForegroundColor Green

# --- Roda o PyInstaller ---
Write-Host ""
Write-Host "[4/5] Compilando o .exe (pode demorar 1-2 minutos)..." -ForegroundColor Yellow

Push-Location $buildDir

pyinstaller `
    --onefile `
    --noconsole `
    --name "PCAgent" `
    --add-data "agente_ia.py;." `
    launcher.py

Pop-Location

# --- Copia o .exe final ---
Write-Host ""
Write-Host "[5/5] Finalizando..." -ForegroundColor Yellow

$exeSource = "$buildDir\dist\PCAgent.exe"
$exeDest   = "$distDir\PCAgent.exe"

if (Test-Path $exeSource) {
    Copy-Item $exeSource $exeDest -Force
    # Copia a interface HTML junto com o exe
    Copy-Item "$PSScriptRoot\3_interface_web.html" "$distDir\3_interface_web.html" -Force -ErrorAction SilentlyContinue
    # Limpa pasta temporaria de build
    Remove-Item $buildDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "        .EXE GERADO COM SUCESSO!       " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Arquivo: $exeDest" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Como usar:" -ForegroundColor White
    Write-Host "  1. Instale o Ollama: https://ollama.com/download" -ForegroundColor White
    Write-Host "  2. Abra um terminal e rode: ollama pull phi3:mini" -ForegroundColor White
    Write-Host "  3. De dois cliques no PCAgent.exe" -ForegroundColor White
    Write-Host "  4. A interface abre automaticamente no navegador!" -ForegroundColor White
    Write-Host ""
    
    # Abre a pasta dist no Explorer
    Start-Process explorer.exe $distDir

} else {
    Write-Host ""
    Write-Host "  ERRO: O .exe nao foi gerado. Veja os erros acima." -ForegroundColor Red
}

Read-Host "Pressione Enter para fechar"
