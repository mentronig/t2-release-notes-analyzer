#Requires -Version 5.1
<#
.SYNOPSIS
    Export n8n T2 Release Notes Analyzer Workflow mit automatischer Versionierung und Git Integration

.DESCRIPTION
    Dieses Skript exportiert den T2 Release Notes Analyzer Workflow von einer lokalen n8n Installation,
    generiert automatisch eine neue Versionsnummer, speichert die JSON-Datei und erstellt einen Git-Commit.

.PARAMETER ApiKey
    n8n API Key fuer Authentication (optional, wird aus Umgebungsvariable N8N_API_KEY gelesen)
    Beispiel: -ApiKey "your-api-key-here"

.PARAMETER WorkflowId  
    ID des zu exportierenden Workflows (optional, Standard: yRP2Hvjq8RPNMwRx)
    Beispiel: -WorkflowId "AqGTCcrHgUGbLYSq"

.PARAMETER OutputPath
    Pfad fuer die Export-Datei (optional, Standard: ./workflows/)
    Beispiel: -OutputPath "./exports/"

.PARAMETER CommitMessage
    Custom Git Commit Message (optional, sonst wird automatische Message generiert)
    Beispiel: -CommitMessage "Fixed email formatting bug"

.PARAMETER SkipGit
    Ueberspringt alle Git-Operationen (nur Export, kein Commit/Push)
    Beispiel: -SkipGit

.EXAMPLE
    .\export-workflow.ps1
    Exportiert mit Standardeinstellungen (API Key aus Umgebungsvariable)
    
.EXAMPLE
    .\export-workflow.ps1 -ApiKey "your-api-key" -CommitMessage "Fixed email formatting"
    Exportiert mit spezifischem API Key und Custom Commit Message

.EXAMPLE
    .\export-workflow.ps1 -SkipGit
    Exportiert nur, ohne Git-Operationen

.EXAMPLE
    .\export-workflow.ps1 -OutputPath "./backups/" -WorkflowId "AnotherWorkflowId"
    Exportiert anderen Workflow in anderen Ordner

.NOTES
    Autor: T2 Release Notes Analyzer Team
    Version: 1.0
    Erfordert: PowerShell 5.1+, Git (fuer Git-Operationen), n8n lokale Installation
    
.LINK
    https://github.com/mentronig/t2-release-notes-analyzer
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = $env:N8N_API_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$WorkflowId = "yRP2Hvjq8RPNMwRx",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "./workflows",
    
    [Parameter(Mandatory=$false)]
    [string]$CommitMessage = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipGit
)

# Konfiguration
$Script:Config = @{
    N8nBaseUrl = "http://localhost:5678/api/v1"
    WorkflowName = "T2 Release Notes Analyzer"
    FileNameTemplate = "t2-analyzer-v{0}.json"
    VersionFile = "./version.txt"
    LogFile = "./logs/export-workflow.log"
}

# Logging Funktion
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARN"    { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        default   { Write-Host $logMessage -ForegroundColor White }
    }
    
    try {
        $logDir = Split-Path $Script:Config.LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $Script:Config.LogFile -Value $logMessage
    }
    catch {
        Write-Warning "Logging to file failed: $($_.Exception.Message)"
    }
}

# Voraussetzungen pruefen
function Test-Prerequisites {
    Write-Log "Ueberpruefe Voraussetzungen..."
    
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Log "API Key fehlt! Setze N8N_API_KEY Umgebungsvariable oder verwende -ApiKey Parameter" -Level "ERROR"
        return $false
    }
    
    if (-not $SkipGit) {
        try {
            git --version | Out-Null
            Write-Log "Git ist verfuegbar" -Level "SUCCESS"
        }
        catch {
            Write-Log "Git ist nicht verfuegbar oder nicht im PATH. Verwende -SkipGit zum Ueberspringen" -Level "ERROR"
            return $false
        }
    }
    
    try {
        $testUrl = "$($Script:Config.N8nBaseUrl)/workflows"
        $testResponse = Invoke-RestMethod -Uri $testUrl -Headers @{"X-N8N-API-KEY" = $ApiKey} -ErrorAction Stop
        Write-Log "n8n API ist erreichbar ($(($testResponse.data).Count) Workflows gefunden)" -Level "SUCCESS"
    }
    catch {
        Write-Log "n8n API nicht erreichbar: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    
    return $true
}

# Naechste Version generieren
function Get-NextVersion {
    $versionFile = $Script:Config.VersionFile
    
    if (Test-Path $versionFile) {
        try {
            $currentVersion = Get-Content $versionFile -Raw | ConvertFrom-Json
            $major = $currentVersion.major
            $minor = $currentVersion.minor
            $patch = $currentVersion.patch + 1
            
            Write-Log "Aktuelle Version: $major.$minor.$($currentVersion.patch)"
        }
        catch {
            Write-Log "Version-Datei beschaedigt, starte mit 1.0.0" -Level "WARN"
            $major = 1; $minor = 0; $patch = 0
        }
    }
    else {
        Write-Log "Erste Version wird erstellt: 1.0.0"
        $major = 1; $minor = 0; $patch = 0
    }
    
    $newVersion = @{
        major = $major
        minor = $minor  
        patch = $patch
        full = "$major.$minor.$patch"
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Write-Log "Neue Version: $($newVersion.full)" -Level "SUCCESS"
    return $newVersion
}

# Version speichern
function Save-Version {
    param([object]$Version)
    
    try {
        $versionDir = Split-Path $Script:Config.VersionFile -Parent
        if (-not (Test-Path $versionDir)) {
            New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
        }
        
        $Version | ConvertTo-Json -Depth 3 | Set-Content $Script:Config.VersionFile
        Write-Log "Version gespeichert: $($Version.full)"
    }
    catch {
        Write-Log "Fehler beim Speichern der Version: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Workflow exportieren
function Export-N8nWorkflow {
    param(
        [string]$WorkflowId,
        [string]$ApiKey,
        [object]$Version
    )
    
    Write-Log "Exportiere Workflow: $WorkflowId"
    
    try {
        $url = "$($Script:Config.N8nBaseUrl)/workflows/$WorkflowId"
        $workflow = Invoke-RestMethod -Uri $url -Headers @{"X-N8N-API-KEY" = $ApiKey} -ErrorAction Stop
        
        Write-Log "Workflow erfolgreich geholt: '$($workflow.name)' ($(($workflow.nodes).Count) Nodes)" -Level "SUCCESS"
        
        $exportData = @{
            exported_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            exported_by = "export-workflow.ps1"
            version = $Version.full
            n8n_version = "local-installation"
            workflow = $workflow
        }
        
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            Write-Log "Output-Verzeichnis erstellt: $OutputPath"
        }
        
        $fileName = $Script:Config.FileNameTemplate -f $Version.full
        $filePath = Join-Path $OutputPath $fileName
        
        $exportData | ConvertTo-Json -Depth 10 | Set-Content $filePath -Encoding UTF8
        
        Write-Log "Workflow exportiert: $filePath" -Level "SUCCESS"
        
        return @{
            success = $true
            filePath = $filePath
            fileName = $fileName
            nodeCount = ($workflow.nodes).Count
            workflowName = $workflow.name
        }
    }
    catch {
        Write-Log "Fehler beim Workflow-Export: $($_.Exception.Message)" -Level "ERROR"
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# Git Commit
function Invoke-GitCommit {
    param(
        [object]$ExportResult,
        [object]$Version,
        [string]$CustomMessage = ""
    )
    
    if ($SkipGit) {
        Write-Log "Git-Operationen uebersprungen (-SkipGit)" -Level "WARN"
        return $true
    }
    
    Write-Log "Starte Git-Integration..."
    
    try {
        $gitStatus = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Nicht in einem Git-Repository. Git-Operationen uebersprungen." -Level "WARN"
            return $false
        }
        
        git add $ExportResult.filePath
        git add $Script:Config.VersionFile
        
        if ([string]::IsNullOrWhiteSpace($CustomMessage)) {
            $commitMessage = "feat: Export $($ExportResult.workflowName) v$($Version.full)"
        }
        else {
            $commitMessage = $CustomMessage
        }
        
        git commit -m $commitMessage
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Git Commit erfolgreich erstellt" -Level "SUCCESS"
            
            $tagName = "v$($Version.full)"
            git tag $tagName
            Write-Log "Git Tag erstellt: $tagName" -Level "SUCCESS"
            
            Write-Log "Pushe Aenderungen zu GitHub Remote..."
            git push origin
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Git Push erfolgreich" -Level "SUCCESS"
                
                git push origin --tags
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Git Tags erfolgreich gepusht" -Level "SUCCESS"
                }
                else {
                    Write-Log "Git Tags Push fehlgeschlagen" -Level "WARN"
                }
            }
            else {
                Write-Log "Git Push fehlgeschlagen. Lokaler Commit trotzdem erstellt." -Level "WARN"
            }
            
            return $true
        }
        else {
            Write-Log "Git Commit fehlgeschlagen" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Git-Fehler: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main Funktion
function Main {
    Write-Log "=== T2 Release Notes Analyzer - Workflow Export Script ===" -Level "SUCCESS"
    Write-Log "Start: $(Get-Date)"
    
    try {
        if (-not (Test-Prerequisites)) {
            Write-Log "Voraussetzungen nicht erfuellt. Abbruch." -Level "ERROR"
            exit 1
        }
        
        $version = Get-NextVersion
        
        Write-Log "Starte Workflow-Export..."
        $exportResult = Export-N8nWorkflow -WorkflowId $WorkflowId -ApiKey $ApiKey -Version $version
        
        if (-not $exportResult.success) {
            Write-Log "Workflow-Export fehlgeschlagen: $($exportResult.error)" -Level "ERROR"
            exit 1
        }
        
        Save-Version $version
        
        $gitSuccess = Invoke-GitCommit -ExportResult $exportResult -Version $version -CustomMessage $CommitMessage
        
        Write-Log "=== EXPORT ERFOLGREICH ===" -Level "SUCCESS"
        Write-Log "Workflow: $($exportResult.workflowName)"
        Write-Log "Version: $($version.full)"  
        Write-Log "Datei: $($exportResult.filePath)"
        Write-Log "Nodes: $($exportResult.nodeCount)"
        Write-Log "Git Commit: $(if ($gitSuccess) { 'Ja' } else { 'Nein' })"
        Write-Log "GitHub Push: $(if ($gitSuccess -and -not $SkipGit) { 'Ja' } else { 'Nein' })"
        Write-Log "Abgeschlossen: $(Get-Date)"
        
        exit 0
    }
    catch {
        Write-Log "Unerwarteter Fehler: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

# Script ausfuehren
Main