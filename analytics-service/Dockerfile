FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd -m app
USER app
EXPOSE 8005
CMD ["gunicorn", "--bind", "0.0.0.0:8005", "--workers", "1", "--threads", "2", "app:app"]
