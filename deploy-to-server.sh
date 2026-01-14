#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Certen Testnet Deployment Script
# Deploys 3 validators to remote Ubuntu server
# ═══════════════════════════════════════════════════════════════

set -e

# Configuration
REMOTE_HOST="${REMOTE_HOST:-116.202.214.38}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_DIR="/opt/certen-testnet"
CHAIN_ID="certen-testnet"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       CERTEN TESTNET DEPLOYMENT                               ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║ Target: ${REMOTE_USER}@${REMOTE_HOST}                                      ║"
echo "║ Path:   ${REMOTE_DIR}                                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Generate fresh genesis for the server
echo "[Step 1/5] Generating genesis configuration..."
./generate-genesis.exe \
    --validators=4 \
    --chain-id=${CHAIN_ID} \
    --output=./genesis-output \
    --voting-power=10 \
    --base-host=${REMOTE_HOST}

echo ""

# Step 2: Create server deployment package
echo "[Step 2/5] Creating deployment package..."
mkdir -p deploy-package

# Create docker-compose for server (3 validators)
cat > deploy-package/docker-compose.yml << 'COMPOSE_EOF'
# Certen Testnet - 3 Validator Setup
# Server: 116.202.214.38

services:
  postgres:
    image: postgres:15-alpine
    container_name: certen-postgres
    environment:
      POSTGRES_DB: certen
      POSTGRES_USER: certen
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-certen_secure_pass}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./migrations/001_initial_schema.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro
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
    image: certen-validator:latest
    build:
      context: ./validator-build
      dockerfile: Dockerfile
    container_name: certen-validator-1
    hostname: validator-1
    ports:
      - "8081:8080"
      - "9091:9090"
      - "26656:26656"
      - "26657:26657"
    environment:
      VALIDATOR_ID: validator-1
      DATABASE_URL: postgres://certen:${POSTGRES_PASSWORD:-certen_secure_pass}@postgres:5432/certen?sslmode=disable
      COMETBFT_ENABLED: "true"
      COMETBFT_MODE: validator
      COMETBFT_CHAIN_ID: certen-testnet
      COMETBFT_P2P_LADDR: tcp://0.0.0.0:26656
      COMETBFT_RPC_LADDR: tcp://0.0.0.0:26657
      COMETBFT_P2P_PERSISTENT_PEERS: ""
      ACCUMULATE_URL: https://kermit.accumulatenetwork.io/v2
      ETHEREUM_URL: ${ETHEREUM_URL:-https://eth-sepolia.g.alchemy.com/v2/demo}
      ETH_CHAIN_ID: "11155111"
      ETH_PRIVATE_KEY: ${ETH_PRIVATE_KEY_1:-0x0000000000000000000000000000000000000000000000000000000000000001}
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
    image: certen-validator:latest
    container_name: certen-validator-2
    hostname: validator-2
    ports:
      - "8082:8080"
      - "9092:9090"
      - "26666:26656"
      - "26667:26657"
    environment:
      VALIDATOR_ID: validator-2
      DATABASE_URL: postgres://certen:${POSTGRES_PASSWORD:-certen_secure_pass}@postgres:5432/certen?sslmode=disable
      COMETBFT_ENABLED: "true"
      COMETBFT_MODE: validator
      COMETBFT_CHAIN_ID: certen-testnet
      COMETBFT_P2P_LADDR: tcp://0.0.0.0:26656
      COMETBFT_RPC_LADDR: tcp://0.0.0.0:26657
      COMETBFT_P2P_PERSISTENT_PEERS: ""
      ACCUMULATE_URL: https://kermit.accumulatenetwork.io/v2
      ETHEREUM_URL: ${ETHEREUM_URL:-https://eth-sepolia.g.alchemy.com/v2/demo}
      ETH_CHAIN_ID: "11155111"
      ETH_PRIVATE_KEY: ${ETH_PRIVATE_KEY_2:-0x0000000000000000000000000000000000000000000000000000000000000002}
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
      validator-1:
        condition: service_started
    restart: unless-stopped
    networks:
      - certen-net

  validator-3:
    image: certen-validator:latest
    container_name: certen-validator-3
    hostname: validator-3
    ports:
      - "8083:8080"
      - "9093:9090"
      - "26676:26656"
      - "26677:26657"
    environment:
      VALIDATOR_ID: validator-3
      DATABASE_URL: postgres://certen:${POSTGRES_PASSWORD:-certen_secure_pass}@postgres:5432/certen?sslmode=disable
      COMETBFT_ENABLED: "true"
      COMETBFT_MODE: validator
      COMETBFT_CHAIN_ID: certen-testnet
      COMETBFT_P2P_LADDR: tcp://0.0.0.0:26656
      COMETBFT_RPC_LADDR: tcp://0.0.0.0:26657
      COMETBFT_P2P_PERSISTENT_PEERS: ""
      ACCUMULATE_URL: https://kermit.accumulatenetwork.io/v2
      ETHEREUM_URL: ${ETHEREUM_URL:-https://eth-sepolia.g.alchemy.com/v2/demo}
      ETH_CHAIN_ID: "11155111"
      ETH_PRIVATE_KEY: ${ETH_PRIVATE_KEY_3:-0x0000000000000000000000000000000000000000000000000000000000000003}
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
      validator-1:
        condition: service_started
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
COMPOSE_EOF

# Create .env for server
cat > deploy-package/.env << 'ENV_EOF'
# Certen Testnet Configuration
POSTGRES_PASSWORD=certen_testnet_2026

# Ethereum (Sepolia) - UPDATE THESE!
ETHEREUM_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
ETH_PRIVATE_KEY_1=0x0000000000000000000000000000000000000000000000000000000000000001
ETH_PRIVATE_KEY_2=0x0000000000000000000000000000000000000000000000000000000000000002
ETH_PRIVATE_KEY_3=0x0000000000000000000000000000000000000000000000000000000000000003
ENV_EOF

# Copy migrations
cp -r migrations deploy-package/

# Copy validator build context (the independant_validator)
mkdir -p deploy-package/validator-build
cp -r ../independant_validator/* deploy-package/validator-build/ 2>/dev/null || true

# Create setup script for server
cat > deploy-package/setup.sh << 'SETUP_EOF'
#!/bin/bash
set -e

echo "Setting up Certen Testnet..."

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Install docker-compose plugin if not present
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get update
    apt-get install -y docker-compose-plugin
fi

# Open firewall ports
if command -v ufw &> /dev/null; then
    echo "Configuring firewall..."
    ufw allow 8081:8083/tcp  # Validator APIs
    ufw allow 26656/tcp      # CometBFT P2P (validator-1)
    ufw allow 26666/tcp      # CometBFT P2P (validator-2)
    ufw allow 26676/tcp      # CometBFT P2P (validator-3)
    ufw allow 26657/tcp      # CometBFT RPC (validator-1)
fi

# Build and start
echo "Building validator image..."
docker compose build

echo "Starting testnet..."
docker compose up -d

echo ""
echo "Testnet started! Endpoints:"
echo "  validator-1: http://localhost:8081/health"
echo "  validator-2: http://localhost:8082/health"
echo "  validator-3: http://localhost:8083/health"
echo ""
echo "View logs: docker compose logs -f"
SETUP_EOF
chmod +x deploy-package/setup.sh

echo "Deployment package created in ./deploy-package/"
echo ""

# Step 3: Create tarball
echo "[Step 3/5] Creating deployment archive..."
tar -czf certen-testnet-deploy.tar.gz -C deploy-package .
echo "Created: certen-testnet-deploy.tar.gz"
echo ""

# Step 4: Upload to server
echo "[Step 4/5] Uploading to ${REMOTE_HOST}..."
echo "Running: scp certen-testnet-deploy.tar.gz ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"

ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${REMOTE_DIR}"
scp certen-testnet-deploy.tar.gz ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/

echo ""

# Step 5: Extract and setup on server
echo "[Step 5/5] Setting up on server..."
ssh ${REMOTE_USER}@${REMOTE_HOST} << REMOTE_EOF
cd ${REMOTE_DIR}
tar -xzf certen-testnet-deploy.tar.gz
chmod +x setup.sh
./setup.sh
REMOTE_EOF

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              DEPLOYMENT COMPLETE                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Testnet is running on ${REMOTE_HOST}"
echo ""
echo "Validator endpoints:"
echo "  http://${REMOTE_HOST}:8081/health  (validator-1)"
echo "  http://${REMOTE_HOST}:8082/health  (validator-2)"
echo "  http://${REMOTE_HOST}:8083/health  (validator-3)"
echo ""
echo "CometBFT P2P ports (for your local validator):"
echo "  ${REMOTE_HOST}:26656  (validator-1)"
echo "  ${REMOTE_HOST}:26666  (validator-2)"
echo "  ${REMOTE_HOST}:26676  (validator-3)"
echo ""
echo "To connect your local validator, update independant_validator/.env:"
echo "  COMETBFT_P2P_PERSISTENT_PEERS=<nodeID>@${REMOTE_HOST}:26656"
echo "  ATTESTATION_PEERS=http://${REMOTE_HOST}:8081,http://${REMOTE_HOST}:8082,http://${REMOTE_HOST}:8083"
