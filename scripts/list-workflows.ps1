# File: .\scripts\list-workflows.ps1
# List all available n8n workflows with IDs and names

#Requires -Version 7.0
<#
.SYNOPSIS
    Lists all available n8n workflows with IDs and names
    
.DESCRIPTION
    Connects to n8n API and shows all workflows to help identify correct workflow ID
    
.EXAMPLE
    .\scripts\list-workflows.ps1
    
.NOTES
    File: .\scripts\list-workflows.ps1
    Version: 1.0.0
    Created: 2025-08-22
#>

Write-Host "=== n8n Workflows List ===" -ForegroundColor Cyan

# Load environment variables
if (Test-Path ".\.env") {
    $envContent = Get-Content ".\.env"
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
}

$apiKey = [Environment]::GetEnvironmentVariable("N8N_API_KEY", "Process")
$baseUrl = [Environment]::GetEnvironmentVariable("N8N_BASE_URL", "Process")
$currentWorkflowId = [Environment]::GetEnvironmentVariable("N8N_WORKFLOW_ID", "Process")

if (-not $baseUrl) { $baseUrl = "http://localhost:5678/api/v1" }

if (-not $apiKey) {
    Write-Host "❌ N8N_API_KEY not found in .env file" -ForegroundColor Red
    exit 1
}

try {
    $headers = @{
        "X-N8N-API-KEY" = $apiKey
        "Content-Type" = "application/json"
    }
    
    Write-Host "🔍 Fetching workflows from: $baseUrl/workflows" -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri "$baseUrl/workflows" -Method Get -Headers $headers -TimeoutSec 10
    
    # Handle nested response format
    $workflows = if ($response.data) { $response.data } else { $response }
    
    Write-Host "✅ Found $($workflows.Count) workflow(s):" -ForegroundColor Green
    Write-Host "`n📋 Workflow Details:" -ForegroundColor Cyan
    
    foreach ($workflow in $workflows) {
        $isCurrentWorkflow = $workflow.id -eq $currentWorkflowId
        $indicator = if ($isCurrentWorkflow) { "👉 CURRENT" } else { "  " }
        $color = if ($isCurrentWorkflow) { "Yellow" } else { "White" }
        
        Write-Host "---" -ForegroundColor Gray
        Write-Host "$indicator ID: $($workflow.id)" -ForegroundColor $color
        Write-Host "     Name: $($workflow.name)" -ForegroundColor $color
        Write-Host "     Active: $($workflow.active)" -ForegroundColor $color
        Write-Host "     Created: $($workflow.createdAt)" -ForegroundColor Gray
        Write-Host "     Updated: $($workflow.updatedAt)" -ForegroundColor Gray
        Write-Host "     Archived: $($workflow.isArchived)" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($currentWorkflowId) {
        $foundCurrent = $workflows | Where-Object { $_.id -eq $currentWorkflowId }
        if (-not $foundCurrent) {
            Write-Host "⚠️  Current workflow ID '$currentWorkflowId' NOT FOUND!" -ForegroundColor Yellow
            Write-Host "🔧 Update .env file with correct workflow ID from the list above" -ForegroundColor Cyan
        } else {
            Write-Host "✅ Current workflow ID '$currentWorkflowId' is VALID!" -ForegroundColor Green
            Write-Host "✅ Workflow Name: '$($foundCurrent.name)'" -ForegroundColor Green
        }
    }
    
} catch {
    Write-Host "❌ Error fetching workflows: $($_.Exception.Message)" -ForegroundColor Red
}