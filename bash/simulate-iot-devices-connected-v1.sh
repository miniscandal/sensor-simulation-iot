#!/bin/bash

# ─────────────────────────────────────────────────────────────
# MQTT Device Simulation Script
# Simulates multiple devices sending MQTT messages with configurable delay.
# ─────────────────────────────────────────────────────────────

# ───────────── MQTT broker configuration ─────────────
readonly HOST="10.84.51.163"
readonly PORT=1883
readonly TOPIC="web-iot-control-panel"

# ───────────── Logging configuration ─────────────
readonly LOG_DIR="logs"
readonly LOG_FILE="$LOG_DIR/mqtt_simulation.log"

# ───────────── Default parameters ─────────────
DEVICE_COUNT=10
PAUSE_SECONDS=1
STATUS_CODE=205
ENABLE_LOG=""

# ───────────── Function: show_usage ─────────────
show_usage() {
  echo "Usage: $0 [-d device_count] [-p pause_seconds] [-s status_code] [-l]"
  echo "  -d    Number of devices to simulate (default: 10)"
  echo "  -p    Pause between messages in seconds (default: 1)"
  echo "  -s    Status code to send in payload (default: 101)"
  echo "  -l    Enable logging to file"
  exit 1
}

# ───────────── Function: log ─────────────
log() {
  local message="$1"
  local timestamp="[$(date +%Y-%m-%dT%H:%M:%S)]"
  echo "$timestamp $message"
  [[ "$ENABLE_LOG" == "log" ]] && echo "$timestamp $message" >> "$LOG_FILE"
}

# ───────────── Function: validate_integer ─────────────
validate_integer() {
  local value="$1"
  local name="$2"
  local allow_zero="$3"

  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    log "(×_×) Error: $name must be an integer."
    exit 1
  fi

  if [[ "$allow_zero" == "false" && "$value" -le 0 ]]; then
    log "(×_×) Error: $name must be greater than zero."
    exit 1
  fi
}

# ───────────── Function: check_broker_connection ─────────────
check_broker_connection() {
  log "(O_O) Verifying TCP connection to Broker: $HOST:$PORT..."
  
  if command -v nc &> /dev/null; then
    nc -z -w 5 "$HOST" "$PORT"
    local status=$?
  else
    timeout 5 mosquitto_pub -h "$HOST" -p "$PORT" -t "health/check" -m "" -q 0
    local status=$?
  fi

  if [[ $status -eq 0 ]]; then
    log "(^_^)/ Connection successful. Broker is reachable."
  else
    log "(×_×) Error: Failed to connect to Broker $HOST:$PORT. Check broker status or network settings."
    exit 1
  fi
}
# ─────────────────────────────────────────────────────────────

# ───────────── Function: send_payload ─────────────
send_payload() {
  local device_id="$1"
  local payload="{\"deviceId\": \"$device_id\", \"statusCode\": $STATUS_CODE}"
  log "(・_・) Sending to device $device_id: $payload"
  mosquitto_pub -h "$HOST" -p "$PORT" -t "$TOPIC" -m "$payload"
}

# ───────────── Parse arguments ─────────────
while getopts "d:p:s:l" opt; do
  case $opt in
    d) DEVICE_COUNT="$OPTARG" ;;
    p) PAUSE_SECONDS="$OPTARG" ;;
    s) STATUS_CODE="$OPTARG" ;;
    l) ENABLE_LOG="log" ;;
    *) show_usage ;;
  esac
done

# ───────────── Main Execution ─────────────
[[ "$ENABLE_LOG" == "log" ]] && mkdir -p "$LOG_DIR" && > "$LOG_FILE"

check_broker_connection

log "Starting MQTT simulation with $DEVICE_COUNT devices. Pause: $PAUSE_SECONDS seconds. StatusCode: $STATUS_CODE"

validate_integer "$DEVICE_COUNT" "DEVICE_COUNT" "false"
validate_integer "$PAUSE_SECONDS" "PAUSE_SECONDS" "true"
validate_integer "$STATUS_CODE" "STATUS_CODE" "true"

for ((i = 1; i <= DEVICE_COUNT; i++)); do
  device_id=$(printf "%02d" "$i")
  send_payload "$device_id"
  sleep "$PAUSE_SECONDS"
done

log "Simulation completed successfully."
