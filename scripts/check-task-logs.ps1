#Requires -Version 5.1
<#
.SYNOPSIS
    Detaillierte Analyse der T2 Daily Backup Task Logs

.DESCRIPTION
    Analysiert alle Log-Dateien des automatischen Backup-Systems und bietet
    verschiedene Ansichten für Debugging, Monitoring und Troubleshooting.

.PARAMETER Hours
    Anzahl Stunden rückblickend zu analysieren (Standard: 24)

.PARAMETER LogType
    Spezifischer Log-Typ zur Analyse
    - All: Alle Logs (Standard)
    - Daily: Nur daily-backup.log
    - Export: Nur export-workflow.log  
    - Setup: Nur setup-daily-backup.log

.PARAMETER ShowErrors
    Zeigt nur Fehler und Warnungen

.PARAMETER ShowStats
    Zeigt Log-Statistiken und Zusammenfassung

.PARAMETER ExportReport
    Exportiert Analyse als HTML-Report

.EXAMPLE
    .\check-task-logs.ps1
    Zeigt alle Logs der letzten 24 Stunden
    
.EXAMPLE
    .\check-task-logs.ps1 -Hours 72 -ShowErrors
    Zeigt nur Fehler der letzten 3 Tage

.EXAMPLE
    .\check-task-logs.ps1 -LogType Daily -ShowStats
    Analysiert nur Daily-Backup-Logs mit Statistiken

.EXAMPLE
    .\check-task-logs.ps1 -ExportReport
    Erstellt HTML-Report der Log-Analyse
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$Hours = 24,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "Daily", "Export", "Setup")]
    [string]$LogType = "All",
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowErrors,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowStats,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportReport
)

# Konfiguration
$Script:Config = @{
    LogsPath = "./logs"
    LogFiles = @{
        Daily = "daily-backup.log"
        Export = "export-workflow.log"
        Setup = "setup-daily-backup.log"
    }
    TimeWindow = (Get-Date).AddHours(-$Hours)
    ReportPath = "./reports"
}

# Log-Einträge Klasse
class LogEntry {
    [DateTime]$Timestamp
    [string]$Level
    [string]$Message
    [string]$Source
    [string]$OriginalLine
    
    LogEntry([string]$line, [string]$source) {
        $this.OriginalLine = $line
        $this.Source = $source
        
        # Parse: [2025-08-21 18:46:29] [SUCCESS] Message
        if ($line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] \[(\w+)\] (.*)$') {
            $this.Timestamp = [DateTime]::Parse($matches[1])
            $this.Level = $matches[2]
            $this.Message = $matches[3]
        } else {
            $this.Timestamp = Get-Date
            $this.Level = "INFO"
            $this.Message = $line
        }
    }
}

# Logging Funktion
function Write-LogAnalysis {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "HEADER", "STAT")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    switch ($Level) {
        "HEADER"  { Write-Host "[$timestamp] === $Message ===" -ForegroundColor Cyan }
        "STAT"    { Write-Host "[$timestamp] 📊 $Message" -ForegroundColor Magenta }
        "SUCCESS" { Write-Host "[$timestamp] ✅ $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[$timestamp] ⚠️  $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[$timestamp] ❌ $Message" -ForegroundColor Red }
        default   { Write-Host "[$timestamp] ℹ️  $Message" -ForegroundColor White }
    }
}

# Log-Dateien sammeln
function Get-LogFiles {
    Write-LogAnalysis "Log-Dateien sammeln und analysieren" -Level "HEADER"
    
    $logFiles = @()
    
    if (-not (Test-Path $Script:Config.LogsPath)) {
        Write-LogAnalysis "Logs-Verzeichnis nicht gefunden: $($Script:Config.LogsPath)" -Level "ERROR"
        return $logFiles
    }
    
    foreach ($logName in $Script:Config.LogFiles.Keys) {
        if ($LogType -eq "All" -or $LogType -eq $logName) {
            $logPath = Join-Path $Script:Config.LogsPath $Script:Config.LogFiles[$logName]
            
            if (Test-Path $logPath) {
                $fileInfo = Get-Item $logPath
                $size = [math]::Round($fileInfo.Length / 1KB, 2)
                $lastWrite = $fileInfo.LastWriteTime
                
                Write-LogAnalysis "✅ $logName Log: $($Script:Config.LogFiles[$logName]) (${size}KB, $($lastWrite.ToString('yyyy-MM-dd HH:mm')))"
                
                $logFiles += @{
                    Name = $logName
                    Path = $logPath
                    Size = $size
                    LastWrite = $lastWrite
                }
            } else {
                Write-LogAnalysis "❌ $logName Log nicht gefunden: $($Script:Config.LogFiles[$logName])" -Level "WARN"
            }
        }
    }
    
    return $logFiles
}

# Log-Einträge parsen
function Parse-LogEntries {
    param([array]$LogFiles)
    
    Write-LogAnalysis "Log-Einträge parsen (seit $($Script:Config.TimeWindow.ToString('yyyy-MM-dd HH:mm')))" -Level "HEADER"
    
    $allEntries = @()
    
    foreach ($logFile in $LogFiles) {
        Write-LogAnalysis "Parse $($logFile.Name) Log..."
        
        try {
            $lines = Get-Content $logFile.Path -ErrorAction Stop
            $entries = @()
            
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $entry = [LogEntry]::new($line, $logFile.Name)
                    
                    # Nur Einträge im Zeitfenster
                    if ($entry.Timestamp -ge $Script:Config.TimeWindow) {
                        $entries += $entry
                    }
                }
            }
            
            Write-LogAnalysis "  $($entries.Count) Einträge im Zeitfenster gefunden"
            $allEntries += $entries
        }
        catch {
            Write-LogAnalysis "Fehler beim Lesen von $($logFile.Name): $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    # Nach Timestamp sortieren
    $sortedEntries = $allEntries | Sort-Object Timestamp
    Write-LogAnalysis "Gesamt: $($sortedEntries.Count) Log-Einträge analysiert" -Level "SUCCESS"
    
    return $sortedEntries
}

# Log-Statistiken generieren
function Get-LogStatistics {
    param([array]$Entries)
    
    Write-LogAnalysis "Log-Statistiken" -Level "HEADER"
    
    # Level-Verteilung
    $levelStats = $Entries | Group-Object Level | Sort-Object Name
    Write-LogAnalysis "Log-Level Verteilung:" -Level "STAT"
    foreach ($level in $levelStats) {
        $color = switch ($level.Name) {
            "SUCCESS" { "Green" }
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            default { "White" }
        }
        Write-Host "  $($level.Name): $($level.Count)" -ForegroundColor $color
    }
    
    # Source-Verteilung
    $sourceStats = $Entries | Group-Object Source | Sort-Object Name
    Write-LogAnalysis "Log-Quellen Verteilung:" -Level "STAT"
    foreach ($source in $sourceStats) {
        Write-Host "  $($source.Name): $($source.Count)" -ForegroundColor Cyan
    }
    
    # Zeitliche Verteilung (letzte 24h in 6h Blöcken)
    Write-LogAnalysis "Zeitliche Aktivität (6-Stunden-Blöcke):" -Level "STAT"
    $now = Get-Date
    for ($i = 0; $i -lt 4; $i++) {
        $blockStart = $now.AddHours(-6 * ($i + 1))
        $blockEnd = $now.AddHours(-6 * $i)
        $blockEntries = $Entries | Where-Object { $_.Timestamp -ge $blockStart -and $_.Timestamp -lt $blockEnd }
        Write-Host "  $($blockStart.ToString('HH:mm'))-$($blockEnd.ToString('HH:mm')): $($blockEntries.Count) Einträge" -ForegroundColor Blue
    }
    
    # Backup-Erfolg Analyse
    $successfulBackups = $Entries | Where-Object { $_.Message -like "*Daily backup completed successfully*" }
    $failedBackups = $Entries | Where-Object { $_.Message -like "*Daily backup failed*" }
    
    Write-LogAnalysis "Backup-Erfolgsrate:" -Level "STAT"
    Write-Host "  Erfolgreich: $($successfulBackups.Count)" -ForegroundColor Green
    Write-Host "  Fehlgeschlagen: $($failedBackups.Count)" -ForegroundColor Red
    
    if ($successfulBackups.Count -gt 0) {
        $latestSuccess = $successfulBackups | Sort-Object Timestamp -Descending | Select-Object -First 1
        Write-Host "  Letzter Erfolg: $($latestSuccess.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
    }
    
    return @{
        TotalEntries = $Entries.Count
        SuccessfulBackups = $successfulBackups.Count
        FailedBackups = $failedBackups.Count
        ErrorCount = ($Entries | Where-Object { $_.Level -eq "ERROR" }).Count
        WarningCount = ($Entries | Where-Object { $_.Level -eq "WARN" }).Count
        LatestSuccess = if($successfulBackups.Count -gt 0) { ($successfulBackups | Sort-Object Timestamp -Descending | Select-Object -First 1).Timestamp } else { $null }
    }
}

# Fehler und Warnungen anzeigen
function Show-ErrorsAndWarnings {
    param([array]$Entries)
    
    $errors = $Entries | Where-Object { $_.Level -eq "ERROR" }
    $warnings = $Entries | Where-Object { $_.Level -eq "WARN" }
    
    if ($errors.Count -gt 0 -or $warnings.Count -gt 0) {
        Write-LogAnalysis "Fehler und Warnungen" -Level "HEADER"
        
        if ($errors.Count -gt 0) {
            Write-LogAnalysis "🔴 FEHLER ($($errors.Count)):" -Level "ERROR"
            foreach ($error in $errors) {
                Write-Host "  [$($error.Timestamp.ToString('MM-dd HH:mm'))] [$($error.Source)] $($error.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        if ($warnings.Count -gt 0) {
            Write-LogAnalysis "🟡 WARNUNGEN ($($warnings.Count)):" -Level "WARN"
            foreach ($warning in $warnings) {
                Write-Host "  [$($warning.Timestamp.ToString('MM-dd HH:mm'))] [$($warning.Source)] $($warning.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-LogAnalysis "✅ Keine Fehler oder Warnungen im Zeitfenster gefunden!" -Level "SUCCESS"
    }
}

# Backup-Verlauf anzeigen
function Show-BackupHistory {
    param([array]$Entries)
    
    Write-LogAnalysis "Backup-Verlauf" -Level "HEADER"
    
    # Backup-Sessions finden
    $backupStarts = $Entries | Where-Object { $_.Message -like "*T2 Daily Backup Started*" }
    $backupEnds = $Entries | Where-Object { $_.Message -like "*T2 Daily Backup Finished*" }
    
    Write-LogAnalysis "Backup-Sessions im Zeitfenster: $($backupStarts.Count)"
    
    foreach ($start in $backupStarts | Sort-Object Timestamp -Descending | Select-Object -First 5) {
        $sessionEnd = $backupEnds | Where-Object { $_.Timestamp -gt $start.Timestamp } | Sort-Object Timestamp | Select-Object -First 1
        
        Write-Host ""
        Write-Host "🔄 Backup Session: $($start.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Blue
        
        if ($sessionEnd) {
            $duration = ($sessionEnd.Timestamp - $start.Timestamp).TotalSeconds
            Write-Host "   Dauer: $duration Sekunden" -ForegroundColor Gray
            
            # Session-Ereignisse
            $sessionEvents = $Entries | Where-Object { 
                $_.Timestamp -ge $start.Timestamp -and 
                $_.Timestamp -le $sessionEnd.Timestamp 
            } | Sort-Object Timestamp
            
            foreach ($event in $sessionEvents) {
                $color = switch ($event.Level) {
                    "SUCCESS" { "Green" }
                    "ERROR" { "Red" }
                    "WARN" { "Yellow" }
                    default { "Gray" }
                }
                Write-Host "   [$($event.Level)] $($event.Message)" -ForegroundColor $color
            }
        } else {
            Write-Host "   Status: Laufend oder unvollständig" -ForegroundColor Yellow
        }
    }
}

# System-Zusammenfassung anzeigen
function Show-SystemSummary {
    param([object]$Stats)
    
    Write-LogAnalysis "System-Zusammenfassung" -Level "HEADER"
    
    # Gesamtstatus ermitteln
    $isHealthy = $Stats.ErrorCount -eq 0 -and $Stats.FailedBackups -eq 0
    $hasIssues = $Stats.ErrorCount -gt 0 -or $Stats.FailedBackups -gt 0
    $hasWarnings = $Stats.WarningCount -gt 0
    
    # Status-Icon und Gesamtbewertung
    if ($isHealthy) {
        Write-Host "🟢 SYSTEM STATUS: AUSGEZEICHNET" -ForegroundColor Green
        Write-Host "   Das automatische Backup-System läuft perfekt!" -ForegroundColor Green
    } elseif ($hasIssues -and $Stats.LatestSuccess) {
        Write-Host "🟡 SYSTEM STATUS: PROBLEME BEHOBEN" -ForegroundColor Yellow  
        Write-Host "   Frühere Probleme wurden erfolgreich gelöst!" -ForegroundColor Yellow
    } elseif ($hasIssues) {
        Write-Host "🔴 SYSTEM STATUS: PROBLEME ERKANNT" -ForegroundColor Red
        Write-Host "   Das System benötigt Aufmerksamkeit!" -ForegroundColor Red
    } else {
        Write-Host "🔵 SYSTEM STATUS: STABIL" -ForegroundColor Blue
        Write-Host "   System läuft mit kleineren Warnungen." -ForegroundColor Blue
    }
    
    Write-Host ""
    
    # Kernmetriken
    Write-Host "📊 KERNMETRIKEN (Letzte $Hours Stunden):" -ForegroundColor Cyan
    Write-Host "   Log-Einträge analysiert: $($Stats.TotalEntries)" -ForegroundColor White
    Write-Host "   Erfolgreiche Backups: $($Stats.SuccessfulBackups)" -ForegroundColor Green
    Write-Host "   Fehlgeschlagene Backups: $($Stats.FailedBackups)" -ForegroundColor $(if($Stats.FailedBackups -gt 0){"Red"}else{"Green"})
    Write-Host "   Fehler: $($Stats.ErrorCount)" -ForegroundColor $(if($Stats.ErrorCount -gt 0){"Red"}else{"Green"})
    Write-Host "   Warnungen: $($Stats.WarningCount)" -ForegroundColor $(if($Stats.WarningCount -gt 0){"Yellow"}else{"Green"})
    
    Write-Host ""
    
    # Zeitstempel
    if ($Stats.LatestSuccess) {
        $timeSinceSuccess = (Get-Date) - $Stats.LatestSuccess
        if ($timeSinceSuccess.TotalHours -lt 24) {
            Write-Host "⏱️  LETZTER ERFOLG: $($Stats.LatestSuccess.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
            Write-Host "   Vor $([math]::Round($timeSinceSuccess.TotalHours, 1)) Stunden" -ForegroundColor Green
        } else {
            Write-Host "⏱️  LETZTER ERFOLG: $($Stats.LatestSuccess.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
            Write-Host "   Vor $([math]::Round($timeSinceSuccess.TotalDays, 1)) Tagen" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  KEIN ERFOLGREICHER BACKUP IM ZEITFENSTER" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Empfehlungen basierend auf Status
    Write-Host "💡 EMPFEHLUNGEN:" -ForegroundColor Magenta
    
    if ($isHealthy) {
        Write-Host "   ✅ System läuft optimal - keine Aktion erforderlich" -ForegroundColor Green
        Write-Host "   ✅ Tägliche Backups funktionieren einwandfrei" -ForegroundColor Green
        Write-Host "   ✅ Fortsetzung des aktuellen Monitoring-Rhythmus" -ForegroundColor Green
    } elseif ($Stats.LatestSuccess -and $Stats.ErrorCount -gt 0) {
        Write-Host "   🔄 Probleme wurden behoben - Monitor für weitere 24h" -ForegroundColor Yellow
        Write-Host "   📊 Führe morgen erneut Analyse durch zur Bestätigung" -ForegroundColor Yellow
    } elseif ($Stats.FailedBackups -gt 0) {
        Write-Host "   🚨 Führe fix-git-credentials.ps1 aus zur Problembehebung" -ForegroundColor Red
        Write-Host "   🔧 Prüfe n8n API und GitHub-Token Status" -ForegroundColor Red
        Write-Host "   📋 Verwende test-manual-backup.ps1 für detailliertes Debugging" -ForegroundColor Red
    } elseif ($Stats.WarningCount -gt 0) {
        Write-Host "   👀 Überwache Warnungen - meist unkritisch aber beobachten" -ForegroundColor Yellow
        Write-Host "   📈 System-Performance ist gut trotz kleinerer Warnungen" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Support-Tools Hinweise
    Write-Host "🛠️  VERFÜGBARE SUPPORT-TOOLS:" -ForegroundColor Blue
    Write-Host "   check-system-status.ps1  - Vollständiger System-Check" -ForegroundColor Gray
    Write-Host "   test-manual-backup.ps1   - Manueller Backup-Test" -ForegroundColor Gray
    Write-Host "   fix-git-credentials.ps1  - Git/GitHub-Probleme beheben" -ForegroundColor Gray
    Write-Host "   check-task-logs.ps1 -ExportReport - HTML-Report generieren" -ForegroundColor Gray
}
function Export-HTMLReport {
    param([array]$Entries, [array]$LogFiles)
    
    Write-LogAnalysis "HTML-Report generieren" -Level "HEADER"
    
    if (-not (Test-Path $Script:Config.ReportPath)) {
        New-Item -ItemType Directory -Path $Script:Config.ReportPath -Force | Out-Null
    }
    
    $reportFile = Join-Path $Script:Config.ReportPath "log-analysis-$(Get-Date -Format 'yyyy-MM-dd-HHmm').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>T2 Backup Log Analysis - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { color: #2563eb; border-bottom: 2px solid #2563eb; padding-bottom: 10px; }
        .success { color: #16a34a; }
        .error { color: #dc2626; }
        .warning { color: #ea580c; }
        .info { color: #6b7280; }
        .stat { background-color: #f3f4f6; padding: 10px; margin: 10px 0; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #d1d5db; padding: 8px; text-align: left; }
        th { background-color: #f9fafb; }
        .log-entry { margin: 5px 0; padding: 5px; border-left: 3px solid #d1d5db; }
    </style>
</head>
<body>
    <h1 class="header">T2 Release Notes Analyzer - Log Analysis</h1>
    <div class="stat">
        <strong>Analyse-Zeitraum:</strong> $($Script:Config.TimeWindow.ToString('yyyy-MM-dd HH:mm')) bis $(Get-Date -Format 'yyyy-MM-dd HH:mm')<br>
        <strong>Generiert:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')<br>
        <strong>Analysierte Einträge:</strong> $($Entries.Count)
    </div>
    
    <h2>Log-Dateien Übersicht</h2>
    <table>
        <tr><th>Log-Typ</th><th>Datei</th><th>Größe (KB)</th><th>Letzte Änderung</th></tr>
"@

    foreach ($logFile in $LogFiles) {
        $html += "<tr><td>$($logFile.Name)</td><td>$($logFile.Path)</td><td>$($logFile.Size)</td><td>$($logFile.LastWrite.ToString('yyyy-MM-dd HH:mm'))</td></tr>"
    }

    $html += @"
    </table>
    
    <h2>Log-Level Statistiken</h2>
    <div class="stat">
"@

    $levelStats = $Entries | Group-Object Level
    foreach ($level in $levelStats) {
        $cssClass = switch ($level.Name) {
            "SUCCESS" { "success" }
            "ERROR" { "error" }
            "WARN" { "warning" }
            default { "info" }
        }
        $html += "<span class='$cssClass'><strong>$($level.Name):</strong> $($level.Count)</span> | "
    }

    $html += @"
    </div>
    
    <h2>Letzte Log-Einträge</h2>
"@

    $recentEntries = $Entries | Sort-Object Timestamp -Descending | Select-Object -First 50
    foreach ($entry in $recentEntries) {
        $cssClass = switch ($entry.Level) {
            "SUCCESS" { "success" }
            "ERROR" { "error" }
            "WARN" { "warning" }
            default { "info" }
        }
        $html += "<div class='log-entry'><span class='$cssClass'>[$($entry.Timestamp.ToString('MM-dd HH:mm'))] [$($entry.Level)] [$($entry.Source)]</span> $($entry.Message)</div>"
    }

    $html += @"
</body>
</html>
"@

    try {
        $html | Set-Content $reportFile -Encoding UTF8
        Write-LogAnalysis "HTML-Report erstellt: $reportFile" -Level "SUCCESS"
        return $reportFile
    }
    catch {
        Write-LogAnalysis "Fehler beim Erstellen des HTML-Reports: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Main Execution
function Main {
    Write-Host ""
    Write-LogAnalysis "T2 Release Notes Analyzer - Log-Analyse" -Level "HEADER"
    Write-LogAnalysis "Zeitraum: Letzte $Hours Stunden | Log-Typ: $LogType" -Level "INFO"
    Write-Host ""
    
    # 1. Log-Dateien sammeln
    $logFiles = Get-LogFiles
    if ($logFiles.Count -eq 0) {
        Write-LogAnalysis "Keine Log-Dateien gefunden!" -Level "ERROR"
        exit 1
    }
    Write-Host ""
    
    # 2. Log-Einträge parsen
    $entries = Parse-LogEntries -LogFiles $logFiles
    if ($entries.Count -eq 0) {
        Write-LogAnalysis "Keine Log-Einträge im Zeitfenster gefunden!" -Level "WARN"
        exit 0
    }
    Write-Host ""
    
    # 3. Statistiken (wenn gewünscht oder Standard)
    $stats = $null
    if ($ShowStats -or (-not $ShowErrors)) {
        $stats = Get-LogStatistics -Entries $entries
        Write-Host ""
    }
    
    # 4. Fehler und Warnungen
    if ($ShowErrors -or (-not $ShowStats)) {
        Show-ErrorsAndWarnings -Entries $entries
        Write-Host ""
    }
    
    # 5. Backup-Verlauf (nur wenn nicht nur Fehler angezeigt werden)
    if (-not $ShowErrors) {
        Show-BackupHistory -Entries $entries
        Write-Host ""
    }
    
    # 6. HTML-Report (wenn gewünscht)
    if ($ExportReport) {
        $reportFile = Export-HTMLReport -Entries $entries -LogFiles $logFiles
        if ($reportFile) {
            Write-LogAnalysis "Report verfügbar: $reportFile"
        }
        Write-Host ""
    }
    
    # 7. System-Zusammenfassung (nur wenn Statistiken verfügbar)
    if ($stats) {
        Show-SystemSummary -Stats $stats
        Write-Host ""
    }
    
    Write-LogAnalysis "Log-Analyse abgeschlossen" -Level "SUCCESS"
}

# Script ausführen
Main