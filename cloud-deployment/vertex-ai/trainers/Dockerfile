FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /trainer

RUN pip install --no-cache-dir \
    google-cloud-bigquery \
    google-cloud-storage \
    google-cloud-aiplatform \
    scikit-learn==1.3.2 \
    pandas \
    numpy \
    joblib \
    db-dtypes \
    pyarrow \
    pandas-gbq

COPY . .

ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["python3", "-m"]
