#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Certen Network Bootstrap Script
# Initializes and starts a multi-validator Certen BFT network
# ═══════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHAIN_ID="${CHAIN_ID:-certen-testnet}"
NUM_VALIDATORS="${NUM_VALIDATORS:-4}"
GENESIS_DELAY_MINUTES="${GENESIS_DELAY_MINUTES:-2}"
OUTPUT_DIR="${OUTPUT_DIR:-./genesis-output}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       CERTEN NETWORK BOOTSTRAP SCRIPT                         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Build genesis generator
echo -e "${YELLOW}[Step 1/5] Building genesis generator...${NC}"
if [ ! -f "./cmd/generate-genesis/main.go" ]; then
    echo -e "${RED}Error: generate-genesis source not found${NC}"
    exit 1
fi

cd cmd/generate-genesis
go build -o ../../generate-genesis .
cd ../..
echo -e "${GREEN}✓ Genesis generator built${NC}"
echo ""

# Step 2: Generate genesis and validator keys
echo -e "${YELLOW}[Step 2/5] Generating genesis configuration...${NC}"
GENESIS_TIME=$(date -u -d "+${GENESIS_DELAY_MINUTES} minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
               date -u -v+${GENESIS_DELAY_MINUTES}M +"%Y-%m-%dT%H:%M:%SZ")

./generate-genesis \
    --validators=${NUM_VALIDATORS} \
    --chain-id=${CHAIN_ID} \
    --output=${OUTPUT_DIR} \
    --genesis-time="${GENESIS_TIME}" \
    --voting-power=10

echo -e "${GREEN}✓ Genesis configuration generated${NC}"
echo ""

# Step 3: Copy database migrations
echo -e "${YELLOW}[Step 3/5] Setting up database migrations...${NC}"
mkdir -p ./migrations
if [ -f "../independant_validator/pkg/database/migrations/001_initial_schema.sql" ]; then
    cp ../independant_validator/pkg/database/migrations/001_initial_schema.sql ./migrations/
    echo -e "${GREEN}✓ Database migrations copied${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Could not find migrations file${NC}"
fi
echo ""

# Step 4: Create .env file for docker-compose
echo -e "${YELLOW}[Step 4/5] Creating network environment file...${NC}"
cat > .env << EOF
# Certen Network Configuration
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

CHAIN_ID=${CHAIN_ID}
NETWORK_NAME=${CHAIN_ID}
POSTGRES_PASSWORD=certen_network_pass_$(openssl rand -hex 8 2>/dev/null || echo "changeme")

# Accumulate Network
ACCUMULATE_URL=https://kermit.accumulatenetwork.io/v2

# Ethereum Network (Sepolia Testnet)
ETHEREUM_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
ETH_CHAIN_ID=11155111

# Validator Ethereum Private Keys (CHANGE THESE!)
ETH_PRIVATE_KEY_1=0x0000000000000000000000000000000000000000000000000000000000000001
ETH_PRIVATE_KEY_2=0x0000000000000000000000000000000000000000000000000000000000000002
ETH_PRIVATE_KEY_3=0x0000000000000000000000000000000000000000000000000000000000000003
ETH_PRIVATE_KEY_4=0x0000000000000000000000000000000000000000000000000000000000000004

# Contract Addresses (Sepolia)
CERTEN_CONTRACT_ADDRESS=0xEb17eBd351D2e040a0cB3026a3D04BEc182d8b98
CERTEN_ANCHOR_V3_ADDRESS=0xEb17eBd351D2e040a0cB3026a3D04BEc182d8b98
BLS_ZK_VERIFIER_ADDRESS=0x631B6444216b981561034655349F8a28962DcC5F

# Persistent Peers (read from generated config)
PERSISTENT_PEERS=$(cat ${OUTPUT_DIR}/peers.txt | grep -v "^#" | tr -d '\n')
EOF
echo -e "${GREEN}✓ Environment file created${NC}"
echo ""

# Step 5: Start the network
echo -e "${YELLOW}[Step 5/5] Starting the network...${NC}"
echo ""
echo -e "${BLUE}Network Configuration:${NC}"
echo "  Chain ID:       ${CHAIN_ID}"
echo "  Validators:     ${NUM_VALIDATORS}"
echo "  Genesis Time:   ${GENESIS_TIME}"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker-compose not found${NC}"
    exit 1
fi

# Use docker compose (v2) or docker-compose (v1)
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

echo -e "${YELLOW}Starting PostgreSQL...${NC}"
$COMPOSE_CMD -f docker-compose-network.yml up -d postgres

echo -e "${YELLOW}Waiting for PostgreSQL to be healthy...${NC}"
sleep 10

echo -e "${YELLOW}Starting validators...${NC}"
$COMPOSE_CMD -f docker-compose-network.yml up -d validator-1 validator-2 validator-3 validator-4

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              NETWORK STARTED SUCCESSFULLY                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Validator endpoints:"
echo "  validator-1: http://localhost:8081/health"
echo "  validator-2: http://localhost:8082/health"
echo "  validator-3: http://localhost:8083/health"
echo "  validator-4: http://localhost:8084/health"
echo ""
echo "CometBFT RPC endpoints:"
echo "  validator-1: http://localhost:26671/status"
echo "  validator-2: http://localhost:26672/status"
echo "  validator-3: http://localhost:26673/status"
echo "  validator-4: http://localhost:26674/status"
echo ""
echo "Commands:"
echo "  View logs:    $COMPOSE_CMD -f docker-compose-network.yml logs -f"
echo "  Stop network: $COMPOSE_CMD -f docker-compose-network.yml down"
echo "  Restart:      $COMPOSE_CMD -f docker-compose-network.yml restart"
echo ""
echo -e "${YELLOW}Waiting for genesis time: ${GENESIS_TIME}${NC}"
