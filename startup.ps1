# Start WordPress with Docker Compose and display credentials

Write-Host "Starting WordPress 7 with MySQL..." -ForegroundColor Green
Write-Host ""

# Start containers
Invoke-Expression "docker compose up -d"

# Wait for services to be ready
Write-Host "Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

$maxAttempts = 30
$attempt = 0

# Check if WordPress is responding
do {
    $attempt++
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            break
        }
    } catch {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }
} while ($attempt -lt $maxAttempts)

Write-Host ""
Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "WordPress Setup Complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access WordPress:" -ForegroundColor Cyan
Write-Host "  📍 Main Site: http://localhost:8080" -ForegroundColor White
Write-Host "  📍 Admin Panel: http://localhost:8080/wp-admin" -ForegroundColor White
Write-Host ""
Write-Host "Database Credentials:" -ForegroundColor Cyan
Write-Host "  🔐 Database: wordpress" -ForegroundColor White
Write-Host "  🔐 DB User: wordpress" -ForegroundColor White
Write-Host "  🔐 DB Password: wordpresspass123" -ForegroundColor White
Write-Host "  🔐 Root Password: rootpassword123" -ForegroundColor White
Write-Host ""
Write-Host "First Time Setup:" -ForegroundColor Cyan
Write-Host "  1. Open http://localhost:8080 in your browser" -ForegroundColor White
Write-Host "  2. Complete the WordPress installation wizard" -ForegroundColor White
Write-Host "  3. Create your admin username and password" -ForegroundColor White
Write-Host ""
Write-Host "Containers Status:" -ForegroundColor Cyan
Invoke-Expression "docker compose ps"
Write-Host ""
Write-Host "View logs with: docker compose logs -f wordpress" -ForegroundColor Yellow
