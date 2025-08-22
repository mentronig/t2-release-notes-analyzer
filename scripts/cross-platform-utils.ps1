# File: .\scripts\cross-platform-utils.ps1
# Cross-Platform Compatibility Utilities

#Requires -Version 7.0
<#
.SYNOPSIS
    Cross-platform utility functions for PowerShell scripts
    
.DESCRIPTION
    Provides abstractions for platform-specific operations to make scripts
    work on Windows, macOS, and Linux.
    
.NOTES
    File: .\scripts\cross-platform-utils.ps1
    Version: 1.0.0
    Created: 2025-08-22
    Supports: Windows, macOS, Linux
#>

# =============================================================================
# PLATFORM DETECTION
# =============================================================================

function Get-CurrentPlatform {
    <#
    .SYNOPSIS
        Detects the current platform
    .OUTPUTS
        String: "Windows", "macOS", "Linux", or "Unknown"
    #>
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return "Windows"
    } elseif ($IsMacOS) {
        return "macOS" 
    } elseif ($IsLinux) {
        return "Linux"
    } else {
        return "Unknown"
    }
}

function Test-IsWindows {
    return ($IsWindows -or $env:OS -eq "Windows_NT")
}

function Test-IsUnix {
    return ($IsLinux -or $IsMacOS)
}

# =============================================================================
# FILE SYSTEM OPERATIONS
# =============================================================================

function Get-PlatformPath {
    <#
    .SYNOPSIS
        Converts path to platform-appropriate format
    #>
    param(
        [string]$Path,
        [switch]$AsUnix
    )
    
    if ($AsUnix -or (Test-IsUnix)) {
        return $Path -replace "\\", "/"
    } else {
        return $Path -replace "/", "\"
    }
}

function Get-HomeDirectory {
    <#
    .SYNOPSIS
        Gets the user's home directory cross-platform
    #>
    if (Test-IsWindows) {
        return $env:USERPROFILE
    } else {
        return $env:HOME
    }
}

function Get-TempDirectory {
    <#
    .SYNOPSIS
        Gets the temporary directory cross-platform
    #>
    if (Test-IsWindows) {
        return $env:TEMP
    } else {
        return "/tmp"
    }
}

function Test-PathExists {
    <#
    .SYNOPSIS
        Cross-platform path existence check
    #>
    param([string]$Path)
    
    $normalizedPath = Get-PlatformPath $Path
    return Test-Path $normalizedPath
}

# =============================================================================
# PROCESS MANAGEMENT
# =============================================================================

function Start-CrossPlatformProcess {
    <#
    .SYNOPSIS
        Starts a process with platform-appropriate method
    #>
    param(
        [string]$Command,
        [string[]]$Arguments = @(),
        [switch]$Wait,
        [switch]$NoNewWindow
    )
    
    try {
        if (Test-IsWindows) {
            $startInfo = @{
                FilePath = $Command
                ArgumentList = $Arguments
                Wait = $Wait
                NoNewWindow = $NoNewWindow
            }
        } else {
            # On Unix, combine command and arguments
            $fullCommand = "$Command $($Arguments -join ' ')"
            $startInfo = @{
                FilePath = "/bin/bash"
                ArgumentList = @("-c", $fullCommand)
                Wait = $Wait
                NoNewWindow = $true  # Always true on Unix
            }
        }
        
        return Start-Process @startInfo
    } catch {
        Write-Error "Failed to start process: $($_.Exception.Message)"
        return $null
    }
}

function Get-ProcessByName {
    <#
    .SYNOPSIS
        Gets processes by name cross-platform
    #>
    param([string]$ProcessName)
    
    if (Test-IsWindows) {
        return Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    } else {
        # Use ps command on Unix systems
        try {
            $output = & ps aux | grep $ProcessName | grep -v grep
            return $output
        } catch {
            return $null
        }
    }
}

function Stop-CrossPlatformProcess {
    <#
    .SYNOPSIS
        Stops a process cross-platform
    #>
    param(
        [string]$ProcessName,
        [switch]$Force
    )
    
    if (Test-IsWindows) {
        if ($Force) {
            taskkill /f /im "$ProcessName*"
        } else {
            Stop-Process -Name $ProcessName -ErrorAction SilentlyContinue
        }
    } else {
        if ($Force) {
            & pkill -9 $ProcessName
        } else {
            & pkill $ProcessName
        }
    }
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

function Get-ServiceStatus {
    <#
    .SYNOPSIS
        Gets service status cross-platform
    #>
    param([string]$ServiceName)
    
    if (Test-IsWindows) {
        try {
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            return @{
                Name = $ServiceName
                Status = $service.Status
                Running = $service.Status -eq "Running"
            }
        } catch {
            return @{
                Name = $ServiceName
                Status = "Not Found"
                Running = $false
            }
        }
    } else {
        try {
            $output = & systemctl is-active $ServiceName 2>/dev/null
            $isRunning = $output -eq "active"
            return @{
                Name = $ServiceName
                Status = $output
                Running = $isRunning
            }
        } catch {
            return @{
                Name = $ServiceName
                Status = "Unknown"
                Running = $false
            }
        }
    }
}

function Start-CrossPlatformService {
    <#
    .SYNOPSIS
        Starts a service cross-platform
    #>
    param([string]$ServiceName)
    
    if (Test-IsWindows) {
        Start-Service -Name $ServiceName
    } else {
        & sudo systemctl start $ServiceName
    }
}

function Stop-CrossPlatformService {
    <#
    .SYNOPSIS
        Stops a service cross-platform
    #>
    param([string]$ServiceName)
    
    if (Test-IsWindows) {
        Stop-Service -Name $ServiceName
    } else {
        & sudo systemctl stop $ServiceName
    }
}

# =============================================================================
# NETWORK OPERATIONS
# =============================================================================

function Test-NetworkConnection {
    <#
    .SYNOPSIS
        Tests network connectivity cross-platform
    #>
    param(
        [string]$ComputerName,
        [int]$Port = 80,
        [int]$TimeoutSeconds = 5
    )
    
    try {
        if (Test-IsWindows) {
            # Use Test-NetConnection on Windows (if available)
            if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
                $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet
                return $result
            }
        }
        
        # Fallback: Use TCP client (works on all platforms)
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
        
        if ($wait) {
            try {
                $tcpClient.EndConnect($asyncResult)
                return $true
            } catch {
                return $false
            }
        } else {
            return $false
        }
    } catch {
        return $false
    } finally {
        if ($tcpClient) {
            $tcpClient.Close()
        }
    }
}

# =============================================================================
# APPLICATION LAUNCHERS
# =============================================================================

function Open-CrossPlatformFile {
    <#
    .SYNOPSIS
        Opens a file with the default application cross-platform
    #>
    param([string]$FilePath)
    
    $normalizedPath = Get-PlatformPath $FilePath
    
    if (Test-IsWindows) {
        Start-Process $normalizedPath
    } elseif ($IsMacOS) {
        & open $normalizedPath
    } else {
        # Linux - try common file managers
        if (Get-Command xdg-open -ErrorAction SilentlyContinue) {
            & xdg-open $normalizedPath
        } elseif (Get-Command gnome-open -ErrorAction SilentlyContinue) {
            & gnome-open $normalizedPath
        } else {
            Write-Warning "No suitable file opener found"
        }
    }
}

function Open-CrossPlatformTextEditor {
    <#
    .SYNOPSIS
        Opens a text file in the platform's default editor
    #>
    param([string]$FilePath)
    
    $normalizedPath = Get-PlatformPath $FilePath
    
    if (Test-IsWindows) {
        # Try VS Code first, fallback to notepad
        if (Get-Command code -ErrorAction SilentlyContinue) {
            & code $normalizedPath
        } else {
            & notepad $normalizedPath
        }
    } elseif ($IsMacOS) {
        # Try VS Code first, fallback to TextEdit
        if (Get-Command code -ErrorAction SilentlyContinue) {
            & code $normalizedPath
        } else {
            & open -e $normalizedPath
        }
    } else {
        # Linux - try various editors
        if (Get-Command code -ErrorAction SilentlyContinue) {
            & code $normalizedPath
        } elseif (Get-Command gedit -ErrorAction SilentlyContinue) {
            & gedit $normalizedPath
        } elseif (Get-Command nano -ErrorAction SilentlyContinueSilently) {
            & nano $normalizedPath
        } else {
            & vi $normalizedPath
        }
    }
}

# =============================================================================
# SCHEDULING (Task/Cron)
# =============================================================================

function New-CrossPlatformScheduledTask {
    <#
    .SYNOPSIS
        Creates a scheduled task cross-platform
    #>
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string]$Schedule, # "daily", "weekly", "hourly"
        [string]$Time = "02:00"
    )
    
    if (Test-IsWindows) {
        # Windows Task Scheduler
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$ScriptPath`""
        
        switch ($Schedule) {
            "daily" {
                $trigger = New-ScheduledTaskTrigger -Daily -At $Time
            }
            "weekly" {
                $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $Time
            }
            "hourly" {
                $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
            }
        }
        
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger
    } else {
        # Unix cron
        $cronExpression = switch ($Schedule) {
            "daily" {
                $timeParts = $Time.Split(":")
                "$($timeParts[1]) $($timeParts[0]) * * *"
            }
            "weekly" {
                $timeParts = $Time.Split(":")
                "$($timeParts[1]) $($timeParts[0]) * * 1"  # Monday
            }
            "hourly" {
                "0 * * * *"
            }
        }
        
        # Add to crontab
        $cronEntry = "$cronExpression /usr/bin/pwsh $ScriptPath"
        $currentCron = & crontab -l 2>/dev/null
        $newCron = if ($currentCron) {
            "$currentCron`n$cronEntry"
        } else {
            $cronEntry
        }
        
        $newCron | & crontab -
    }
}

# =============================================================================
# EXPORTS
# =============================================================================

Export-ModuleMember -Function *