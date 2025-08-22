# File: .\scripts\project-config.ps1
# Portable Admin Framework - Project Configuration Template

#Requires -Version 7.0
<#
.SYNOPSIS
    Project-specific configuration for the Portable Admin Framework
    
.DESCRIPTION
    This file contains all project-specific settings that need to be customized
    for each new project. Copy this template and modify for your project.
    
.NOTES
    File: .\scripts\project-config.ps1
    Version: 1.0.0
    Created: 2025-08-22
    Template for: ANY n8n/Git/PowerShell project
#>

# =============================================================================
# PROJECT IDENTIFICATION
# =============================================================================
$Global:ProjectConfig = @{
    # Basic Project Info
    ProjectName = "T2 Release Notes Analyzer"  # CHANGE THIS
    ProjectShortName = "T2"                   # CHANGE THIS
    ProjectDescription = "Automated release notes analysis"  # CHANGE THIS
    
    # Version Management
    VersionFile = "version.txt"
    VersionFormat = "v{0}"  # {0} will be replaced with version number
    
    # Directory Structure
    Directories = @{
        Scripts = ".\scripts"
        Logs = ".\logs" 
        Workflows = ".\workflows"          # CHANGE IF DIFFERENT
        Reports = ".\reports"
        Backups = ".\backups"             # Optional: separate from workflows
    }
    
    # Environment Files
    EnvFiles = @{
        Template = ".\.env.template"
        Local = ".\.env"
        Example = ".\.env.example"        # Optional
    }
}

# =============================================================================
# N8N CONFIGURATION (Modify for your n8n setup)
# =============================================================================
$Global:N8nConfig = @{
    # API Settings
    BaseUrl = "http://localhost:5678/api/v1"   # CHANGE IF DIFFERENT
    WebUrl = "http://localhost:5678"           # CHANGE IF DIFFERENT
    ApiKeyVariable = "N8N_API_KEY"             # Usually the same
    WorkflowIdVariable = "N8N_WORKFLOW_ID"     # Usually the same
    
    # Workflow Settings  
    WorkflowFilePattern = "{0}-{1}.json"       # {0}=name, {1}=version
    BackupPrefix = "backup"                    # Prefix for backup files
    
    # API Settings
    RequestTimeout = 10                        # Seconds
    RetryAttempts = 3
    RetryDelay = 2                            # Seconds
}

# =============================================================================
# GIT CONFIGURATION (Modify for your Git setup)
# =============================================================================
$Global:GitConfig = @{
    # Repository Settings
    RepoUrlVariable = "GITHUB_REPO_URL"        # Environment variable name
    TokenVariable = "GITHUB_TOKEN"             # Environment variable name
    DefaultBranch = "main"                     # CHANGE IF DIFFERENT (master, develop, etc.)
    
    # Commit Settings
    CommitMessagePrefix = "feat"               # CHANGE (feat, fix, docs, etc.)
    AutoCommitPattern = "{0}: {1} {2}"         # {0}=prefix, {1}=action, {2}=version
    
    # Backup Settings
    BackupCommitMessage = "{0}: Automated backup {1}"  # {0}=prefix, {1}=version
    
    # File Patterns
    IgnorePatterns = @(".env", "*.log", "node_modules/", ".idea/")
}

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================
$Global:LogConfig = @{
    # Log Files
    SystemLog = "system.log"
    BackupLog = "daily-backup.log"
    ExportLog = "export-workflow.log" 
    SetupLog = "setup-daily-backup.log"
    
    # Log Settings
    MaxLogSize = 10MB                          # Max size before rotation
    KeepLogDays = 30                          # Days to keep logs
    LogLevel = "INFO"                         # DEBUG, INFO, WARN, ERROR
    
    # Log Format
    TimestampFormat = "yyyy-MM-dd HH:mm:ss"
    LogFormat = "[{0}] {1}: {2}"              # {0}=timestamp, {1}=level, {2}=message
}

# =============================================================================
# TASK SCHEDULER CONFIGURATION (Windows-specific)
# =============================================================================
$Global:TaskConfig = @{
    # Task Settings
    TaskName = "T2-Daily-Backup"               # CHANGE THIS
    TaskPath = "\T2-Release-Notes-Analyzer\"   # CHANGE THIS
    TaskDescription = "Daily automated backup for T2 Release Notes Analyzer"  # CHANGE THIS
    
    # Schedule Settings
    ScheduleTime = "02:00"                     # 24-hour format
    RunAsAccount = "SYSTEM"                    # SYSTEM, or specific user
    
    # Script Settings
    WrapperScript = "daily-backup-wrapper.ps1"
    ExecutionPolicy = "Bypass"
}

# =============================================================================
# NOTIFICATION CONFIGURATION (Optional)
# =============================================================================
$Global:NotificationConfig = @{
    # Email Settings (if implemented)
    SmtpServer = ""
    SmtpPort = 587
    SmtpUsername = ""
    SmtpPassword = ""
    
    # Slack Settings (if implemented)
    SlackWebhook = ""
    SlackChannel = "#automation"
    
    # Teams Settings (if implemented)
    TeamsWebhook = ""
}

# =============================================================================
# CROSS-PLATFORM COMPATIBILITY SETTINGS
# =============================================================================
$Global:PlatformConfig = @{
    # Path Separators
    PathSeparator = if ($IsWindows -or $env:OS -eq "Windows_NT") { "\" } else { "/" }
    
    # Default Applications
    TextEditor = if ($IsWindows -or $env:OS -eq "Windows_NT") { 
        "notepad.exe" 
    } elseif ($IsMacOS) { 
        "open -e" 
    } else { 
        "nano" 
    }
    
    # Shell Commands
    Shell = if ($IsWindows -or $env:OS -eq "Windows_NT") { 
        "cmd.exe" 
    } else { 
        "/bin/bash" 
    }
    
    # Service Management (for n8n)
    ServiceCommands = @{
        Start = if ($IsWindows -or $env:OS -eq "Windows_NT") {
            "n8n start"
        } else {
            "systemctl start n8n"  # or "docker start n8n" 
        }
        Stop = if ($IsWindows -or $env:OS -eq "Windows_NT") {
            "taskkill /f /im n8n.exe"
        } else {
            "systemctl stop n8n"
        }
        Status = if ($IsWindows -or $env:OS -eq "Windows_NT") {
            "tasklist | findstr n8n"
        } else {
            "systemctl status n8n"
        }
    }
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

function Test-ProjectConfig {
    <#
    .SYNOPSIS
        Validates the project configuration
    #>
    $errors = @()
    
    # Check required variables
    if (-not $Global:ProjectConfig.ProjectName) {
        $errors += "ProjectName is required"
    }
    
    if (-not $Global:N8nConfig.BaseUrl) {
        $errors += "N8N BaseUrl is required"
    }
    
    # Check directories exist or can be created
    foreach ($dir in $Global:ProjectConfig.Directories.Values) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Path $dir -Force -WhatIf | Out-Null
            } catch {
                $errors += "Cannot create directory: $dir"
            }
        }
    }
    
    if ($errors.Count -gt 0) {
        Write-Host "❌ Configuration validation failed:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
        return $false
    }
    
    Write-Host "✅ Project configuration is valid" -ForegroundColor Green
    return $true
}

function Initialize-ProjectDirectories {
    <#
    .SYNOPSIS
        Creates all required project directories
    #>
    foreach ($dirName in $Global:ProjectConfig.Directories.Keys) {
        $dirPath = $Global:ProjectConfig.Directories[$dirName]
        if (-not (Test-Path $dirPath)) {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
            Write-Host "✅ Created directory: $dirPath" -ForegroundColor Green
        }
    }
}

function Get-CrossPlatformPath {
    <#
    .SYNOPSIS
        Converts paths to be cross-platform compatible
    #>
    param([string]$Path)
    
    if ($Global:PlatformConfig.PathSeparator -eq "/") {
        return $Path -replace "\\", "/"
    } else {
        return $Path -replace "/", "\"
    }
}

# =============================================================================
# EXPORT CONFIGURATION
# =============================================================================

# Make configurations available globally
Export-ModuleMember -Variable ProjectConfig, N8nConfig, GitConfig, LogConfig, TaskConfig, NotificationConfig, PlatformConfig
Export-ModuleMember -Function Test-ProjectConfig, Initialize-ProjectDirectories, Get-CrossPlatformPath

Write-Host "📦 Project configuration loaded: $($Global:ProjectConfig.ProjectName)" -ForegroundColor Cyan