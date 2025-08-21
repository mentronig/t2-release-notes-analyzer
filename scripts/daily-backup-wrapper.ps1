# T2 Daily Backup Wrapper Script - Complete Version
$ErrorActionPreference = "Continue"
$logFile = "C:\Users\Roland\source\repos\t2-release-notes-analyzer\logs\daily-backup.log"

function Write-TaskLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

Write-TaskLog "=== T2 Daily Backup Started ===" -Level "INFO"
Write-TaskLog "Triggered by: Windows Task Scheduler"

try {
    # Setup
    $workingDir = "C:\Users\Roland\source\repos\t2-release-notes-analyzer"
    $apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxZTcyNzkzNC03YjYzLTRlZTItODY4My00MDk3MWEwODM1ZjkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzU1NzgxMjY0LCJleHAiOjE3OTA3MTkyMDB9.Om1zEUU6itZ36UiEHvYpwfzakMERZsYmSqY-EQP8aP4"
    $workflowId = "yRP2Hvjq8RPNMwRx"
    
    Set-Location $workingDir
    Write-TaskLog "Working Directory: $workingDir"
    
    # Git Safe Directory Fix
    Write-TaskLog "Git configured for SYSTEM account"
    git config --global --add safe.directory $workingDir.Replace('\','/') 2>&1 | Out-Null
    
    # Git User Identity für SYSTEM Account
    Write-TaskLog "Setting Git user identity for SYSTEM account..."
    git config --global user.name "T2-Daily-Backup-System"
    git config --global user.email "system@t2-release-notes-analyzer.local"
    Write-TaskLog "Git user identity configured"
    
    # GitHub Credentials für SYSTEM Account
    Write-TaskLog "Configuring GitHub credentials for SYSTEM account..."
    $githubToken = $env:GITHUB_TOKEN
    $githubUrl = "https://github.com/mentronig/t2-release-notes-analyzer.git"
    $authenticatedUrl = $githubUrl -replace "https://", "https://$githubToken@"
    git remote set-url origin $authenticatedUrl
    Write-TaskLog "GitHub credentials configured"
    
    # Direct Export
    Write-TaskLog "Starting direct workflow export..."
    
    # API Call
    $url = "http://localhost:5678/api/v1/workflows/$workflowId"
    $headers = @{"X-N8N-API-KEY" = $apiKey}
    
    $workflow = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
    Write-TaskLog "Workflow retrieved: $($workflow.name) ($($workflow.nodes.Count) nodes)" -Level "SUCCESS"
    
    # Version
    $versionFile = "./version.txt"
    if (Test-Path $versionFile) {
        $currentVersion = Get-Content $versionFile -Raw | ConvertFrom-Json
        $patch = $currentVersion.patch + 1
    } else {
        $patch = 1
    }
    
    $version = @{
        major = 1; minor = 0; patch = $patch
        full = "1.0.$patch"
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    # Export
    $exportData = @{
        exported_at = $version.timestamp
        exported_by = "daily-backup-wrapper.ps1"
        version = $version.full
        workflow = $workflow
    }
    
    if (-not (Test-Path "./workflows")) {
        New-Item -ItemType Directory -Path "./workflows" -Force | Out-Null
    }
    
    $fileName = "t2-analyzer-v$($version.full).json"
    $filePath = "./workflows/$fileName"
    $exportData | ConvertTo-Json -Depth 10 | Set-Content $filePath -Encoding UTF8
    
    Write-TaskLog "Workflow exported: $filePath" -Level "SUCCESS"
    
    # Save Version
    $version | ConvertTo-Json | Set-Content $versionFile
    
    # Git Operations with detailed debugging
    Write-TaskLog "Starting Git operations..."
    
    Write-TaskLog "Git add $filePath"
    git add $filePath 2>&1 | Out-String | Write-TaskLog
    
    Write-TaskLog "Git add $versionFile"  
    git add $versionFile 2>&1 | Out-String | Write-TaskLog
    
    Write-TaskLog "Git status before commit:"
    git status --porcelain 2>&1 | Out-String | Write-TaskLog
    
    Write-TaskLog "Attempting Git commit..."
    $commitOutput = git commit -m "feat: Daily automated backup v$($version.full)" 2>&1
    $commitExitCode = $LASTEXITCODE
    
    Write-TaskLog "Git commit output: $commitOutput"
    Write-TaskLog "Git commit exit code: $commitExitCode"
    
    if ($commitExitCode -eq 0) {
        Write-TaskLog "Git commit successful" -Level "SUCCESS"
        
        Write-TaskLog "Attempting GitHub push..."
        $pushOutput = git push origin 2>&1
        $pushExitCode = $LASTEXITCODE
        
        Write-TaskLog "Git push output: $pushOutput"
        Write-TaskLog "Git push exit code: $pushExitCode"
        
        if ($pushExitCode -eq 0) {
            Write-TaskLog "GitHub push successful" -Level "SUCCESS"
        } else {
            Write-TaskLog "GitHub push failed" -Level "WARN"
        }
    } else {
        Write-TaskLog "Git commit failed" -Level "WARN"
    }
    
    Write-TaskLog "Daily backup completed successfully" -Level "SUCCESS"
    exit 0
}
catch {
    Write-TaskLog "Daily backup failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

Write-TaskLog "=== T2 Daily Backup Finished ==="
exit 0