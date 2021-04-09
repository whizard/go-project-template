FROM golang:alpine as builder

# Install git + SSL ca certificates
RUN apk update && apk add git && apk add ca-certificates

# Create appuser
RUN adduser -D -g '' appuser
COPY . /src
WORKDIR /app

#get dependancies
RUN cd /src && go get -d -v

#build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags=”-w -s” -o /app/bin/app

#change ownership to appuser
RUN chown -R appuser: /app

# STEP 2 build a small image
# start from scratch
FROM scratch

# copy over the certs and the passwd file for the appuser
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /etc/passwd /etc/passwd

# Copy our static executable
COPY --from=builder /app/bin/myapp /app/myapp

# never run as root; use appuser
USER appuser

ENTRYPOINT ["/app/myapp"]
