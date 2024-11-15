#!/bin/bash

set -e

# Make sure we're at the source of the repo.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

docker_compose_plugin_installed() {
    docker compose version >/dev/null 2>&1
}

if ! command_exists cargo; then
    echo "Error: Cargo is not installed. Please install Cargo (Rust) before running this script."
    exit 1
fi

if ! command_exists docker; then
    echo "Error: Docker is not installed. Please install Docker before running this script."
    exit 1
fi

if ! command_exists protoc; then
    echo "Error: Protoc is not installed. Please refer to the Linera documentation for installation instructions."
    exit 1
fi

if ! docker_compose_plugin_installed; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose before running this script."
    exit 1
fi

# Check if the host is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <host>"
  exit 1
fi

HOST="$1"

# Get the current branch name and replace underscores with dashes
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
FORMATTED_BRANCH_NAME="${BRANCH_NAME//_/-}"
GIT_COMMIT=$(git rev-parse --short HEAD)

# Variables
PORT="19100"
METRICS_PORT="21100"
GENESIS_URL="https://storage.googleapis.com/linera-io-dev-public/$FORMATTED_BRANCH_NAME/genesis.json"
VALIDATOR_CONFIG="docker/validator-config.toml"
GENESIS_CONFIG="docker/genesis.json"

echo "Building Linera binaries"
cargo install --locked --path linera-service

# Create validator configuration file
echo "Creating validator configuration..."
cat > $VALIDATOR_CONFIG <<EOL
server_config_path = "server.json"
host = "$HOST"
port = $PORT
metrics_host = "proxy"
metrics_port = $METRICS_PORT
internal_host = "proxy"
internal_port = 20100
[external_protocol]
Grpc = "ClearText"
[internal_protocol]
Grpc = "ClearText"

[[shards]]
host = "docker-shard-1"
port = $PORT
metrics_host = "docker-shard-1"
metrics_port = $METRICS_PORT

[[shards]]
host = "docker-shard-2"
port = $PORT
metrics_host = "docker-shard-2"
metrics_port = $METRICS_PORT

[[shards]]
host = "docker-shard-3"
port = $PORT
metrics_host = "docker-shard-3"
metrics_port = $METRICS_PORT

[[shards]]
host = "docker-shard-4"
port = $PORT
metrics_host = "docker-shard-4"
metrics_port = $METRICS_PORT
EOL

# Download genesis configuration
echo "Downloading genesis configuration..."
wget -O $GENESIS_CONFIG $GENESIS_URL

cd docker

# Generate validator keys
echo "Generating validator keys..."
PUBLIC_KEY=$(linera-server generate --validators validator-config.toml)

echo "Validator setup completed successfully."
echo "Starting docker compose..."

export LINERA_IMAGE="us-docker.pkg.dev/linera-io-dev/linera-public-registry/linera:$BRANCH_NAME"
docker compose up --wait

echo "Public Key: $PUBLIC_KEY"
