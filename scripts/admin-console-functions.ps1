# File: .\scripts\admin-console-functions.ps1
# Function library for T2 Admin Console

#Requires -Version 7.0
<#
.SYNOPSIS
    Function library for T2 Release Notes Analyzer Admin Console
    
.DESCRIPTION
    Contains all the functions that wrap existing scripts and provide
    additional functionality for the unified admin interface.
    
.NOTES
    File: .\scripts\admin-console-functions.ps1
    Version: 1.0.0
    Created: 2025-08-22
#>

# =============================================================================
# SYSTEM STATUS & DIAGNOSTICS
# =============================================================================

function Invoke-FullSystemCheck {
    Write-Host "🔍 Running complete system check..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\full-system-check.ps1") {
        & ".\scripts\full-system-check.ps1"
    } else {
        Write-Host "❌ full-system-check.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-SystemStatus {
    Write-Host "🔍 Checking system status..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\check-system-status.ps1") {
        & ".\scripts\check-system-status.ps1"
    } else {
        Write-Host "❌ check-system-status.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-TaskLogs {
    Write-Host "📊 Analyzing task logs..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\check-task-logs.ps1") {
        & ".\scripts\check-task-logs.ps1" -ShowStats
    } else {
        Write-Host "❌ check-task-logs.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-GitStatus {
    Write-Host "📁 Checking Git repository status..." -ForegroundColor Cyan
    try {
        Write-Host "`nGit Status:" -ForegroundColor Yellow
        git status --short
        Write-Host "`nRecent Commits:" -ForegroundColor Yellow
        git log --oneline -5
        Write-Host "`nBranch Information:" -ForegroundColor Yellow
        git branch -vv
    } catch {
        Write-Host "❌ Git error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# =============================================================================
# WORKFLOW MANAGEMENT
# =============================================================================

function Invoke-ListWorkflows {
    Write-Host "📋 Listing n8n workflows..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\list-workflows.ps1") {
        & ".\scripts\list-workflows.ps1"
    } else {
        Write-Host "❌ list-workflows.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-TestBackup {
    Write-Host "🧪 Testing manual backup..." -ForegroundColor Cyan
    $dryRun = Read-Host "Run in dry-run mode? (Y/n)"
    if ($dryRun -eq "" -or $dryRun -eq "Y" -or $dryRun -eq "y") {
        if (Test-Path ".\scripts\test-manual-backup.ps1") {
            & ".\scripts\test-manual-backup.ps1" -DryRun
        } else {
            Write-Host "❌ test-manual-backup.ps1 not found" -ForegroundColor Red
        }
    } else {
        if (Test-Path ".\scripts\test-manual-backup.ps1") {
            & ".\scripts\test-manual-backup.ps1"
        } else {
            Write-Host "❌ test-manual-backup.ps1 not found" -ForegroundColor Red
        }
    }
}

function Invoke-ExportWorkflow {
    Write-Host "📤 Exporting workflow..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\export-workflow.ps1") {
        & ".\scripts\export-workflow.ps1"
    } else {
        Write-Host "❌ export-workflow.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-SetupDailyBackup {
    Write-Host "⏰ Setting up daily backup..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\setup-daily-backup.ps1") {
        & ".\scripts\setup-daily-backup.ps1"
    } else {
        Write-Host "❌ setup-daily-backup.ps1 not found" -ForegroundColor Red
    }
}

# =============================================================================
# MAINTENANCE & UTILITIES
# =============================================================================

function Invoke-FixGitCredentials {
    Write-Host "🔧 Fixing Git credentials..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\fix-git-credentials.ps1") {
        & ".\scripts\fix-git-credentials.ps1"
    } else {
        Write-Host "❌ fix-git-credentials.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-CleanBackups {
    Write-Host "🧹 Cleaning old backups..." -ForegroundColor Cyan
    # This would be a new script we could create
    Write-Host "ℹ️  Feature coming soon: cleanup-old-backups.ps1" -ForegroundColor Yellow
    
    # Preview functionality
    if (Test-Path ".\workflows") {
        $backups = Get-ChildItem ".\workflows" -Filter "*.json" | Sort-Object LastWriteTime
        Write-Host "📊 Current backups: $($backups.Count)" -ForegroundColor Gray
        Write-Host "📅 Oldest: $($backups[0].LastWriteTime)" -ForegroundColor Gray
        Write-Host "📅 Newest: $($backups[-1].LastWriteTime)" -ForegroundColor Gray
    }
}

function Invoke-EnvironmentCheck {
    Write-Host "🔍 Checking environment configuration..." -ForegroundColor Cyan
    if (Test-Path ".\.env") {
        Write-Host "✅ .env file found" -ForegroundColor Green
        Write-Host "`nEnvironment variables:" -ForegroundColor Yellow
        Get-Content ".\.env" | ForEach-Object {
            if ($_ -and -not $_.StartsWith('#')) {
                $parts = $_.Split('=', 2)
                if ($parts.Count -eq 2) {
                    $key = $parts[0]
                    $value = $parts[1]
                    if ($key -like "*KEY*" -or $key -like "*TOKEN*") {
                        Write-Host "  $key = ***HIDDEN***" -ForegroundColor Gray
                    } else {
                        Write-Host "  $key = $value" -ForegroundColor Gray
                    }
                }
            }
        }
    } else {
        Write-Host "❌ .env file not found" -ForegroundColor Red
        if (Test-Path ".\.env.template") {
            Write-Host "💡 Template available: .env.template" -ForegroundColor Yellow
        }
    }
}

function Invoke-ApiDiagnostics {
    Write-Host "🔬 Running API diagnostics..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\diagnose-api.ps1") {
        & ".\scripts\diagnose-api.ps1"
    } else {
        Write-Host "ℹ️  Feature coming soon: Enhanced API diagnostics" -ForegroundColor Yellow
    }
}

# =============================================================================
# REPORTS & ANALYSIS
# =============================================================================

function Invoke-StatusReport {
    Write-Host "📊 Generating status report..." -ForegroundColor Cyan
    if (Test-Path ".\scripts\full-system-check.ps1") {
        & ".\scripts\full-system-check.ps1" -SaveReport
        Write-Host "✅ Report saved to ./reports/ directory" -ForegroundColor Green
    } else {
        Write-Host "❌ Cannot generate report - full-system-check.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-BackupStats {
    Write-Host "📈 Analyzing backup statistics..." -ForegroundColor Cyan
    if (Test-Path ".\logs\daily-backup.log") {
        $logContent = Get-Content ".\logs\daily-backup.log"
        $successCount = ($logContent | Where-Object { $_ -like "*SUCCESS*" }).Count
        $errorCount = ($logContent | Where-Object { $_ -like "*ERROR*" }).Count
        $totalEntries = $logContent.Count
        
        Write-Host "`n📊 Backup Statistics:" -ForegroundColor Yellow
        Write-Host "  Total log entries: $totalEntries" -ForegroundColor Gray
        Write-Host "  Successful operations: $successCount" -ForegroundColor Green
        Write-Host "  Errors: $errorCount" -ForegroundColor Red
        Write-Host "  Success rate: $([math]::Round(($successCount / ($successCount + $errorCount)) * 100, 1))%" -ForegroundColor Cyan
    } else {
        Write-Host "❌ No backup logs found" -ForegroundColor Red
    }
}

function Invoke-PerformanceMetrics {
    Write-Host "⚡ Gathering performance metrics..." -ForegroundColor Cyan
    Write-Host "`n🖥️  System Information:" -ForegroundColor Yellow
    Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "  OS Version: $([Environment]::OSVersion.VersionString)" -ForegroundColor Gray
    Write-Host "  Current Directory: $(Get-Location)" -ForegroundColor Gray
    Write-Host "  Available Memory: $([math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)) GB" -ForegroundColor Gray
}

# =============================================================================
# CONFIGURATION
# =============================================================================

function Invoke-UpdateEnvironment {
    Write-Host "⚙️  Opening environment configuration..." -ForegroundColor Cyan
    if (Test-Path ".\.env") {
        Write-Host "📝 Opening .env file for editing..." -ForegroundColor Yellow
        Start-Process notepad ".\.env"
    } else {
        Write-Host "❌ .env file not found. Would you like to create it from template?" -ForegroundColor Yellow
        $create = Read-Host "Create .env from template? (Y/n)"
        if ($create -eq "" -or $create -eq "Y" -or $create -eq "y") {
            if (Test-Path ".\.env.template") {
                Copy-Item ".\.env.template" ".\.env"
                Write-Host "✅ .env created from template" -ForegroundColor Green
                Start-Process notepad ".\.env"
            } else {
                Write-Host "❌ .env.template not found" -ForegroundColor Red
            }
        }
    }
}

function Invoke-ViewConfig {
    Write-Host "👀 Viewing current configuration..." -ForegroundColor Cyan
    Invoke-EnvironmentCheck
}

function Invoke-ResetConfig {
    Write-Host "🔄 Resetting configuration..." -ForegroundColor Cyan
    Write-Host "⚠️  This will overwrite your current .env file!" -ForegroundColor Yellow
    $confirm = Read-Host "Are you sure? (type 'RESET' to confirm)"
    if ($confirm -eq "RESET") {
        if (Test-Path ".\.env.template") {
            Copy-Item ".\.env.template" ".\.env" -Force
            Write-Host "✅ Configuration reset to template defaults" -ForegroundColor Green
        } else {
            Write-Host "❌ .env.template not found" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Reset cancelled" -ForegroundColor Yellow
    }
}

# =============================================================================
# QUICK ACTIONS
# =============================================================================

function Invoke-EmergencyBackup {
    Write-Host "🚨 Emergency backup..." -ForegroundColor Red
    if (Test-Path ".\scripts\export-workflow.ps1") {
        Write-Host "⚡ Running immediate backup..." -ForegroundColor Yellow
        & ".\scripts\export-workflow.ps1"
    } else {
        Write-Host "❌ export-workflow.ps1 not found" -ForegroundColor Red
    }
}

function Invoke-QuickStatus {
    Write-Host "⚡ Quick 30-second status check..." -ForegroundColor Red
    
    # Quick checks
    Write-Host "🔍 n8n: " -ForegroundColor Gray -NoNewline
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5678" -TimeoutSec 3 -UseBasicParsing
        Write-Host "✅ Running" -ForegroundColor Green
    } catch {
        Write-Host "❌ Not accessible" -ForegroundColor Red
    }
    
    Write-Host "🔍 Git: " -ForegroundColor Gray -NoNewline
    try {
        git status --porcelain | Out-Null
        Write-Host "✅ Repository OK" -ForegroundColor Green
    } catch {
        Write-Host "❌ Issue detected" -ForegroundColor Red
    }
    
    Write-Host "🔍 Logs: " -ForegroundColor Gray -NoNewline
    if (Test-Path ".\logs") {
        $logFiles = Get-ChildItem ".\logs" -Filter "*.log"
        Write-Host "✅ $($logFiles.Count) log files" -ForegroundColor Green
    } else {
        Write-Host "❌ No logs directory" -ForegroundColor Red
    }
}

function Invoke-CommitChanges {
    Write-Host "📝 Committing changes..." -ForegroundColor Red
    try {
        $status = git status --porcelain
        if ($status) {
            Write-Host "📋 Uncommitted changes found:" -ForegroundColor Yellow
            git status --short
            
            $message = Read-Host "`nEnter commit message"
            if ($message) {
                git add .
                git commit -m $message
                
                $push = Read-Host "Push to GitHub? (Y/n)"
                if ($push -eq "" -or $push -eq "Y" -or $push -eq "y") {
                    git push
                    Write-Host "✅ Changes pushed to GitHub" -ForegroundColor Green
                }
            } else {
                Write-Host "❌ No commit message provided" -ForegroundColor Red
            }
        } else {
            Write-Host "ℹ️  No changes to commit" -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ Git error: $($_.Exception.Message)" -ForegroundColor Red
    }
}