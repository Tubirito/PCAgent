# PC Agent 🤖

Agente de IA local para otimização e manutenção do Windows, rodando com Ollama.

## Instalação em uma linha

Abra o PowerShell como **Administrador** e cole:

```powershell
irm "https://raw.githubusercontent.com/Tubirito/pcagent/main/install.ps1" | iex
```

> `Tubirito`

## O que faz

- Chat com IA local (sem internet, sem custo)
- Monitora CPU, RAM e disco em tempo real
- Limpa arquivos temporários automaticamente
- Flush de DNS
- Lista e remove programas da inicialização
- Tarefas agendadas (limpeza diária, relatório, monitoramento)
- Menu interativo no PowerShell

## Requisitos

- Windows 10/11
- [Python](https://python.org/downloads) (marcar "Add to PATH")
- [Ollama](https://ollama.com/download) (instalado automaticamente)

## Estrutura do repositório

```
pcagent/
├── install.ps1            ← instalador (irm | iex)
├── menu.ps1               ← menu principal
├── 2_agente_ia.py         ← servidor da IA
├── 3_interface_web.html   ← interface do chat
├── 4_tarefas_agendadas.py ← tarefas automáticas
└── 5_build_exe.ps1        ← gera o .exe
```

## Modelo de IA

Usa `llama3.2:3b` (~2 GB) rodando 100% local via Ollama. Sem GPU necessária.
