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

# Run as a fixed unprivileged uid. The pod specs also set runAsNonRoot, but a
# pod-level setting only protects the pods that carry it; baking it into the
# image means the container is unprivileged wherever it runs, including
# `docker run` on a laptop. The uid is numeric rather than a name because
# runAsNonRoot cannot verify a username -- the kubelet has no way to resolve
# it against the image's /etc/passwd before starting the container.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin app
USER 10001

CMD ["python", "consumer.py"]
