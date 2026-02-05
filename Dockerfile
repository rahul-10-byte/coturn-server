# Dockerfile for Coturn STUN/TURN Server
# Phase 1: Proof of Concept
# Base: Ubuntu 22.04 LTS

FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install coturn and dependencies
RUN apt-get update && apt-get install -y \
    coturn \
    net-tools \
    iproute2 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create directory for logs
RUN mkdir -p /var/log && touch /var/log/turnserver.log

# Copy configuration file
COPY coturn/turnserver.conf /etc/turnserver.conf

# Create a startup script to detect host IP
RUN echo '#!/bin/bash\n\
# Detect host IP for relay\n\
RELAY_IP=${RELAY_IP:-$(hostname -I | awk "{print \$1}")}\n\
echo "Using relay IP: $RELAY_IP"\n\
\n\
# Get container IPs for binding\n\
CONTAINER_IP=$(hostname -I | awk "{print \$1}")\n\
echo "Container IP: $CONTAINER_IP"\n\
\n\
# Start turnserver with correct configuration\n\
# --listening-ip: bind to all interfaces in container\n\
# --external-ip: advertise the host IP to clients\n\
# relay will bind to container IP automatically\n\
exec turnserver \
    -c /etc/turnserver.conf \
    --listening-ip=0.0.0.0 \
    --external-ip=$RELAY_IP \
    --verbose\n\
' > /usr/local/bin/start-coturn.sh && chmod +x /usr/local/bin/start-coturn.sh

# Expose STUN/TURN ports
# 3478 - STUN/TURN UDP/TCP
# 5349 - STUN/TURN over TLS/DTLS
# 49152-65535 - Relay port range
EXPOSE 3478/tcp 3478/udp
EXPOSE 5349/tcp 5349/udp
EXPOSE 49152-65535/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD netstat -tuln | grep -q 3478 || exit 1

# Run coturn
ENTRYPOINT ["/usr/local/bin/start-coturn.sh"]
