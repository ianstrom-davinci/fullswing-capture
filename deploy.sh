#!/bin/bash

set -e

echo "🚀 Deploying Full Swing Capture to K3s"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if we have the required directories
if [ ! -d "backend" ]; then
    log_error "backend directory not found!"
    exit 1
fi

if [ ! -d "frontend" ]; then
    log_error "frontend directory not found!"
    exit 1
fi

# Build Docker images from existing code
log_info "Building Docker images..."

log_info "Building Django backend..."
cd backend
docker build -t fullswing-backend:latest .
cd ..

log_info "Building React frontend..."
cd frontend
docker build -t fullswing-frontend:latest .
cd ..

log_success "Docker images built successfully"

# Create/update Kubernetes manifests
log_info "Creating Kubernetes manifests..."

cat > k8s-deploy.yaml << 'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: fullswing-capture
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: django-config
  namespace: fullswing-capture
data:
  DJANGO_DEBUG: "False"
  ALLOWED_HOSTS: "fullswing.stromfamily.ca,localhost,127.0.0.1"
  DATABASE_NAME: "fullswing_db"
  DATABASE_USER: "fullswing_user"
  CORS_ALLOWED_ORIGINS: "https://fullswing.stromfamily.ca"
---
apiVersion: v1
kind: Secret
metadata:
  name: django-secret
  namespace: fullswing-capture
type: Opaque
data:
  SECRET_KEY: ZGphbmdvLWluc2VjdXJlLWNoYW5nZS1tZS1hc2FwLWZvcmNlLWV4aXQtMTIzNDU2Nzg5MA==
  DATABASE_PASSWORD: ZnVsbHN3aW5nMTIz
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: fullswing-capture
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: media-pvc
  namespace: fullswing-capture
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: fullswing-capture
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: fullswing_db
        - name: POSTGRES_USER
          value: fullswing_user
        - name: POSTGRES_PASSWORD
          value: fullswing123
        - name: PGUSER
          value: fullswing_user
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: fullswing-capture
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: django-backend
  namespace: fullswing-capture
spec:
  replicas: 1
  selector:
    matchLabels:
      app: django-backend
  template:
    metadata:
      labels:
        app: django-backend
    spec:
      containers:
      - name: django
        image: fullswing-backend:latest
        imagePullPolicy: Never
        env:
        - name: SECRET_KEY
          value: "django-insecure-change-me-asap-force-exit-1234567890"
        - name: DJANGO_DEBUG
          value: "False"
        - name: ALLOWED_HOSTS
          value: "fullswing.stromfamily.ca,localhost,127.0.0.1"
        - name: DATABASE_NAME
          value: "fullswing_db"
        - name: DATABASE_USER
          value: "fullswing_user"
        - name: DATABASE_PASSWORD
          value: "fullswing123"
        - name: DATABASE_HOST
          value: "postgres-service"
        - name: CORS_ALLOWED_ORIGINS
          value: "https://fullswing.stromfamily.ca"
        ports:
        - containerPort: 8000
        volumeMounts:
        - name: media-storage
          mountPath: /app/media
      volumes:
      - name: media-storage
        persistentVolumeClaim:
          claimName: media-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: django-service
  namespace: fullswing-capture
spec:
  selector:
    app: django-backend
  ports:
  - port: 8000
    targetPort: 8000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: react-frontend
  namespace: fullswing-capture
spec:
  replicas: 1
  selector:
    matchLabels:
      app: react-frontend
  template:
    metadata:
      labels:
        app: react-frontend
    spec:
      containers:
      - name: nginx
        image: fullswing-frontend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: react-service
  namespace: fullswing-capture
spec:
  selector:
    app: react-frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fullswing-ingress
  namespace: fullswing-capture
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-production"
    traefik.ingress.kubernetes.io/router.middlewares: "fullswing-capture-api-stripprefix@kubernetescrd"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - fullswing.stromfamily.ca
    secretName: fullswing-tls
  rules:
  - host: fullswing.stromfamily.ca
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: django-service
            port:
              number: 8000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: react-service
            port:
              number: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: api-stripprefix
  namespace: fullswing-capture
spec:
  stripPrefix:
    prefixes:
      - /api
EOF

log_success "Kubernetes manifests created"

# Deploy to K8s
log_info "Deploying to Kubernetes..."

kubectl apply -f k8s-deploy.yaml

log_info "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n fullswing-capture --timeout=300s

log_info "Waiting for Django backend to be ready..."
kubectl wait --for=condition=ready pod -l app=django-backend -n fullswing-capture --timeout=300s

log_info "Running Django migrations..."
kubectl exec -n fullswing-capture deployment/django-backend -- python manage.py migrate

log_success "Deployment completed successfully!"

echo ""
echo "🎉 Full Swing Data Capture is now deployed!"
echo ""
echo "📋 Access your app at: https://fullswing.stromfamily.ca"
echo ""
echo "🔧 Useful Commands:"
echo "• Check status: kubectl get pods -n fullswing-capture"
echo "• View Django logs: kubectl logs -n fullswing-capture deployment/django-backend"
echo "• Create admin user: kubectl exec -it -n fullswing-capture deployment/django-backend -- python manage.py createsuperuser"
echo ""