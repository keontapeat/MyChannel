FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir fastapi uvicorn
COPY services/translate/api /app/api
ENV PORT=9095
EXPOSE 9095
CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "9095"]



