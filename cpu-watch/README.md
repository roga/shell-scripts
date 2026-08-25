# cpu-watch

A lightweight CPU incident watcher for Linux.

`cpu-watch.sh` monitors total CPU usage with almost no disk writes during normal operation. When sustained high CPU usage is detected, it automatically starts collecting diagnostic information into an incident log for later investigation.

It is designed for troubleshooting intermittent CPU spikes that are difficult to catch manually.

## How It Works

During normal operation, the script periodically reads:

```text
/proc/stat
```

to calculate CPU utilization.

No log file is written unless CPU usage exceeds the configured threshold for several consecutive checks.

When an incident is detected, the script creates a log file such as:

```text
/var/log/cpu-watch/incident-20260825-162315.log
```

and periodically records system information until CPU usage returns to normal.

Each CPU incident is stored in a separate log file.

## Information Collected

During an incident, the script records:

* Current date and time
* CPU usage
* System load and uptime
* Memory and swap usage
* `vmstat` statistics
* Top CPU-consuming processes
* Top memory-consuming processes
* PHP / PHP-FPM processes
* MySQL / MariaDB processes
* Disk usage
* Network connection summary

This makes it easier to determine whether the CPU spike is caused by:

* PHP or web requests
* MySQL / MariaDB
* Backup or maintenance jobs
* Disk I/O
* High system CPU usage
* Long-running processes
* Unexpected or abnormal processes

## Default Settings

The following values can be adjusted near the top of the script:

```sh
INTERVAL=5
THRESHOLD=250
TRIGGER_COUNT=3
CAPTURE_INTERVAL=10
LOGDIR=/var/log/cpu-watch
```

### `INTERVAL`

CPU usage sampling interval, in seconds.

Default:

```text
5 seconds
```

### `THRESHOLD`

CPU usage required to trigger an incident.

CPU usage is calculated as the combined utilization of all CPU cores.

For example, on a 4-core server:

```text
100% = approximately 1 CPU core fully utilized
200% = approximately 2 CPU cores fully utilized
400% = approximately all 4 CPU cores fully utilized
```

The default threshold is:

```text
250%
```

### `TRIGGER_COUNT`

Number of consecutive threshold violations required before an incident is created.

Default:

```text
3
```

With:

```text
INTERVAL=5
TRIGGER_COUNT=3
```

CPU usage must remain above the threshold for approximately 15 seconds before logging begins.

This helps avoid logging short and harmless CPU bursts.

### `CAPTURE_INTERVAL`

How often diagnostic information is recorded during an active incident.

Default:

```text
10 seconds
```

### `LOGDIR`

Directory used for incident logs.

Default:

```text
/var/log/cpu-watch
```

## Installation

Copy the script to:

```sh
/usr/local/bin/cpu-watch.sh
```

Make it executable:

```sh
sudo chmod +x /usr/local/bin/cpu-watch.sh
```

## Running Manually

Run it in the foreground:

```sh
sudo /usr/local/bin/cpu-watch.sh
```

During normal CPU usage, the script produces no output.

Press:

```text
Ctrl-C
```

to stop it.

## Running in the Background

For temporary monitoring:

```sh
sudo nohup /usr/local/bin/cpu-watch.sh >/dev/null 2>&1 &
```

Check whether it is running:

```sh
pgrep -af cpu-watch
```

Example:

```text
12345 /bin/sh /usr/local/bin/cpu-watch.sh
```

## Stopping

Find the process:

```sh
pgrep -af cpu-watch
```

Then stop it:

```sh
sudo kill <PID>
```

Alternatively:

```sh
sudo pkill -f '/usr/local/bin/cpu-watch.sh'
```

## Viewing Incident Logs

List captured incidents:

```sh
ls -lh /var/log/cpu-watch/
```

Example:

```text
incident-20260825-162315.log
incident-20260826-160842.log
incident-20260827-161102.log
```

View an incident:

```sh
less /var/log/cpu-watch/incident-20260825-162315.log
```

To quickly find the top CPU process entries:

```sh
grep -A 40 'TOP CPU PROCESSES' /var/log/cpu-watch/incident-*.log
```

## Interpreting `vmstat`

The incident log includes output from:

```sh
vmstat 1 2
```

Important CPU fields include:

```text
us
sy
wa
id
```

### `us`

CPU time spent executing user-space applications.

High `us` may indicate CPU-heavy applications such as PHP, database queries, compression, or other computation.

### `sy`

CPU time spent inside the Linux kernel.

High `sy` can indicate heavy system calls, networking, filesystem activity, or kernel-level work.

### `wa`

CPU time spent waiting for I/O.

High `wa` usually indicates a disk or storage bottleneck rather than pure CPU computation.

### `id`

Idle CPU percentage.

A low `id` value means the CPUs are heavily utilized.

For example:

```text
us sy wa id
85 10  1  4
```

indicates that the CPUs are primarily busy doing computation.

While:

```text
us sy wa id
10  5 80  5
```

indicates that the system is primarily waiting for disk I/O.

## Why Incident-Based Logging?

A traditional monitoring script might write process information every few seconds continuously:

```text
24 hours × 60 minutes × 60 seconds
```

This creates unnecessary disk writes and large log files.

`cpu-watch` instead stays almost completely passive during normal operation and only starts detailed logging after detecting sustained abnormal CPU usage.

This makes it suitable for running for days or weeks while waiting for an intermittent problem to occur.

## Typical Investigation Workflow

Start the watcher:

```sh
sudo nohup /usr/local/bin/cpu-watch.sh >/dev/null 2>&1 &
```

Wait for the CPU problem to occur.

Then inspect:

```sh
ls -ltr /var/log/cpu-watch/
```

Open the newest incident:

```sh
less /var/log/cpu-watch/incident-*.log
```

Look first at:

```text
TOP CPU PROCESSES
VMSTAT
MYSQL / MARIADB
PHP
```

These sections usually provide enough information to identify the process responsible for the CPU spike.

## Notes

The script is intended primarily as a troubleshooting tool rather than a full monitoring system.

For long-term system monitoring, tools such as:

```text
sysstat
pidstat
sar
Prometheus
Grafana
```

may provide more complete historical metrics.

`cpu-watch` is useful when the goal is simpler:

> Wait quietly until something abnormal happens, then collect enough evidence to identify the culprit.

## Author

2026 roga <roga@roga.tw>
