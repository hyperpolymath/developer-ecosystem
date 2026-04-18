#!/usr/bin/env bash
# Starts container services and ensures the Kafka topic exists.

set -e
echo "[kafka] Bringing up Kafka + Zookeeper + ArangoDB for audit..."

COMPOSE_FILE="ops/podman-compose.yml"

# Determine which compose tool to use
if command -v podman-compose >/dev/null 2>&1; then
    COMPOSE_CMD="podman-compose -f $COMPOSE_FILE"
    # Ensure podman service is running if needed (common podman-compose requirement)
    # Note: On some systems, this needs to be running or 'podman machine' started.
    echo "Attempting to start services using podman-compose..."
else
    # Fallback to standard docker compose command
    COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
    echo "Falling back to standard docker compose..."
fi

# Start containers
$COMPOSE_CMD up -d

echo "[kafka] Waiting for Kafka to be ready (5s delay)..."
sleep 5

# Create the audit topic (must use the specific container name)
# We use 'podman exec' if podman-compose was used, or 'docker exec' otherwise.
if [[ "$COMPOSE_CMD" == podman-compose* ]]; then
    EXEC_CMD="podman exec"
else
    EXEC_CMD="docker exec"
fi

$EXEC_CMD filegov-kafka bash -lc "/opt/kafka/bin/kafka-topics.sh --create --if-not-exists --bootstrap-server kafka:9092 --replication-factor 1 --partitions 1 --topic audit.events.filegov" || true

echo "[kafka] Kafka infrastructure is ready."
