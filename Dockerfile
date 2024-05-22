FROM alpine:3.19.1

RUN apk add --no-cache bash dcron curl jq

WORKDIR /app

COPY . .

ENTRYPOINT ["sh", "entrypoint.sh"]