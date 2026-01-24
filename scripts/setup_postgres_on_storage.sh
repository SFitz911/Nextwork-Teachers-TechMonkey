#!/bin/bash
# Set up PostgreSQL directly on Vast.ai storage volume (no Docker)
# Usage: bash scripts/setup_postgres_on_storage.sh

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Setting Up PostgreSQL on Storage Volume"
echo "=========================================="
echo ""

# Detect storage
if [ -z "${VAST_STORAGE:-}" ]; then
    if [ -f "$PROJECT_DIR/.env" ]; then
        VAST_STORAGE=$(grep "VAST_STORAGE_PATH=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
    fi
    
    if [ -z "$VAST_STORAGE" ]; then
        for loc in "/root/vast-storage" "/mnt/vast-storage" "/vast-storage"; do
            if [ -d "$loc" ]; then
                VAST_STORAGE="$loc"
                break
            fi
        done
    fi
    
    if [ -z "$VAST_STORAGE" ]; then
        VAST_STORAGE="/root/vast-storage"
        mkdir -p "$VAST_STORAGE"
    fi
fi

export VAST_STORAGE
echo "Using storage: $VAST_STORAGE"
echo ""

# Install PostgreSQL if not installed
if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL..."
    apt-get update -qq
    apt-get install -y postgresql postgresql-contrib
    echo "✅ PostgreSQL installed"
else
    echo "✅ PostgreSQL already installed: $(psql --version)"
fi

# Install pgvector extension
echo ""
echo "Installing pgvector extension..."
apt-get install -y postgresql-server-dev-all build-essential git || echo "⚠️  Some packages may need manual install"

# Try to install pgvector from source
if ! psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null; then
    echo "Building pgvector from source..."
    cd /tmp
    if [ ! -d "pgvector" ]; then
        git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git
    fi
    cd pgvector
    make
    make install
    echo "✅ pgvector installed"
else
    echo "✅ pgvector extension available"
fi

# Stop PostgreSQL if running
systemctl stop postgresql 2>/dev/null || service postgresql stop 2>/dev/null || true

# Create PostgreSQL data directory on storage
PG_DATA_DIR="$VAST_STORAGE/postgresql/data"
PG_VERSION=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "14")
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

echo ""
echo "Setting up PostgreSQL data directory on storage volume..."
echo "PostgreSQL version: ${PG_VERSION}"
echo "Data directory: $PG_DATA_DIR"
echo ""

# Initialize database if needed
if [ ! -d "$PG_DATA_DIR" ] || [ -z "$(ls -A $PG_DATA_DIR 2>/dev/null)" ]; then
    echo "Initializing PostgreSQL database on storage volume..."
    mkdir -p "$PG_DATA_DIR"
    chown -R postgres:postgres "$PG_DATA_DIR"
    
    # Find initdb
    INITDB_CMD=""
    if [ -f "${PG_BIN}/initdb" ]; then
        INITDB_CMD="${PG_BIN}/initdb"
    elif command -v initdb &> /dev/null; then
        INITDB_CMD="initdb"
    else
        INITDB_CMD=$(find /usr -name initdb -type f 2>/dev/null | head -1)
    fi
    
    if [ -z "$INITDB_CMD" ] || [ ! -f "$INITDB_CMD" ]; then
        echo "❌ Could not find initdb"
        exit 1
    fi
    
    echo "Initializing database..."
    sudo -u postgres "$INITDB_CMD" \
        -D "$PG_DATA_DIR" \
        --encoding=UTF8 \
        --locale=en_US.UTF-8 \
        || {
        echo "⚠️  Trying without checksums..."
        sudo -u postgres "$INITDB_CMD" \
            -D "$PG_DATA_DIR" \
            --encoding=UTF8 \
            --locale=en_US.UTF-8
    }
    
    echo "✅ Database initialized"
else
    echo "✅ Database directory already exists"
fi

# Configure PostgreSQL to use storage volume
echo ""
echo "Configuring PostgreSQL to use storage volume..."

# Update postgresql.conf
PG_CONF="$PG_DATA_DIR/postgresql.conf"
if [ -f "$PG_CONF" ]; then
    sed -i "s|#listen_addresses = 'localhost'|listen_addresses = 'localhost'|g" "$PG_CONF"
    sed -i "s|#shared_buffers = 128MB|shared_buffers = 256MB|g" "$PG_CONF"
    sed -i "s|#max_connections = 100|max_connections = 200|g" "$PG_CONF"
    echo "✅ PostgreSQL configuration updated"
fi

# Start PostgreSQL with custom data directory
echo ""
echo "Starting PostgreSQL..."
sudo -u postgres "$PG_BIN"/pg_ctl -D "$PG_DATA_DIR" -l "$VAST_STORAGE/postgresql/postgresql.log" start || {
    echo "⚠️  Could not start with pg_ctl, trying systemctl..."
    # Create systemd override
    mkdir -p /etc/systemd/system/postgresql.service.d
    cat > /etc/systemd/system/postgresql.service.d/custom-data-dir.conf << EOF
[Service]
Environment="PGDATA=$PG_DATA_DIR"
EOF
    systemctl daemon-reload
    systemctl start postgresql || service postgresql start
}

sleep 3

# Create database and user
echo ""
echo "Creating database and user..."
if [ -f "$PROJECT_DIR/.env" ]; then
    POSTGRES_PASSWORD=$(grep "POSTGRES_PASSWORD=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(openssl rand -base64 32)
fi

sudo -u postgres psql << EOF || echo "⚠️  Database/user may already exist"
CREATE DATABASE ai_teacher;
CREATE USER ai_teacher WITH PASSWORD '$POSTGRES_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE ai_teacher TO ai_teacher;
\q
EOF

# Install pgvector extension
echo ""
echo "Installing pgvector extension..."
sudo -u postgres psql -d ai_teacher -c "CREATE EXTENSION IF NOT EXISTS vector;" || {
    echo "⚠️  pgvector extension installation failed"
    echo "   You may need to install it manually"
}

# Update .env file
if [ -f "$PROJECT_DIR/.env" ]; then
    if ! grep -q "POSTGRES_PASSWORD=" "$PROJECT_DIR/.env"; then
        echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> "$PROJECT_DIR/.env"
    else
        sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" "$PROJECT_DIR/.env"
    fi
fi

echo ""
echo "=========================================="
echo "✅ PostgreSQL Setup Complete!"
echo "=========================================="
echo ""
echo "Database: ai_teacher"
echo "User: ai_teacher"
echo "Password: (saved in .env file)"
echo "Data location: $PG_DATA_DIR (on storage volume)"
echo ""
echo "Test connection:"
echo "  psql -U ai_teacher -d ai_teacher -h localhost"
echo ""
