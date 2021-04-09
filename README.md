**Platform**
---

## Running locally via Docker

```
$ make build
$ make run
```

## Swagger Documentation
http://localhost:8080/api


## gRPCC command-line examples
```
$ grpcc --proto ./platform.proto --address localhost:6565 -i
> client.function()
```
