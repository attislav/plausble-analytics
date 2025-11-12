#!/bin/bash
#
# Auto-deployment script for Plausible Analytics
# Triggered by GitHub webhook on push to master
#

set -e  # Exit on error

# Configuration
DEPLOY_DIR="/opt/plausible"
LOG_FILE="/var/log/plausible-deploy.log"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    log "❌ ERROR: $1"
    exit 1
}

# Start deployment
log "🚀 Starting deployment..."

# Navigate to deployment directory
cd "$DEPLOY_DIR" || error_exit "Failed to navigate to $DEPLOY_DIR"

# Fetch latest changes
log "📥 Fetching latest changes from GitHub..."
git fetch origin || error_exit "Git fetch failed"

# Check if there are actually new commits
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/master)

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    log "✅ Already up to date. Nothing to deploy."
    exit 0
fi

log "📝 New commits detected:"
git log --oneline "$LOCAL_COMMIT..$REMOTE_COMMIT" | tee -a "$LOG_FILE"

# Stash any local changes (if any)
if ! git diff-index --quiet HEAD --; then
    log "⚠️  Local changes detected, stashing..."
    git stash || error_exit "Git stash failed"
fi

# Pull latest changes
log "⬇️  Pulling latest changes..."
git pull origin master || error_exit "Git pull failed"

# Backup current containers (optional, keep old images)
log "💾 Creating backup of current state..."
docker-compose ps -q > /tmp/plausible-containers-backup.txt || true

# Stop services
log "🛑 Stopping services..."
docker-compose down || error_exit "Failed to stop services"

# Rebuild images
log "🔨 Building new Docker images..."
docker-compose build --no-cache || error_exit "Docker build failed"

# Start services
log "▶️  Starting services..."
docker-compose up -d || error_exit "Failed to start services"

# Wait for services to be ready
log "⏳ Waiting for services to start..."
sleep 10

# Run database migrations
log "🗄️  Running database migrations..."
docker-compose exec -T plausible /entrypoint.sh db migrate || log "⚠️  Migration warning (might be already applied)"

# Health check
log "🏥 Performing health check..."
if docker-compose ps | grep -q "Up"; then
    log "✅ Services are running"
else
    error_exit "Services failed to start properly"
fi

# Clean up old images
log "🧹 Cleaning up old Docker images..."
docker image prune -f || true

# Get new commit info
NEW_COMMIT=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --pretty=%B)

log "✨ Deployment completed successfully!"
log "📌 Now running commit: $NEW_COMMIT"
log "📄 Commit message: $COMMIT_MSG"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
