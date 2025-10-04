# Moshai Pulse Agent

Moshai Pulse is a lightweight, reliable server monitoring agent that collects CPU, memory, disk, and network metrics and sends them to a central API at `https://pulse.moshai.dev/api/agent`. It is designed to work across all Linux distributions and supports non-interactive installation.

## Features

* CPU: average + max over interval
* Memory: snapshot (used, total, percent)
* Disk/Network: throughput per interval
* SQLite buffer for reliable data storage if API fails
* Configurable via `/etc/moshai-pulse/config`
* Systemd service for automatic start and restart
* Non-interactive installation with server key
* Supports Debian, Ubuntu, CentOS, RHEL, Rocky, Alma, Fedora

---

## Requirements

* Linux server with Python 3 installed
* Network access to `https://pulse.moshai.dev/api/agent`

---

## Installation

### Non-interactive install (all Linux distros)

Replace `YOUR_SERVER_KEY` with your server key:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moshai-dev/pulse/main/scripts/install.sh) --key YOUR_SERVER_KEY
```

This will:

1. Install dependencies (`python3`, `python3-psutil`, `python3-requests`, `sqlite3`, `curl`)
2. Create `/etc/moshai-pulse/config` and `/var/lib/moshai-pulse`
3. Download the agent to `/usr/local/bin/moshai-pulse.py`
4. Inject your server key into the config
5. Install and start `moshai-pulse.service` via systemd

**Check logs:**

```bash
journalctl -u moshai-pulse -f
```

---

## Configuration

Config file path: `/etc/moshai-pulse/config`

```ini
[agent]
server_key = YOUR_SERVER_KEY
api_url = https://pulse.moshai.dev/api/agent
db_path = /var/lib/moshai-pulse/metrics.db
collection_interval = 60
retry_count = 3
retry_gap = 5
```

* `collection_interval`: seconds between metric collections
* `retry_count`: how many times to retry failed API requests
* `retry_gap`: seconds between retries

---

## Uninstall

Run the uninstall script to cleanly remove the agent:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moshai-dev/pulse/main/scripts/uninstall.sh)
```

This removes:

* Systemd service
* Agent binary
* Configuration
* SQLite data directory

---

## Directory Structure

```
/usr/local/bin/moshai-pulse.py       # Agent executable
/etc/moshai-pulse/config            # Configuration file
/var/lib/moshai-pulse/metrics.db    # SQLite metrics storage
/etc/systemd/system/moshai-pulse.service  # Systemd service
```

---

## Updating

To update the agent, re-run the installer with the same server key. Systemd will restart the updated agent automatically.

---

## License

MIT License
