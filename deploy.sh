#!/bin/bash

# Production-ready deployment script for fullswing-capture
# Builds images, transfers to K3s, deploys, and runs migrations safely

set -e

# Configuration
K3S_HOST="root@192.168.218.5"
NAMESPACE="fullswing-capture"
MANIFEST_FILE="k8s-manifests.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Check prerequisites
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi

if [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    log_error "backend or frontend directory not found!"
    exit 1
fi

# Check if secrets file exists
if [ ! -f "k8s-secrets.yaml" ]; then
    log_warning "k8s-secrets.yaml not found. You need to create this file first."
    log_warning "See the setup instructions for how to create secure secrets."
    exit 1
fi

# Build Docker images
log_info "Building local Docker images..."
docker build -t fullswing-backend:latest ./backend
docker build -t fullswing-frontend:latest ./frontend
log_success "Docker images built successfully."

# Transfer images to K3s node
log_info "Transferring images to K3s node via SSH..."
docker save fullswing-backend:latest | ssh ${K3S_HOST} "k3s ctr images import -"
docker save fullswing-frontend:latest | ssh ${K3S_HOST} "k3s ctr images import -"
log_success "Images successfully imported into K3s."

# Apply secrets first (in case they've changed)
log_info "Applying secrets..."
kubectl apply -f k8s-secrets.yaml

# Deploy to Kubernetes
log_info "Applying Kubernetes manifests from ${MANIFEST_FILE}..."
kubectl apply -f ${MANIFEST_FILE}
log_success "Manifests applied."

# Wait for deployments
log_info "Waiting for deployments to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=300s
log_info "PostgreSQL is ready."
kubectl wait --for=condition=ready pod -l app=django-backend -n ${NAMESPACE} --timeout=300s
log_info "Django backend is ready."

# Run migrations robustly
log_info "Finding a running backend pod to run migrations..."
BACKEND_POD=$(kubectl get pods -n ${NAMESPACE} -l app=django-backend -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | cut -d' ' -f1)

if [ -z "$BACKEND_POD" ]; then
    log_error "Could not find a running backend pod to run migrations."
    exit 1
fi

log_info "Running migrations on pod: ${BACKEND_POD}..."
kubectl exec -n ${NAMESPACE} ${BACKEND_POD} -- python manage.py migrate
log_success "Migrations completed successfully!"

echo ""
echo "🎉 Full Swing Capture is now deployed!"
echo "   Access your app at: https://fullswing.stromfamily.ca"
echo ""
echo "🔧 Useful Commands:"
echo "• Check status: kubectl get pods -n ${NAMESPACE}"
echo "• View Django logs: kubectl logs -n ${NAMESPACE} ${BACKEND_POD}"
echo "• Create admin user: kubectl exec -it -n ${NAMESPACE} ${BACKEND_POD} -- python manage.py createsuperuser"
echo ""