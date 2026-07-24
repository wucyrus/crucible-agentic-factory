param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,

    [Parameter(Mandatory=$false)]
    [string]$Path = "/api/v1/telemetry",

    [Parameter(Mandatory=$true)]
    [string]$HeaderValue
)

$uri = "https://$Domain$Path"
Write-Host "Testing URL: $uri"

Write-Host "\n[1/2] No header request (expect honeypot or tarpit route)..." -ForegroundColor Yellow
curl.exe -vk $uri

Write-Host "\n[2/2] Valid header request (expect Xray backend route)..." -ForegroundColor Yellow
curl.exe -vk -H "X-App-Auth: $HeaderValue" $uri
