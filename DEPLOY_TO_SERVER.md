# Deploy Certen Testnet to 116.202.214.38

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 SERVER: 116.202.214.38                          │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ validator-1 │  │ validator-2 │  │ validator-3 │             │
│  │ :8081/:26656│  │ :8082/:26666│  │ :8083/:26676│             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         └────────────────┼────────────────┘                     │
│                    ┌─────┴─────┐                                │
│                    │ PostgreSQL│                                │
│                    │   :5432   │                                │
│                    └───────────┘                                │
└─────────────────────────────────────────────────────────────────┘
                           │
                    PUBLIC INTERNET
                           │
┌─────────────────────────────────────────────────────────────────┐
│                    YOUR LOCAL MACHINE                           │
│                   ┌─────────────┐                               │
│                   │ validator-4 │  ← Your independent validator │
│                   │   (local)   │                               │
│                   └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: Prepare Local Files

From your Windows machine, run:

```powershell
cd C:\Accumulate_Stuff\certen\certen-network-set-up

# Generate genesis (already done, but regenerate if needed)
.\generate-genesis.exe --validators=4 --chain-id=certen-testnet --output=.\genesis-output
```

## Step 2: SSH to Server and Install Docker

```bash
ssh root@116.202.214.38

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Install docker compose
apt-get update && apt-get install -y docker-compose-plugin

# Create directory
mkdir -p /opt/certen-testnet
cd /opt/certen-testnet
```

## Step 3: Upload Files to Server

From Windows (using Git Bash or PowerShell with OpenSSH):

```bash
# Option A: Use SCP
scp -r C:/Accumulate_Stuff/certen/independant_validator root@116.202.214.38:/opt/certen-testnet/validator-build

# Option B: Or clone from git if you have a repo
```

## Step 4: Create Docker Compose on Server

SSH to server and create the compose file:

```bash
ssh root@116.202.214.38
cd /opt/certen-testnet

cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: certen-postgres
    environment:
      POSTGRES_DB: certen
      POSTGRES_USER: certen
      POSTGRES_PASSWORD: certen_testnet_2026
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./validator-build/pkg/database/migrations/001_initial_schema.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U certen -d certen"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    networks:
      - certen-net

  validator-1:
    build:
      context: ./validator-build
      dockerfile: Dockerfile
    container_name: certen-validator-1
    hostname: validator-1
    ports:
      - "8081:8080"    # API
      - "26656:26656"  # P2P
      - "26657:26657"  # RPC
    environment:
      VALIDATOR_ID: validator-1
      DATABASE_URL: postgres://certen:certen_testnet_2026@postgres:5432/certen?sslmode=disable
      COMETBFT_ENABLED: "true"
      COMETBFT_MODE: validator
      COMETBFT_CHAIN_ID: certen-testnet
      ACCUMULATE_URL: https://kermit.accumulatenetwork.io/v2
      ETHEREUM_URL: https://eth-sepolia.g.alchemy.com/v2/demo
      ETH_CHAIN_ID: "11155111"
      ETH_PRIVATE_KEY: "0x0000000000000000000000000000000000000000000000000000000000000001"
      CERTEN_CONTRACT_ADDRESS: "0xEb17eBd351D2e040a0cB3026a3D04BEc182d8b98"
      ATTESTATION_PEERS: http://validator-2:8080,http://validator-3:8080
      ATTESTATION_REQUIRED_COUNT: "2"
      BLS_ZK_TESTING_MODE: "true"
      LOG_LEVEL: info
    volumes:
      - validator1_data:/app/data
      - validator1_keys:/app/bft-keys
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - certen-net

  validator-2:
    build:
      context: ./validator-build
      dockerfile: Dockerfile
    container_name: certen-validator-2
    hostname: validator-2
    ports:
      - "8082:8080"
      - "26666:26656"
      - "26667:26657"
    environment:
      VALIDATOR_ID: validator-2
      DATABASE_URL: postgres://certen:certen_testnet_2026@postgres:5432/certen?sslmode=disable
      COMETBFT_ENABLED: "true"
      COMETBFT_MODE: validator
      COMETBFT_CHAIN_ID: certen-testnet
      ACCUMULATE_URL: https://kermit.accumulatenetwork.io/v2
      ETHEREUM_URL: https://eth-sepolia.g.alchemy.com/v2/demo
      ETH_CHAIN_ID: "11155111"
      ETH_PRIVATE_KEY: "0x0000000000000000000000000000000000000000000000000000000000000002"
      CERTEN_CONTRACT_ADDRESS: "0xEb17eBd351D2e040a0cB3026a3D04BEc182d8b98"
      ATTESTATION_PEERS: http://validator-1:8080,http://validator-3:8080
      ATTESTATION_REQUIRED_COUNT: "2"
      BLS_ZK_TESTING_MODE: "true"
      LOG_LEVEL: info
    volumes:
      - validator2_data:/app/data
      - validator2_keys:/app/bft-keys
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - certen-net

  validator-3:
    build:
      context: ./validator-build
      dockerfile: Dockerfile
    container_name: certen-validator-3
    hostname: validator-3
    ports:
      - "8083:8080"
      - "26676:26656"
      - "26677:26657"
    environment:
      VALIDATOR_ID: validator-3
      DATABASE_URL: postgres://certen:certen_testnet_2026@postgres:5432/certen?sslmode=disable
      COMETBFT_ENABLED: "true"
      COMETBFT_MODE: validator
      COMETBFT_CHAIN_ID: certen-testnet
      ACCUMULATE_URL: https://kermit.accumulatenetwork.io/v2
      ETHEREUM_URL: https://eth-sepolia.g.alchemy.com/v2/demo
      ETH_CHAIN_ID: "11155111"
      ETH_PRIVATE_KEY: "0x0000000000000000000000000000000000000000000000000000000000000003"
      CERTEN_CONTRACT_ADDRESS: "0xEb17eBd351D2e040a0cB3026a3D04BEc182d8b98"
      ATTESTATION_PEERS: http://validator-1:8080,http://validator-2:8080
      ATTESTATION_REQUIRED_COUNT: "2"
      BLS_ZK_TESTING_MODE: "true"
      LOG_LEVEL: info
    volumes:
      - validator3_data:/app/data
      - validator3_keys:/app/bft-keys
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - certen-net

volumes:
  postgres_data:
  validator1_data:
  validator1_keys:
  validator2_data:
  validator2_keys:
  validator3_data:
  validator3_keys:

networks:
  certen-net:
    driver: bridge
EOF
```

## Step 5: Open Firewall Ports

```bash
# If using ufw
ufw allow 8081:8083/tcp   # Validator APIs
ufw allow 26656/tcp       # CometBFT P2P (validator-1)
ufw allow 26666/tcp       # CometBFT P2P (validator-2)
ufw allow 26676/tcp       # CometBFT P2P (validator-3)
ufw allow 26657/tcp       # CometBFT RPC
ufw reload
```

## Step 6: Build and Start Testnet

```bash
cd /opt/certen-testnet

# Build (takes ~5-10 minutes first time)
docker compose build

# Start
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

## Step 7: Verify Testnet is Running

```bash
# Check health endpoints
curl http://localhost:8081/health
curl http://localhost:8082/health
curl http://localhost:8083/health

# Check CometBFT status
curl http://localhost:26657/status | jq '.result.sync_info'
```

Expected health response:
```json
{"status":"ok","phase":"5","consensus":"cometbft","database":"connected",...}
```

## Step 8: Get Node IDs for Local Validator

```bash
# Get validator-1 node ID
curl -s http://localhost:26657/status | jq -r '.result.node_info.id'

# Example output: 711cf92cde9c9fb78c4b595fdb7deba181a1c1e5
```

## Step 9: Configure Local Validator

On your Windows machine, update `C:\Accumulate_Stuff\certen\independant_validator\.env`:

```env
# Connect to testnet on 116.202.214.38
VALIDATOR_ID=validator-4

# Get these node IDs from Step 8
COMETBFT_P2P_PERSISTENT_PEERS=<nodeID1>@116.202.214.38:26656,<nodeID2>@116.202.214.38:26666,<nodeID3>@116.202.214.38:26676

# Attestation peers
ATTESTATION_PEERS=http://116.202.214.38:8081,http://116.202.214.38:8082,http://116.202.214.38:8083
ATTESTATION_REQUIRED_COUNT=3
```

## Step 10: Start Local Validator

```powershell
cd C:\Accumulate_Stuff\certen\independant_validator
docker-compose up -d

# Check logs
docker-compose logs -f validator
```

## Verification

Your local validator should:
1. Connect to the 3 server validators via P2P
2. Sync blocks from the testnet
3. Participate in consensus once synced

Check connection:
```bash
# On server - should show 1 peer (your local validator)
curl http://116.202.214.38:26657/net_info | jq '.result.n_peers'

# On local - should show 3 peers (server validators)
curl http://localhost:26667/net_info | jq '.result.n_peers'
```

## Port Summary

| Service | API | P2P | RPC |
|---------|-----|-----|-----|
| validator-1 (server) | :8081 | :26656 | :26657 |
| validator-2 (server) | :8082 | :26666 | :26667 |
| validator-3 (server) | :8083 | :26676 | :26677 |
| validator-4 (local) | :8086 | :26666 | :26667 |

## Troubleshooting

**Build fails on server:**
```bash
# Check disk space
df -h

# Check memory
free -m

# View build logs
docker compose build --progress=plain 2>&1 | tee build.log
```

**Validators not connecting:**
```bash
# Check firewall
ufw status

# Check if ports are listening
netstat -tlnp | grep 26656

# Check Docker networking
docker network inspect certen-testnet_certen-net
```

**Local validator can't connect:**
```bash
# Test connectivity
nc -zv 116.202.214.38 26656

# Check if server ports are open
nmap -p 26656,26666,26676 116.202.214.38
```
