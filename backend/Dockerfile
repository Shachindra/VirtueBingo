FROM golang:alpine AS build-app
WORKDIR /app
RUN apk update && apk add --no-cache git
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY . .
RUN go build -o bingo . && apk del git

FROM alpine:latest
# FROM chromedp/headless-shell:113.0.5672.93
RUN apk add chromium
RUN cp /usr/bin/chromium /usr/bin/google-chrome
WORKDIR /app
COPY --from=build-app /app/bingo .
COPY --from=build-app /app/image.png .

CMD ["./bingo"]