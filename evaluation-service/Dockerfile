FROM golang:1.21-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go mod tidy && CGO_ENABLED=0 GOOS=linux go build -o service .
FROM alpine:3.20
RUN adduser -D app
USER app
COPY --from=build /app/service /service
EXPOSE 8004
CMD ["/service"]
