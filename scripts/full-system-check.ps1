#Requires -Version 7.0
<#
.SYNOPSIS
    T2 Release Notes Analyzer - Complete System Status Check
    
.DESCRIPTION
    Executes all handover commands in sequence for comprehensive system overview.
    Based on handover-commands-20250821.txt for seamless project continuation.
    
.PARAMETER ShowDetails
    Show detailed output from each check (default: $true)
    
.PARAMETER SaveReport
    Save status report to reports/ directory
    
.EXAMPLE
    .\scripts\full-system-check.ps1
    
.EXAMPLE
    .\scripts\full-system-check.ps1 -SaveReport
    
.NOTES
    Author: T2 Release Notes Analyzer Team
    Version: 1.0.0
    Created: 2025-08-22
    Part of: SHOULD-items from project backlog
#>

param(
    [switch]$ShowDetails = $true,
    [switch]$SaveReport = $false
)

# Initialize
$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$reportContent = @()

function Write-Section {
    param([string]$Title, [string]$Icon = "🔍")
    $line = "=" * 60
    Write-Host "`n$Icon $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Gray
    
    if ($SaveReport) {
        $script:reportContent += "`n$Icon $Title"
        $script:reportContent += $line
    }
}

function Write-Step {
    param([string]$Message, [string]$Icon = "▶️")
    Write-Host "`n$Icon $Message" -ForegroundColor Yellow
    
    if ($SaveReport) {
        $script:reportContent += "`n$Icon $Message"
    }
}

function Execute-Command {
    param(
        [string]$Description,
        [scriptblock]$Command,
        [string]$Icon = "▶️"
    )
    
    Write-Step $Description $Icon
    
    try {
        $output = & $Command
        
        if ($ShowDetails) {
            $output | Write-Host
        }
        
        if ($SaveReport) {
            $script:reportContent += $output
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($SaveReport) {
            $script:reportContent += "❌ Error: $($_.Exception.Message)"
        }
        
        return $false
    }
}

# Main execution
Write-Section "T2 Release Notes Analyzer - System Status Check" "🔍"
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray

if ($SaveReport) {
    $reportContent += "T2 Release Notes Analyzer - System Status Check"
    $reportContent += "Timestamp: $timestamp"
}

# 1. Comprehensive System Status Check
$success1 = Execute-Command "Running comprehensive system status check..." {
    if (Test-Path ".\scripts\check-system-status.ps1") {
        .\scripts\check-system-status.ps1
    } else {
        throw "check-system-status.ps1 not found"
    }
} "1️⃣"

# 2. Task Logs Analysis with Statistics  
$success2 = Execute-Command "Analyzing task logs with statistics..." {
    if (Test-Path ".\scripts\check-task-logs.ps1") {
        .\scripts\check-task-logs.ps1 -ShowStats
    } else {
        throw "check-task-logs.ps1 not found"
    }
} "2️⃣"

# 3. Recent Git History
$success3 = Execute-Command "Showing recent git commits..." {
    git log --oneline -5 2>&1
} "3️⃣"

# 4. Environment Template Review
$success4 = Execute-Command "Environment configuration template..." {
    if (Test-Path ".env.template") {
        Get-Content .env.template
    } else {
        throw ".env.template not found"
    }
} "4️⃣"

# Summary
Write-Section "Summary & Next Steps" "📊"

$totalChecks = 4
$successfulChecks = @($success1, $success2, $success3, $success4) | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count

Write-Host "✅ Successful checks: $successfulChecks/$totalChecks" -ForegroundColor Green

if ($successfulChecks -eq $totalChecks) {
    Write-Host "🎉 All system checks passed!" -ForegroundColor Green
    Write-Host "`n🎯 Ready for SHOULD-items from backlog:" -ForegroundColor Cyan
    Write-Host "   1. workflow-manager.ps1 - Import/Export Management" -ForegroundColor White
    Write-Host "   2. cleanup-old-backups.ps1 - Retention Management" -ForegroundColor White  
    Write-Host "   3. send-status-notification.ps1 - Benachrichtigungssystem" -ForegroundColor White
    Write-Host "   4. quick-commands.ps1 - Utility-Shortcuts" -ForegroundColor White
} else {
    Write-Host "⚠️ Some checks failed - review output above" -ForegroundColor Yellow
}

# Save report if requested
if ($SaveReport) {
    $reportsDir = ".\reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    $reportFile = Join-Path $reportsDir "system-status-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "`n📄 Report saved to: $reportFile" -ForegroundColor Green
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "System Status Check Complete! 🚀" -ForegroundColor Green