 param (
    [Parameter(Mandatory = $true)] [string]$AriaOpsURL,
    [Parameter(Mandatory = $true)] [string]$AuthSource,
    [Parameter(Mandatory = $true)] [string]$Username,
    [Parameter(Mandatory = $true)] [string]$Password,
    [Parameter(Mandatory = $true)] [string]$ExportPassword,
    [Parameter(Mandatory = $true)] [string]$DownloadPath,
    [Parameter(Mandatory = $true)] [int]$RetentionDays,
    [Parameter(Mandatory = $true)] [string]$LogFile
    
)

# Function to log messages
function Write-Log {
    param (
        [string]$Message
    )
    if (-not $LogFile) {
        Write-Host "Log file path is not set. Exiting."
        exit 1
    }
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append
}

Write-Log "Starting Aria Ops Content Export Script"

# Validate https URL
if (-not $AriaOpsURL -or $AriaOpsURL -notmatch "^https?://") {
    Write-Log "Invalid SSL AriaOps URL. Exiting."
    exit 1
}

# Authenticate to Aria Operations API
$loginUri = "$AriaOpsURL/suite-api/api/auth/token/acquire"
$loginData = @{ username = $Username; authSource = $AuthSource; password = $Password } | ConvertTo-Json -Depth 10

Write-Log "Sending authentication request: $loginUri with body: (password obfuscated)"
try {
    $response = Invoke-RestMethod -Uri $loginUri -Method POST -Body $loginData -ContentType "application/json;charset=UTF-8" -Headers @{ "Accept"="application/json" } -UseBasicParsing -ErrorAction Stop
    $Token = $response.token
    Write-Log "Auth Token acquired : $Token"
} catch {
    Write-Log "Error during authentication: $_.Exception.Message"
    Write-Log "Response: $_"
    exit 1
}

# Create content management export job, edit choices as required.
$ExportPayload = @{ 
    scope = "CUSTOM"
    contentTypes = @(
        "VIEW_DEFINITIONS", "REPORT_DEFINITIONS", "DASHBOARDS", "REPORT_SCHEDULES", "POLICIES", 
        "ALERT_DEFINITIONS", "SYMPTOM_DEFINITIONS", "RECOMMENDATION_DEFINITIONS", "CUSTOM_GROUPS", 
        "CUSTOM_METRICGROUPS", "SUPER_METRICS", "CONFIG_FILES", "COMPLIANCE_SCORECARDS", "NOTIFICATION_RULES", 
        "OUTBOUND_SETTINGS", "PAYLOAD_TEMPLATES", "INTEGRATIONS", "USERS", "USER_GROUPS", "ROLES", 
        "AUTH_SOURCES", "HTTP_PROXIES", "COST_DRIVERS", "SDMP_CUSTOM_SERVICES", "SDMP_CUSTOM_APPLICATIONS", 
        "CUSTOM_PROFILES", "DISCOVERY_RULES", "APP_DEF_ASSIGNMENTS", "GLOBAL_SETTINGS"
    )
} | ConvertTo-Json -Depth 10

Write-Log "Export Payload: $ExportPayload"

$ExportUri = "$AriaOpsURL/suite-api/api/content/operations/export?_no_links=true"
Write-Log "Sending export request: $ExportUri"
try {
    $ExportJobResponse = Invoke-RestMethod -Uri $ExportUri -Method Post -Headers @{
        "Authorization" = "OpsToken $Token";
        "EncryptionPassword" = $ExportPassword;
        "Content-Type" = "application/json;charset=UTF-8"
    } -Body $ExportPayload -ErrorAction Stop

} catch {
    Write-Log "Export job creation failed: $_.Exception.Message"
    Write-Log "Response: $_"
    exit 1
}

# Retry download until successful
$JobCompleted = $false
$DownloadAttempts = 0
$MaxDownloadAttempts = 10  # Set a maximum number of retries

while (-not $JobCompleted -and $DownloadAttempts -lt $MaxDownloadAttempts) {
    $DownloadAttempts++
    Write-Log "Attempting to download backup. Attempt #$DownloadAttempts"

    $DownloadUrl = "$AriaOpsURL/suite-api/api/content/operations/export/zip?_no_links=true"
    $ExportFileName = "AriaOpsBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
    $ExportFilePath = Join-Path -Path $DownloadPath -ChildPath $ExportFileName

    try {
        Write-Log "Downloading backup from: $DownloadUrl"
        Invoke-WebRequest -Uri $DownloadUrl -Headers @{ Authorization = "OpsToken $Token" } -OutFile $ExportFilePath -UseBasicParsing -ErrorAction Stop
        Write-Log "Backup file downloaded successfully: $ExportFilePath"
        $JobCompleted = $true
    } catch {
        Write-Log "Error downloading backup: $_.Exception.Message"
        Write-Log "Response: $_"
        Start-Sleep -Seconds 30  # Wait before retrying
    }
}

# Check if the job completed successfully
if (-not $JobCompleted) {
    Write-Log "Download failed after $MaxDownloadAttempts attempts."
    exit 1
}

# Backup retention management - drop files older than the $RetentionDays argument
$RetentionDate = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem -Path $DownloadPath -Filter "AriaOpsBackup*.bak" | Where-Object { $_.CreationTime -lt $RetentionDate } | ForEach-Object {
    Write-Log "Deleting old backup file: $($_.FullName)"
    Remove-Item $_.FullName -Force
}

Write-Log "Backup script completed successfully."
exit 0
 
