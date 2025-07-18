FROM python:3.11

# Install system dependencies for OpenCV and Tesseract
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-eng \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libgomp1 \
    libgtk-3-0 \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create media directory
RUN mkdir -p /app/media /app/staticfiles

EXPOSE 8000

# Run collectstatic at startup when env vars are available
CMD python manage.py collectstatic --noinput && \
    python manage.py migrate && \
    gunicorn --bind 0.0.0.0:8000 --workers 2 project.wsgi:application
