#!/usr/bin/env python3
import os
import time
import json
import sqlite3
import socket
import requests
import psutil
import configparser
import subprocess

# --- Load config ---
CONFIG_PATH = "/etc/moshai-pulse/config"
config = configparser.ConfigParser()
config.read(CONFIG_PATH)

SERVER_KEY = config.get("agent", "server_key")
API_URL = config.get("agent", "api_url", fallback="https://pulse.moshai.dev/api/agent")
DB_PATH = config.get("agent", "db_path", fallback="/var/lib/moshai-pulse/metrics.db")
COLLECTION_INTERVAL = config.getint("agent", "collection_interval", fallback=60)
RETRY_COUNT = config.getint("agent", "retry_count", fallback=3)
RETRY_GAP = config.getint("agent", "retry_gap", fallback=5)

# --- Setup ---
hostname = socket.gethostname()
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

conn = sqlite3.connect(DB_PATH, check_same_thread=False)
cur = conn.cursor()
cur.execute("""
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER,
    payload TEXT
)
""")
conn.commit()

# --- Metrics Collection ---
def collect_metrics(interval=COLLECTION_INTERVAL):
    cpu_samples = []
    disk_start = psutil.disk_io_counters()
    net_start = psutil.net_io_counters()

    for _ in range(interval):
        cpu_samples.append(psutil.cpu_percent(interval=1))

    cpu_avg = sum(cpu_samples) / len(cpu_samples)
    cpu_max = max(cpu_samples)

    mem = psutil.virtual_memory()
    disk_end = psutil.disk_io_counters()
    net_end = psutil.net_io_counters()

    disk_read = disk_end.read_bytes - disk_start.read_bytes
    disk_write = disk_end.write_bytes - disk_start.write_bytes
    disk_usage = psutil.disk_usage("/")

    net_in = net_end.bytes_recv - net_start.bytes_recv
    net_out = net_end.bytes_sent - net_start.bytes_sent

    # --- Clean CPU model ---
    cpu_model_raw = os.popen("lscpu | grep 'Model name' | awk -F ':' '{print $2}'").read().strip()
    cpu_model = cpu_model_raw.splitlines()[0].strip()  # remove duplicates, extra spaces

    ts = int(time.time())
    payload = {
        "hostname": hostname,
        "timestamp": ts,
        "cpu": {"avg": cpu_avg, "max": cpu_max, "cores": psutil.cpu_count()},
        "memory": {"used": mem.used, "total": mem.total, "percent": mem.percent},
        "disk": {
            "used": disk_usage.used,
            "total": disk_usage.total,
            "percent": disk_usage.percent,
            "read_bytes": disk_read,
            "write_bytes": disk_write
        },
        "network": {"in_bytes": net_in, "out_bytes": net_out},
        "system": {
            "os": os.uname().sysname + " " + os.uname().release,
            "cpu_model": cpu_model,
            "memory_total_bytes": mem.total
        },
        "services": get_all_service_status()
    }

    cur.execute("INSERT INTO metrics (timestamp, payload) VALUES (?, ?)", (ts, json.dumps(payload)))
    conn.commit()
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Collected metrics")

# --- Get all systemd service statuses (compatible with older Python) ---
def get_all_service_status():
    services = {}
    try:
        result = subprocess.run(
            ["systemctl", "list-units", "--type=service", "--all", "--no-legend", "--no-pager"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,   # compatible with Python 3.4+
            check=True
        )
        lines = result.stdout.strip().split("\n")
        for line in lines:
            if not line:
                continue
            parts = line.split()
            service_name = parts[0]
            active_state = parts[3] if len(parts) > 3 else "unknown"
            services[service_name] = active_state
    except Exception as e:
        services["error"] = str(e)
    return services

# --- Send Metrics ---
def send_batch():
    cur.execute("SELECT id, payload FROM metrics ORDER BY id ASC")
    rows = cur.fetchall()
    if not rows:
        return

    payloads = [json.loads(r[1]) for r in rows]
    success = False

    for attempt in range(RETRY_COUNT):
        try:
            res = requests.post(API_URL, json=payloads, headers={"Authorization": f"Bearer {SERVER_KEY}"}, timeout=10)
            if res.status_code == 200:
                success = True
                break
            else:
                print(f"Server returned {res.status_code}")
        except Exception as e:
            print(f"Attempt {attempt+1} failed: {e}")
        time.sleep(RETRY_GAP)

    if success:
        ids = [str(r[0]) for r in rows]
        cur.execute(f"DELETE FROM metrics WHERE id IN ({','.join(ids)})")
        conn.commit()
        print(f"✅ Sent {len(rows)} metrics, deleted from DB.")
    else:
        print(f"❌ Failed to send {len(rows)} metrics, keeping in DB.")

# --- Main Loop ---
def main():
    while True:
        collect_metrics(COLLECTION_INTERVAL)
        send_batch()

if __name__ == "__main__":
    main()
