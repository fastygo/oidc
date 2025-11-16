#!/bin/bash
set -e

echo "================================================"
echo "Starting Authelia with custom entrypoint"
echo "================================================"

# Print environment variables for debugging
echo "Environment variables:"
echo "ROOT_DOMAIN=${ROOT_DOMAIN}"
echo "TZ=${TZ}"
echo "LOG_LEVEL=${LOG_LEVEL}"

# Create secrets if they don't exist
echo "Checking secrets..."

if [ ! -f /secrets/JWT_SECRET ]; then
    echo "Creating JWT_SECRET..."
    echo "${AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET:-changeme}" > /secrets/JWT_SECRET
fi

if [ ! -f /secrets/SESSION_SECRET ]; then
    echo "Creating SESSION_SECRET..."
    echo "${AUTHELIA_SESSION_SECRET:-changeme}" > /secrets/SESSION_SECRET
fi

if [ ! -f /secrets/STORAGE_ENCRYPTION_KEY ]; then
    echo "Creating STORAGE_ENCRYPTION_KEY..."
    echo "${AUTHELIA_STORAGE_ENCRYPTION_KEY:-changeme}" > /secrets/STORAGE_ENCRYPTION_KEY
fi

# Check if configuration file exists
if [ ! -f /config/configuration.yml ]; then
    echo "ERROR: Configuration file not found at /config/configuration.yml"
    exit 1
fi

echo "Configuration file found: /config/configuration.yml"

# Check if users file exists
if [ ! -f /config/users.yml ]; then
    echo "ERROR: Users file not found at /config/users.yml"
    exit 1
fi

echo "Users file found: /config/users.yml"

# Validate configuration
echo "Validating configuration..."
authelia validate-config /config/configuration.yml || {
    echo "ERROR: Configuration validation failed!"
    exit 1
}

echo "Configuration validated successfully!"
echo "================================================"
echo "Starting Authelia..."
echo "================================================"

# Execute the main command
exec "$@"

