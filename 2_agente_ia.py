"""
PC AGENT - Agente de IA Local para Otimizacao do PC
Roda um servidor Flask que recebe mensagens e responde usando Ollama
"""

import os
import re
import json
import subprocess
import psutil
import requests
import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "llama3.2:3b"  # Melhor que phi3:mini para seguir instrucoes

LOG_FILE = os.path.join(os.path.expanduser("~"), "PCAgent", "agent_log.txt")

# ============================================================
# FERRAMENTAS DE SISTEMA
# ============================================================

def get_system_info():
    cpu = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory()
    disk = psutil.disk_usage('C:\\')
    processes = []
    for proc in sorted(psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']),
                       key=lambda p: p.info['cpu_percent'] or 0, reverse=True)[:10]:
        try:
            processes.append({
                "pid": proc.info['pid'],
                "name": proc.info['name'],
                "cpu": round(proc.info['cpu_percent'] or 0, 1),
                "ram": round(proc.info['memory_percent'] or 0, 1)
            })
        except:
            pass
    return {
        "cpu_percent": cpu,
        "ram_total_gb": round(ram.total / 1e9, 1),
        "ram_used_gb": round(ram.used / 1e9, 1),
        "ram_percent": ram.percent,
        "disk_total_gb": round(disk.total / 1e9, 1),
        "disk_free_gb": round(disk.free / 1e9, 1),
        "disk_percent": disk.percent,
        "top_processes": processes
    }

def clean_temp_files():
    paths = [
        os.environ.get("TEMP", ""),
        os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Temp"),
        os.path.join(os.environ.get("LOCALAPPDATA", ""), "Temp"),
    ]
    cleaned = 0
    total_freed = 0
    for path in paths:
        if not path or not os.path.exists(path):
            continue
        for f in os.listdir(path):
            fp = os.path.join(path, f)
            try:
                size = os.path.getsize(fp) if os.path.isfile(fp) else 0
                if os.path.isfile(fp):
                    os.remove(fp)
                    total_freed += size
                    cleaned += 1
            except:
                pass
    return {"cleaned_files": cleaned, "freed_mb": round(total_freed / 1e6, 2)}

def flush_dns():
    result = subprocess.run(["ipconfig", "/flushdns"], capture_output=True, text=True)
    return {"output": result.stdout.strip()}

def list_startup_programs():
    result = subprocess.run(
        ["reg", "query", r"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"],
        capture_output=True, text=True
    )
    lines = [l.strip() for l in result.stdout.splitlines() if l.strip() and "REG_" in l]
    programs = []
    for line in lines:
        parts = line.split(None, 2)
        if len(parts) >= 3:
            programs.append({"name": parts[0], "path": parts[2]})
    return {"startup_programs": programs}

def run_disk_cleanup():
    subprocess.Popen(["cleanmgr", "/sagerun:1"])
    return {"status": "Limpeza de disco iniciada em segundo plano."}

def kill_process(pid: int):
    try:
        p = psutil.Process(pid)
        name = p.name()
        p.terminate()
        return {"status": f"Processo {name} (PID {pid}) encerrado."}
    except Exception as e:
        return {"error": str(e)}

def read_log_file(path: str):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()[-4000:]
        return {"content": content}
    except Exception as e:
        return {"error": str(e)}

TOOLS = {
    "get_system_info": get_system_info,
    "clean_temp_files": clean_temp_files,
    "flush_dns": flush_dns,
    "list_startup_programs": list_startup_programs,
    "run_disk_cleanup": run_disk_cleanup,
    "kill_process": kill_process,
    "read_log_file": read_log_file,
}

# ============================================================
# PROMPT DO SISTEMA — mais direto e restritivo
# ============================================================

SYSTEM_PROMPT = """Você é um assistente de PC com Windows. Responda SEMPRE em português, de forma curta e direta.

REGRAS OBRIGATÓRIAS:
1. Se precisar de dados do sistema, responda SOMENTE com JSON puro, sem nenhum texto antes ou depois:
   {"tool": "get_system_info", "args": {}}
2. Se precisar limpar temp:
   {"tool": "clean_temp_files", "args": {}}
3. Se precisar do DNS:
   {"tool": "flush_dns", "args": {}}
4. Se precisar da startup:
   {"tool": "list_startup_programs", "args": {}}
5. NUNCA mostre o JSON na resposta final ao usuário. O JSON é apenas para uso interno.
6. Após receber o resultado de uma ferramenta, responda em português normal.
7. Seja objetivo. Máximo 5 linhas por resposta."""

# ============================================================
# LOGICA DO AGENTE
# ============================================================

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

def extract_json_tool(text: str):
    """Tenta extrair um JSON de ferramenta do texto, mesmo que tenha texto ao redor"""
    # Tenta parse direto
    try:
        data = json.loads(text.strip())
        if "tool" in data:
            return data
    except:
        pass
    # Tenta encontrar JSON embutido no texto
    match = re.search(r'\{[^{}]*"tool"[^{}]*\}', text, re.DOTALL)
    if match:
        try:
            data = json.loads(match.group())
            if "tool" in data:
                return data
        except:
            pass
    return None

def remove_json_from_text(text: str) -> str:
    """Remove qualquer bloco JSON da resposta final"""
    # Remove JSON puro
    try:
        json.loads(text.strip())
        return ""  # a resposta inteira era JSON, nao mostrar
    except:
        pass
    # Remove JSON embutido
    cleaned = re.sub(r'\{[^{}]*"tool"[^{}]*\}', '', text, flags=re.DOTALL)
    return cleaned.strip()

def ask_ollama(messages: list) -> str:
    prompt = SYSTEM_PROMPT + "\n\n"
    for m in messages:
        role = "Usuario" if m["role"] == "user" else "Agente"
        prompt += f"{role}: {m['content']}\n"
    prompt += "Agente:"

    try:
        resp = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_predict": 400,
                "stop": ["Usuario:", "\nUsuario"]
            }
        }, timeout=120)
        resp.raise_for_status()
        return resp.json().get("response", "").strip()
    except Exception as e:
        return f"[ERRO ao chamar Ollama: {e}]"

def process_message(user_message: str, history: list) -> dict:
    history = history + [{"role": "user", "content": user_message}]
    log(f"Usuario: {user_message}")

    response = ask_ollama(history)
    log(f"Modelo (raw): {response}")

    tool_result = None
    tool_data = extract_json_tool(response)

    if tool_data:
        tool_name = tool_data.get("tool")
        tool_args = tool_data.get("args", {})

        if tool_name in TOOLS:
            log(f"Executando ferramenta: {tool_name}({tool_args})")
            tool_result = TOOLS[tool_name](**tool_args)
            log(f"Resultado: {tool_result}")

            tool_context = f"Resultado de {tool_name}: {json.dumps(tool_result, ensure_ascii=False)}"
            history.append({"role": "assistant", "content": f"[ferramenta: {tool_name}]"})
            history.append({"role": "user", "content": tool_context})
            response = ask_ollama(history)
            log(f"Modelo (final): {response}")
        else:
            response = f"Ferramenta '{tool_name}' nao encontrada."

    # Garante que nenhum JSON aparece na resposta final
    response = remove_json_from_text(response)
    if not response:
        response = "Pronto, tarefa executada com sucesso!"

    history.append({"role": "assistant", "content": response})

    return {
        "response": response,
        "tool_used": tool_result is not None,
        "tool_result": tool_result,
        "history": history
    }

# ============================================================
# ROTAS DA API
# ============================================================

@app.route("/chat", methods=["POST"])
def chat():
    body = request.json or {}
    user_message = body.get("message", "").strip()
    history = body.get("history", [])
    if not user_message:
        return jsonify({"error": "Mensagem vazia"}), 400
    result = process_message(user_message, history)
    return jsonify(result)

@app.route("/status", methods=["GET"])
def status():
    ollama_ok = False
    try:
        r = requests.get("http://localhost:11434/api/tags", timeout=3)
        ollama_ok = r.status_code == 200
    except:
        pass
    return jsonify({
        "agent": "online",
        "ollama": "online" if ollama_ok else "offline",
        "model": MODEL,
        "timestamp": datetime.datetime.now().isoformat()
    })

@app.route("/sysinfo", methods=["GET"])
def sysinfo():
    return jsonify(get_system_info())

# ============================================================
# INICIO
# ============================================================

if __name__ == "__main__":
    log("=" * 50)
    log("PC AGENT iniciando...")
    log(f"Modelo: {MODEL}")
    log(f"Log salvo em: {LOG_FILE}")
    log("Servidor rodando em: http://localhost:5000")
    log("=" * 50)
    try:
        r = requests.get("http://localhost:11434/api/tags", timeout=3)
        log("Ollama: ONLINE")
    except:
        log("AVISO: Ollama offline. Inicie o Ollama antes de usar!")
    app.run(host="127.0.0.1", port=5000, debug=False)
