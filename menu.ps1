# ============================================================
#  PC AGENT - MENU DE GERENCIAMENTO
#  Execute como Administrador no PowerShell
# ============================================================

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host "        PC AGENT - MENU DE GERENCIAMENTO    " -ForegroundColor Cyan
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Trocar modelo (remove phi3:mini, instala llama3.2:3b)" -ForegroundColor White
    Write-Host "  [2] Ver modelos instalados" -ForegroundColor White
    Write-Host "  [3] Remover um modelo manualmente" -ForegroundColor White
    Write-Host "  [4] Iniciar o PC Agent" -ForegroundColor White
    Write-Host "  [5] Parar o PC Agent" -ForegroundColor White
    Write-Host "  [6] Gerar novo .exe" -ForegroundColor White
    Write-Host "  [7] Ver espaco em disco" -ForegroundColor White
    Write-Host "  [0] Sair" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Trocar-Modelo {
    Write-Host ""
    Write-Host "  [*] Removendo phi3:mini..." -ForegroundColor Yellow
    ollama rm phi3:mini 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] phi3:mini removido!" -ForegroundColor Green
    } else {
        Write-Host "  [!] phi3:mini nao encontrado ou ja removido." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "  [*] Baixando llama3.2:3b (~2 GB, aguarde)..." -ForegroundColor Yellow
    ollama pull llama3.2:3b
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  [OK] llama3.2:3b instalado com sucesso!" -ForegroundColor Green

        # Atualiza o MODEL no agente_ia.py automaticamente
        $agentPath = "$env:USERPROFILE\PCAgent\2_agente_ia.py"
        if (Test-Path $agentPath) {
            (Get-Content $agentPath) -replace 'MODEL = ".*"', 'MODEL = "llama3.2:3b"' |
                Set-Content $agentPath
            Write-Host "  [OK] agente_ia.py atualizado para usar llama3.2:3b!" -ForegroundColor Green
        }
    } else {
        Write-Host "  [ERRO] Falha ao baixar o modelo." -ForegroundColor Red
    }

    Write-Host ""
    Pause-Menu
}

function Ver-Modelos {
    Write-Host ""
    Write-Host "  Modelos instalados no Ollama:" -ForegroundColor Cyan
    Write-Host ""
    ollama list
    Write-Host ""
    Pause-Menu
}

function Remover-Modelo {
    Write-Host ""
    ollama list
    Write-Host ""
    $nome = Read-Host "  Digite o nome do modelo para remover (ex: phi3:mini)"
    if ($nome -ne "") {
        Write-Host "  Removendo $nome..." -ForegroundColor Yellow
        ollama rm $nome
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] $nome removido!" -ForegroundColor Green
        } else {
            Write-Host "  [ERRO] Nao foi possivel remover $nome." -ForegroundColor Red
        }
    }
    Write-Host ""
    Pause-Menu
}

function Iniciar-Agente {
    $agentPath = "$env:USERPROFILE\PCAgent\2_agente_ia.py"
    if (-not (Test-Path $agentPath)) {
        Write-Host "  [ERRO] Arquivo nao encontrado: $agentPath" -ForegroundColor Red
        Write-Host "  Coloque o 2_agente_ia.py na pasta C:\Users\<voce>\PCAgent\" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "  [*] Iniciando PC Agent em nova janela..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "python `"$agentPath`""
        Write-Host "  [OK] Agente iniciado! Acesse: http://localhost:5000" -ForegroundColor Green
        
        # Abre a interface HTML se existir
        $htmlPath = "$env:USERPROFILE\PCAgent\3_interface_web.html"
        if (Test-Path $htmlPath) {
            Start-Sleep -Seconds 2
            Start-Process $htmlPath
            Write-Host "  [OK] Interface web aberta no navegador!" -ForegroundColor Green
        }
    }
    Write-Host ""
    Pause-Menu
}

function Parar-Agente {
    Write-Host ""
    Write-Host "  [*] Procurando processo do agente na porta 5000..." -ForegroundColor Yellow
    $proc = Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Id $proc -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Agente encerrado (PID $proc)!" -ForegroundColor Green
    } else {
        Write-Host "  [!] Nenhum agente rodando na porta 5000." -ForegroundColor DarkYellow
    }
    Write-Host ""
    Pause-Menu
}

function Gerar-Exe {
    $buildScript = Join-Path (Split-Path -Parent $MyInvocation.ScriptName) "5_build_exe.ps1"
    if (Test-Path $buildScript) {
        Write-Host ""
        Write-Host "  [*] Iniciando build do .exe..." -ForegroundColor Yellow
        & $buildScript
    } else {
        Write-Host ""
        Write-Host "  [ERRO] 5_build_exe.ps1 nao encontrado na mesma pasta." -ForegroundColor Red
        Write-Host "  Coloque todos os scripts na mesma pasta." -ForegroundColor Yellow
    }
    Pause-Menu
}

function Ver-Disco {
    Write-Host ""
    Write-Host "  Espaco em disco:" -ForegroundColor Cyan
    Write-Host ""
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } |
        ForEach-Object {
            $total = [math]::Round(($_.Used + $_.Free) / 1GB, 1)
            $usado = [math]::Round($_.Used / 1GB, 1)
            $livre = [math]::Round($_.Free / 1GB, 1)
            $pct   = if ($total -gt 0) { [math]::Round($_.Used / ($_.Used + $_.Free) * 100) } else { 0 }
            $cor   = if ($pct -gt 85) { "Red" } elseif ($pct -gt 65) { "Yellow" } else { "Green" }
            Write-Host ("  {0,-4} Total: {1,6} GB   Usado: {2,6} GB   Livre: {3,6} GB   ({4}%)" -f $_.Name, $total, $usado, $livre, $pct) -ForegroundColor $cor
        }
    Write-Host ""
    
    # Mostra tamanho dos modelos Ollama
    $ollamaModels = "$env:USERPROFILE\.ollama\models"
    if (Test-Path $ollamaModels) {
        $size = (Get-ChildItem $ollamaModels -Recurse -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        $sizeGB = [math]::Round($size / 1GB, 2)
        Write-Host "  Modelos Ollama ocupam: $sizeGB GB" -ForegroundColor DarkCyan
        Write-Host "  Pasta: $ollamaModels" -ForegroundColor DarkGray
    }
    Write-Host ""
    Pause-Menu
}

function Pause-Menu {
    Write-Host "  Pressione qualquer tecla para voltar ao menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ============================================================
# LOOP PRINCIPAL
# ============================================================

# Verifica se Ollama esta instalado
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Clear-Host
    Write-Host ""
    Write-Host "  [ERRO] Ollama nao encontrado!" -ForegroundColor Red
    Write-Host "  Instale em: https://ollama.com/download" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Pressione Enter para sair"
    exit 1
}

do {
    Show-Menu
    $opcao = Read-Host "  Escolha uma opcao"

    switch ($opcao) {
        "1" { Trocar-Modelo }
        "2" { Ver-Modelos }
        "3" { Remover-Modelo }
        "4" { Iniciar-Agente }
        "5" { Parar-Agente }
        "6" { Gerar-Exe }
        "7" { Ver-Disco }
        "0" { Clear-Host; exit }
        default {
            Write-Host "  Opcao invalida!" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
