#!/bin/bash

set -e

echo "🚀 Full Swing Data Capture - Complete Setup & Deploy Script"
echo "==========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "kubectl cannot connect to your K8s cluster"
    exit 1
fi

log_success "Prerequisites check passed"

# Create project structure
log_info "Creating project structure..."

mkdir -p backend/project
mkdir -p backend/fullswing
mkdir -p frontend/src/{components,hooks,services}
mkdir -p frontend/public

# Create backend files
log_info "Creating Django backend files..."

# requirements.txt
cat > backend/requirements.txt << 'EOF'
Django==5.0.1
djangorestframework==3.14.0
django-cors-headers==4.3.1
Pillow==10.2.0
opencv-python-headless==4.9.0.80
pytesseract==0.3.10
psycopg2-binary==2.9.9
python-decouple==3.8
gunicorn==21.2.0
EOF

# Backend Dockerfile
cat > backend/Dockerfile << 'EOF'
FROM python:3.11-slim

# Install system dependencies for OpenCV and Tesseract
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-eng \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgtk-3-0 \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libdc1394-22-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Collect static files
RUN python manage.py collectstatic --noinput

# Create media directory
RUN mkdir -p /app/media

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "project.wsgi:application"]
EOF

# manage.py
cat > backend/manage.py << 'EOF'
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys

if __name__ == '__main__':
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)
EOF

# project/__init__.py
touch backend/project/__init__.py

# project/settings.py
cat > backend/project/settings.py << 'EOF'
import os
from pathlib import Path
from decouple import config

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DJANGO_DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'fullswing',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'project.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DATABASE_NAME'),
        'USER': config('DATABASE_USER'),
        'PASSWORD': config('DATABASE_PASSWORD'),
        'HOST': config('DATABASE_HOST', default='localhost'),
        'PORT': config('DATABASE_PORT', default='5432'),
    }
}

CORS_ALLOWED_ORIGINS = config('CORS_ALLOWED_ORIGINS', default='http://localhost:3000').split(',')
CORS_ALLOW_CREDENTIALS = True

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ]
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOF

# project/urls.py
cat > backend/project/urls.py << 'EOF'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('fullswing.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
EOF

# project/wsgi.py
cat > backend/project/wsgi.py << 'EOF'
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
application = get_wsgi_application()
EOF

# fullswing app files
touch backend/fullswing/__init__.py

# fullswing/models.py
cat > backend/fullswing/models.py << 'EOF'
from django.db import models
from django.utils import timezone

class Session(models.Model):
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(default=timezone.now)
    notes = models.TextField(blank=True)
    
    def __str__(self):
        return f"{self.name} - {self.created_at.strftime('%Y-%m-%d %H:%M')}"

class Shot(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name='shots')
    timestamp = models.DateTimeField(default=timezone.now)
    image = models.ImageField(upload_to='shots/')
    
    # Full Swing KIT basic data (4 values on OLED)
    ball_speed = models.FloatField(null=True, blank=True)
    club_head_speed = models.FloatField(null=True, blank=True)
    carry_distance = models.FloatField(null=True, blank=True)
    total_distance = models.FloatField(null=True, blank=True)
    
    # Extended iPad data (14-16 values)
    smash_factor = models.FloatField(null=True, blank=True)
    launch_angle = models.FloatField(null=True, blank=True)
    spin_rate = models.FloatField(null=True, blank=True)
    side_spin = models.FloatField(null=True, blank=True)
    angle_of_attack = models.FloatField(null=True, blank=True)
    club_path = models.FloatField(null=True, blank=True)
    face_angle = models.FloatField(null=True, blank=True)
    dynamic_loft = models.FloatField(null=True, blank=True)
    impact_height = models.FloatField(null=True, blank=True)
    impact_toe = models.FloatField(null=True, blank=True)
    ball_height = models.FloatField(null=True, blank=True)
    descent_angle = models.FloatField(null=True, blank=True)
    apex_height = models.FloatField(null=True, blank=True)
    hang_time = models.FloatField(null=True, blank=True)
    offline = models.FloatField(null=True, blank=True)
    
    # Processing metadata
    processed = models.BooleanField(default=False)
    processing_errors = models.TextField(blank=True)
    confidence_score = models.FloatField(null=True, blank=True)
    
    def __str__(self):
        return f"Shot {self.id} - {self.timestamp.strftime('%H:%M:%S')}"
EOF

# fullswing/serializers.py
cat > backend/fullswing/serializers.py << 'EOF'
from rest_framework import serializers
from .models import Session, Shot

class ShotSerializer(serializers.ModelSerializer):
    class Meta:
        model = Shot
        fields = '__all__'

class SessionSerializer(serializers.ModelSerializer):
    shot_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Session
        fields = ['id', 'name', 'created_at', 'notes', 'shot_count']
    
    def get_shot_count(self, obj):
        return obj.shots.count()
EOF

# fullswing/ocr_processor.py
cat > backend/fullswing/ocr_processor.py << 'EOF'
import cv2
import numpy as np
import pytesseract
import re
from typing import Dict, Optional, Tuple
from PIL import Image

class FullSwingOCR:
    def __init__(self):
        # Configure tesseract for better number recognition
        self.config = r'--oem 3 --psm 6 -c tessedit_char_whitelist=0123456789.-+mph°ft/s'
    
    def preprocess_image(self, image_path: str) -> np.ndarray:
        """Preprocess image for better OCR accuracy"""
        # Read image
        img = cv2.imread(image_path)
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply bilateral filter to reduce noise while keeping edges sharp
        filtered = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Apply adaptive threshold
        thresh = cv2.adaptiveThreshold(
            filtered, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        
        # Morphological operations to clean up
        kernel = np.ones((2, 2), np.uint8)
        cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        # Resize for better OCR (if image is too small)
        height, width = cleaned.shape
        if height < 500:
            scale_factor = 500 / height
            new_width = int(width * scale_factor)
            cleaned = cv2.resize(cleaned, (new_width, 500), interpolation=cv2.INTER_CUBIC)
        
        return cleaned
    
    def extract_numbers_from_text(self, text: str) -> list:
        """Extract numeric values from OCR text"""
        numbers = []
        
        # Remove common OCR artifacts and normalize
        text = text.replace('O', '0').replace('o', '0').replace('l', '1').replace('I', '1')
        
        # Find all numeric patterns
        patterns = [
            r'(\d+\.?\d*)\s*mph',
            r'(\d+\.?\d*)\s*ft',
            r'(\d+\.?\d*)\s*°',
            r'(\d+\.?\d*)\s*rpm',
            r'(\d+\.?\d*)\s*/s',
            r'(-?\d+\.?\d*)',  # Any number (including negative)
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                try:
                    numbers.append(float(match))
                except ValueError:
                    continue
        
        return numbers
    
    def process_oled_display(self, image_path: str) -> Tuple[Dict[str, Optional[float]], str, float]:
        """Process Full Swing KIT OLED display (4 basic values)"""
        processed_img = self.preprocess_image(image_path)
        
        # Extract text
        text = pytesseract.image_to_string(processed_img, config=self.config)
        numbers = self.extract_numbers_from_text(text)
        
        # Map to expected OLED values (adjust based on your display layout)
        result = {
            'ball_speed': numbers[0] if len(numbers) > 0 else None,
            'club_head_speed': numbers[1] if len(numbers) > 1 else None,
            'carry_distance': numbers[2] if len(numbers) > 2 else None,
            'total_distance': numbers[3] if len(numbers) > 3 else None,
        }
        
        return result, text, len(numbers) / 4.0  # confidence score
    
    def process_ipad_display(self, image_path: str) -> Tuple[Dict[str, Optional[float]], str, float]:
        """Process iPad display with all 14-16 values"""
        processed_img = self.preprocess_image(image_path)
        
        # Extract text
        text = pytesseract.image_to_string(processed_img, config=self.config)
        numbers = self.extract_numbers_from_text(text)
        
        # Map to expected iPad values (you'll need to adjust this based on layout)
        fields = [
            'ball_speed', 'club_head_speed', 'smash_factor', 'carry_distance',
            'total_distance', 'launch_angle', 'spin_rate', 'side_spin',
            'angle_of_attack', 'club_path', 'face_angle', 'dynamic_loft',
            'impact_height', 'impact_toe', 'ball_height', 'descent_angle'
        ]
        
        result = {}
        for i, field in enumerate(fields):
            result[field] = numbers[i] if len(numbers) > i else None
            
        return result, text, min(1.0, len(numbers) / len(fields))
EOF

# fullswing/views.py
cat > backend/fullswing/views.py << 'EOF'
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from .models import Session, Shot
from .ocr_processor import FullSwingOCR
from .serializers import SessionSerializer, ShotSerializer

@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser])
def process_image(request):
    """Process uploaded image and extract shot data"""
    try:
        image_file = request.FILES.get('image')
        session_id = request.data.get('session_id')
        display_type = request.data.get('display_type', 'oled')  # 'oled' or 'ipad'
        
        if not image_file:
            return Response({'error': 'No image provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get or create session
        session = None
        if session_id:
            try:
                session = Session.objects.get(id=session_id)
            except Session.DoesNotExist:
                pass
        
        if not session:
            session = Session.objects.create(name=f"Session {timezone.now().strftime('%Y-%m-%d %H:%M')}")
        
        # Create shot record
        shot = Shot.objects.create(session=session, image=image_file)
        
        # Process image with OCR
        ocr_processor = FullSwingOCR()
        
        try:
            if display_type == 'oled':
                data, raw_text, confidence = ocr_processor.process_oled_display(shot.image.path)
            else:
                data, raw_text, confidence = ocr_processor.process_ipad_display(shot.image.path)
            
            # Update shot with extracted data
            for field, value in data.items():
                if value is not None and hasattr(shot, field):
                    setattr(shot, field, value)
            
            shot.processed = True
            shot.confidence_score = confidence
            shot.save()
            
            return Response({
                'shot_id': shot.id,
                'session_id': session.id,
                'data': data,
                'confidence': confidence,
                'raw_text': raw_text
            })
            
        except Exception as e:
            shot.processing_errors = str(e)
            shot.save()
            return Response({
                'error': f'Processing failed: {str(e)}',
                'shot_id': shot.id
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET', 'POST'])
def sessions(request):
    """Get all sessions or create new session"""
    if request.method == 'GET':
        sessions = Session.objects.all().order_by('-created_at')
        serializer = SessionSerializer(sessions, many=True)
        return Response(serializer.data)
    
    elif request.method == 'POST':
        serializer = SessionSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def session_shots(request, session_id):
    """Get all shots for a session"""
    try:
        session = Session.objects.get(id=session_id)
        shots = session.shots.all().order_by('-timestamp')
        serializer = ShotSerializer(shots, many=True)
        return Response(serializer.data)
    except Session.DoesNotExist:
        return Response({'error': 'Session not found'}, status=status.HTTP_404_NOT_FOUND)
EOF

# fullswing/urls.py
cat > backend/fullswing/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path('process-image/', views.process_image, name='process_image'),
    path('sessions/', views.sessions, name='sessions'),
    path('sessions/<int:session_id>/shots/', views.session_shots, name='session_shots'),
]
EOF

# fullswing/admin.py
cat > backend/fullswing/admin.py << 'EOF'
from django.contrib import admin
from .models import Session, Shot

@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = ['name', 'created_at', 'shot_count']
    list_filter = ['created_at']
    search_fields = ['name']
    
    def shot_count(self, obj):
        return obj.shots.count()

@admin.register(Shot)
class ShotAdmin(admin.ModelAdmin):
    list_display = ['id', 'session', 'timestamp', 'ball_speed', 'club_head_speed', 'confidence_score', 'processed']
    list_filter = ['session', 'processed', 'timestamp']
    readonly_fields = ['timestamp', 'image']
    fieldsets = (
        ('Basic Info', {
            'fields': ('session', 'timestamp', 'image', 'processed', 'confidence_score', 'processing_errors')
        }),
        ('Basic Data', {
            'fields': ('ball_speed', 'club_head_speed', 'carry_distance', 'total_distance')
        }),
        ('Advanced Data', {
            'fields': ('smash_factor', 'launch_angle', 'spin_rate', 'side_spin', 'angle_of_attack', 
                      'club_path', 'face_angle', 'dynamic_loft', 'impact_height', 'impact_toe',
                      'ball_height', 'descent_angle', 'apex_height', 'hang_time', 'offline')
        }),
    )
EOF

log_success "Django backend files created"

# Create frontend files
log_info "Creating React frontend files..."

# package.json
cat > frontend/package.json << 'EOF'
{
  "name": "fullswing-capture",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@types/node": "^16.18.68",
    "@types/react": "^18.2.45",
    "@types/react-dom": "^18.2.18",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "typescript": "^4.9.5"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "devDependencies": {
    "tailwindcss": "^3.3.6",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32"
  }
}
EOF

# tailwind.config.js
cat > frontend/tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {
      screens: {
        'xs': '475px',
      },
    },
  },
  plugins: [],
}
EOF

# postcss.config.js
cat > frontend/postcss.config.js << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# Frontend Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build

# Production stage with nginx
FROM nginx:alpine

# Copy built React app
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# nginx.conf
cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html index.htm;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;
    
    # Handle React Router
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# public/index.html
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Full Swing Golf Simulator Data Capture" />
    <title>Full Swing Capture</title>
    
    <!-- PWA optimization for iOS -->
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="default">
    <meta name="apple-mobile-web-app-title" content="FS Capture">
    
    <!-- Prevent zoom on input focus -->
    <style>
      input[type="text"], input[type="number"], select, textarea {
        font-size: 16px !important;
      }
    </style>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# src/index.tsx
cat > frontend/src/index.tsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# src/index.css
cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF

# src/types.ts
cat > frontend/src/types.ts << 'EOF'
export interface Shot {
  id: number;
  timestamp: string;
  image: string;
  ball_speed?: number;
  club_head_speed?: number;
  carry_distance?: number;
  total_distance?: number;
  smash_factor?: number;
  launch_angle?: number;
  spin_rate?: number;
  side_spin?: number;
  angle_of_attack?: number;
  club_path?: number;
  face_angle?: number;
  dynamic_loft?: number;
  impact_height?: number;
  impact_toe?: number;
  ball_height?: number;
  descent_angle?: number;
  apex_height?: number;
  hang_time?: number;
  offline?: number;
  processed: boolean;
  confidence_score?: number;
  processing_errors?: string;
}

export interface Session {
  id: number;
  name: string;
  created_at: string;
  notes: string;
  shot_count: number;
}

export interface CaptureSettings {
  interval: number;
  displayType: 'oled' | 'ipad';
  autoCapture: boolean;
}
EOF

# Continue with more React files...
# src/hooks/useCamera.ts
cat > frontend/src/hooks/useCamera.ts << 'EOF'
import { useRef, useState, useCallback } from 'react';

export const useCamera = () => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const startCamera = useCallback(async () => {
    try {
      setError(null);
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'environment', // Use back camera on mobile
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        }
      });
      
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        setIsStreaming(true);
      }
    } catch (err) {
      setError('Failed to access camera. Please ensure camera permissions are granted.');
      console.error('Camera error:', err);
    }
  }, []);

  const stopCamera = useCallback(() => {
    if (videoRef.current?.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream;
      stream.getTracks().forEach(track => track.stop());
      videoRef.current.srcObject = null;
      setIsStreaming(false);
    }
  }, []);

  const capturePhoto = useCallback((): Promise<Blob | null> => {
    return new Promise((resolve) => {
      if (!videoRef.current || !canvasRef.current) {
        resolve(null);
        return;
      }

      const video = videoRef.current;
      const canvas = canvasRef.current;
      const ctx = canvas.getContext('2d');

      if (!ctx) {
        resolve(null);
        return;
      }

      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      ctx.drawImage(video, 0, 0);

      canvas.toBlob(resolve, 'image/jpeg', 0.9);
    });
  }, []);

  return {
    videoRef,
    canvasRef,
    isStreaming,
    error,
    startCamera,
    stopCamera,
    capturePhoto
  };
};
EOF

# src/services/api.ts
cat > frontend/src/services/api.ts << 'EOF'
import { Session, Shot } from '../types';

const API_BASE = '/api';

export const api = {
  async uploadImage(imageBlob: Blob, sessionId?: number, displayType: string = 'oled') {
    const formData = new FormData();
    formData.append('image', imageBlob, 'capture.jpg');
    if (sessionId) formData.append('session_id', sessionId.toString());
    formData.append('display_type', displayType);

    const response = await fetch(`${API_BASE}/process-image/`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`Upload failed: ${response.statusText}`);
    }

    return response.json();
  },

  async getSessions(): Promise<Session[]> {
    const response = await fetch(`${API_BASE}/sessions/`);
    if (!response.ok) throw new Error('Failed to fetch sessions');
    return response.json();
  },

  async createSession(name: string, notes?: string): Promise<Session> {
    const response = await fetch(`${API_BASE}/sessions/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, notes }),
    });
    if (!response.ok) throw new Error('Failed to create session');
    return response.json();
  },

  async getSessionShots(sessionId: number): Promise<Shot[]> {
    const response = await fetch(`${API_BASE}/sessions/${sessionId}/shots/`);
    if (!response.ok) throw new Error('Failed to fetch shots');
    return response.json();
  }
};
EOF

# Create React components (simplified for brevity)
cat > frontend/src/App.tsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { api } from './services/api';
import { Session, Shot, CaptureSettings } from './types';
import { useCamera } from './hooks/useCamera';

function App() {
  const { videoRef, canvasRef, isStreaming, error: cameraError, startCamera, stopCamera, capturePhoto } = useCamera();
  const [settings, setSettings] = useState<CaptureSettings>({
    interval: 3,
    displayType: 'oled',
    autoCapture: false
  });
  
  const [sessions, setSessions] = useState<Session[]>([]);
  const [currentSession, setCurrentSession] = useState<Session | undefined>();
  const [recentShots, setRecentShots] = useState<Shot[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  const [countdown, setCountdown] = useState<number | null>(null);

  useEffect(() => {
    loadSessions();
  }, []);

  useEffect(() => {
    if (cameraError) {
      setError(cameraError);
    }
  }, [cameraError]);

  const loadSessions = async () => {
    try {
      const sessionsData = await api.getSessions();
      setSessions(sessionsData);
      if (sessionsData.length > 0 && !currentSession) {
        setCurrentSession(sessionsData[0]);
      }
    } catch (err) {
      setError('Failed to load sessions');
    }
  };

  const createNewSession = async () => {
    try {
      setLoading(true);
      const sessionName = `Session ${new Date().toLocaleDateString()} ${new Date().toLocaleTimeString()}`;
      const newSession = await api.createSession(sessionName);
      setSessions(prev => [newSession, ...prev]);
      setCurrentSession(newSession);
      setRecentShots([]);
    } catch (err) {
      setError('Failed to create session');
    } finally {
      setLoading(false);
    }
  };

  const handleSingleCapture = async () => {
    if (!isStreaming) return;
    
    setIsCapturing(true);
    try {
      const imageBlob = await capturePhoto();
      if (imageBlob) {
        const result = await api.uploadImage(
          imageBlob, 
          currentSession?.id, 
          settings.displayType
        );
        
        // Reload shots to get the latest data
        if (currentSession) {
          loadSessionShots(currentSession.id);
        }
        
        setError(null);
      }
    } catch (err) {
      setError(`Capture failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setIsCapturing(false);
    }
  };

  const loadSessionShots = async (sessionId: number) => {
    try {
      const shots = await api.getSessionShots(sessionId);
      setRecentShots(shots.slice(0, 5));
    } catch (err) {
      setError('Failed to load shots');
    }
  };

  useEffect(() => {
    if (currentSession) {
      loadSessionShots(currentSession.id);
    }
  }, [currentSession]);

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold text-center mb-8">
          Full Swing Data Capture
        </h1>
        
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">
            {error}
            <button 
              onClick={() => setError(null)}
              className="float-right text-red-500 hover:text-red-700"
            >
              ×
            </button>
          </div>
        )}
        
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Camera Section */}
          <div className="lg:col-span-2 space-y-6">
            <div className="relative w-full max-w-2xl mx-auto">
              <div className="relative bg-black rounded-lg overflow-hidden">
                <video
                  ref={videoRef}
                  autoPlay
                  playsInline
                  muted
                  className="w-full h-auto max-h-96 object-cover"
                />
                <canvas ref={canvasRef} className="hidden" />
                
                {countdown && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
                    <div className="text-6xl font-bold text-white animate-pulse">
                      {countdown}
                    </div>
                  </div>
                )}
                
                {isCapturing && !countdown && (
                  <div className="absolute top-4 right-4 bg-red-500 text-white px-3 py-1 rounded-full text-sm">
                    Recording...
                  </div>
                )}
              </div>
              
              <div className="mt-4 space-y-3">
                <div className="flex flex-wrap gap-3 justify-center">
                  {!isStreaming ? (
                    <button
                      onClick={startCamera}
                      className="bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg text-lg font-semibold"
                    >
                      Start Camera
                    </button>
                  ) : (
                    <>
                      <button
                        onClick={handleSingleCapture}
                        disabled={isCapturing}
                        className="bg-green-500 hover:bg-green-600 disabled:bg-gray-400 text-white px-6 py-3 rounded-lg text-lg font-semibold"
                      >
                        Capture Shot
                      </button>
                      
                      <button
                        onClick={stopCamera}
                        className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-3 rounded-lg font-semibold"
                      >
                        Stop Camera
                      </button>
                    </>
                  )}
                </div>
              </div>
            </div>
            
            {/* Settings */}
            <div className="bg-white rounded-lg shadow-md p-6 space-y-4">
              <h3 className="text-lg font-semibold mb-4">Capture Settings</h3>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Display Type
                </label>
                <select
                  value={settings.displayType}
                  onChange={(e) => setSettings({
                    ...settings,
                    displayType: e.target.value as 'oled' | 'ipad'
                  })}
                  className="w-full p-2 border border-gray-300 rounded-md"
                >
                  <option value="oled">Full Swing KIT OLED (4 values)</option>
                  <option value="ipad">iPad Display (14-16 values)</option>
                </select>
              </div>
            </div>
          </div>
          
          {/* Session Management and Recent Shots */}
          <div className="space-y-6">
            {/* Session Management */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold mb-4">Session</h3>
              
              <div className="space-y-4">
                <button
                  onClick={createNewSession}
                  disabled={loading}
                  className="w-full bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white py-2 px-4 rounded"
                >
                  {loading ? 'Creating...' : 'New Session'}
                </button>
                
                <select
                  value={currentSession?.id || ''}
                  onChange={(e) => {
                    const sessionId = parseInt(e.target.value);
                    const session = sessions.find(s => s.id === sessionId);
                    setCurrentSession(session);
                  }}
                  className="w-full p-2 border border-gray-300 rounded"
                >
                  <option value="">Select Session</option>
                  {sessions.map(session => (
                    <option key={session.id} value={session.id}>
                      {session.name} ({session.shot_count} shots)
                    </option>
                  ))}
                </select>
                
                {currentSession && (
                  <div className="text-sm text-gray-600">
                    <div>Current: {currentSession.name}</div>
                    <div>Created: {new Date(currentSession.created_at).toLocaleString()}</div>
                  </div>
                )}
              </div>
            </div>
            
            {/* Recent Shots */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Recent Shots</h3>
              {recentShots.length === 0 ? (
                <div className="text-gray-500 text-center py-8">
                  No shots captured yet
                </div>
              ) : (
                recentShots.map(shot => (
                  <div key={shot.id} className="bg-white rounded-lg shadow-md p-6">
                    <div className="flex justify-between items-start mb-4">
                      <h4 className="text-lg font-semibold">Shot #{shot.id}</h4>
                      <div className="text-sm text-gray-500">
                        {new Date(shot.timestamp).toLocaleTimeString()}
                      </div>
                    </div>
                    
                    {shot.confidence_score && (
                      <div className="mb-4">
                        <div className="text-sm text-gray-600">
                          Confidence: {(shot.confidence_score * 100).toFixed(1)}%
                        </div>
                        <div className="w-full bg-gray-200 rounded-full h-2">
                          <div
                            className="bg-blue-600 h-2 rounded-full"
                            style={{ width: `${shot.confidence_score * 100}%` }}
                          />
                        </div>
                      </div>
                    )}
                    
                    <div className="grid grid-cols-2 gap-4">
                      {[
                        { key: 'ball_speed', label: 'Ball Speed', unit: 'mph' },
                        { key: 'club_head_speed', label: 'Club Speed', unit: 'mph' },
                        { key: 'carry_distance', label: 'Carry', unit: 'yds' },
                        { key: 'total_distance', label: 'Total', unit: 'yds' },
                      ].map(field => (
                        <div key={field.key} className="bg-gray-50 p-3 rounded">
                          <div className="text-sm text-gray-600">{field.label}</div>
                          <div className="text-xl font-bold">
                            {shot[field.key as keyof Shot] ? 
                              `${shot[field.key as keyof Shot]}${field.unit}` : 
                              '---'
                            }
                          </div>
                        </div>
                      ))}
                    </div>
                    
                    {shot.processing_errors && (
                      <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded">
                        <div className="text-sm text-red-700">
                          Processing Error: {shot.processing_errors}
                        </div>
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
EOF

log_success "React frontend files created"

# Create Kubernetes manifests
log_info "Creating Kubernetes manifests..."

cat > k8s-manifests.yaml << 'EOF'
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
  SECRET_KEY: PLACEHOLDER_SECRET_KEY
  DATABASE_PASSWORD: PLACEHOLDER_DB_PASSWORD
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
          valueFrom:
            configMapKeyRef:
              name: django-config
              key: DATABASE_NAME
        - name: POSTGRES_USER
          valueFrom:
            configMapKeyRef:
              name: django-config
              key: DATABASE_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: django-secret
              key: DATABASE_PASSWORD
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
        envFrom:
        - configMapRef:
            name: django-config
        env:
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: django-secret
              key: SECRET_KEY
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: django-secret
              key: DATABASE_PASSWORD
        - name: DATABASE_HOST
          value: "postgres-service"
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

# Generate secrets and update manifests
log_info "Generating secrets..."

# Generate Django secret key
DJANGO_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

# Base64 encode secrets
SECRET_KEY_B64=$(echo -n "$DJANGO_SECRET_KEY" | base64 -w 0)
DB_PASSWORD_B64=$(echo -n "$DB_PASSWORD" | base64 -w 0)

# Update the manifest with encoded secrets
sed -i "s/PLACEHOLDER_SECRET_KEY/$SECRET_KEY_B64/g" k8s-manifests.yaml
sed -i "s/PLACEHOLDER_DB_PASSWORD/$DB_PASSWORD_B64/g" k8s-manifests.yaml

log_success "Secrets generated and updated in manifests"

# Build Docker images
log_info "Building Docker images..."

log_info "Building Django backend..."
cd backend
docker build -t fullswing-backend:latest . --quiet
cd ..

log_info "Building React frontend..."
cd frontend
npm install --silent
npm run build --silent
docker build -t fullswing-frontend:latest . --quiet
cd ..

log_success "Docker images built successfully"

# Deploy to K8s
log_info "Deploying to Kubernetes..."

kubectl apply -f k8s-manifests.yaml

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
echo "📋 Next Steps:"
echo "1. Add DNS record: fullswing.stromfamily.ca CNAME strommahoganytelus.duckdns.org"
echo "2. Wait for Let's Encrypt certificate (may take a few minutes)"
echo "3. Access your app at: https://fullswing.stromfamily.ca"
echo ""
echo "🔧 Admin Commands:"
echo "• Create Django superuser: kubectl exec -it -n fullswing-capture deployment/django-backend -- python manage.py createsuperuser"
echo "• Check status: kubectl get pods -n fullswing-capture"
echo "• View logs: kubectl logs -n fullswing-capture deployment/django-backend"
echo ""
echo "📱 Usage:"
echo "• Open https://fullswing.stromfamily.ca on your iPhone"
echo "• Grant camera permissions when prompted"
echo "• Position camera to capture your Full Swing display"
echo "• Tap 'Capture Shot' to process each golf shot"
echo ""
log_success "Setup complete! Happy golfing! ⛳"
