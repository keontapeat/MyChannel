FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

ENV PORT=8080
ENV GCP_PROJECT=mychannel-ca26d

CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 main:app
