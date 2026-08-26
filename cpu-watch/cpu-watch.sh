#!/bin/sh

# cpu-watch.sh
#
# Lightweight CPU incident watcher for Linux.
#
# Normal operation:
# - Reads /proc/stat periodically.
# - Writes only a small status file under /run (usually tmpfs / RAM).
# - Does not write incident logs to disk.
#
# Incident operation:
# - When sustained CPU usage exceeds THRESHOLD,
#   detailed diagnostic information is written to LOGDIR.
#
# CPU usage is expressed as the sum of all CPU cores.
#
# Example:
#   4 cores = maximum 400%
#
# Requirements:
#   ps
#   awk
#   vmstat
#   free
#   ss
#   nproc
#
# Optional:
#   mpstat (from sysstat)

INTERVAL=5
THRESHOLD=250
TRIGGER_COUNT=3
CAPTURE_INTERVAL=10

LOGDIR=/var/log/cpu-watch
STATUSFILE=/run/cpu-watch.status

mkdir -p "$LOGDIR"

CPUS=$(nproc)

read_cpu()
{
    awk '/^cpu / {
        usr=$2
        nice=$3
        sys=$4
        idle=$5
        iowait=$6
        irq=$7
        softirq=$8
        steal=$9

        total=usr+nice+sys+idle+iowait+irq+softirq+steal

        print total, idle+iowait, steal
    }' /proc/stat
}

get_cpu_usage()
{
    set -- $(read_cpu)

    TOTAL1=$1
    IDLE1=$2
    STEAL1=$3

    sleep "$INTERVAL"

    set -- $(read_cpu)

    TOTAL2=$1
    IDLE2=$2
    STEAL2=$3

    DT=$((TOTAL2 - TOTAL1))
    DI=$((IDLE2 - IDLE1))
    DS=$((STEAL2 - STEAL1))

    if [ "$DT" -eq 0 ]; then
        CPU=0
        STEAL=0
        return
    fi

    CPU=$(awk \
        -v dt="$DT" \
        -v di="$DI" \
        -v cpus="$CPUS" \
        'BEGIN {
            printf "%.0f", ((dt-di)/dt) * 100 * cpus
        }')

    STEAL=$(awk \
        -v dt="$DT" \
        -v ds="$DS" \
        'BEGIN {
            printf "%.1f", (ds/dt) * 100
        }')
}

write_status()
{
    printf '%s CPU=%s%% STEAL=%s%% CORES=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$CPU" \
        "$STEAL" \
        "$CPUS" \
        > "$STATUSFILE"
}

capture()
{
    FILE="$1"

    {
        echo
        echo "============================================================"
        echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "CPU: ${CPU}%"
        echo "STEAL: ${STEAL}%"
        echo "CPU CORES: $CPUS"
        echo "============================================================"

        echo
        echo "----- UPTIME -----"
        uptime

        echo
        echo "----- LOADAVG -----"
        cat /proc/loadavg

        echo
        echo "----- MEMORY -----"
        free -m

        echo
        echo "----- VMSTAT -----"
        vmstat 1 2

        if command -v mpstat >/dev/null 2>&1; then
            echo
            echo "----- MPSTAT -----"
            mpstat 1 2
        fi

        echo
        echo "----- TOP CPU PROCESSES -----"
        ps -eo pid,ppid,user,%cpu,%mem,etime,stat,cmd \
            --sort=-%cpu | head -40

        echo
        echo "----- TOP MEMORY PROCESSES -----"
        ps -eo pid,ppid,user,%cpu,%mem,etime,stat,cmd \
            --sort=-%mem | head -20

        echo
        echo "----- PHP / PHP-FPM -----"
        pgrep -af 'php|php-fpm' || true

        echo
        echo "----- MYSQL / MARIADB -----"
        ps -eo pid,ppid,user,%cpu,%mem,etime,stat,cmd |
            grep '[m]aria\|[m]ysql' || true

        echo
        echo "----- PROCESS STATES -----"
        ps -eo stat,pid,ppid,user,%cpu,%mem,etime,cmd \
            | awk '$1 ~ /^D/ || $1 ~ /^R/'

        echo
        echo "----- DISK FILESYSTEM -----"
        df -h

        echo
        echo "----- DISK INODES -----"
        df -i

        echo
        echo "----- NETWORK SUMMARY -----"
        ss -s 2>/dev/null || true

        echo
        echo "----- TCP CONNECTIONS -----"
        ss -tan 2>/dev/null | head -100 || true

        echo
        echo "----- /PROC/STAT CPU -----"
        grep '^cpu' /proc/stat

        echo

    } >> "$FILE"
}

COUNT=0
INCIDENT=0
LOGFILE=""

while true
do
    get_cpu_usage

    write_status

    if [ "$CPU" -ge "$THRESHOLD" ]; then
        COUNT=$((COUNT + 1))
    else
        COUNT=0

        if [ "$INCIDENT" -eq 1 ]; then
            {
                echo
                echo "============================================================"
                echo "INCIDENT ENDED: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "CPU: ${CPU}%"
                echo "STEAL: ${STEAL}%"
                echo "============================================================"
            } >> "$LOGFILE"

            INCIDENT=0
            LOGFILE=""
        fi
    fi

    if [ "$COUNT" -ge "$TRIGGER_COUNT" ]; then

        if [ "$INCIDENT" -eq 0 ]; then
            LOGFILE="$LOGDIR/incident-$(date '+%Y%m%d-%H%M%S').log"

            INCIDENT=1

            {
                echo "CPU INCIDENT"
                echo
                echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Threshold: ${THRESHOLD}%"
                echo "Trigger count: $TRIGGER_COUNT"
                echo "CPU cores: $CPUS"
                echo "CPU: ${CPU}%"
                echo "STEAL: ${STEAL}%"
            } > "$LOGFILE"
        fi

        capture "$LOGFILE"

        sleep "$CAPTURE_INTERVAL"
    fi
done