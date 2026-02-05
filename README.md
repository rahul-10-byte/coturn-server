# Coturn STUN/TURN Server

STUN/TURN server for NAT traversal in WebRTC applications, providing relay services when direct peer-to-peer connections fail.

## Related Projects

- **SFU Server**: [github.com/tmanomukil/sfu-server](https://github.com/tmanomukil/sfu-server) - WebRTC SFU that connects to this TURN server
- **Flutter App**: [github.com/tmanomukil/sfu-flutter-app](https://github.com/tmanomukil/sfu-flutter-app) - Mobile client
- **Load Test**: [github.com/tmanomukil/sfu-load-test](https://github.com/tmanomukil/sfu-load-test) - Performance testing

## What is Coturn?

Coturn is an open-source STUN and TURN server that enables WebRTC connections across NAT and firewalls:

- **STUN** (Session Traversal Utilities for NAT): Discovers public IP addresses
- **TURN** (Traversal Using Relays around NAT): Relays media when direct connections fail

## Quick Start

### 1. Configuration

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
EXTERNAL_IP=your-public-ip
RELAY_IP=your-public-ip
TURN_USERNAME=your_username
TURN_PASSWORD=your_password
```

For auto-detection of IP (Docker/local):
```env
EXTERNAL_IP=auto
RELAY_IP=auto
```

### 2. Run with Docker

```bash
# Build image
docker build -t coturn-server .

# Run container
docker run -d \
  --network=host \
  -v $(pwd)/coturn:/etc/coturn \
  -e EXTERNAL_IP=auto \
  -e TURN_USERNAME=sfuuser \
  -e TURN_PASSWORD=sfupass123 \
  --name coturn \
  coturn-server
```

**Note**: `--network=host` is recommended for proper NAT traversal and port mapping.

### 3. Verify Server

Test STUN/TURN connectivity using the SFU server's test tool:
```
http://your-sfu-server:8080/test-ice.html
```

Or see [TESTING_GOAL2.md](TESTING_GOAL2.md) for detailed testing procedures.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EXTERNAL_IP` | Public/LAN IP for clients | `auto` (detected) |
| `RELAY_IP` | IP for media relay | `auto` (same as EXTERNAL_IP) |
| `TURN_USERNAME` | TURN auth username | `sfuuser` |
| `TURN_PASSWORD` | TURN auth password | `sfupass123` |
| `LISTENING_PORT` | STUN/TURN port | `3478` |
| `TLS_PORT` | TLS port | `5349` |
| `MIN_PORT` | Min relay port | `49152` |
| `MAX_PORT` | Max relay port | `65535` |
| `REALM` | Auth realm | `sfu.local` |

### Manual Configuration

Edit `coturn/turnserver.conf` directly:

```properties
# Replace placeholders manually
external-ip=YOUR_IP
relay-ip=YOUR_IP
user=username:password
```

### Credential Synchronization

⚠️ **IMPORTANT**: TURN credentials must match between:
1. This Coturn server (`TURN_USERNAME`, `TURN_PASSWORD`)
2. SFU server configuration (see [sfu-server](https://github.com/tmanomukil/sfu-server))

## Ports Required

Ensure these ports are open in your firewall/security group:

| Port | Protocol | Purpose |
|------|----------|---------|
| 3478 | UDP/TCP | STUN/TURN |
| 5349 | TCP | TURN over TLS |
| 49152-65535 | UDP | Media relay range |

For testing/development, you can use a subset like `49152-49200`.

## Docker Networks

For multi-container deployments with SFU server:

```bash
# Create networks
docker network create coturn-network
docker network create shared-network

# Run Coturn
docker run -d \
  --network coturn-network \
  -p 3478:3478/udp \
  -p 3478:3478/tcp \
  -p 5349:5349/tcp \
  -p 49152-49200:49152-49200/udp \
  coturn-server

# Connect to shared network for SFU communication
docker network connect shared-network coturn
```

See [docker-compose.yml](docker-compose.yml) for complete orchestration.

## Project Structure

```
coturn-server/
├── coturn/
│   └── turnserver.conf    - Coturn configuration
├── Dockerfile              - Container build
├── .env.example            - Configuration template
├── NETWORK_ARCHITECTURE.md - Network topology docs
├── TESTING_GOAL2.md        - Testing procedures
└── README.md              - This file
```

## EC2 Deployment

### 1. Launch EC2 Instance

- AMI: Ubuntu 22.04 or Amazon Linux 2023
- Instance type: t3.small or larger
- Storage: 8 GB minimum

### 2. Configure Security Group

Open required ports (see Ports Required section above).

### 3. Install Docker

```bash
# Ubuntu
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo usermod -aG docker $USER
```

### 4. Deploy Coturn

```bash
# Clone repository
git clone https://github.com/tmanomukil/coturn-server.git
cd coturn-server

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Configure
cp .env.example .env
echo "EXTERNAL_IP=$PUBLIC_IP" >> .env
echo "RELAY_IP=$PUBLIC_IP" >> .env

# Build and run
docker build -t coturn-server .
docker run -d --network=host coturn-server
```

### 5. Update SFU Server

Configure SFU server to use this Coturn instance:

```env
# In sfu-server/.env
STUN_SERVER_URL=stun:your-coturn-public-ip:3478
TURN_SERVER_URL=turn:your-coturn-public-ip:3478
TURN_USERNAME=sfuuser
TURN_PASSWORD=sfupass123
```

## Testing

### Basic STUN Test

```bash
# Install stun client
sudo apt install -y stuntman-client

# Test STUN
stunclient your-coturn-ip 3478
```

### Comprehensive Testing

See [TESTING_GOAL2.md](TESTING_GOAL2.md) for:
- STUN functionality testing
- TURN authentication verification
- Relay allocation testing
- Integration testing with SFU

Or use the SFU test tool at:
```
http://your-sfu-ip:8080/test-ice.html
```

## Troubleshooting

### STUN working but TURN failing

- Verify credentials match between Coturn and SFU
- Check relay port range (49152-65535) is open
- Confirm external IP is correctly set
- Review logs: `docker logs coturn`

### "Allocation mismatch" errors

- External IP may be incorrectly configured
- Try `EXTERNAL_IP=auto` for Docker
- For EC2, ensure public IP is used

### Peers can't connect despite TURN

- Test individual components using [TESTING_GOAL2.md](TESTING_GOAL2.md)
- Verify network path from clients to Coturn
- Check firewall rules on both ends

## Architecture

See [NETWORK_ARCHITECTURE.md](NETWORK_ARCHITECTURE.md) for:
- Complete network topology
- Docker network design (coturn-network, sfu-network, shared-network)
- Multi-instance deployment patterns
- Security considerations

## Advanced Configuration

### TLS/DTLS

For production, enable TLS:

1. Generate certificates:
```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /etc/coturn/turn_server_pkey.pem \
  -out /etc/coturn/turn_server_cert.pem \
  -days 365
```

2. Update `turnserver.conf`:
```properties
cert=/etc/coturn/turn_server_cert.pem
pkey=/etc/coturn/turn_server_pkey.pem
```

### Database Backend

For scalability, use PostgreSQL/MySQL instead of flat file credentials:

```properties
psql-userdb="host=db dbname=coturn user=coturn password=pwd"
```

### Monitoring

Enable Prometheus metrics:

```properties
prometheus
prometheus-port=9641
```

## Performance Tuning

For high-load scenarios:

```properties
# Increase allocation limits
max-bps=1000000
bps-capacity=0

# Enable optimization
no-tcp-relay
no-multicast-peers
```

## License

Coturn is licensed under BSD. See LICENSE file.

## Resources

- [Coturn Documentation](https://github.com/coturn/coturn/wiki)
- [WebRTC and NAT Traversal](https://webrtc.org/getting-started/turn-server)
- [SFU Server Integration Guide](https://github.com/tmanomukil/sfu-server)
