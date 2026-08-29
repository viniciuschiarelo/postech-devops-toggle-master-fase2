FROM golang:1.21-alpine AS builder 

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_enabled=0 GOOS=linux go 
build -o evalution-service .



FROM alpine:3.19
WORKDIR /app
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/evaluation-service . 
EXPOSE 8004

CMD ["./evaluation-service"]
