# VPN Coordinator (Tailscale & Surfshark)

Automated VPN mutual-exclusion watchdog for **VISH-HOMESERVER**.

---

## 1. Overview & Purpose

On this home server:
- **Tailscale** is intended to run **24/7** to provide secure remote administration (SSH, RDP, trading dashboard) and mobile ad-blocking DNS via the `tailscale-dns` (CoreDNS) container pointing to AdGuard Home.
- **Surfshark VPN** is used **on-demand** when torrenting. qBittorrent is bound directly to the `SurfsharkWireGuard` network interface as an automatic kill switch.

### The Conflict
When Surfshark connects, WireGuard installs high-priority routes (`0.0.0.0/1` and `128.0.0.0/1` at metric 0). Having both Tailscale and Surfshark tunnels active simultaneously creates routing ambiguity, DNS races, and potential leakage.

### The Solution: Mutual Exclusion
`vpn-coordinator` continuously monitors the status of Surfshark:
1. **Surfshark Connects** $\rightarrow$ Coordinator immediately executes `tailscale down`.
2. **Surfshark Disconnects** $\rightarrow$ Coordinator immediately executes `tailscale up` (with `--unattended` enabled).
3. **Alerts** $\rightarrow$ Status changes are pushed directly to the home server's **ntfy** notification topic.

---

## 2. Why a Native Windows Service (Not Docker)?

While most server workloads on this machine run as Docker containers under `X:\Docker\`, Docker Desktop for Windows runs containers inside an isolated WSL2 Linux VM. A container cannot:
- Directly monitor or query Windows host network adapters (`Get-NetAdapter`, `Get-NetIPAddress`).
- Control Windows host services or invoke host binaries like `tailscale.exe`.

Attempting to control host networking from inside Docker requires SSH or reverse-proxy bridges back to the Windows host, introducing circular dependencies and failure points. A native Windows service managed by **NSSM** (Non-Sucking Service Manager) is the cleanest, most resilient solution (<15 MB RAM, 0% idle CPU).

---

## 3. Algo Trading Protection (Safety Guarantee)

> [!IMPORTANT]
> **This server runs live algorithmic trading systems.**
> The `AlgoTradingDashboard` service (port 8000) and the `\AlgoTrading\` scheduled tasks execute critical market tasks during trading days.
> 
> **`vpn-coordinator` is strictly scoped:**
> - It **never** touches LAN network adapters (`vEthernet (HomeNetworkSwitch)`).
> - It **never** alters physical network routing or default gateways used by trading processes.
> - It **never** inspects, kills, or restarts any Python or trading processes.
> - It only toggles the host Tailscale connection (`tailscale down` / `tailscale up`).

---

## 4. Script & File Manifest

| File | Purpose |
|---|---|
| `vpn-coordinator.ps1` | The core watchdog script. Monitors adapters, manages Tailscale, writes logs, and sends ntfy alerts. |
| `install-service.ps1` | Elevated setup script that registers and starts `VpnCoordinator` as an NSSM Windows service. |
| `uninstall-service.ps1` | Elevated script to cleanly stop and unregister the `VpnCoordinator` service. |
| `status.ps1` | Quick health-check utility displaying live statuses of Surfshark, Tailscale, service state, and recent logs. |
| `vpn-coordinator.log` | Coordinator event and state change history log. |
| `vpn-coordinator.service.log` | Standard output stream captured by NSSM. |
| `vpn-coordinator.err.log` | Standard error stream captured by NSSM. |

---

## 5. Usage & Operations

### A. Quick Health Check
To see the current state of both VPNs and the coordinator service:
```powershell
powershell -ExecutionPolicy Bypass -File .\status.ps1
```

### B. Interactive / One-Off Test
To run a single verification check without running the loop:
```powershell
powershell -ExecutionPolicy Bypass -File .\vpn-coordinator.ps1 -RunOnce -VerboseOutput
```

To run interactively in the console with live color-coded output:
```powershell
powershell -ExecutionPolicy Bypass -File .\vpn-coordinator.ps1 -VerboseOutput
```

### C. Installing the Windows Service
Run from an elevated PowerShell prompt (or launch directly to trigger the UAC prompt):
```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\Vishnu-Server\Desktop\Coding\Personal-Agents\Scripts\vpn-coordinator\install-service.ps1'
```

Once installed:
- Service Name: `VpnCoordinator`
- Display Name: `VPN Coordinator (Tailscale/Surfshark)`
- Startup Type: `Automatic` (runs at boot under `LocalSystem`)
- Crash recovery: NSSM automatically restarts the process after a 5-second delay.

### D. Managing the Service
```powershell
# Check service status
Get-Service VpnCoordinator

# Stop / Start service
Stop-Service VpnCoordinator
Start-Service VpnCoordinator

# View real-time log
Get-Content .\vpn-coordinator.log -Wait -Tail 20
```

### E. Uninstalling the Service
```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\Vishnu-Server\Desktop\Coding\Personal-Agents\Scripts\vpn-coordinator\uninstall-service.ps1'
```

---

## 6. Integration Details

### Notifications (ntfy)
State transitions trigger HTTP POST notifications to:
`http://10.0.0.111:8081/vish-alerts-4fbdb2ea83af`
- **Tailscale Dropped**: Priority 3, tags `warning,lock`
- **Tailscale Restored**: Priority 3, tags `link,white_check_mark`

### Tailscale Unattended Mode
Tailscale is configured with `unattended=true` (`tailscale set --unattended=true`), ensuring that Tailscale can connect and operate headlessly without requiring an active desktop login.
