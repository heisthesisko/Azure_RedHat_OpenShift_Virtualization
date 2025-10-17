# -------------------------------------------------------------
# Deploy-SQLContainer.ps1
# Purpose: Deploy SQL Server 2022 in a Windows container
# Target:  Windows Server 2022 with Containers feature enabled
# -------------------------------------------------------------

# Variables
$containerName = "your_sql_container"  # Change this to your desired container name
$sqlPassword = "yourpassword"         # Change this to a strong password
$sqlPort = 1433
$imageName = "mcr.microsoft.com/mssql/server:2022-latest"

Write-Host "=== SQL Server Container Deployment Script ===" -ForegroundColor Cyan

# 1. Ensure Docker is installed
if (-not (Get-Service docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker not found. Installing Docker..." -ForegroundColor Yellow
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force
    Start-Service docker
} else {
    Write-Host "Docker is already installed." -ForegroundColor Green
    if ((Get-Service docker).Status -ne 'Running') {
        Write-Host "Starting Docker service..." -ForegroundColor Yellow
        Start-Service docker
    }
}

# 2. Pull SQL Server image if not present
if (-not (docker images | Select-String $imageName)) {
    Write-Host "Pulling SQL Server image ($imageName)..." -ForegroundColor Yellow
    docker pull $imageName
} else {
    Write-Host "SQL Server image already available locally." -ForegroundColor Green
}

# 3. Remove old container if it exists
if (docker ps -a --format "{{.Names}}" | Select-String -Pattern $containerName) {
    Write-Host "Existing container found. Removing..." -ForegroundColor Yellow
    docker stop $containerName | Out-Null
    docker rm $containerName | Out-Null
}

# 4. Deploy SQL Server container
Write-Host "Deploying SQL Server container..." -ForegroundColor Cyan
docker run -e "ACCEPT_EULA=Y" `
           -e "SA_PASSWORD=$sqlPassword" `
           -p $sqlPort:1433 `
           --name $containerName `
           -d $imageName

# 5. Wait and verify container status
Start-Sleep -Seconds 10
$containerStatus = docker inspect -f "{{.State.Status}}" $containerName

if ($containerStatus -eq "running") {
    Write-Host "✅ SQL Server container '$containerName' is running on port $sqlPort." -ForegroundColor Green
} else {
    Write-Host "❌ Container failed to start. Check logs:" -ForegroundColor Red
    docker logs $containerName
    exit 1
}

# 6. Optional: Test connectivity inside the container
Write-Host "Testing SQL Server connection inside container..." -ForegroundColor Cyan
docker exec -it $containerName /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $sqlPassword -Q "SELECT @@VERSION;"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SQL Server connection successful." -ForegroundColor Green
} else {
    Write-Host "⚠️ SQL Server connection test failed." -ForegroundColor Yellow
}

Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan