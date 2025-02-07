#!/bin/bash

# Default values
THRESHOLD=7
OUTPUT_FILE="system_monitor.log"

# Parse optional arguments
while getopts ":t:f:" opt; do
  case $opt in
    t) THRESHOLD="$OPTARG" ;;
    f) OUTPUT_FILE="$OPTARG" ;;
    *) echo "Usage: $0 [-t threshold] [-f output_file]" >&2
       exit 1
       ;;
  esac
done

# Function to send email alerts using msmtp
send_email() {
    local subject="$1"
    local body="$2"
    (
        echo "To: mirahatem29@gmail.com"
        echo "From: mirahatem29@gmail.com"
        echo "Subject: $subject"
        echo ""
        echo "$body"
    ) | msmtp --read-recipients
}

# Function to add color to warnings
color_warning() {
    echo -e "\033[1;31m$1\033[0m" # Red color for warnings
}

# Get current timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Initialize report
REPORT="System Monitoring Report - $TIMESTAMP\n"
REPORT+="======================================\n"

# 1. Check Disk Usage
REPORT+="\nDisk Usage:\n"
DISK_USAGE=$(df -h | grep -vE '^Filesystem|tmpfs|cdrom')
REPORT+="$DISK_USAGE\n"

# Check for disk usage exceeding the threshold
echo "$DISK_USAGE" | while read -r line; do
    USAGE_PERCENT=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    MOUNT_POINT=$(echo "$line" | awk '{print $6}')
    if [ "$USAGE_PERCENT" -gt "$THRESHOLD" ]; then
        WARNING="Warning: $MOUNT_POINT is above $THRESHOLD% usage!"
        REPORT+="$(color_warning "$WARNING")\n"
        # Send email alert
        send_email "Disk Usage Alert - $TIMESTAMP" "$WARNING"
    fi
done

# 2. Check CPU Usage
REPORT+="\nCPU Usage:\n"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
REPORT+="Current CPU Usage: $CPU_USAGE%\n"

# 3. Check Memory Usage
REPORT+="\nMemory Usage:\n"
MEMORY_USAGE=$(free -h | grep Mem)
TOTAL_MEM=$(echo "$MEMORY_USAGE" | awk '{print $2}')
USED_MEM=$(echo "$MEMORY_USAGE" | awk '{print $3}')
FREE_MEM=$(echo "$MEMORY_USAGE" | awk '{print $4}')
REPORT+="Total Memory: $TOTAL_MEM\n"
REPORT+="Used Memory: $USED_MEM\n"
REPORT+="Free Memory: $FREE_MEM\n"

# 4. Check Running Processes
REPORT+="\nTop 5 Memory-Consuming Processes:\n"
TOP_PROCESSES=$(ps aux --sort=-%mem | head -n 6)
REPORT+="$TOP_PROCESSES\n"

# 5. Save the report to the output file
echo -e "$REPORT" >> "$OUTPUT_FILE"

# Print the report to the console
echo -e "$REPORT"
