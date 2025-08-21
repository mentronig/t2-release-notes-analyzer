#Requires -Version 5.1
<#
.SYNOPSIS
    Umfassender System-Status Check für T2 Release Notes Analyzer

.DESCRIPTION
    Überprüft alle wichtigen Komponenten des automatischen Backup-Systems:
    - n8n API Erreichbarkeit
    - Git Repository Status
    - Task Scheduler Status
    - GitHub Connectivity
    - Logs und Dateien

.PARAMETER Verbose
    Zeigt detaillierte Ausgaben für alle Checks

.PARAMETER CheckGitHub
    Führt auch GitHub-spezifische Tests durch

.EXAMPLE
    .\check-system-status.ps1
    Führt alle Standard-Checks durch
    
.EXAMPLE
    .\check-system-status.ps1 -Verbose -CheckGitHub
    Detaillierte Ausgabe mit GitHub-Tests
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$CheckGitHub
)

# Konfiguration
$Script:Config = @{
    N8nBaseUrl = "http://localhost:5678/api/v1"
    WorkflowId = "yRP2Hvjq8RPNMwRx"
    TaskName = "T2-Daily-Backup"
    TaskPath = "\T2-Release-Notes-Analyzer\"
    LogsPath = "./logs"
    WorkflowsPath = "./workflows"
}

# Logging Funktion
function Write-StatusLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "HEADER")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    switch ($Level) {
        "HEADER"  { Write-Host "[$timestamp] === $Message ===" -ForegroundColor Cyan }
        "SUCCESS" { Write-Host "[$timestamp] ✅ $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[$timestamp] ⚠️  $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[$timestamp] ❌ $Message" -ForegroundColor Red }
        default   { Write-Host "[$timestamp] ℹ️  $Message" -ForegroundColor White }
    }
}

# n8n API Check
function Test-N8nAPI {
    Write-StatusLog "n8n API Status Check" -Level "HEADER"
    
    try {
        # Prüfe ob n8n läuft
        $response = Invoke-WebRequest -Uri "http://localhost:5678" -Method GET -TimeoutSec 5 -ErrorAction Stop
        Write-StatusLog "n8n Web Interface erreichbar (Port 5678)" -Level "SUCCESS"
    }
    catch {
        Write-StatusLog "n8n Web Interface NICHT erreichbar: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    
    # API Key prüfen
    $apiKey = $env:N8N_API_KEY
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-StatusLog "N8N_API_KEY Umgebungsvariable NICHT gesetzt" -Level "ERROR"
        return $false
    }
    
    try {
        $testUrl = "$($Script:Config.N8nBaseUrl)/workflows"
        $testHeaders = @{"X-N8N-API-KEY" = $apiKey}
        $workflows = Invoke-RestMethod -Uri $testUrl -Headers $testHeaders -ErrorAction Stop
        
        Write-StatusLog "n8n API erfolgreich authentifiziert" -Level "SUCCESS"
        Write-StatusLog "Gefundene Workflows: $($workflows.data.Count)" -Level "INFO"
        
        # Teste spezifischen Workflow
        $targetWorkflow = $workflows.data | Where-Object {$_.id -eq $Script:Config.WorkflowId}
        if ($targetWorkflow) {
            Write-StatusLog "Target Workflow gefunden: '$($targetWorkflow.name)' ($(if($targetWorkflow.active){'AKTIV'}else{'INAKTIV'}))" -Level "SUCCESS"
        } else {
            Write-StatusLog "Target Workflow ID '$($Script:Config.WorkflowId)' NICHT gefunden" -Level "ERROR"
        }
        
        return $true
    }
    catch {
        Write-StatusLog "n8n API Test fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Git Repository Check
function Test-GitRepository {
    Write-StatusLog "Git Repository Status Check" -Level "HEADER"
    
    # Git Verfügbarkeit
    try {
        $gitVersion = git --version
        Write-StatusLog "Git verfügbar: $gitVersion" -Level "SUCCESS"
    }
    catch {
        Write-StatusLog "Git NICHT verfügbar oder nicht im PATH" -Level "ERROR"
        return $false
    }
    
    # Repository Status
    try {
        $gitStatus = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-StatusLog "NICHT in einem Git Repository" -Level "ERROR"
            return $false
        }
        
        Write-StatusLog "Git Repository erkannt" -Level "SUCCESS"
        
        # Branch Info
        $currentBranch = git branch --show-current
        Write-StatusLog "Aktueller Branch: $currentBranch" -Level "INFO"
        
        # Pending Changes
        $statusLines = git status --porcelain
        if ($statusLines) {
            Write-StatusLog "Uncommitted Changes: $($statusLines.Count) Dateien" -Level "WARN"
            if ($VerbosePreference -eq "Continue") {
                $statusLines | ForEach-Object { Write-StatusLog "  $_" -Level "INFO" }
            }
        } else {
            Write-StatusLog "Working Directory sauber (keine uncommitted changes)" -Level "SUCCESS"
        }
        
        # Remote Status
        $remoteBehind = git rev-list --count HEAD..origin/main 2>$null
        $remoteAhead = git rev-list --count origin/main..HEAD 2>$null
        
        if ($remoteBehind -gt 0) {
            Write-StatusLog "Branch ist $remoteBehind Commits hinter origin/main" -Level "WARN"
        }
        if ($remoteAhead -gt 0) {
            Write-StatusLog "Branch ist $remoteAhead Commits vor origin/main (Push erforderlich)" -Level "WARN"
        }
        if ($remoteBehind -eq 0 -and $remoteAhead -eq 0) {
            Write-StatusLog "Branch ist synchron mit origin/main" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-StatusLog "Git Status Check fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Task Scheduler Check
function Test-TaskScheduler {
    Write-StatusLog "Task Scheduler Status Check" -Level "HEADER"
    
    try {
        $task = Get-ScheduledTask -TaskPath $Script:Config.TaskPath -TaskName $Script:Config.TaskName -ErrorAction Stop
        Write-StatusLog "Task gefunden: $($Script:Config.TaskName)" -Level "SUCCESS"
        Write-StatusLog "Task Status: $($task.State)" -Level "INFO"
        
        $taskInfo = Get-ScheduledTaskInfo -TaskPath $Script:Config.TaskPath -TaskName $Script:Config.TaskName
        Write-StatusLog "Letzter Lauf: $($taskInfo.LastRunTime)" -Level "INFO"
        Write-StatusLog "Letztes Ergebnis: $($taskInfo.LastTaskResult)" -Level $(if($taskInfo.LastTaskResult -eq 0){"SUCCESS"}else{"WARN"})
        Write-StatusLog "Nächster Lauf: $($taskInfo.NextRunTime)" -Level "INFO"
        
        # Task Trigger Info
        $triggers = $task.Triggers
        foreach ($trigger in $triggers) {
            if ($trigger.CimClass.CimClassName -eq "MSFT_TaskDailyTrigger") {
                $startTime = [DateTime]::Parse($trigger.StartBoundary).ToString("HH:mm")
                Write-StatusLog "Täglicher Trigger um: $startTime" -Level "INFO"
            }
        }
        
        return $true
    }
    catch {
        Write-StatusLog "Task '$($Script:Config.TaskName)' NICHT gefunden oder Fehler: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Logs Check
function Test-LogsAndFiles {
    Write-StatusLog "Logs und Dateien Check" -Level "HEADER"
    
    # Logs Verzeichnis
    if (Test-Path $Script:Config.LogsPath) {
        Write-StatusLog "Logs Verzeichnis existiert: $($Script:Config.LogsPath)" -Level "SUCCESS"
        
        $logFiles = Get-ChildItem $Script:Config.LogsPath -Filter "*.log"
        Write-StatusLog "Log-Dateien gefunden: $($logFiles.Count)" -Level "INFO"
        
        foreach ($logFile in $logFiles) {
            $size = [math]::Round($logFile.Length / 1KB, 2)
            $lastWrite = $logFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Write-StatusLog "  $($logFile.Name): ${size}KB (letzter Schreibvorgang: $lastWrite)" -Level "INFO"
        }
        
        # Letzte Log-Einträge prüfen
        $dailyBackupLog = Join-Path $Script:Config.LogsPath "daily-backup.log"
        if (Test-Path $dailyBackupLog) {
            $lastEntries = Get-Content $dailyBackupLog -Tail 3
            if ($lastEntries -match "Daily backup completed successfully") {
                Write-StatusLog "Letztes Backup war erfolgreich" -Level "SUCCESS"
            } elseif ($lastEntries -match "Daily backup failed") {
                Write-StatusLog "Letztes Backup ist fehlgeschlagen" -Level "WARN"
            }
        }
    } else {
        Write-StatusLog "Logs Verzeichnis existiert NICHT: $($Script:Config.LogsPath)" -Level "ERROR"
    }
    
    # Workflows Verzeichnis
    if (Test-Path $Script:Config.WorkflowsPath) {
        Write-StatusLog "Workflows Verzeichnis existiert: $($Script:Config.WorkflowsPath)" -Level "SUCCESS"
        
        $workflowFiles = Get-ChildItem $Script:Config.WorkflowsPath -Filter "t2-analyzer-v*.json"
        Write-StatusLog "Workflow-Backups gefunden: $($workflowFiles.Count)" -Level "INFO"
        
        if ($workflowFiles.Count -gt 0) {
            $latest = $workflowFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $latestTime = $latest.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Write-StatusLog "Neuestes Backup: $($latest.Name) ($latestTime)" -Level "SUCCESS"
        }
    } else {
        Write-StatusLog "Workflows Verzeichnis existiert NICHT: $($Script:Config.WorkflowsPath)" -Level "ERROR"
    }
}

# GitHub Connectivity Check
function Test-GitHubConnectivity {
    if (-not $CheckGitHub) { return $true }
    
    Write-StatusLog "GitHub Connectivity Check" -Level "HEADER"
    
    try {
        # GitHub erreichbar?
        $githubTest = Invoke-WebRequest -Uri "https://github.com" -Method HEAD -TimeoutSec 10 -ErrorAction Stop
        Write-StatusLog "GitHub.com erreichbar" -Level "SUCCESS"
    }
    catch {
        Write-StatusLog "GitHub.com NICHT erreichbar: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    
    # Git Remote Check
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($remoteUrl) {
            Write-StatusLog "Git Remote URL: $($remoteUrl -replace 'ghp_[^@]*@', 'ghp_***@')" -Level "INFO"
            
            if ($remoteUrl -match "ghp_") {
                Write-StatusLog "GitHub Token in Remote URL erkannt" -Level "SUCCESS"
            } elseif ($remoteUrl -match "git@github.com") {
                Write-StatusLog "SSH Authentication erkannt" -Level "INFO"
            } else {
                Write-StatusLog "Unbekannte Authentication-Methode" -Level "WARN"
            }
        } else {
            Write-StatusLog "Keine Git Remote URL gefunden" -Level "ERROR"
        }
    }
    catch {
        Write-StatusLog "Git Remote Check fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
    }
    
    # Test Git Push (dry-run)
    try {
        Write-StatusLog "Teste GitHub Push-Berechtigung (dry-run)..." -Level "INFO"
        $pushTest = git push --dry-run origin 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-StatusLog "GitHub Push-Test erfolgreich" -Level "SUCCESS"
        } else {
            Write-StatusLog "GitHub Push-Test fehlgeschlagen: $pushTest" -Level "WARN"
        }
    }
    catch {
        Write-StatusLog "GitHub Push-Test Fehler: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $true
}

# System Summary
function Show-SystemSummary {
    Write-StatusLog "System Summary" -Level "HEADER"
    
    Write-StatusLog "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
    Write-StatusLog "Betriebssystem: $($PSVersionTable.OS)" -Level "INFO"
    Write-StatusLog "Aktuelles Verzeichnis: $(Get-Location)" -Level "INFO"
    Write-StatusLog "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
}

# Main Execution
function Main {
    Write-Host ""
    Write-StatusLog "T2 Release Notes Analyzer - System Status Check" -Level "HEADER"
    Write-Host ""
    
    $allChecksOK = $true
    
    # Führe alle Checks durch
    $allChecksOK = (Test-N8nAPI) -and $allChecksOK
    Write-Host ""
    
    $allChecksOK = (Test-GitRepository) -and $allChecksOK
    Write-Host ""
    
    $allChecksOK = (Test-TaskScheduler) -and $allChecksOK
    Write-Host ""
    
    Test-LogsAndFiles
    Write-Host ""
    
    $allChecksOK = (Test-GitHubConnectivity) -and $allChecksOK
    Write-Host ""
    
    Show-SystemSummary
    Write-Host ""
    
    # Finale Bewertung
    if ($allChecksOK) {
        Write-StatusLog "🎉 ALLE SYSTEM-CHECKS ERFOLGREICH!" -Level "SUCCESS"
        Write-StatusLog "Das automatische Backup-System ist voll funktionsfähig." -Level "SUCCESS"
    } else {
        Write-StatusLog "⚠️ EINIGE SYSTEM-CHECKS FEHLGESCHLAGEN!" -Level "WARN"
        Write-StatusLog "Prüfe die obigen Fehler und führe entsprechende Korrekturen durch." -Level "WARN"
    }
    
    Write-Host ""
}

# Script ausführen
Main