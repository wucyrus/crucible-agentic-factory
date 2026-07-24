param(
    [string]$Since = "6h",
    [string]$RawOutput = "tarpit-raw.log",
    [string]$CsvOutput = "tarpit-events.csv"
)

$ErrorActionPreference = "Stop"

Write-Host "Exporting tarpit logs since $Since ..."
docker logs --since $Since xray-tarpit 2>&1 | Tee-Object -FilePath $RawOutput | Out-Null

$events = Get-Content -Path $RawOutput |
    ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } |
    Where-Object {
        $_ -and $_.event -eq "tarpit_request"
    } |
    Select-Object ts, client_ip, host, method, path, user_agent, hold_seconds, chunks_sent, disconnected_early

$events | Export-Csv -Path $CsvOutput -NoTypeInformation -Encoding UTF8

Write-Host "Saved: $RawOutput"
Write-Host "Saved: $CsvOutput"

if ($events.Count -gt 0) {
    Write-Host "Top scanner IPs:" -ForegroundColor Cyan
    $events | Group-Object client_ip | Sort-Object Count -Descending | Select-Object -First 10 | Format-Table Count, Name -AutoSize
} else {
    Write-Host "No tarpit_request events found in selected window."
}
