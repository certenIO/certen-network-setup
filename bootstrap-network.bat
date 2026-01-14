@echo off
REM ═══════════════════════════════════════════════════════════════
REM Certen Network Bootstrap Script (Windows)
REM Initializes and starts a multi-validator Certen BFT network
REM ═══════════════════════════════════════════════════════════════

setlocal enabledelayedexpansion

REM Configuration
if "%CHAIN_ID%"=="" set CHAIN_ID=certen-testnet
if "%NUM_VALIDATORS%"=="" set NUM_VALIDATORS=4
if "%OUTPUT_DIR%"=="" set OUTPUT_DIR=genesis-output

echo ===============================================================
echo        CERTEN NETWORK BOOTSTRAP SCRIPT (Windows)
echo ===============================================================
echo.

REM Step 1: Build genesis generator
echo [Step 1/5] Building genesis generator...
if not exist "cmd\generate-genesis\main.go" (
    echo Error: generate-genesis source not found
    exit /b 1
)

cd cmd\generate-genesis
go build -o ..\..\generate-genesis.exe .
cd ..\..
echo [OK] Genesis generator built
echo.

REM Step 2: Generate genesis and validator keys
echo [Step 2/5] Generating genesis configuration...

REM Get current time + 5 minutes for genesis (simplified)
for /f "tokens=*" %%a in ('powershell -command "[DateTime]::UtcNow.AddMinutes(5).ToString('yyyy-MM-ddTHH:mm:ssZ')"') do set GENESIS_TIME=%%a

generate-genesis.exe ^
    -validators=%NUM_VALIDATORS% ^
    -chain-id=%CHAIN_ID% ^
    -output=%OUTPUT_DIR% ^
    -genesis-time="%GENESIS_TIME%" ^
    -voting-power=10

echo [OK] Genesis configuration generated
echo.

REM Step 3: Copy database migrations
echo [Step 3/5] Setting up database migrations...
if not exist "migrations" mkdir migrations
if exist "..\independant_validator\pkg\database\migrations\001_initial_schema.sql" (
    copy "..\independant_validator\pkg\database\migrations\001_initial_schema.sql" "migrations\" >nul
    echo [OK] Database migrations copied
) else (
    echo [WARN] Could not find migrations file
)
echo.

REM Step 4: Create .env file
echo [Step 4/5] Creating network environment file...
(
echo # Certen Network Configuration
echo CHAIN_ID=%CHAIN_ID%
echo NETWORK_NAME=%CHAIN_ID%
echo POSTGRES_PASSWORD=certen_network_pass
echo.
echo # Accumulate Network
echo ACCUMULATE_URL=https://kermit.accumulatenetwork.io/v2
echo.
echo # Ethereum Network ^(Sepolia Testnet^)
echo ETHEREUM_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
echo ETH_CHAIN_ID=11155111
echo.
echo # Validator Ethereum Private Keys ^(CHANGE THESE!^)
echo ETH_PRIVATE_KEY_1=0x0000000000000000000000000000000000000000000000000000000000000001
echo ETH_PRIVATE_KEY_2=0x0000000000000000000000000000000000000000000000000000000000000002
echo ETH_PRIVATE_KEY_3=0x0000000000000000000000000000000000000000000000000000000000000003
echo ETH_PRIVATE_KEY_4=0x0000000000000000000000000000000000000000000000000000000000000004
echo.
echo # Contract Addresses ^(Sepolia^)
echo CERTEN_CONTRACT_ADDRESS=0xEb17eBd351D2e040a0cB3026a3D04BEc182d8b98
echo CERTEN_ANCHOR_V3_ADDRESS=0xEb17eBd351D2e040a0cB3026a3D04BEc182d8b98
echo BLS_ZK_VERIFIER_ADDRESS=0x631B6444216b981561034655349F8a28962DcC5F
) > .env
echo [OK] Environment file created
echo.

REM Step 5: Start the network
echo [Step 5/5] Starting the network...
echo.
echo Network Configuration:
echo   Chain ID:       %CHAIN_ID%
echo   Validators:     %NUM_VALIDATORS%
echo   Genesis Time:   %GENESIS_TIME%
echo.

echo Starting PostgreSQL...
docker-compose -f docker-compose-network.yml up -d postgres

echo Waiting for PostgreSQL to be healthy...
timeout /t 10 /nobreak >nul

echo Starting validators...
docker-compose -f docker-compose-network.yml up -d validator-1 validator-2 validator-3 validator-4

echo.
echo ===============================================================
echo              NETWORK STARTED SUCCESSFULLY
echo ===============================================================
echo.
echo Validator endpoints:
echo   validator-1: http://localhost:8081/health
echo   validator-2: http://localhost:8082/health
echo   validator-3: http://localhost:8083/health
echo   validator-4: http://localhost:8084/health
echo.
echo CometBFT RPC endpoints:
echo   validator-1: http://localhost:26671/status
echo   validator-2: http://localhost:26672/status
echo   validator-3: http://localhost:26673/status
echo   validator-4: http://localhost:26674/status
echo.
echo Commands:
echo   View logs:    docker-compose -f docker-compose-network.yml logs -f
echo   Stop network: docker-compose -f docker-compose-network.yml down
echo   Restart:      docker-compose -f docker-compose-network.yml restart
echo.

endlocal
