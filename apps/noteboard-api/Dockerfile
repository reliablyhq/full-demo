
FROM python:3.9-slim-buster as build

COPY requirements.txt requirements.txt
COPY requirements-gcp.txt requirements-gcp.txt

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        make \
        gcc && \
    pip install --user -q -U pip wheel && \
    pip install --user -q --prefer-binary -r requirements.txt && \
    pip install --user -q --prefer-binary -r requirements-gcp.txt

FROM python:3.9-slim-buster as run

# Any non-zero number will do, and unfortunately a named user will not,
# as k8s pod securityContext runAsNonRoot can't resolve the user ID:
# https://github.com/kubernetes/kubernetes/issues/40958
RUN addgroup --gid 1001 svc
RUN useradd -m -u 1001 -g 1001 svc
USER 1001
WORKDIR /home/svc
ENV PORT 8001

COPY app.py app.py
COPY --chown=svc:svc --from=build /root/.local /home/svc/.local

ENTRYPOINT ["python"]
CMD ["app.py"]