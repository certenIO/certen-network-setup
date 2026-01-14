# Certen Network Setup

Tools and configuration for bootstrapping a Certen Protocol BFT validator network.

## Quick Start

### Windows
```batch
bootstrap-network.bat
```

### Linux/macOS
```bash
chmod +x bootstrap-network.sh
./bootstrap-network.sh
```

## Directory Structure

```
certen-network-set-up/
├── cmd/
│   └── generate-genesis/
│       └── main.go              # Genesis generator source
├── genesis-output/              # Generated after running bootstrap
│   ├── genesis.json             # Shared genesis file
│   ├── network-config.json      # Full network configuration
│   ├── peers.txt                # Persistent peers list
│   └── validators/
│       ├── validator-1/
│       │   ├── config/
│       │   │   ├── genesis.json
│       │   │   ├── node_key.json
│       │   │   └── priv_validator_key.json
│       │   ├── data/
│       │   │   └── priv_validator_state.json
│       │   └── .env
│       ├── validator-2/
│       ├── validator-3/
│       └── validator-4/
├── migrations/
│   └── 001_initial_schema.sql   # Database schema
├── docker-compose-network.yml   # Multi-validator compose
├── bootstrap-network.sh         # Linux/macOS bootstrap
├── bootstrap-network.bat        # Windows bootstrap
├── go.mod                       # Go module
├── .env                         # Network environment (generated)
└── README.md                    # This file
```

## Manual Setup

### 1. Build the Genesis Generator

```bash
cd cmd/generate-genesis
go build -o ../../generate-genesis .
cd ../..
```

### 2. Generate Genesis Configuration

```bash
./generate-genesis \
    --validators=4 \
    --chain-id=certen-mainnet \
    --output=./genesis-output \
    --genesis-time="2026-01-15T00:00:00Z" \
    --voting-power=10
```

**Options:**
| Flag | Default | Description |
|------|---------|-------------|
| `--validators` | 4 | Number of validators |
| `--chain-id` | certen-mainnet | Network chain ID |
| `--output` | ./genesis-output | Output directory |
| `--genesis-time` | now + 5 min | Genesis time (RFC3339) |
| `--voting-power` | 10 | Power per validator |
| `--base-port` | 26656 | Base P2P port |
| `--base-host` | validator | Hostname pattern |

### 3. Configure Environment

Edit `.env` with your credentials:

```env
# Required: Ethereum RPC endpoint
ETHEREUM_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Required: Validator private keys (one per validator)
ETH_PRIVATE_KEY_1=0x_YOUR_PRIVATE_KEY_1
ETH_PRIVATE_KEY_2=0x_YOUR_PRIVATE_KEY_2
ETH_PRIVATE_KEY_3=0x_YOUR_PRIVATE_KEY_3
ETH_PRIVATE_KEY_4=0x_YOUR_PRIVATE_KEY_4

# Optional: Database password
POSTGRES_PASSWORD=your_secure_password
```

### 4. Start the Network

```bash
# Start database first
docker-compose -f docker-compose-network.yml up -d postgres

# Wait for database
sleep 10

# Start all validators
docker-compose -f docker-compose-network.yml up -d
```

### 5. Verify Network Health

```bash
# Check validator health endpoints
curl http://localhost:8081/health
curl http://localhost:8082/health
curl http://localhost:8083/health
curl http://localhost:8084/health

# Check CometBFT consensus status
curl http://localhost:26671/status | jq '.result.sync_info'
```

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CERTEN VALIDATOR NETWORK                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ Validator-1 │◄──►│ Validator-2 │◄──►│ Validator-3 │         │
│  │  :8081      │    │  :8082      │    │  :8083      │         │
│  │  :26671     │    │  :26672     │    │  :26673     │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│                   ┌────────┴────────┐                          │
│                   │   Validator-4   │                          │
│                   │     :8084       │                          │
│                   │     :26674      │                          │
│                   └────────┬────────┘                          │
│                            │                                    │
│                   ┌────────┴────────┐                          │
│                   │   PostgreSQL    │                          │
│                   │     :5432       │                          │
│                   └─────────────────┘                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Port Mappings

| Service | API Port | Metrics | P2P Port | RPC Port |
|---------|----------|---------|----------|----------|
| validator-1 | 8081 | 9091 | 26661 | 26671 |
| validator-2 | 8082 | 9092 | 26662 | 26672 |
| validator-3 | 8083 | 9093 | 26663 | 26673 |
| validator-4 | 8084 | 9094 | 26664 | 26674 |
| postgres | - | - | - | 5432 |

## Consensus Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Validators | 4 | Total validator count |
| Byzantine Threshold | 1 | Max faulty nodes (f) |
| Consensus Quorum | 3 | Required votes (2f+1) |
| Voting Power | 10 each | Equal power distribution |
| Block Time | ~1-3s | CometBFT default |

## Commands Reference

```bash
# View all logs
docker-compose -f docker-compose-network.yml logs -f

# View specific validator logs
docker-compose -f docker-compose-network.yml logs -f validator-1

# Stop network
docker-compose -f docker-compose-network.yml down

# Stop and remove volumes (DESTROYS DATA)
docker-compose -f docker-compose-network.yml down -v

# Restart specific validator
docker-compose -f docker-compose-network.yml restart validator-1

# Scale validators (if using replicas)
docker-compose -f docker-compose-network.yml up -d --scale validator=4

# Check container status
docker-compose -f docker-compose-network.yml ps
```

## Distributed Deployment

For deploying validators across multiple machines:

### 1. Generate Genesis on Coordinator

```bash
./generate-genesis --validators=4 --chain-id=certen-production
```

### 2. Distribute Validator Configs

Copy to each validator node:
- `genesis-output/validators/validator-N/` → Node N
- `genesis-output/genesis.json` → All nodes
- `genesis-output/peers.txt` → All nodes

### 3. Configure Each Node

On each validator machine, update the `.env`:

```env
# Use actual hostnames/IPs
COMETBFT_P2P_PERSISTENT_PEERS=nodeID1@validator-1.example.com:26656,nodeID2@validator-2.example.com:26656,...

# Attestation peers with public URLs
ATTESTATION_PEERS=http://validator-1.example.com:8080,http://validator-2.example.com:8080,...
```

### 4. Start Validators

Start all validators **before** genesis time:

```bash
# On each node
docker-compose -f docker-compose.yml up -d
```

## Troubleshooting

### Validators Not Connecting

1. Check persistent peers are correctly configured
2. Verify firewall allows P2P ports (26656)
3. Check all validators use same genesis.json

```bash
# Compare genesis hashes
sha256sum genesis-output/validators/*/config/genesis.json
```

### Consensus Not Progressing

1. Ensure 2f+1 validators are running (3 of 4)
2. Check validators have synced clocks
3. Verify genesis time has passed

```bash
# Check CometBFT status
curl http://localhost:26671/status | jq '.result.sync_info.catching_up'
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
docker-compose -f docker-compose-network.yml logs postgres

# Verify database is accessible
docker exec certen-postgres pg_isready -U certen -d certen
```

## Security Considerations

1. **Private Keys**: Never commit `.env` files with real private keys
2. **Database**: Change default PostgreSQL password in production
3. **Network**: Use TLS for inter-validator communication in production
4. **Firewall**: Restrict P2P ports to known validator IPs
5. **Keys**: Store validator keys in secure key management system

## Next Steps

After network is running:

1. **Register Validators**: Call `registerValidator()` on CertenAnchorV3 contract
2. **Fund Validators**: Ensure each validator has ETH for gas
3. **Monitor**: Set up Prometheus/Grafana dashboards
4. **Backup**: Configure automated key and database backups
