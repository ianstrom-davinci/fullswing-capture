#!/bin/bash
# local-deploy.sh - Deploy script for running directly on K3s server

set -e

NAMESPACE="fullswing-capture"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

log_info "🚀 Building and deploying locally on K3s server..."

# Build images locally
log_info "Building Docker images..."
docker build -t fullswing-backend:latest ./backend
docker build -t fullswing-frontend:latest ./frontend
log_success "Docker images built successfully."

# Import images directly into K3s using temporary files
log_info "Importing images into K3s..."

# Create temporary files
BACKEND_TAR="/tmp/fullswing-backend.tar"
FRONTEND_TAR="/tmp/fullswing-frontend.tar"

# Save images to temporary files
docker save fullswing-backend:latest -o ${BACKEND_TAR}
docker save fullswing-frontend:latest -o ${FRONTEND_TAR}

# Import into K3s
sudo k3s ctr images import ${BACKEND_TAR}
sudo k3s ctr images import ${FRONTEND_TAR}

# Clean up temporary files
rm -f ${BACKEND_TAR} ${FRONTEND_TAR}

log_success "Images imported into K3s."

# Apply secrets and manifests
log_info "Applying secrets..."
kubectl apply -f k8s-secrets.yaml

log_info "Applying manifests..."
kubectl apply -f k8s-manifests.yaml
log_success "Manifests applied."

# Wait for deployments
log_info "Waiting for PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=300s
log_info "Waiting for Django backend..."
kubectl wait --for=condition=ready pod -l app=django-backend -n ${NAMESPACE} --timeout=300s

# Run migrations
log_info "Finding backend pod for migrations..."
BACKEND_POD=$(kubectl get pods -n ${NAMESPACE} -l app=django-backend -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | cut -d' ' -f1)

if [ -z "$BACKEND_POD" ]; then
    log_error "Could not find a running backend pod."
    exit 1
fi

log_info "Running migrations on pod: ${BACKEND_POD}..."
kubectl exec -n ${NAMESPACE} ${BACKEND_POD} -- python manage.py migrate

log_success "🎉 Deployment complete!"
echo ""
echo "📋 Access your app at: https://fullswing.stromfamily.ca"
echo "🔧 Check status: kubectl get pods -n ${NAMESPACE}"
echo ""