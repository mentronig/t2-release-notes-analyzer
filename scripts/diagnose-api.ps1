# n8n API Key Diagnostic Script
# Save as: diagnose-api.ps1

Write-Host "=== n8n API Key Diagnostic ===" -ForegroundColor Cyan

# Load environment variables (reuse the working function)
if (Test-Path ".\.env") {
    $envContent = Get-Content ".\.env"
    foreach ($line in $envContent) {
        if (-not [string]::IsNullOrWhiteSpace($line) -and -not $line.TrimStart().StartsWith('#') -and $line.Contains('=')) {
            $parts = $line.Split('=', 2)
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                [Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
        }
    }
}

$apiKey = [Environment]::GetEnvironmentVariable("N8N_API_KEY", "Process")
$baseUrl = [Environment]::GetEnvironmentVariable("N8N_BASE_URL", "Process")

Write-Host "`n1. API Key Analysis:" -ForegroundColor Yellow
Write-Host "   Length: $($apiKey.Length) characters"
Write-Host "   Starts with: $($apiKey.Substring(0, [Math]::Min(10, $apiKey.Length)))..."
Write-Host "   Contains spaces: $(if($apiKey.Contains(' ')){'YES - PROBLEM!'}else{'No'})"
Write-Host "   Contains quotes: $(if($apiKey.Contains('"') -or $apiKey.Contains("'")){'YES - PROBLEM!'}else{'No'})"

Write-Host "`n2. n8n Web Interface Test:" -ForegroundColor Yellow
try {
    $webResponse = Invoke-WebRequest -Uri "http://localhost:5678" -TimeoutSec 5 -UseBasicParsing
    Write-Host "   ✅ n8n Web Interface: ACCESSIBLE (Status: $($webResponse.StatusCode))"
} catch {
    Write-Host "   ❌ n8n Web Interface: NOT ACCESSIBLE - $($_.Exception.Message)"
    Write-Host "   → Start n8n first: 'n8n start'"
    exit 1
}

Write-Host "`n3. API Endpoint Tests:" -ForegroundColor Yellow

# Test 1: Basic API without auth (should give 401 but different message)
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/workflows" -Method Get -TimeoutSec 5
    Write-Host "   ❌ UNEXPECTED: API accessible without auth!"
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "   ✅ API correctly requires authentication"
    } else {
        Write-Host "   ❌ Unexpected error: $($_.Exception.Message)"
    }
}

# Test 2: API with current key
Write-Host "`n4. API Key Validation:" -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }
    
    Write-Host "   Testing with headers:"
    Write-Host "     Authorization: Bearer $($apiKey.Substring(0, [Math]::Min(10, $apiKey.Length)))..."
    Write-Host "     Content-Type: application/json"
    
    $response = Invoke-RestMethod -Uri "$baseUrl/workflows" -Method Get -Headers $headers -TimeoutSec 10
    Write-Host "   ✅ API KEY VALID - $($response.Count) workflows accessible"
    
} catch {
    Write-Host "   ❌ API KEY INVALID - $($_.Exception.Message)"
    
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "`n🔧 SOLUTION STEPS:"
        Write-Host "   1. Check n8n API key in n8n settings:"
        Write-Host "      → Open: http://localhost:5678/settings/api"
        Write-Host "   2. Generate new API key if needed"
        Write-Host "   3. Update .env file with correct key"
        Write-Host "   4. Verify key format: should be like 'n8n_api_xxxxxxxxxxxxx'"
    }
}

Write-Host "`n5. Common Issues Check:" -ForegroundColor Yellow

# Check if API is enabled
Write-Host "   Checking if n8n API is enabled..."
try {
    $settingsResponse = Invoke-WebRequest -Uri "http://localhost:5678/rest/settings" -UseBasicParsing -TimeoutSec 5
    Write-Host "   ✅ n8n REST endpoint accessible"
} catch {
    Write-Host "   ⚠️  n8n REST endpoint issue: $($_.Exception.Message)"
}

Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Open n8n in browser: http://localhost:5678"
Write-Host "2. Go to Settings → API"
Write-Host "3. Create/verify API key"
Write-Host "4. Update .env file if needed"
Write-Host "5. Re-run: .\scripts\test-manual-backup.ps1 -DryRun"