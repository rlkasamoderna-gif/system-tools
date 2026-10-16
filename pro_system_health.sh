#!/bin/bash

# ===========================
# CONFIGURATION
# ===========================
LOGFILE="/var/log/pro_system_health.log"
USE_LOG=false
USE_COLOR=true
VERBOSE=false

# ===========================
# COLORS (auto-disable)
# ===========================
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

if [[ ! -t 1 ]]; then
    USE_COLOR=false
fi

color() {
    if $USE_COLOR; then
        echo -e "$1"
    else
        echo "$2"
    fi
}

log() {
    if $USE_LOG; then
        echo "$1" >> "$LOGFILE"
    fi
}

out() {
    color "$1" "$2"
    log "$2"
}

# ===========================
# ARGUMENT PARSER
# ===========================
for arg in "$@"; do
    case $arg in
        --log)
            USE_LOG=true
            ;;
        --no-color)
            USE_COLOR=false
            ;;
        --verbose)
            VERBOSE=true
            ;;
    esac
done

# ===========================
# HEADER
# ===========================
header() {
    out "${BLUE}===============================" "==============================="
    out "${BLUE}  $1" "$1"
    out "${BLUE}===============================${RESET}" "==============================="
}

# ===========================
# CPU CHECK
# ===========================
check_cpu() {
    header "CPU Usage"
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    out "CPU Load: ${CPU}%" "CPU Load: ${CPU}%"

    if (( $(echo "$CPU > 80" | bc -l) )); then
        out "${RED}Warning: High CPU usage!${RESET}" "Warning: High CPU usage!"
    else
        out "${GREEN}CPU usage normal.${RESET}" "CPU usage normal."
    fi
}

# ===========================
# MEMORY CHECK
# ===========================
check_memory() {
    header "Memory Usage"
    free -h | tee >(log)

    MEM_USED=$(free | awk '/Mem:/ {print $3/$2 * 100.0}')

    if (( $(echo "$MEM_USED > 80" | bc -l) )); then
        out "${RED}Warning: High memory usage!${RESET}" "Warning: High memory usage!"
    else
        out "${GREEN}Memory usage normal.${RESET}" "Memory usage normal."
    fi
}

# ===========================
# DISK CHECK
# ===========================
check_disk() {
    header "Disk Usage"
    df -h / | tee >(log)
    DISK_USED=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

    if (( DISK_USED > 80 )); then
        out "${RED}Warning: Disk almost full!${RESET}" "Warning: Disk almost full!"
    else
        out "${GREEN}Disk usage normal.${RESET}" "Disk usage normal."
    fi
}

# ===========================
# NETWORK CHECK
# ===========================
check_network() {
    header "Network Status"
    IP=$(hostname -I | awk '{print $1}')
    out "IP Address: $IP" "IP Address: $IP"

    ping -c 2 google.com &> /dev/null
    if [[ $? -eq 0 ]]; then
        out "${GREEN}Internet reachable.${RESET}" "Internet reachable."
    else
        out "${RED}Internet unreachable!${RESET}" "Internet unreachable!"
    fi
}

# ===========================
# TEMPERATURE CHECK
# ===========================
check_temp() {
    header "Temperature"
    if command -v sensors &> /dev/null; then
        sensors | tee >(log)
    else
        out "${YELLOW}lm-sensors not installed.${RESET}" "lm-sensors not installed."
        out "Install with: sudo apt install lm-sensors" "Install with: sudo apt install lm-sensors"
    fi
}

# ===========================
# BATTERY CHECK (Surface Book)
# ===========================
check_battery() {
    header "Battery Status"
    if [[ -d /sys/class/power_supply/BAT0 ]]; then
        CAP=$(cat /sys/class/power_supply/BAT0/capacity)
        STATUS=$(cat /sys/class/power_supply/BAT0/status)
        out "Battery: $CAP%" "Battery: $CAP%"
        out "Status: $STATUS" "Status: $STATUS"
    else
        out "${YELLOW}No battery detected.${RESET}" "No battery detected."
    fi
}

# ===========================
# TOP PROCESSES
# ===========================
check_processes() {
    header "Top Processes"
    ps aux --sort=-%cpu | head -5 | tee >(log)
}

# ===========================
# JSON OUTPUT
# ===========================
json_output() {
    header "JSON Summary"
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    MEM_USED=$(free | awk '/Mem:/ {print $3/$2 * 100.0}')
    DISK_USED=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    IP=$(hostname -I | awk '{print $1}')

    JSON=$(cat <<EOF
{
  "cpu": "$CPU",
  "memory": "$MEM_USED",
  "disk": "$DISK_USED",
  "ip": "$IP"
}
EOF
)
    out "$JSON" "$JSON"
}

# ===========================
# RUN ALL CHECKS
# ===========================
header "Pro System Health Report"
check_cpu
check_memory
check_disk
check_network
check_temp
check_battery
check_processes
json_output

out "${BLUE}Report complete.${RESET}" "Report complete."
if $USE_LOG; then
    out "${BLUE}Log saved to $LOGFILE${RESET}" "Log saved to $LOGFILE"
fi
