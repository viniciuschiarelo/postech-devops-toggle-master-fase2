FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd -m app
USER app
EXPOSE 8003
CMD ["gunicorn", "--bind", "0.0.0.0:8003", "app:app"]
