FROM golang:bookworm AS build-app
WORKDIR /app
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY . .
RUN go build -o virtuegaming .

FROM ubuntu:22.04 as aptos_builder
WORKDIR /app
RUN apt update -y && \
    apt install -y wget unzip && \
    wget https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v3.0.2/aptos-cli-3.0.2-Ubuntu-22.04-x86_64.zip && \
    unzip aptos-cli-3.0.2-Ubuntu-22.04-x86_64.zip && \
    rm -rf /app/aptos-cli-3.0.2-Ubuntu-22.04-x86_64.zip && apt remove -y wget unzip

FROM ubuntu:22.04
# FROM chromedp/headless-shell:113.0.5672.93
WORKDIR /app
RUN apt update &&\
    apt install -y curl &&\
    curl -LO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get install -y ./google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb && \
    apt remove -y curl
COPY --from=build-app /app/virtuegaming .
COPY --from=build-app /app/image.png .
COPY --from=aptos_builder /app/aptos .
COPY ./docker-start.sh .

CMD [ "bash", "docker-start.sh" ]