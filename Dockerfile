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

# Copy configuration file (compose bind-mount can override this path)
COPY coturn/turnserver.conf /etc/coturn/turnserver.conf

# Create a startup script.
RUN echo '#!/bin/bash\n\
# Show container IP for quick diagnostics\n\
CONTAINER_IP=$(hostname -I | awk "{print \$1}")\n\
echo "Container IP: $CONTAINER_IP"\n\
\n\
# Start turnserver using the mounted config file only.\n\
# Avoid command-line external-ip overrides because they can conflict\n\
# with EC2 public/private mapping in turnserver.conf.\n\
exec turnserver \
    -c /etc/coturn/turnserver.conf \
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
