# ============================================================
# 错题猎手（ErrorHunter）本地开发环境启动脚本
# 适用于 Windows PowerShell
# ============================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

function Write-Info  { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ---------- 1. 检查 Docker ----------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err "未检测到 Docker，请先安装 Docker Desktop"
    exit 1
}

try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker not running" }
} catch {
    Write-Err "Docker 未运行，请先启动 Docker Desktop"
    exit 1
}
Write-Info "Docker 运行正常 ✓"

# ---------- 2. 加载环境变量 ----------
$envFile = Join-Path $ScriptDir ".env"
if (Test-Path $envFile) {
    Write-Info "加载 .env 配置文件"
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
        }
    }
} else {
    Write-Warn "未找到 .env 文件，将使用默认值"
    Write-Warn "建议执行: Copy-Item .env.example .env 并按需修改"
}

# 读取变量（带默认值）
$pgPort     = if ($env:POSTGRES_PORT)     { $env:POSTGRES_PORT }     else { "5432" }
$pgDb       = if ($env:POSTGRES_DB)       { $env:POSTGRES_DB }       else { "errorhunter" }
$pgUser     = if ($env:POSTGRES_USER)     { $env:POSTGRES_USER }     else { "errorhunter" }
$pgPass     = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "errorhunter_dev" }
$redisPort  = if ($env:REDIS_PORT)        { $env:REDIS_PORT }        else { "6379" }
$minioApi   = if ($env:MINIO_API_PORT)    { $env:MINIO_API_PORT }    else { "9000" }
$minioWeb   = if ($env:MINIO_CONSOLE_PORT){ $env:MINIO_CONSOLE_PORT }else { "9001" }
$minioUser  = if ($env:MINIO_ROOT_USER)   { $env:MINIO_ROOT_USER }   else { "minioadmin" }
$minioPass  = if ($env:MINIO_ROOT_PASSWORD){ $env:MINIO_ROOT_PASSWORD}else { "minioadmin123" }

# ---------- 3. 拉取镜像 ----------
Write-Info "拉取最新镜像..."
docker compose pull

# ---------- 4. 启动服务 ----------
Write-Info "启动基础设施服务..."
docker compose up -d

# ---------- 5. 等待健康检查 ----------
Write-Info "等待服务就绪..."

function Wait-Healthy {
    param([string]$Service, [int]$MaxRetries = 30)
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        $output = docker compose ps --format json $Service 2>$null
        if ($output -match '"Health"\s*:\s*"healthy"') {
            return $true
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

$allOk = $true

if (Wait-Healthy -Service "postgres") {
    Write-Info "PostgreSQL 就绪 ✓"
} else {
    Write-Warn "PostgreSQL 健康检查超时，请手动确认"
    $allOk = $false
}

if (Wait-Healthy -Service "redis") {
    Write-Info "Redis 就绪 ✓"
} else {
    Write-Warn "Redis 健康检查超时，请手动确认"
    $allOk = $false
}

if (Wait-Healthy -Service "minio") {
    Write-Info "MinIO 就绪 ✓"
} else {
    Write-Warn "MinIO 健康检查超时，请手动确认"
    $allOk = $false
}

# ---------- 6. 打印连接信息 ----------
Write-Host ""
Write-Host "============================================================"
Write-Host "  错题猎手（ErrorHunter）本地开发环境"
Write-Host "============================================================"
Write-Host ""
Write-Host "  PostgreSQL"
Write-Host "     Host:     localhost"
Write-Host "     Port:     $pgPort"
Write-Host "     Database: $pgDb"
Write-Host "     User:     $pgUser"
Write-Host "     Password: $pgPass"
Write-Host "     JDBC:     jdbc:postgresql://localhost:$pgPort/$pgDb"
Write-Host ""
Write-Host "  Redis"
Write-Host "     Host:     localhost"
Write-Host "     Port:     $redisPort"
Write-Host "     URL:      redis://localhost:$redisPort"
Write-Host ""
Write-Host "  MinIO (S3-compatible)"
Write-Host "     API:      http://localhost:$minioApi"
Write-Host "     Console:  http://localhost:$minioWeb"
Write-Host "     User:     $minioUser"
Write-Host "     Password: $minioPass"
Write-Host ""
Write-Host "============================================================"

if ($allOk) {
    Write-Info "All services are ready!"
} else {
    Write-Warn "Some services may still be starting, please retry later"
}
