# ============================================================
#  PC AGENT - INSTALADOR ONLINE
#  Uso: irm "https://raw.githubusercontent.com/SEU_USUARIO/pcagent/main/install.ps1" | iex
# ============================================================

# URL base do seu repositorio GitHub 
$GITHUB_USER = "Tubirito"
$GITHUB_REPO = "pcagent"
$BRANCH      = "main"
$BASE_URL    = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH"

$INSTALL_DIR = "$env:USERPROFILE\PCAgent"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                          ║" -ForegroundColor Cyan
    Write-Host "  ║           PC AGENT INSTALLER             ║" -ForegroundColor Cyan
    Write-Host "  ║        by $GITHUB_USER                        ║" -ForegroundColor Cyan
    Write-Host "  ║                                          ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($n, $total, $msg) {
    Write-Host "  [$n/$total] $msg" -ForegroundColor Yellow
}

function Write-OK($msg) {
    Write-Host "      OK  $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host "      ERRO  $msg" -ForegroundColor Red
}

function Download-File($url, $dest) {
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# ---- BANNER ----
Write-Banner

# ---- VERIFICACOES ----
Write-Step 1 6 "Verificando requisitos..."

# Admin?
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Fail "Execute como Administrador!"
    Write-Host ""
    Write-Host "  Clique com botao direito no PowerShell > Executar como Administrador" -ForegroundColor Yellow
    Read-Host "  Pressione Enter para sair"
    exit 1
}
Write-OK "Rodando como Administrador"

# Python?
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Fail "Python nao encontrado!"
    Write-Host ""
    Write-Host "  Instale em: https://python.org/downloads" -ForegroundColor Yellow
    Write-Host "  IMPORTANTE: marque 'Add Python to PATH' na instalacao!" -ForegroundColor Red
    Read-Host "  Pressione Enter para sair"
    exit 1
}
Write-OK "Python: $(python --version 2>&1)"

# Ollama?
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  Ollama nao encontrado. Instalando automaticamente..." -ForegroundColor Yellow
    $tmp = "$env:TEMP\OllamaSetup.exe"
    Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $tmp
    Start-Process -FilePath $tmp -Args "/S" -Wait
    Write-OK "Ollama instalado!"
} else {
    Write-OK "Ollama: ja instalado"
}

# ---- PASTA ----
Write-Step 2 6 "Criando pasta $INSTALL_DIR..."
New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
Write-OK "Pasta criada"

# ---- BAIXAR ARQUIVOS ----
Write-Step 3 6 "Baixando arquivos do GitHub..."

$files = @(
    @{ url = "$BASE_URL/2_agente_ia.py";          dest = "$INSTALL_DIR\2_agente_ia.py" },
    @{ url = "$BASE_URL/3_interface_web.html";     dest = "$INSTALL_DIR\3_interface_web.html" },
    @{ url = "$BASE_URL/4_tarefas_agendadas.py";   dest = "$INSTALL_DIR\4_tarefas_agendadas.py" },
    @{ url = "$BASE_URL/5_build_exe.ps1";          dest = "$INSTALL_DIR\5_build_exe.ps1" },
    @{ url = "$BASE_URL/menu.ps1";                 dest = "$INSTALL_DIR\menu.ps1" }
)

$allOk = $true
foreach ($f in $files) {
    $name = Split-Path $f.dest -Leaf
    if (Download-File $f.url $f.dest) {
        Write-OK "$name"
    } else {
        Write-Fail "$name (verifique se o repositorio e publico)"
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "  Alguns arquivos falharam. Verifique se o repositorio GitHub esta publico." -ForegroundColor Red
    Read-Host "  Pressione Enter para sair"
    exit 1
}

# ---- DEPENDENCIAS PYTHON ----
Write-Step 4 6 "Instalando dependencias Python..."
pip install requests psutil schedule flask flask-cors --quiet
Write-OK "requests, psutil, schedule, flask, flask-cors"

# ---- MODELO ----
Write-Step 5 6 "Baixando modelo de IA (llama3.2:3b ~2 GB)..."
Write-Host "      Isso pode demorar alguns minutos..." -ForegroundColor Gray
ollama pull llama3.2:3b
Write-OK "Modelo llama3.2:3b pronto"

# ---- ATALHO NO DESKTOP ----
Write-Step 6 6 "Criando atalho no Desktop..."
$shortcutPath = "$env:USERPROFILE\Desktop\PC Agent.lnk"
$wsh = New-Object -ComObject WScript.Shell
$sc  = $wsh.CreateShortcut($shortcutPath)
$sc.TargetPath       = "powershell.exe"
$sc.Arguments        = "-ExecutionPolicy Bypass -File `"$INSTALL_DIR\menu.ps1`""
$sc.WorkingDirectory = $INSTALL_DIR
$sc.Description      = "PC Agent - Menu de Gerenciamento"
$sc.Save()
Write-OK "Atalho criado no Desktop!"

# ---- CONCLUIDO ----
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║      INSTALACAO CONCLUIDA COM SUCESSO!   ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Como usar:" -ForegroundColor Cyan
Write-Host "  - Clique duas vezes em 'PC Agent' no Desktop" -ForegroundColor White
Write-Host "  - Ou rode: powershell -File `"$INSTALL_DIR\menu.ps1`"" -ForegroundColor White
Write-Host ""

$abrir = Read-Host "  Abrir o menu agora? (S/N)"
if ($abrir -match "^[Ss]") {
    & "$INSTALL_DIR\menu.ps1"
}
