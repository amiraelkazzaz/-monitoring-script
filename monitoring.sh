#!/bin/bash

# Default settings
THRESHOLD=10          # Default disk usage warning threshold (in %)
LOG_FILE="system_monitor.log"
EMAIL="your_email@example.com"  # Replace with your email address

# Parse optional arguments
while getopts ":t:f:" opt; do
  case ${opt} in
    t )
      THRESHOLD=$OPTARG
      ;;
    f )
      LOG_FILE=$OPTARG
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Function to log messages with timestamp
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send email alerts
send_email() {
  local subject="$1"
  local body="$2"
  echo -e "$body" | mail -s "$subject" "$EMAIL"
}

# Check Disk Usage
log_message "Disk Usage:"
df -h | awk '{print $1, $2, $3, $4, $5, $6}' | tee -a "$LOG_FILE"
DISK_WARNING=""
while IFS=' ' read -ra LINE; do
  if [[ "${LINE[4]}" =~ ([0-9]+)% && "${BASH_REMATCH[1]}" -ge "$THRESHOLD" ]]; then
    DISK_WARNING+="Warning: ${LINE[0]} is above $THRESHOLD% usage!\n"
  fi
done < <(df -h | awk 'NR>1 {print $1, $2, $3, $4, $5, $6}')
if [[ -n "$DISK_WARNING" ]]; then
  log_message "$DISK_WARNING"
fi

# Check CPU Usage
log_message "CPU Usage:"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
log_message "Current CPU Usage: $CPU_USAGE"

# Check Memory Usage
log_message "Memory Usage:"
MEMORY_INFO=$(free -h | awk '/Mem:/ {printf "Total Memory: %s\nUsed Memory: %s\nFree Memory: %s\n", $2, $3, $4}')
log_message "$MEMORY_INFO"

# Check Top 5 Memory-Consuming Processes
log_message "Top 5 Memory-Consuming Processes:"
TOP_PROCESSES=$(ps aux --sort=-%mem | head -n 6 | awk '{print $2, $1, $4, $11}')
log_message "$TOP_PROCESSES"

# Generate Report
REPORT=$(cat <<EOF
System Monitoring Report - $(date '+%Y-%m-%d %H:%M:%S')
======================================
Disk Usage:
$(df -h | awk '{print $1, $2, $3, $4, $5, $6}')
$DISK_WARNING
CPU Usage:
Current CPU Usage: $CPU_USAGE
Memory Usage:
$MEMORY_INFO
Top 5 Memory-Consuming Processes:
PID USER %MEM COMMAND
$TOP_PROCESSES
EOF
)

# Send Email Alert if Disk Usage Exceeds Threshold
if [[ -n "$DISK_WARNING" ]]; then
  ALERT_SUBJECT="System Monitoring Alert - $(date '+%Y-%m-%d %H:%M:%S')"
  ALERT_BODY="$REPORT"
  send_email "$ALERT_SUBJECT" "$ALERT_BODY"
fi

# Save Report to Log File
echo "$REPORT" >> "$LOG_FILE"
