FROM golang:1.8-alpine

ADD . /go/src/hello-app

WORKDIR /go/src/hello-app
RUN apk add --no-cache git
RUN go build -ldflags "-X main.Version=$(git rev-parse --short HEAD) -X main.Buildtime=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" -o /go/bin/hello-app .

FROM alpine:latest
COPY --from=0 /go/bin/hello-app .
ENV PORT 8080
CMD ["./hello-app"]
