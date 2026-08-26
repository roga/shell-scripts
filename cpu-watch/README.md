# cpu-watch

A lightweight CPU incident watcher for Linux.

`cpu-watch.sh` stays almost silent during normal operation. It samples CPU usage from `/proc/stat`, writes a small heartbeat/status file under `/run`, and only writes detailed diagnostic logs to disk when sustained high CPU usage is detected.

The tool is intended for intermittent CPU problems that are difficult to catch manually.

## Quick Start

Install the script at:

```text
/usr/local/bin/cpu-watch.sh
```

Make it executable:

```sh
sudo chmod +x /usr/local/bin/cpu-watch.sh
```

Before running it in the background, test it once in the foreground:

```sh
sudo /usr/local/bin/cpu-watch.sh
```

In another terminal, verify that the heartbeat is updating:

```sh
cat /run/cpu-watch.status
```

Example:

```text
2026-08-26 10:10:58 CPU=3% STEAL=0.0% CORES=4
```

The timestamp should update approximately every 5 seconds.

Press `Ctrl-C` to stop the foreground test.

## Start in the Background

Recommended command:

```sh
sudo nohup /usr/local/bin/cpu-watch.sh \
    >/tmp/cpu-watch.out \
    2>/tmp/cpu-watch.err &
```

Check that it is running:

```sh
pgrep -af cpu-watch
```

You may see several related processes because `sudo`, the shell, and temporary subshells can all appear in the process list. They normally belong to the same process tree.

To inspect the tree:

```sh
pstree -ap $(pgrep -o -f '/usr/local/bin/cpu-watch.sh')
```

## Check Watcher Status

The current watcher status is stored in:

```text
/run/cpu-watch.status
```

Check it with:

```sh
cat /run/cpu-watch.status
```

Example:

```text
2026-08-26 10:10:58 CPU=3% STEAL=0.0% CORES=4
```

This file is written under `/run`, which is normally backed by `tmpfs`, so the heartbeat does not continuously write to persistent disk storage.

The status fields are:

- `CPU` — combined CPU usage across all CPU cores
- `STEAL` — CPU steal time observed by the guest OS
- `CORES` — number of CPU cores detected by `nproc`

For a 4-core server:

```text
100% = approximately 1 fully utilized core
200% = approximately 2 fully utilized cores
400% = approximately all 4 cores fully utilized
```

## Error Output

Background startup messages and script errors are written to:

```text
/tmp/cpu-watch.err
```

Check it with:

```sh
cat /tmp/cpu-watch.err
```

A message such as:

```text
nohup: ignoring input
```

is normal and can be ignored.

Standard output is written to:

```text
/tmp/cpu-watch.out
```

Under normal operation, this file should usually remain empty.

## Incident Logs

Detailed incident logs are stored in:

```text
/var/log/cpu-watch/
```

No incident log is created while CPU usage remains below the configured threshold.

When sustained high CPU usage is detected, a new file is created, for example:

```text
/var/log/cpu-watch/incident-20260826-161530.log
```

List incidents:

```sh
sudo ls -lh /var/log/cpu-watch/
```

List them in chronological order:

```sh
sudo ls -ltr /var/log/cpu-watch/
```

Open an incident:

```sh
sudo less /var/log/cpu-watch/incident-20260826-161530.log
```

Open the newest matching incident:

```sh
sudo less /var/log/cpu-watch/incident-*.log
```

To quickly inspect captured CPU-heavy processes:

```sh
sudo grep -A 40 'TOP CPU PROCESSES' /var/log/cpu-watch/incident-*.log
```

To inspect `vmstat` data:

```sh
sudo grep -A 15 'VMSTAT' /var/log/cpu-watch/incident-*.log
```

## What Gets Captured

During an active CPU incident, the script records:

- Timestamp
- CPU usage
- CPU steal time
- CPU core count
- Uptime and load average
- Memory and swap usage
- `vmstat`
- `mpstat` when available
- Top CPU-consuming processes
- Top memory-consuming processes
- PHP / PHP-FPM processes
- MySQL / MariaDB processes
- Processes in running or uninterruptible I/O states
- Filesystem usage
- Inode usage
- Network connection summary
- TCP connections
- Raw `/proc/stat` CPU counters

This is intended to help distinguish between causes such as:

- CPU-heavy PHP requests
- MySQL / MariaDB activity
- Backup or maintenance jobs
- Compression or batch processing
- Disk I/O bottlenecks
- High kernel/system activity
- CPU steal / virtualization contention
- Unexpected long-running processes

## Default Settings

The main settings are defined near the top of `cpu-watch.sh`:

```sh
INTERVAL=5
THRESHOLD=250
TRIGGER_COUNT=3
CAPTURE_INTERVAL=10

LOGDIR=/var/log/cpu-watch
STATUSFILE=/run/cpu-watch.status
```

### `INTERVAL`

How often CPU utilization is sampled.

Default:

```text
5 seconds
```

### `THRESHOLD`

Combined CPU usage required to consider the system abnormal.

Default:

```text
250%
```

On a 4-core system, `250%` means roughly 2.5 cores are fully utilized.

### `TRIGGER_COUNT`

Number of consecutive samples above the threshold before an incident starts.

Default:

```text
3
```

With a 5-second interval, CPU usage must remain above the threshold for approximately 15 seconds before an incident log is created.

### `CAPTURE_INTERVAL`

How long the script waits between detailed captures during an active incident.

Default:

```text
10 seconds
```

### `LOGDIR`

Persistent incident log location:

```text
/var/log/cpu-watch
```

### `STATUSFILE`

Current watcher heartbeat/status:

```text
/run/cpu-watch.status
```

## Stop the Watcher

Stop all instances of the watcher:

```sh
sudo pkill -f '/usr/local/bin/cpu-watch.sh'
```

Confirm that it has stopped:

```sh
pgrep -af cpu-watch
```

No output means no matching watcher process remains.

## Restart After Updating the Script

After modifying `cpu-watch.sh`:

```sh
sudo pkill -f '/usr/local/bin/cpu-watch.sh'
```

Then start the new version:

```sh
sudo nohup /usr/local/bin/cpu-watch.sh \
    >/tmp/cpu-watch.out \
    2>/tmp/cpu-watch.err &
```

Verify the heartbeat:

```sh
cat /run/cpu-watch.status
```

Wait at least 5 seconds and check again:

```sh
sleep 6
cat /run/cpu-watch.status
```

The timestamp should change.

Finally, check for startup errors:

```sh
cat /tmp/cpu-watch.err
```

## Typical Investigation Workflow

When a CPU alert occurs:

1. Check what the watcher currently sees:

```sh
cat /run/cpu-watch.status
```

2. Check whether an incident log was created:

```sh
sudo ls -ltr /var/log/cpu-watch/
```

3. Inspect the newest incident log:

```sh
sudo less /var/log/cpu-watch/incident-*.log
```

4. Focus first on:

```text
TOP CPU PROCESSES
VMSTAT
MPSTAT
MYSQL / MARIADB
PHP / PHP-FPM
PROCESS STATES
```

The important distinction is:

```text
/run/cpu-watch.status
```

is the lightweight live heartbeat, while:

```text
/var/log/cpu-watch/incident-*.log
```

contains the persistent forensic evidence captured only during an abnormal CPU event.

## Design Goal

`cpu-watch` is not intended to replace a full monitoring platform.

Its purpose is simple:

> Wait quietly until something abnormal happens, then collect enough evidence to identify the culprit.

## Author

2026 roga <roga@roga.tw>
