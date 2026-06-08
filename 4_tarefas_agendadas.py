"""
TAREFAS AGENDADAS - Roda manutencoes automaticas no PC
Execute em segundo plano junto com o agente principal
"""

import schedule
import time
import os
import psutil
import requests
import datetime
import json
import subprocess

LOG_FILE = os.path.join(os.path.expanduser("~"), "PCAgent", "tarefas_log.txt")
AGENT_URL = "http://localhost:5000"

def log(msg):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except:
        pass

# ============================================================
# TAREFAS
# ============================================================

def tarefa_limpar_temp():
    """Limpeza de temporarios - roda toda madrugada"""
    log("[TAREFA] Iniciando limpeza de temporarios...")
    try:
        r = requests.post(f"{AGENT_URL}/chat", json={
            "message": "Limpe os arquivos temporarios do sistema agora.",
            "history": []
        }, timeout=60)
        data = r.json()
        log(f"[TAREFA] Resultado: {data.get('response', 'sem resposta')}")
        if data.get("tool_result"):
            freed = data["tool_result"].get("freed_mb", 0)
            log(f"[TAREFA] Espaco liberado: {freed} MB")
    except Exception as e:
        log(f"[TAREFA] Erro na limpeza: {e}")

def tarefa_monitorar_recursos():
    """Monitora uso de recursos a cada 15 minutos e alerta se estiver alto"""
    cpu = psutil.cpu_percent(interval=2)
    ram = psutil.virtual_memory().percent
    disk = psutil.disk_usage('C:\\').percent

    log(f"[MONITOR] CPU: {cpu}% | RAM: {ram}% | Disco C: {disk}%")

    alertas = []
    if cpu > 90:
        alertas.append(f"CPU em {cpu}%")
    if ram > 90:
        alertas.append(f"RAM em {ram}%")
    if disk > 90:
        alertas.append(f"Disco C em {disk}%")

    if alertas:
        msg = "ALERTA: " + ", ".join(alertas)
        log(f"[MONITOR] {msg}")
        # Pede recomendacao ao agente
        try:
            r = requests.post(f"{AGENT_URL}/chat", json={
                "message": f"O sistema esta com uso alto: {', '.join(alertas)}. O que eu devo fazer?",
                "history": []
            }, timeout=60)
            data = r.json()
            log(f"[MONITOR] Recomendacao do agente: {data.get('response', '')}")
        except:
            pass

def tarefa_flush_dns():
    """Limpa DNS uma vez por dia"""
    log("[TAREFA] Limpando cache DNS...")
    try:
        result = subprocess.run(["ipconfig", "/flushdns"], capture_output=True, text=True)
        log(f"[TAREFA] DNS: {result.stdout.strip()}")
    except Exception as e:
        log(f"[TAREFA] Erro DNS: {e}")

def tarefa_relatorio_diario():
    """Gera um relatorio diario do estado do PC"""
    log("[RELATORIO] Gerando relatorio diario...")
    try:
        r = requests.get(f"{AGENT_URL}/sysinfo", timeout=10)
        info = r.json()
        
        relatorio = f"""
==========================================
RELATORIO DIARIO - {datetime.datetime.now().strftime('%d/%m/%Y %H:%M')}
==========================================
CPU:   {info['cpu_percent']}%
RAM:   {info['ram_used_gb']} GB / {info['ram_total_gb']} GB ({info['ram_percent']}%)
DISCO: {info['disk_free_gb']} GB livres de {info['disk_total_gb']} GB ({info['disk_percent']}% usado)

TOP PROCESSOS POR CPU:
"""
        for p in info.get("top_processes", [])[:5]:
            relatorio += f"  {p['name']:30s} CPU: {p['cpu']}%  RAM: {p['ram']}%\n"
        
        relatorio += "==========================================\n"
        
        relatorio_path = os.path.join(os.path.expanduser("~"), "PCAgent", "relatorios")
        os.makedirs(relatorio_path, exist_ok=True)
        fname = os.path.join(relatorio_path, f"relatorio_{datetime.date.today()}.txt")
        with open(fname, "w", encoding="utf-8") as f:
            f.write(relatorio)
        
        log(f"[RELATORIO] Salvo em: {fname}")
        print(relatorio)
    except Exception as e:
        log(f"[RELATORIO] Erro: {e}")

# ============================================================
# AGENDAMENTO
# ============================================================

def configurar_agendamentos():
    # Limpeza de temp: toda madrugada as 3h
    schedule.every().day.at("03:00").do(tarefa_limpar_temp)
    
    # Monitoramento: a cada 15 minutos
    schedule.every(15).minutes.do(tarefa_monitorar_recursos)
    
    # Flush DNS: todo dia ao meio-dia
    schedule.every().day.at("12:00").do(tarefa_flush_dns)
    
    # Relatorio diario: todo dia as 20h
    schedule.every().day.at("20:00").do(tarefa_relatorio_diario)
    
    log("Agendamentos configurados:")
    log("  - Limpeza de temp: diaria as 03:00")
    log("  - Monitoramento: a cada 15 minutos")
    log("  - Flush DNS: diario ao meio-dia")
    log("  - Relatorio diario: as 20:00")

if __name__ == "__main__":
    log("=" * 50)
    log("SISTEMA DE TAREFAS AGENDADAS iniciando...")
    log("=" * 50)
    
    configurar_agendamentos()
    
    # Roda o monitoramento imediatamente ao iniciar
    tarefa_monitorar_recursos()
    
    log("Aguardando proximas tarefas... (Ctrl+C para parar)")
    while True:
        schedule.run_pending()
        time.sleep(30)
