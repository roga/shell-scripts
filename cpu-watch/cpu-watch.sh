#!/bin/sh

# Author: 2026 roga <roga@roga.tw>

# CPU usage is expressed as sum of all CPU cores.
# Example: 4 cores = maximum 400%.

INTERVAL=5
THRESHOLD=250
TRIGGER_COUNT=3
CAPTURE_INTERVAL=10
LOGDIR=/var/log/cpu-watch

mkdir -p "$LOGDIR"

CPUS=$(nproc)

read_cpu()
{
    awk '/^cpu / {
        idle=$5+$6
        total=0
        for (i=2; i<=NF; i++)
            total += $i
        print total, idle
    }' /proc/stat
}

get_cpu_usage()
{
    set -- $(read_cpu)
    TOTAL1=$1
    IDLE1=$2

    sleep "$INTERVAL"

    set -- $(read_cpu)
    TOTAL2=$1
    IDLE2=$2

    DT=$((TOTAL2 - TOTAL1))
    DI=$((IDLE2 - IDLE1))

    awk -v dt="$DT" -v di="$DI" -v cpus="$CPUS" \
        'BEGIN {
            if (dt == 0)
                print 0
            else
                printf "%.0f", ((dt-di)/dt) * 100 * cpus
        }'
}

capture()
{
    FILE="$1"
    CPU="$2"

    {
        echo
        echo "============================================================"
        echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "CPU: ${CPU}%"
        echo "============================================================"

        echo
        echo "----- UPTIME -----"
        uptime

        echo
        echo "----- MEMORY -----"
        free -m

        echo
        echo "----- VMSTAT -----"
        vmstat 1 2

        echo
        echo "----- TOP CPU PROCESSES -----"
        ps -eo pid,ppid,user,%cpu,%mem,etime,stat,cmd \
            --sort=-%cpu | head -40

        echo
        echo "----- TOP MEMORY PROCESSES -----"
        ps -eo pid,ppid,user,%cpu,%mem,etime,stat,cmd \
            --sort=-%mem | head -20

        echo
        echo "----- PHP -----"
        pgrep -af 'php|php-fpm' || true

        echo
        echo "----- MYSQL / MARIADB -----"
        ps -eo pid,ppid,user,%cpu,%mem,etime,stat,cmd |
            grep '[m]aria\|[m]ysql' || true

        echo
        echo "----- DISK -----"
        df -h

        echo
        echo "----- NETWORK CONNECTION SUMMARY -----"
        ss -s 2>/dev/null || true

    } >> "$FILE"
}

COUNT=0
INCIDENT=0
LOGFILE=""

while true
do
    CPU=$(get_cpu_usage)

    if [ "$CPU" -ge "$THRESHOLD" ]; then
        COUNT=$((COUNT + 1))
    else
        COUNT=0

        if [ "$INCIDENT" -eq 1 ]; then
            {
                echo
                echo "============================================================"
                echo "INCIDENT ENDED: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "CPU returned to ${CPU}%"
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
                echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Threshold: ${THRESHOLD}%"
                echo "CPU cores: $CPUS"
            } > "$LOGFILE"
        fi

        capture "$LOGFILE" "$CPU"

        sleep "$CAPTURE_INTERVAL"
    fi
done
