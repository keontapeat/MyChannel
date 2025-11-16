FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY main.py .

# Run the application
CMD exec gunicorn --bind :$PORT --workers 4 --threads 8 --timeout 5 main:app

