<#
.SYNOPSIS
    VPN Coordinator for VISH-HOMESERVER
    Monitors Surfshark VPN and coordinates Tailscale status to enforce mutual exclusion.

.DESCRIPTION
    Tailscale is intended to run 24/7 for remote administration (SSH, RDP) and DNS resolution
    via the tailscale-dns container.
    Surfshark VPN is run on demand when torrenting (with qBittorrent bound to the adapter).
    
    This coordinator script runs continuously in the background:
    1. If Surfshark becomes CONNECTED (WireGuard or OpenVPN adapter Up with active IP),
       it gracefully disconnects Tailscale (`tailscale down`).
    2. When Surfshark becomes DISCONNECTED, it automatically restores Tailscale (`tailscale up`).
    
    Integrations:
    - Pushes status transitions to ntfy (http://10.0.0.111:8081/vish-alerts-4fbdb2ea83af).
    - Pushes periodic heartbeats to Uptime Kuma (http://10.0.0.111:3001/api/push/vpncoord79a41b2c5d8e0f13579bdf24).
    - AlgoTrading services, dashboards, and scheduled tasks are strictly untouched.

.NOTES
    Author: Vishnu-Server Admin / Antigravity
    Target: VISH-HOMESERVER
#>

[CmdletBinding()]
param(
    [int]$PollIntervalSec = 3,
    [string]$TailscaleExe = "C:\Program Files\Tailscale\tailscale.exe",
    [bool]$EnableNtfy = $true,
    [string]$NtfyBase = "http://10.0.0.111:8081",
    [string]$NtfyTopic = "vish-alerts-4fbdb2ea83af",
    [bool]$EnableKuma = $true,
    [string]$KumaPushUrl = "http://10.0.0.111:3001/api/push/vpncoord79a41b2c5d8e0f13579bdf24",
    [int]$KumaPushIntervalSec = 30,
    [string]$LogPath = "",
    [switch]$RunOnce,
    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Continue'

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $LogPath = Join-Path $scriptDir 'vpn-coordinator.log'
}

function Write-CoordinatorLog {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if ($VerboseOutput -or [Environment]::UserInteractive) {
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN'  { 'Yellow' }
            'STATE' { 'Cyan' }
            default { 'White' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
    
    if ($LogPath) {
        try {
            Add-Content -LiteralPath $LogPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch { }
    }
}

function Send-CoordinatorNtfy {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Tags = 'shield',
        [int]$Priority = 3
    )
    if (-not $EnableNtfy) { return }
    try {
        Invoke-RestMethod -Uri "$NtfyBase/$NtfyTopic" -Method Post -Body $Message -TimeoutSec 5 `
            -Headers @{ Title = $Title; Tags = $Tags; Priority = "$Priority" } -ErrorAction Stop | Out-Null
        Write-CoordinatorLog "ntfy alert sent: $Title" -Level 'DEBUG'
    } catch {
        Write-CoordinatorLog "Failed to send ntfy notification: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Send-KumaHeartbeat {
    param(
        [string]$Message,
        [int]$PingMs = 0
    )
    if (-not $EnableKuma -or [string]::IsNullOrWhiteSpace($KumaPushUrl)) { return }
    try {
        $encodedMsg = [System.Uri]::EscapeDataString($Message)
        $url = "$($KumaPushUrl)?status=up&msg=$encodedMsg&ping=$PingMs"
        Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 5 -ErrorAction Stop | Out-Null
        Write-CoordinatorLog "Uptime Kuma heartbeat pushed: $Message" -Level 'DEBUG'
    } catch {
        Write-CoordinatorLog "Failed to push Uptime Kuma heartbeat: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Get-SurfsharkConnected {
    <#
        Checks if any Surfshark adapter (SurfsharkWireGuard or OpenVPN) is Up
        and has an active, preferred IPv4 address (excluding APIPA 169.254.x.x).
    #>
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Surfshark' -and $_.Status -eq 'Up' }
        
        if (-not $adapters) { return $false }
        
        foreach ($adapter in $adapters) {
            $ips = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -notlike '169.254.*' }
            if ($ips) {
                return $true
            }
        }
        return $false
    } catch {
        Write-CoordinatorLog "Error checking Surfshark adapter: $($_.Exception.Message)" -Level 'WARN'
        return $false
    }
}

function Get-TailscaleState {
    <#
        Returns BackendState: 'Running', 'Stopped', 'Starting', 'NeedsLogin', or 'Unavailable'.
    #>
    if (-not (Test-Path $TailscaleExe)) {
        Write-CoordinatorLog "Tailscale executable not found at '$TailscaleExe'" -Level 'ERROR'
        return 'Unavailable'
    }
    
    try {
        $jsonStr = & $TailscaleExe status --json 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($jsonStr)) {
            return 'Stopped'
        }
        $obj = $jsonStr | ConvertFrom-Json
        if ($obj -and $obj.BackendState) {
            return $obj.BackendState
        }
        return 'Unknown'
    } catch {
        return 'Unknown'
    }
}

function Set-TailscaleConnection {
    param([bool]$Connect)
    
    if (-not (Test-Path $TailscaleExe)) {
        Write-CoordinatorLog "Cannot toggle Tailscale: '$TailscaleExe' not found" -Level 'ERROR'
        return $false
    }
    
    if ($Connect) {
        Write-CoordinatorLog "Restoring Tailscale connection (tailscale up)..." -Level 'STATE'
        # Plain 'tailscale up' brings network online without changing existing flags (like --unattended)
        $output = & $TailscaleExe up 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            # Fallback if Tailscale requires explicit flag specification
            $output = & $TailscaleExe up --unattended 2>&1
            $exitCode = $LASTEXITCODE
        }
        if ($exitCode -eq 0) {
            Write-CoordinatorLog "Tailscale brought online successfully." -Level 'STATE'
            Send-CoordinatorNtfy -Title "Tailscale Restored" `
                                 -Message "Surfshark disconnected. Tailscale is now active (24/7 mode)." `
                                 -Tags "link,white_check_mark" -Priority 3
            return $true
        } else {
            Write-CoordinatorLog "Failed to bring Tailscale up (exit $exitCode): $output" -Level 'ERROR'
            return $false
        }
    } else {
        Write-CoordinatorLog "Dropping Tailscale connection (tailscale down)..." -Level 'STATE'
        $output = & $TailscaleExe down 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-CoordinatorLog "Tailscale disconnected successfully." -Level 'STATE'
            Send-CoordinatorNtfy -Title "Tailscale Dropped" `
                                 -Message "Surfshark VPN connected (torrenting active). Tailscale disconnected." `
                                 -Tags "warning,lock" -Priority 3
            return $true
        } else {
            Write-CoordinatorLog "Failed to disconnect Tailscale (exit $exitCode): $output" -Level 'ERROR'
            return $false
        }
    }
}

# --- Initialization ---
Write-CoordinatorLog "=========================================================="
Write-CoordinatorLog "VPN Coordinator started."
Write-CoordinatorLog "Poll interval: ${PollIntervalSec}s | ntfy: $EnableNtfy | Kuma: $EnableKuma | Log: $LogPath"
Write-CoordinatorLog "AlgoTrading processes & routes are protected and untouched."
Write-CoordinatorLog "=========================================================="

$lastSurfsharkState = $null
$lastKumaPush = [datetime]::MinValue

do {
    $isSurfsharkActive = Get-SurfsharkConnected
    $tailscaleState = Get-TailscaleState
    
    # State change detection / evaluation
    if ($isSurfsharkActive) {
        # Surfshark is CONNECTED
        if ($lastSurfsharkState -ne $true) {
            Write-CoordinatorLog "Surfshark VPN detected as ACTIVE." -Level 'STATE'
            $lastSurfsharkState = $true
        }
        
        # Tailscale should NOT be running while Surfshark is active
        if ($tailscaleState -eq 'Running' -or $tailscaleState -eq 'Starting') {
            Write-CoordinatorLog "Mutual exclusion rule triggered: Surfshark is UP but Tailscale is $tailscaleState." -Level 'WARN'
            Start-Sleep -Seconds 1
            if (Get-SurfsharkConnected) {
                Set-TailscaleConnection -Connect $false | Out-Null
            }
        }
    } else {
        # Surfshark is DISCONNECTED
        if ($lastSurfsharkState -ne $false) {
            Write-CoordinatorLog "Surfshark VPN detected as INACTIVE (disconnected)." -Level 'STATE'
            $lastSurfsharkState = $false
        }
        
        # Tailscale SHOULD be running 24/7 when Surfshark is inactive
        if ($tailscaleState -eq 'Stopped' -or $tailscaleState -eq 'NeedsLogin') {
            Write-CoordinatorLog "Mutual exclusion rule triggered: Surfshark is DOWN but Tailscale is $tailscaleState." -Level 'STATE'
            Start-Sleep -Seconds 1
            if (-not (Get-SurfsharkConnected)) {
                Set-TailscaleConnection -Connect $true | Out-Null
            }
        }
    }
    
    # Periodic Uptime Kuma heartbeat push
    $now = Get-Date
    if ($EnableKuma -and (($now - $lastKumaPush).TotalSeconds -ge $KumaPushIntervalSec -or $RunOnce)) {
        $lastKumaPush = $now
        $statusSummary = if ($isSurfsharkActive) {
            "Surfshark: Active | Tailscale: Paused"
        } else {
            "Surfshark: Inactive | Tailscale: Active (24/7)"
        }
        Send-KumaHeartbeat -Message $statusSummary
    }
    
    if ($RunOnce) {
        Write-CoordinatorLog "RunOnce specified. Coordinator check completed." -Level 'INFO'
        break
    }
    
    Start-Sleep -Seconds $PollIntervalSec
} while ($true)
