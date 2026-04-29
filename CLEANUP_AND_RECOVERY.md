# Cleanup and recovery

hubcell creates several host resources for each running cell:

- loop-mounted ext4 root storage
- overlayfs merged rootfs
- loop-mounted ext4 virtual volumes
- veth pairs and optional named-network bridges
- iptables rules for isolation/NAT
- tc qdiscs and filters for rate limits
- cgroups v2 directories
- per-cell systemd units for boot recovery

Cleanup has two layers: transactional rollback while starting a cell, and stale
resource discovery after a cell exits, fails, or is reconciled after reboot.

## Transactional rollback

Storage and network setup are ordered operations. A later failure must unwind
earlier successful steps.

The rollback stack records cleanup actions after each successful host-side
operation. If setup returns an error before commit, actions run in reverse
order. If setup completes, the stack is committed and no rollback action runs.

Storage rollback covers:

- root ext4 loop mount
- overlay mount
- virtual volume mounts

Network rollback covers:

- named bridge created for a network when setup fails before any other member
  uses it
- veth host side
- firewall rules associated with the veth/bridge
- tc state removed as part of link deletion

The cleanup stack reports aggregate rollback errors instead of hiding them.
Normal setup still returns the original setup error to the caller.

## Stale resource discovery

Saved cell state can be incomplete after crashes, failed setup, or old hubcell
versions. For that reason cleanup does not depend only on stored runtime state.

The stale discovery pass:

- scans `/proc/self/mountinfo` for mounted targets under the cell `data_dir`
  and unmounts deepest paths first
- removes network interfaces recorded in cell state
- computes deterministic expected veth names from cell ID and network config
  and removes them even if state did not record them
- removes firewall rules for both per-cell isolated networks and named-network
  bridges when enough config remains
- removes saved and deterministic cgroup paths

Missing links and already removed resources are treated as successful cleanup.

## API boot recovery

When `hubcell serve` starts, it calls runtime recovery:

1. All cells are loaded from the store.
2. Active or `auto_start` cells get their systemd recovery unit refreshed.
3. Cells marked active but without a live payload process are cleaned with
   stale discovery.
4. Previously active or `auto_start` cells are started again.

This means running cells do not require the API server to survive, but the API
can still reconcile stale state when it comes back.

## Systemd recovery units

When a cell starts, hubcell installs:

```text
/etc/systemd/system/hubcell-cell-<id>.service
```

The service executes:

```text
hubcell shim <id>
```

The shim reads the cell config and starts the payload independently of the API
server. Stopping a non-`auto_start` cell removes the unit. `auto_start` cells
keep the unit enabled.

## Manual cleanup signals

The normal public API does not expose a destructive global cleanup endpoint.
Use these checks during development when diagnosing leftovers:

```sh
findmnt | grep hubcell
ip link show | grep -E 'hc|hcb'
iptables -S | grep hubcell
systemctl list-unit-files 'hubcell-cell-*'
```

Then prefer stopping/deleting the affected cell through hubcell so the store,
events, audit log, systemd unit, mounts, cgroups, and network state remain
consistent.
