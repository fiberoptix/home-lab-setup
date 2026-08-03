# One image, two entrypoints. The workload picks producer.py or consumer.py.
FROM python:3.12-slim

WORKDIR /app

# confluent-kafka ships manylinux wheels with librdkafka bundled, so no build
# toolchain is needed here.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY oms.py producer.py consumer.py ./

# Unbuffered, or `kubectl logs` shows nothing until the process exits, which
# makes every demo in Chapter 6 unwatchable.
ENV PYTHONUNBUFFERED=1

CMD ["python", "consumer.py"]
