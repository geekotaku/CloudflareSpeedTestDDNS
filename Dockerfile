FROM alpine:3.19.1

ENV TZ="Asia/Shanghai"

RUN apk add --no-cache bash dcron tzdata curl jq && cp /usr/share/zoneinfo/$TZ /etc/localtime

WORKDIR /app

COPY . .

ENTRYPOINT ["sh", "entrypoint.sh"]