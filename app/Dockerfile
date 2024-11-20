FROM python:3.13-slim

WORKDIR /opt

COPY requirements.txt /opt
RUN pip3 install -r requirements.txt

RUN mkdir certs
RUN apt update
RUN apt install openssl -y
RUN openssl req -newkey rsa:4096 \
    -x509 \
    -sha256 \
    -days 3650 \
    -nodes \
    -out ./certs/cert.crt \
    -keyout ./certs/key.key \
    -subj "/C=US/ST=IN/L=IN/O=Shield/OU=Shield/CN=www.hopliteconsulting.com"

ENV VERSION=3.0.51

COPY . ./app

CMD uvicorn app.main:app --host 0.0.0.0 --ssl-keyfile=./certs/key.key --ssl-certfile=./certs/cert.crt --log-config ./app/config/log.yaml
