# Network Architecture - Phase 2

## Overview
Goal 2 Phase 2 implements network isolation to better emulate a production deployment with separate EC2 instances. Each service runs on its own isolated network with a shared bridge network for inter-service communication.

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                         HOST MACHINE                             │
│                                                                   │
│  Browser Client                                                   │
│      ↓                                                            │
│  localhost:8080 (SFU) ←─────┐                                    │
│  localhost:3478 (STUN/TURN) ←┼─┐                                 │
└──────────────────────────────┼─┼─────────────────────────────────┘
                               │ │
                               │ └──────────────────────┐
                               │                        │
┌──────────────────────────────┼────────────────┐  ┌───┼──────────────────────┐
│        coturn-network        │                │  │   │  sfu-network         │
│          (isolated)          │                │  │   │   (isolated)         │
│                              │                │  │   │                      │
│   ┌──────────────────────────┼──────────┐     │  │   │  ┌──────────────────┼──┐
│   │  coturn-server           │          │     │  │   │  │  sfu-server      │  │
│   │  ──────────────           │          │     │  │   │  │  ───────────     │  │
│   │  IP: 172.21.0.2           │          │     │  │   │  │  IP: 172.22.0.2  │  │
│   │  Ports: 3478, 5349        │          │     │  │   │  │  Port: 8080      │  │
│   │  Relay: 49152-49200       │          │     │  │   │  │                  │  │
│   └──────────────────────────┬──────────┘     │  │   │  └──────────────────┬──┘
│                              │                │  │   │                      │
└──────────────────────────────┼────────────────┘  └───┼──────────────────────┘
                               │                        │
                               │                        │
                               └────────┬───────────────┘
                                        │
                       ┌────────────────▼────────────────┐
                       │     shared-network (bridge)     │
                       │     ────────────────────────     │
                       │     coturn: 172.20.0.2          │
                       │     sfu:    172.20.0.3          │
                       │     DNS: container names        │
                       └─────────────────────────────────┘
```

## Network Configuration

### 1. coturn-network (172.21.0.0/16)
- **Purpose**: Isolated network for coturn service
- **Members**: coturn-server only
- **Subnet**: Automatically assigned by Docker
- **Driver**: bridge
- **Isolation**: Cannot directly access sfu-network

### 2. sfu-network (172.22.0.0/16)
- **Purpose**: Isolated network for SFU service
- **Members**: sfu-server only
- **Subnet**: Automatically assigned by Docker
- **Driver**: bridge
- **Isolation**: Cannot directly access coturn-network

### 3. shared-network (172.20.0.0/16)
- **Purpose**: Bridge network for inter-service communication
- **Members**: Both coturn-server and sfu-server
- **Subnet**: Automatically assigned by Docker
- **Driver**: bridge
- **DNS**: Container name resolution enabled
  - `coturn-server` → `172.20.0.2`
  - `sfu-server` → `172.20.0.3`

## Communication Flow

### Browser to SFU
1. Browser accesses `http://localhost:8080`
2. Request hits host port 8080
3. Docker maps to sfu-server container port 8080
4. SFU responds through same path

### Browser to STUN/TURN
1. Browser receives ICE servers from SFU:
   - STUN: `stun:localhost:3478`
   - TURN: `turn:localhost:3478`
2. Browser sends STUN binding request to `localhost:3478`
3. Request hits host port 3478
4. Docker maps to coturn-server container port 3478
5. Coturn responds with server reflexive address

### SFU to Coturn (Future - for server-side TURN allocation)
1. SFU can resolve `coturn-server` via Docker DNS
2. DNS returns `172.20.0.2` (shared-network IP)
3. Communication happens through shared-network bridge
4. No direct network access between isolated networks

## Port Mappings

### coturn-server
| Host Port | Container Port | Protocol | Purpose |
|-----------|----------------|----------|---------|
| 3478 | 3478 | TCP/UDP | STUN/TURN |
| 5349 | 5349 | TCP/UDP | STUN/TURN over TLS |
| 49152-49200 | 49152-49200 | UDP | TURN relay allocations |

### sfu-server
| Host Port | Container Port | Protocol | Purpose |
|-----------|----------------|----------|---------|
| 8080 | 8080 | TCP | HTTP/WebSocket |

## Security Benefits

### Network Isolation
- Each service has its own private network
- Services cannot directly access each other's isolated networks
- Only communicate through controlled shared-network bridge
- Reduces attack surface

### Defense in Depth
- Even if one container is compromised, network isolation limits lateral movement
- Port mappings controlled at host level
- Docker network security policies enforceable

### EC2 Emulation
- Mirrors production architecture with separate instances
- Each "instance" (container) has its own network
- VPC peering emulated by shared-network
- Easy migration to actual EC2 with VPC configuration

## Comparison with Phase 1

| Aspect | Phase 1 | Phase 2 |
|--------|---------|---------|
| Networks | Single (sfu-network) | Three (coturn, sfu, shared) |
| Isolation | None | Per-service isolation |
| Communication | Direct | Via shared bridge |
| EC2 Readiness | Basic | Better emulation |
| Security | Moderate | Enhanced |
| Complexity | Low | Medium |

## Testing Network Isolation

### Verify Network Membership
```bash
# Check coturn networks
docker inspect coturn-server -f '{{range $net, $config := .NetworkSettings.Networks}}{{$net}}: {{$config.IPAddress}}{{"\n"}}{{end}}'

# Check SFU networks
docker inspect sfu-server -f '{{range $net, $config := .NetworkSettings.Networks}}{{$net}}: {{$config.IPAddress}}{{"\n"}}{{end}}'
```

### Verify DNS Resolution
```bash
# From SFU container
docker exec sfu-server getent hosts coturn-server
# Expected: 172.20.0.2 coturn-server

# From coturn container
docker exec coturn-server getent hosts sfu-server
# Expected: 172.20.0.3 sfu-server
```

### Verify Network List
```bash
docker network ls | grep -E 'coturn|sfu|shared'
# Expected: coturn-network, sfu-network, shared-network
```

## Production Deployment Notes

When deploying to AWS EC2:

1. **Replace Docker Networks with VPCs**
   - coturn-network → EC2 instance in VPC A
   - sfu-network → EC2 instance in VPC B
   - shared-network → VPC peering connection

2. **Update DNS Resolution**
   - Replace container names with private IPs or Route53 names
   - Use AWS PrivateLink or VPC peering for communication

3. **Security Groups**
   - Implement EC2 security groups similar to network isolation
   - Allow only necessary ports between instances

4. **Public IP Configuration**
   - Update coturn external-ip to EC2 public IP
   - Update SFU ICE configuration with public IPs
   - Configure NAT Gateway or Elastic IP as needed

5. **TLS/DTLS**
   - Enable TLS/DTLS for production
   - Use AWS Certificate Manager for certificates
   - Update turnserver.conf with certificate paths

## Related Documentation
- [README.md](README.md) - Project overview and goals
- [TESTING_GOAL2.md](TESTING_GOAL2.md) - Testing procedures
- [docker-compose.yml](docker-compose.yml) - Network configuration
