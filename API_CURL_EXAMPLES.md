# hubcell API curl examples

These examples assume the API is listening on `localhost:10012`.

```sh
BASE=http://localhost:10012
JSON='Content-Type: application/json'
```

Some examples use `jq` only to capture IDs:

```sh
CELL=$(curl -s "$BASE/v1/cells?limit=1" | jq -r '.cells[0].config.id')
```

## Health, config, and schema

```sh
curl "$BASE/healthz"
curl "$BASE/v1/config"
curl "$BASE/v1/openapi.json"
```

## Websocket realtime feed

Open a websocket and subscribe to cells, stats, and event batches.

With `websocat`:

```sh
websocat "ws://localhost:10012/v1/ws"
```

Then send JSON messages such as:

```json
{"action":"subscribe","subscription_id":"cells-main","topic":"cells","interval_ms":1000}
{"action":"subscribe","subscription_id":"demo-stats","topic":"stats","cell_id":"demo","interval_ms":1000}
{"action":"subscribe","subscription_id":"events-main","topic":"events","cursor":"0","interval_ms":1000}
```

Unsubscribe:

```json
{"action":"unsubscribe","subscription_id":"cells-main"}
```

## Image extraction

Extract a Docker image into hubcell's image store without creating a container:

```sh
curl -X POST "$BASE/v1/images/extract" \
  -H "$JSON" \
  -d '{"image":"alpine:latest"}'
```

Legacy extract endpoint:

```sh
curl -X POST "$BASE/extract" \
  -H "$JSON" \
  -d '{"image":"alpine:latest"}'
```

## Standalone volumes

Standalone volumes exist independently of any specific cell and can be attached to any cell as needed.

Create a 5GB standalone volume with the default `balanced` profile:

```sh
curl -X POST "$BASE/v1/volumes" \
  -H "$JSON" \
  -d '{"name": "shared-data", "virtual_size_bytes": 5368709120}'
```

Create a higher-throughput standalone volume:

```sh
curl -X POST "$BASE/v1/volumes" \
  -H "$JSON" \
  -d '{"name":"shared-fast","virtual_size_bytes":5368709120,"performance_profile":"high-performance"}'
```

List all standalone volumes:

```sh
curl "$BASE/v1/volumes"
```

Delete a standalone volume:

```sh
curl -X DELETE "$BASE/v1/volumes/shared-data"
```

## Security & Capabilities

Run a cell with specific added Linux capabilities:

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "image": "alpine:latest",
    "security": {
      "add_capabilities": ["NET_ADMIN", "SYS_PTRACE"]
    }
  }'
```

Run a privileged cell (unconfined, full capabilities, access to host devices):

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "id": "gitea",
    "image": "gitea/gitea:latest",
    "security": {
      "add_capabilities": ["ALL"],
      "drop_capabilities": [],
      "seccomp_profile": "unconfined",
      "no_new_privileges": false
    }
  }'
```

## Create, list, inspect, and delete cells

Create a stopped cell:

```sh
curl -X POST "$BASE/v1/cells" \
  -H "$JSON" \
  -d '{
    "id": "demo",
    "image": "alpine:latest",
    "command": ["/bin/sh", "-c", "sleep 300"],
    "env": ["APP_ENV=dev"],
    "workdir": "/",
    "ignore_memory_warning": false,
    "resources": {
      "memory_max_bytes": 134217728,
      "shm_size_bytes": 134217728,
      "pids_max": 128
    },
    "storage": {
      "rootfs_virtual_size_bytes": 1073741824
    },
    "security": {
      "no_new_privileges": true,
      "drop_capabilities": ["ALL"]
    }
  }'
```

Create a cell without a memory limit. This will default `/dev/shm` to `64 MiB`:

```sh
curl -X POST "$BASE/v1/cells" \
  -H "$JSON" \
  -d '{
    "id": "demo-uncapped",
    "image": "alpine:latest",
    "command": ["/bin/sh", "-c", "sleep 300"]
  }'
```

Create a cell with a memory limit. This will default `/dev/shm` to `512 MiB`,
or lower if the memory limit is smaller:

```sh
curl -X POST "$BASE/v1/cells" \
  -H "$JSON" \
  -d '{
    "id": "demo-capped",
    "image": "alpine:latest",
    "resources": {
      "memory_max_bytes": 1073741824
    }
  }'
```

Create a stopped cell with labels. `created_by_version` is tagged automatically:

```sh
curl -X POST "$BASE/v1/cells" \
  -H "$JSON" \
  -d '{
    "image": "alpine:latest",
    "labels": {
      "app": "demo",
      "tier": "test"
    }
  }'
```

List cells with pagination:

```sh
curl "$BASE/v1/cells?limit=25"
curl "$BASE/v1/cells?limit=25&cursor=25"
```

Inspect one cell:

```sh
curl "$BASE/v1/cells/demo"
```

Delete a stopped cell:

```sh
curl -X DELETE "$BASE/v1/cells/demo"
```

Stop and delete an active cell in one explicit operation:

```sh
curl -X DELETE "$BASE/v1/cells/demo?force-delete=true"
```

The same force flag can be sent as a JSON body when a client cannot easily add
query parameters:

```sh
curl -X DELETE "$BASE/v1/cells/demo" \
  -H "$JSON" \
  -d '{"force-delete":true}'
```

## Run cells

Create and start in one request:

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "image": "alpine:latest",
    "command": ["/bin/sh", "-c", "sleep 300"]
  }'
```

Run with auto-sleep (5 seconds idle) and auto-wake enabled:

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "image": "alpine:latest",
    "command": ["/bin/sh", "-c", "echo \"AWAKE!\" > index.html && busybox httpd -f -p 80"],
    "scaling": {
      "auto_sleep_seconds": 5,
      "auto_wake": true
    },
    "network": {
      "allow_host": true
    }
  }'
```

Run a web-terminal image. It gets an isolated network automatically:

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "id": "webterm",
    "image": "raonigabriel/web-terminal:latest",
    "network": {
      "allow_host": true
    }
  }'
```

Run with vertical autoscaling for memory, CPU, and rootfs growth:

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "image": "alpine:latest",
    "command": ["/bin/sh", "-c", "sleep 300"],
    "resources": {
      "memory_max_bytes": 536870912,
      "cpu_quota_us": 50000,
      "cpu_period_us": 100000
    },
    "storage": {
      "rootfs_initial_size_bytes": 1073741824,
      "rootfs_virtual_size_bytes": 8589934592
    },
    "scaling": {
      "memory": {
        "final_max_bytes": 2147483648
      },
      "cpu": {
        "final_quota_us": 200000
      },
      "rootfs": {
        "max_size_bytes": 8589934592,
        "scale_up_usage_pct": 82,
        "scale_up_step_bytes": 1073741824
      }
    }
  }'
```

Run with Docker image defaults only:

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{"image":"nginx:alpine"}'
```

Run without networking:

```sh
curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "id": "offline",
    "image": "alpine:latest",
    "command": ["sleep", "300"],
    "network": {"disabled": true}
  }'
```

## Lifecycle

```sh
curl -X POST "$BASE/v1/cells/demo/start"
curl -X POST "$BASE/v1/cells/demo/sleep"
curl -X POST "$BASE/v1/cells/demo/wake"
curl -X POST "$BASE/v1/cells/demo/stop"
```

Recreate a cell on the current hubcell runtime while preserving config,
volumes, and network attachments:

```sh
curl -X POST "$BASE/v1/cells/demo/recreate" \
  -H "$JSON" \
  -d '{}'
```

Recreate and start even if it was stopped:

```sh
curl -X POST "$BASE/v1/cells/demo/recreate" \
  -H "$JSON" \
  -d '{"start":true}'
```

Recreate without starting and reset the writable root image:

```sh
curl -X POST "$BASE/v1/cells/demo/recreate" \
  -H "$JSON" \
  -d '{"start":false,"reset_rootfs":true}'
```

## Resource limits

Patch live cgroup settings:

```sh
curl -X PATCH "$BASE/v1/cells/demo/resources" \
  -H "$JSON" \
  -d '{
    "resources": {
      "memory_max_bytes": 268435456,
      "memory_swap_max_bytes": 268435456,
      "shm_size_bytes": 134217728,
      "pids_max": 256,
      "cpu_quota_us": 50000,
      "cpu_period_us": 100000,
      "cpu_weight": 100,
      "io_read_bps": 10485760,
      "io_write_bps": 5242880
    }
  }'
```

Shared memory sizing rules:

- `shm_size_bytes` must be less than or equal to `memory_max_bytes` when a
  memory limit is set.
- Without `memory_max_bytes`, any `shm_size_bytes` above `64 MiB` requires
  `ignore_memory_warning=true`.
- `shm_size_bytes` changes are persisted, but changing `/dev/shm` size for an
  active cell still requires stop/restart or recreate.

Override the uncapped-memory warning explicitly:

```sh
curl -X PATCH "$BASE/v1/cells/demo/resources" \
  -H "$JSON" \
  -d '{
    "ignore_memory_warning": true,
    "resources": {
      "shm_size_bytes": 536870912
    }
  }'
```

Remove a limit by omitting it from the replacement resource object:

```sh
curl -X PATCH "$BASE/v1/cells/demo/resources" \
  -H "$JSON" \
  -d '{"resources":{"pids_max":512}}'
```

## Per-cell network config

Allow host-to-cell routed access and add upload/download shaping:

```sh
curl -X PATCH "$BASE/v1/cells/demo/network" \
  -H "$JSON" \
  -d '{
    "network": {
      "mode": "isolated-nat",
      "allow_host": true,
      "egress_rate_bps": 10000000,
      "ingress_rate_bps": 20000000
    }
  }'
```

Move the primary network to a named network:

```sh
curl -X PATCH "$BASE/v1/cells/demo/network" \
  -H "$JSON" \
  -d '{
    "network": {
      "mode": "isolated-nat",
      "virtual_network": "appnet",
      "interface_name": "eth0"
    }
  }'
```

Replace the full network set. This can move a cell off old networks and onto
multiple new networks in one call:

```sh
curl -X PATCH "$BASE/v1/cells/demo/networks" \
  -H "$JSON" \
  -d '{
    "network": {"mode":"isolated-nat"},
    "networks": [
      {"virtual_network":"appnet","interface_name":"eth1","default_route":true},
      {"virtual_network":"backnet","interface_name":"eth2"}
    ]
  }'
```

## Restart policy

```sh
curl -X PATCH "$BASE/v1/cells/demo/restart" \
  -H "$JSON" \
  -d '{"restart":{"name":"always","delay_seconds":2}}'
```

```sh
curl -X PATCH "$BASE/v1/cells/demo/restart" \
  -H "$JSON" \
  -d '{"restart":{"name":"on-failure","max_retries":3,"delay_seconds":1}}'
```

Disable restart:

```sh
curl -X PATCH "$BASE/v1/cells/demo/restart" \
  -H "$JSON" \
  -d '{"restart":{"name":"no"}}'
```

## Labels and scaling

Update cell labels without restarting:

```sh
curl -X PATCH "$BASE/v1/cells/demo/labels" \
  -H "$JSON" \
  -d '{
    "labels": {
      "owner": "platform",
      "service": "api"
    }
  }'
```

Update vertical scaling policy:

```sh
curl -X PATCH "$BASE/v1/cells/demo/scaling" \
  -H "$JSON" \
  -d '{
    "scaling": {
      "memory": {
        "min_max_bytes": 536870912,
        "final_max_bytes": 2147483648
      },
      "cpu": {
        "min_quota_us": 50000,
        "final_quota_us": 200000
      }
    }
  }'
```

## Logs

```sh
curl "$BASE/v1/cells/demo/logs"
```

## Exec

Captured exec:

```sh
curl -X POST "$BASE/v1/cells/demo/exec" \
  -H "$JSON" \
  -d '{"command":["/bin/sh","-c","id && pwd && cat /etc/os-release"]}'
```

Captured exec with user, workdir, and env:

```sh
curl -X POST "$BASE/v1/cells/demo/exec" \
  -H "$JSON" \
  -d '{
    "command": ["/bin/sh", "-c", "echo $HELLO && id"],
    "env": ["HELLO=world"],
    "workdir": "/tmp",
    "user": "0"
  }'
```

Streaming exec using query args and request body as stdin:

```sh
printf 'echo from-stdin\nexit\n' | curl -N -X POST --data-binary @- \
  "$BASE/v1/cells/demo/exec/stream?stdin=true&tty=true&argv=/bin/sh&argv=-i"
```

Streaming exec with repeated env parameters:

```sh
curl -N -X POST \
  "$BASE/v1/cells/demo/exec/stream?argv=/bin/sh&argv=-c&argv=echo%20%24HELLO&env=HELLO=world"
```

## Volumes

List volumes attached to a cell:

```sh
curl "$BASE/v1/cells/demo/volumes"
```

Attach a stopped-cell private virtual volume:

```sh
curl -X POST "$BASE/v1/cells/demo/volumes" \
  -H "$JSON" \
  -d '{
    "volume": {
      "name": "data",
      "mount_path": "/data",
      "virtual_size_bytes": 10737418240,
      "initial_size_bytes": 268435456,
      "grow_step_bytes": 268435456
    }
  }'
```

Attach a fixed-size read-only volume:

```sh
curl -X POST "$BASE/v1/cells/demo/volumes" \
  -H "$JSON" \
  -d '{
    "volume": {
      "name": "readonly",
      "mount_path": "/readonly",
      "size_bytes": 1073741824,
      "read_only": true
    }
  }'
```

Attach a stopped-cell shared standalone volume:

```sh
curl -X POST "$BASE/v1/cells/demo/volumes" \
  -H "$JSON" \
  -d '{
    "volume": {
      "name": "shared-data",
      "source": "shared-data",
      "mount_path": "/shared"
    }
  }'
```

Create a cell with a shared standalone volume already attached:

```sh
curl -X POST "$BASE/v1/cells" \
  -H "$JSON" \
  -d '{
    "id": "demo",
    "image": "alpine:latest",
    "network": {"disabled": true},
    "volumes": [
      {"name":"shared-data","source":"shared-data","mount_path":"/data"}
    ]
  }'
```

Inspect one volume:

```sh
curl "$BASE/v1/cells/demo/volumes/data"
```

Detach a stopped-cell volume:

```sh
curl -X DELETE "$BASE/v1/cells/demo/volumes/data"
```

## Storage usage and growth

```sh
curl "$BASE/v1/cells/demo/storage"
```

Grow rootfs to at least 2 GiB:

```sh
curl -X POST "$BASE/v1/cells/demo/storage/grow" \
  -H "$JSON" \
  -d '{"target_size_bytes":2147483648}'
```

Grow a volume to at least 4 GiB:

```sh
curl -X POST "$BASE/v1/cells/demo/storage/grow" \
  -H "$JSON" \
  -d '{"volume_name":"data","target_size_bytes":4294967296}'
```

## Virtual networks

Create a named virtual network with automatic subnet allocation:

```sh
curl -X POST "$BASE/v1/networks" \
  -H "$JSON" \
  -d '{"name":"appnet"}'
```

Create a network with an auto-generated name:

```sh
curl -X POST "$BASE/v1/networks" \
  -H "$JSON" \
  -d '{"labels":{"role":"shared"}}'
```

Create a named network with explicit subnet, bridge, labels, and shaping:

```sh
curl -X POST "$BASE/v1/networks" \
  -H "$JSON" \
  -d '{
    "name": "backnet",
    "subnet": "10.250.20.0/24",
    "gateway_ip": "10.250.20.1",
    "bridge_name": "hcbbacknet",
    "internal": true,
    "allow_host": false,
    "enable_icc": true,
    "enable_masquerade": false,
    "egress_rate_bps": 50000000,
    "ingress_rate_bps": 50000000,
    "labels": {"env":"dev"}
  }'
```

List and inspect networks:

```sh
curl "$BASE/v1/networks"
curl "$BASE/v1/networks/appnet"
```

Attach a cell to a named network without replacing its current network set:

```sh
curl -X POST "$BASE/v1/networks/appnet/connect" \
  -H "$JSON" \
  -d '{
    "cell_id": "demo",
    "interface_name": "eth1",
    "default_route": false,
    "allow_host": false,
    "egress_rate_bps": 10000000,
    "ingress_rate_bps": 10000000
  }'
```

Attach with a fixed IP:

```sh
curl -X POST "$BASE/v1/networks/appnet/connect" \
  -H "$JSON" \
  -d '{"cell_id":"demo","ipv4_address":"10.250.20.50","interface_name":"eth1"}'
```

Attach with aliases:

```sh
curl -X POST "$BASE/v1/networks/appnet/connect" \
  -H "$JSON" \
  -d '{
    "cell_id": "demo",
    "aliases": ["web", "frontend"]
  }'
```

Disconnect from one network:

```sh
curl -X POST "$BASE/v1/networks/appnet/disconnect" \
  -H "$JSON" \
  -d '{"cell_id":"demo"}'
```

Delete an unused network:

```sh
curl -X DELETE "$BASE/v1/networks/appnet"
```

Update network labels:

```sh
curl -X PATCH "$BASE/v1/networks/appnet/labels" \
  -H "$JSON" \
  -d '{"labels":{"env":"dev","team":"platform"}}'
```

## Events and audit

List lifecycle events:

```sh
curl "$BASE/v1/events?limit=100"
```

Follow lifecycle events as server-sent events:

```sh
curl -N "$BASE/v1/events?follow=true"
```

Continue from a cursor:

```sh
curl "$BASE/v1/events?limit=50&cursor=50"
```

List audit records:

```sh
curl "$BASE/v1/audit?limit=100"
```

Continue audit pagination:

```sh
curl "$BASE/v1/audit?limit=100&cursor=100"
```

## Error checks

Unknown JSON fields are rejected:

```sh
curl -i -X POST "$BASE/v1/cells" \
  -H "$JSON" \
  -d '{"image":"alpine:latest","bad":true}'
```

Invalid pagination returns a structured error:

```sh
curl -i "$BASE/v1/cells?limit=-1"
```

Starting an already running cell returns conflict-style behavior:

```sh
curl -i -X POST "$BASE/v1/cells/demo/start"
```

## End-to-end smoke flow

This creates a network, runs a cell, attaches a volume, executes a command,
checks usage, recreates the cell, and stops it.

```sh
curl -X POST "$BASE/v1/networks" -H "$JSON" -d '{"name":"smokenet"}'

curl -X POST "$BASE/v1/cells/run" \
  -H "$JSON" \
  -d '{
    "id":"smoke",
    "image":"alpine:latest",
    "command":["/bin/sh","-c","sleep 300"],
    "network":{"virtual_network":"smokenet"},
    "resources":{"pids_max":64,"memory_max_bytes":134217728}
  }'

curl -X POST "$BASE/v1/cells/smoke/stop"

curl -X POST "$BASE/v1/cells/smoke/volumes" \
  -H "$JSON" \
  -d '{"volume":{"name":"data","mount_path":"/data","virtual_size_bytes":1073741824}}'

curl -X POST "$BASE/v1/cells/smoke/start"

curl -X POST "$BASE/v1/cells/smoke/exec" \
  -H "$JSON" \
  -d '{"command":["/bin/sh","-c","echo ok >/data/probe && cat /data/probe"]}'

curl "$BASE/v1/cells/smoke/storage"

curl -X POST "$BASE/v1/cells/smoke/recreate" \
  -H "$JSON" \
  -d '{"start":true}'

curl -X POST "$BASE/v1/cells/smoke/stop"
curl -X DELETE "$BASE/v1/cells/smoke"
curl -X DELETE "$BASE/v1/networks/smokenet"
```
