# Quick Debug Script - Check .env file content and parsing
# Save as: debug-env.ps1 and run to see what's happening

Write-Host "=== DEBUG: .env File Analysis ===" -ForegroundColor Cyan

# Check if .env exists
if (Test-Path ".\.env") {
    Write-Host "✅ .env file found" -ForegroundColor Green
    
    # Show raw content
    $envContent = Get-Content ".\.env"
    Write-Host "`n--- Raw .env content ---" -ForegroundColor Yellow
    $envContent | ForEach-Object { Write-Host "[$($envContent.IndexOf($_))] '$_'" }
    
    Write-Host "`n--- Parsing Analysis ---" -ForegroundColor Yellow
    $loadedCount = 0
    
    foreach ($line in $envContent) {
        Write-Host "Processing line: '$line'" -ForegroundColor Gray
        
        # Check conditions
        $isEmpty = [string]::IsNullOrWhiteSpace($line)
        $isComment = $line.TrimStart().StartsWith('#')
        $hasEquals = $line -contains '='
        
        Write-Host "  IsEmpty: $isEmpty, IsComment: $isComment, HasEquals: $hasEquals" -ForegroundColor Gray
        
        if ($isEmpty -or $isComment) {
            Write-Host "  → SKIPPED (empty or comment)" -ForegroundColor Yellow
            continue
        }
        
        if ($hasEquals) {
            $parts = $line.Split('=', 2)
            Write-Host "  → Parts count: $($parts.Count)" -ForegroundColor Gray
            Write-Host "  → Key: '$($parts[0].Trim())'" -ForegroundColor Gray
            Write-Host "  → Value: '$($parts[1].Trim())'" -ForegroundColor Gray
            $loadedCount++
        } else {
            Write-Host "  → SKIPPED (no equals sign)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nTotal variables that would be loaded: $loadedCount" -ForegroundColor Cyan
    
} else {
    Write-Host "❌ .env file NOT found" -ForegroundColor Red
}

Write-Host "`n=== Current Environment Variables ===" -ForegroundColor Cyan
$env:N8N_API_KEY | ForEach-Object { Write-Host "N8N_API_KEY: '$_'" }
$env:N8N_WORKFLOW_ID | ForEach-Object { Write-Host "N8N_WORKFLOW_ID: '$_'" }
$env:N8N_BASE_URL | ForEach-Object { Write-Host "N8N_BASE_URL: '$_'" }