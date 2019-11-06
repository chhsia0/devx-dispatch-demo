FROM golang:1.8-alpine

ADD . /go/src/hello-app

WORKDIR /go/src/hello-app
RUN apk add --no-cache git
RUN go build -ldflags "-X main.Version=$(git rev-parse --short HEAD) -X main.Buildtime=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" -o /go/bin/hello-app .
RUN go test -c -o /go/bin/hello-app.test

FROM alpine:latest
COPY --from=0 /go/bin/hello-app .
COPY --from=0 /go/bin/hello-app.test .
ENV PORT 8080
CMD ["./hello-app"]
