FROM python:3.11-slim
WORKDIR /home/site/wwwroot
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY blob_query.py .
CMD ["python", "blob_query.py"]
