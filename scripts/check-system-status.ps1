# Save as: .\scripts\check-system-status.ps1
# Enhanced System Status Check with Smart API Diagnostics

#Requires -Version 7.0
<#
.SYNOPSIS
    T2 Release Notes Analyzer - Enhanced System Status Check with Actionable Insights
    
.DESCRIPTION
    Provides quick, actionable system status with specific solutions for each problem.
    Focuses on what needs attention and how to fix it.
    Enhanced with smart n8n API diagnostics.
    
.EXAMPLE
    .\scripts\check-system-status.ps1
    
.NOTES
    Enhanced for: Clear problem identification + Direct solutions + API diagnostics
    Version: 2.1.0 (Smart API Diagnostics)
    File: .\scripts\check-system-status.ps1
#>

param(
    [switch]$QuickCheck = $false
)

# Initialize
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Problem {
    param([string]$Issue, [string]$Solution, [string]$File = "")
    $fileInfo = if ($File) { " ($File)" } else { "" }
    Write-Host "❌ PROBLEM: $Issue$fileInfo" -ForegroundColor Red
    Write-Host "   → SOLUTION: $Solution" -ForegroundColor Yellow
}

function Write-Warning {
    param([string]$Issue, [string]$Action)
    Write-Host "⚠️  WARNING: $Issue" -ForegroundColor Yellow
    Write-Host "   → ACTION: $Action" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ OK: $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  INFO: $Message" -ForegroundColor Gray
}

Write-Host "[$timestamp] === T2 Release Notes Analyzer - System Status Check ===" -ForegroundColor Cyan

# Critical Issues Counter
$criticalIssues = 0
$warnings = 0

Write-Host "`n[$timestamp] === n8n API Status Check ===" -ForegroundColor White

# n8n Web Interface Check
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5678" -TimeoutSec 5 -UseBasicParsing
    Write-Success "n8n Web Interface erreichbar (Port 5678)"
} catch {
    Write-Problem "n8n Web Interface NICHT erreichbar" "Start n8n: 'n8n start' oder überprüfe Port 5678"
    $criticalIssues++
}

# n8n API Key Check - Enhanced with smart diagnostics
$envFile = ".\.env"
$envTemplateFile = ".\.env.template"

if (Test-Path $envFile) {
    # Load environment variables for API testing
    $envContent = Get-Content $envFile
    foreach ($line in $envContent) {
        if (-not [string]::IsNullOrWhiteSpace($line) -and -not $line.TrimStart().StartsWith('#') -and $line.Contains('=')) {
            $parts = $line.Split('=', 2)
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                # Remove quotes if present
                if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                if ($value.StartsWith("'") -and $value.EndsWith("'")) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                [Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
        }
    }
    
    $apiKey = [Environment]::GetEnvironmentVariable("N8N_API_KEY", "Process")
    
    if ($apiKey -and $apiKey -ne "your-n8n-api-key-here" -and $apiKey.Length -gt 10) {
        Write-Success "N8N_API_KEY konfiguriert in .env"
        
        # Test API key validity
        try {
            $baseUrl = [Environment]::GetEnvironmentVariable("N8N_BASE_URL", "Process")
            if (-not $baseUrl) { $baseUrl = "http://localhost:5678/api/v1" }
            
            $headers = @{
                "X-N8N-API-KEY" = $apiKey
                "Content-Type" = "application/json"
            }
            
            $response = Invoke-RestMethod -Uri "$baseUrl/workflows" -Method Get -Headers $headers -TimeoutSec 5
            Write-Success "n8n API Key funktioniert - $($response.Count) Workflows accessible"
            
        } catch {
            if ($_.Exception.Response.StatusCode -eq 401) {
                Write-Problem "n8n API Key INVALID (401 Unauthorized)" "Generate new API key in n8n settings" $envFile
                Write-Info "🔍 API Key Analysis:"
                Write-Info "   → Length: $($apiKey.Length) chars"
                Write-Info "   → Format: $($apiKey.Substring(0, [Math]::Min(10, $apiKey.Length)))..."
                
                if ($apiKey.StartsWith("eyJ")) {
                    Write-Info "   → ⚠️  JWT format detected - may be wrong type!"
                    Write-Info "   → Expected: 'n8n_api_xxxxxxxxxxxxx'"
                }
                
                Write-Info "🔧 FIX: Open http://localhost:5678/settings/api → Generate new key → Update .env"
                $criticalIssues++
            } else {
                Write-Warning "n8n API Key test failed" "Check if n8n is running: http://localhost:5678"
                $warnings++
            }
        }
    } else {
        Write-Problem "N8N_API_KEY nicht korrekt gesetzt" "Edit .env file: Set N8N_API_KEY=<your-actual-key>" $envFile
        $criticalIssues++
    }
} else {
    Write-Problem "Environment file fehlt" "Copy .env.template to .env and configure keys" $envTemplateFile
    $criticalIssues++
}

Write-Host "`n[$timestamp] === Git Repository Status Check ===" -ForegroundColor White

# Git availability
try {
    $gitVersion = git --version
    Write-Success "Git verfügbar: $gitVersion"
} catch {
    Write-Problem "Git nicht verfügbar" "Install Git for Windows: https://git-scm.com/"
    $criticalIssues++
    return
}

# Git repository check
if (Test-Path ".git") {
    Write-Success "Git Repository erkannt"
    
    # Current branch
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Info "Aktueller Branch: $currentBranch"
    
    # Uncommitted changes - Enhanced analysis
    $statusOutput = git status --porcelain
    if ($statusOutput) {
        $fileCount = ($statusOutput | Measure-Object).Count
        $files = $statusOutput | ForEach-Object { $_.Substring(3) } | Select-Object -First 3
        Write-Warning "Uncommitted Changes: $fileCount Dateien" "Review changes: git status, then git add . && git commit -m 'description'"
        Write-Info "Files: $($files -join ', ')$(if($fileCount -gt 3){'...'})"
        $warnings++
    } else {
        Write-Success "Keine uncommitted Changes"
    }
    
    # Remote sync check
    try {
        git fetch origin --dry-run 2>&1 | Out-Null
        $behind = git rev-list --count HEAD..origin/$currentBranch 2>$null
        $ahead = git rev-list --count origin/$currentBranch..HEAD 2>$null
        
        if ($behind -eq "0" -and $ahead -eq "0") {
            Write-Success "Branch ist synchron mit origin/$currentBranch"
        } elseif ($behind -gt 0) {
            Write-Warning "Branch ist $behind commits behind origin" "git pull origin $currentBranch"
            $warnings++
        } elseif ($ahead -gt 0) {
            Write-Warning "Branch ist $ahead commits ahead origin" "git push origin $currentBranch"
            $warnings++
        }
    } catch {
        Write-Warning "Remote sync status nicht prüfbar" "Check internet connection and git remote"
        $warnings++
    }
} else {
    Write-Problem "Kein Git Repository erkannt" "Run: git init && git remote add origin <repo-url>"
    $criticalIssues++
}

Write-Host "`n[$timestamp] === Task Scheduler Status Check ===" -ForegroundColor White

# Task Scheduler Check - Enhanced with clear guidance
try {
    $task = Get-ScheduledTask -TaskName "T2-Daily-Backup" -TaskPath "\T2-Release-Notes-Analyzer\" -ErrorAction Stop
    Write-Success "Task 'T2-Daily-Backup' gefunden"
    
    $taskInfo = Get-ScheduledTaskInfo -TaskName "T2-Daily-Backup" -TaskPath "\T2-Release-Notes-Analyzer\"
    Write-Info "Task Status: $($task.State), Letzter Lauf: $($taskInfo.LastRunTime), Exit Code: $($taskInfo.LastTaskResult)"
    
    if ($taskInfo.LastTaskResult -ne 0) {
        Write-Warning "Task Exit Code: $($taskInfo.LastTaskResult)" "Check task logs: .\logs\daily-backup.log"
        $warnings++
    }
} catch {
    # This is NOT a critical issue - it's expected for development setups
    Write-Info "Task 'T2-Daily-Backup' nicht gefunden (OK für Development Setup)"
    Write-Info "   → OPTIONAL: Run .\scripts\setup-daily-backup.ps1 to enable automated backups"
}

Write-Host "`n[$timestamp] === Logs und Dateien Check ===" -ForegroundColor White

# Logs directory
if (Test-Path "./logs") {
    Write-Success "Logs Verzeichnis existiert: ./logs"
    
    $logFiles = Get-ChildItem "./logs" -Filter "*.log" | Sort-Object LastWriteTime -Descending
    if ($logFiles) {
        Write-Info "Log-Dateien gefunden: $($logFiles.Count)"
        foreach ($logFile in $logFiles | Select-Object -First 3) {
            $size = [math]::Round($logFile.Length / 1KB, 2)
            Write-Info "   $($logFile.Name): ${size}KB (letzter Schreibvorgang: $($logFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))"
        }
        
        # Check last backup result - Enhanced analysis
        $dailyLog = "./logs/daily-backup.log"
        if (Test-Path $dailyLog) {
            $lastLines = Get-Content $dailyLog -Tail 10
            $lastSuccess = $lastLines | Where-Object { $_ -like "*SUCCESS*Backup completed*" } | Select-Object -Last 1
            $lastError = $lastLines | Where-Object { $_ -like "*ERROR*" } | Select-Object -Last 1
            
            if ($lastError -and (!$lastSuccess -or $lastError -gt $lastSuccess)) {
                Write-Problem "Letztes Backup fehlgeschlagen" "Run: .\scripts\test-manual-backup.ps1 -DryRun to diagnose" $dailyLog
                $criticalIssues++
            } elseif ($lastSuccess) {
                Write-Success "Letztes Backup erfolgreich"
            } else {
                Write-Info "Backup-Status unklar (check logs manually)"
            }
        }
    } else {
        Write-Info "Keine Log-Dateien gefunden (System noch nicht gelaufen)"
    }
} else {
    Write-Warning "Logs Verzeichnis fehlt" "Create: New-Item -ItemType Directory -Path './logs'"
    $warnings++
}

# Workflows directory
if (Test-Path "./workflows") {
    Write-Success "Workflows Verzeichnis existiert: ./workflows"
    
    $workflowFiles = Get-ChildItem "./workflows" -Filter "*.json" | Sort-Object LastWriteTime -Descending
    if ($workflowFiles) {
        Write-Info "Workflow-Backups gefunden: $($workflowFiles.Count)"
        $newest = $workflowFiles | Select-Object -First 1
        Write-Success "Neuestes Backup: $($newest.Name) ($($newest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))"
    } else {
        Write-Warning "Keine Workflow-Backups gefunden" "Run: .\scripts\export-workflow.ps1 to create first backup"
        $warnings++
    }
} else {
    Write-Problem "Workflows Verzeichnis fehlt" "Create: New-Item -ItemType Directory -Path './workflows'"
    $criticalIssues++
}

Write-Host "`n[$timestamp] === System Summary ===" -ForegroundColor White
Write-Info "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Info "Betriebssystem: $([Environment]::OSVersion.VersionString)"
Write-Info "Aktuelles Verzeichnis: $(Get-Location)"
Write-Info "Timestamp: $timestamp"

# Final Assessment
Write-Host "`n[$timestamp] === ACTIONABLE SUMMARY ===" -ForegroundColor Cyan

if ($criticalIssues -eq 0 -and $warnings -eq 0) {
    Write-Host "🎉 SYSTEM STATUS: EXCELLENT - No issues found!" -ForegroundColor Green
} elseif ($criticalIssues -eq 0) {
    Write-Host "🟡 SYSTEM STATUS: GOOD - $warnings minor warnings" -ForegroundColor Yellow
    Write-Host "   → Minor issues that don't affect core functionality" -ForegroundColor Gray
} elseif ($criticalIssues -eq 1) {
    Write-Host "🔴 SYSTEM STATUS: NEEDS ATTENTION - $criticalIssues critical issue" -ForegroundColor Red
    Write-Host "   → Fix the critical issue above for full functionality" -ForegroundColor Yellow
} else {
    Write-Host "🔴 SYSTEM STATUS: MULTIPLE ISSUES - $criticalIssues critical issues" -ForegroundColor Red
    Write-Host "   → Address critical issues above before proceeding" -ForegroundColor Yellow
}

Write-Host "`nNext recommended action:" -ForegroundColor Cyan
if ($criticalIssues -gt 0) {
    Write-Host "   1. Fix critical issues listed above" -ForegroundColor Yellow
    Write-Host "   2. Re-run this check: .\scripts\check-system-status.ps1" -ForegroundColor Yellow
} else {
    Write-Host "   → System ready for SHOULD-items from backlog!" -ForegroundColor Green
    Write-Host "   → Run: .\scripts\full-system-check.ps1 for complete overview" -ForegroundColor Green
}