# File: .\scripts\admin-console.ps1
# T2 Release Notes Analyzer - Unified Admin Console

#Requires -Version 7.0
<#
.SYNOPSIS
    T2 Release Notes Analyzer - Unified Admin Console
    
.DESCRIPTION
    Interactive console that consolidates all admin scripts into a single interface.
    Provides menu-driven access to all system management functions.
    
.EXAMPLE
    .\scripts\admin-console.ps1
    
.NOTES
    File: .\scripts\admin-console.ps1
    Version: 1.0.0
    Created: 2025-08-22
    Consolidates: check-system-status, test-manual-backup, list-workflows, etc.
#>

# Import common functions
. "$PSScriptRoot\admin-console-functions.ps1"

function Show-Header {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                T2 RELEASE NOTES ANALYZER                         ║" -ForegroundColor Cyan
    Write-Host "║                      ADMIN CONSOLE                               ║" -ForegroundColor Cyan
    Write-Host "╠═══════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║ All administration scripts in one unified interface              ║" -ForegroundColor White
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📅 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | 🖥️  PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
}

function Show-MainMenu {
    Write-Host "🎛️  MAIN MENU" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""
    Write-Host " 🔍 SYSTEM STATUS & DIAGNOSTICS" -ForegroundColor Cyan
    Write-Host "   1) Full System Check           - Complete status overview"
    Write-Host "   2) System Status Only          - Quick health check"
    Write-Host "   3) Check Task Logs             - Analyze backup logs"
    Write-Host "   4) Git Status                  - Repository status"
    Write-Host ""
    Write-Host " 🔧 WORKFLOW MANAGEMENT" -ForegroundColor Green
    Write-Host "   5) List n8n Workflows          - Show all workflows"
    Write-Host "   6) Test Manual Backup          - Test backup functionality"
    Write-Host "   7) Export Workflow             - Manual workflow export"
    Write-Host "   8) Setup Daily Backup          - Configure automation"
    Write-Host ""
    Write-Host " 🛠️  MAINTENANCE & UTILITIES" -ForegroundColor Yellow
    Write-Host "   9) Fix Git Credentials         - Repair Git/GitHub issues"
    Write-Host "  10) Clean Old Backups           - Remove old backup files"
    Write-Host "  11) Environment Check           - Validate .env configuration"
    Write-Host "  12) API Diagnostics             - Deep n8n API analysis"
    Write-Host ""
    Write-Host " 📊 REPORTS & ANALYSIS" -ForegroundColor Magenta
    Write-Host "  13) Generate Status Report      - HTML system report"
    Write-Host "  14) Backup Statistics           - Analyze backup success"
    Write-Host "  15) Performance Metrics         - System performance data"
    Write-Host ""
    Write-Host " ⚙️  CONFIGURATION" -ForegroundColor Blue
    Write-Host "  16) Update Environment          - Edit .env settings"
    Write-Host "  17) View Configuration          - Show current config"
    Write-Host "  18) Reset Configuration         - Restore defaults"
    Write-Host ""
    Write-Host " 🎯 QUICK ACTIONS" -ForegroundColor Red
    Write-Host "  Q1) Emergency Backup            - Immediate backup"
    Write-Host "  Q2) Quick Status                - 30-second overview"
    Write-Host "  Q3) Commit Changes              - Git add/commit/push"
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host "   0) Exit Console" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-UserChoice {
    do {
        Write-Host "👉 Select option: " -ForegroundColor White -NoNewline
        $choice = Read-Host
        if ($choice -match '^(0|[1-9]|1[0-8]|Q[1-3])$') {
            return $choice.ToUpper()
        }
        Write-Host "❌ Invalid option. Please try again." -ForegroundColor Red
    } while ($true)
}

function Execute-Choice {
    param([string]$Choice)
    
    Write-Host "`n🚀 Executing: " -ForegroundColor Green -NoNewline
    
    switch ($Choice) {
        "1" { 
            Write-Host "Full System Check" -ForegroundColor White
            Invoke-FullSystemCheck
        }
        "2" { 
            Write-Host "System Status Check" -ForegroundColor White
            Invoke-SystemStatus
        }
        "3" { 
            Write-Host "Task Log Analysis" -ForegroundColor White
            Invoke-TaskLogs
        }
        "4" { 
            Write-Host "Git Status Check" -ForegroundColor White
            Invoke-GitStatus
        }
        "5" { 
            Write-Host "List Workflows" -ForegroundColor White
            Invoke-ListWorkflows
        }
        "6" { 
            Write-Host "Test Manual Backup" -ForegroundColor White
            Invoke-TestBackup
        }
        "7" { 
            Write-Host "Export Workflow" -ForegroundColor White
            Invoke-ExportWorkflow
        }
        "8" { 
            Write-Host "Setup Daily Backup" -ForegroundColor White
            Invoke-SetupDailyBackup
        }
        "9" { 
            Write-Host "Fix Git Credentials" -ForegroundColor White
            Invoke-FixGitCredentials
        }
        "10" { 
            Write-Host "Clean Old Backups" -ForegroundColor White
            Invoke-CleanBackups
        }
        "11" { 
            Write-Host "Environment Check" -ForegroundColor White
            Invoke-EnvironmentCheck
        }
        "12" { 
            Write-Host "API Diagnostics" -ForegroundColor White
            Invoke-ApiDiagnostics
        }
        "13" { 
            Write-Host "Generate Status Report" -ForegroundColor White
            Invoke-StatusReport
        }
        "14" { 
            Write-Host "Backup Statistics" -ForegroundColor White
            Invoke-BackupStats
        }
        "15" { 
            Write-Host "Performance Metrics" -ForegroundColor White
            Invoke-PerformanceMetrics
        }
        "16" { 
            Write-Host "Update Environment" -ForegroundColor White
            Invoke-UpdateEnvironment
        }
        "17" { 
            Write-Host "View Configuration" -ForegroundColor White
            Invoke-ViewConfig
        }
        "18" { 
            Write-Host "Reset Configuration" -ForegroundColor White
            Invoke-ResetConfig
        }
        "Q1" { 
            Write-Host "Emergency Backup" -ForegroundColor Red
            Invoke-EmergencyBackup
        }
        "Q2" { 
            Write-Host "Quick Status" -ForegroundColor Red
            Invoke-QuickStatus
        }
        "Q3" { 
            Write-Host "Commit Changes" -ForegroundColor Red
            Invoke-CommitChanges
        }
        "0" { 
            Write-Host "Exiting Admin Console" -ForegroundColor Gray
            return $false
        }
    }
    
    Write-Host "`n" + ("═" * 70) -ForegroundColor Gray
    Write-Host "✅ Operation completed. Press any key to continue..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true
}

function Wait-ForKeyPress {
    param([string]$Message = "Press any key to continue...")
    Write-Host "`n$Message" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main execution loop
try {
    do {
        Show-Header
        Show-MainMenu
        $choice = Get-UserChoice
        $continue = Execute-Choice $choice
    } while ($continue)
    
    Write-Host "`n👋 Thank you for using T2 Admin Console!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📧 Please report this issue to the development team." -ForegroundColor Yellow
    Wait-ForKeyPress
}