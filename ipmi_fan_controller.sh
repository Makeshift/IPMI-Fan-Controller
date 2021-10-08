#!/bin/bash
# Target temperature - We will try to keep the temperature at this level
TARGET_TEMP=${TARGET_TEMP:-80}
# At this temperature, we set the fan speed to $CRIT_SPEED_PERCENT
CRIT_TEMP=${CRIT_TEMP:-99}
CRIT_SPEED_PERCENT=${CRIT_SPEED_PERCENT:-100}
# This is the usual min/max fan speed, assuming temp isn't over critical
MAX_SPEED_PERCENT=${MAX_SPEED_PERCENT:-70}
MIN_SPEED_PERCENT=${MIN_SPEED_PERCENT:-0}
# IPMI credentials
IDRAC_IP=${IDRAC_IP:-"idrac"}
IDRAC_USER=${IDRAC_USER:-"fans"}
IDRAC_PASS=${IDRAC_PASS:-"fans"}
# The fan speed we set to on startup
START_FAN_SPEED=${START_FAN_SPEED:-50}
# How much to increase the fan speed by when we're below/over the target temp
FAN_STEP_PERCENT=${FAN_STEP_PERCENT:-5}
# If the temperature difference is less than TEMP_DIFFERENCE_SMALLER_STEP, we change
#  the fan speed less quickly
TEMP_DIFFERENCE_SMALLER_STEP=${TEMP_DIFFERENCE_SMALLER_STEP:-10}
FAN_STEP_SMALLER_PERCENT=${FAN_STEP_SMALLER_PERCENT:-1}
# Extra log spam
DEBUG=${DEBUG:-false}
# The prefix for the raw command to send via IPMI to control fan speed. $prefix $speed_in_hex
FAN_CONTROL_COMMAND_PREFIX=${FAN_CONTROL_COMMAND_PREFIX:-"raw 0x30 0x30 0x02 0xff"}
# The raw command to send via IPMI to control whether or not the fans are manually or automatically controlled. $prefix 0x00 for manual, or $prefix 0x01 for auto
IPMI_MANUAL_CONTROL_PREFIX=${IPMI_MANUAL_CONTROL_PREFIX:-"raw 0x30 0x30 0x01"}
IPMI_ENABLE_MANUAL_CONTROL=${IPMI_ENABLE_MANUAL_CONTROL:-"$IPMI_MANUAL_CONTROL_PREFIX 0x00"}
IPMI_DISABLE_MANUAL_CONTROL=${IPMI_DISABLE_MANUAL_CONTROL:-"$IPMI_MANUAL_CONTROL_PREFIX 0x01"}

tohex() {
    printf '0x%02x' "$1"
}

info() {
  echo "Temp: ${TEMP}c | Target: ${TARGET_TEMP}c | Diff: ${TEMP_DIFF}c | Current: ${CURRENT_FAN_SPEED}% | Step: ${FAN_STEP}%"
}

send_command() {
  local command=$1
  ipmitool -I lanplus -H $IDRAC_IP -U $IDRAC_USER -P $IDRAC_PASS $command
}

set_fan_speed() {
  local fan_speed_dec=$1
  local fan_speed_hex=$(tohex "$fan_speed_dec")
  CURRENT_FAN_SPEED=$fan_speed_dec
  echo "$(info) | Setting fan speed to $fan_speed_dec"
  send_command "$FAN_CONTROL_COMMAND_PREFIX $fan_speed_hex"
}

debug() {
  if [ "$DEBUG" == "true" ]; then
    echo $1
  fi
}

# If this script exits for any reason (eg. crash, shutdown, whatever), we should try to turn automatic fan control back on
on_exit() {
  echo "Exit caught, setting fans back to automatic control"
  send_command "$IPMI_DISABLE_MANUAL_CONTROL"
}
trap on_exit EXIT

set -e

# Enable manual control
echo "Setting fan to manual control"
send_command "$IPMI_ENABLE_MANUAL_CONTROL"
# To set to automatic:
# send_command "raw 0x30 0x30 0x01 0x01"

echo "Setting fan speed to $START_FAN_SPEED to start"
set_fan_speed $START_FAN_SPEED
CURRENT_FAN_SPEED=$START_FAN_SPEED

while true; do
    TEMP=$(sensors -u | grep "input" | awk '{print $2}' | cut -d '.' -f1 | sort -nr | head -1)
    FAN_STEP=$FAN_STEP_PERCENT
    if (( TEMP > TARGET_TEMP )); then
        TEMP_DIFF=$(( TEMP - TARGET_TEMP ))
    else
        TEMP_DIFF=$(( TARGET_TEMP - TEMP ))
    fi
    if (( TEMP_DIFF < TEMP_DIFFERENCE_SMALLER_STEP )); then
        FAN_STEP=$FAN_STEP_SMALLER_PERCENT
    fi
    debug "$(info)"
    if (( TEMP > CRIT_TEMP )); then
        echo "Critical temperature reached, maxing fans!"
        set_fan_speed "$CRIT_SPEED_PERCENT"
    elif (( TEMP > TARGET_TEMP )) && (( CURRENT_FAN_SPEED < MAX_SPEED_PERCENT )); then
        TARGET_SPEED=$((CURRENT_FAN_SPEED + FAN_STEP))
        set_fan_speed $((TARGET_SPEED > MAX_SPEED_PERCENT ? MAX_SPEED_PERCENT : TARGET_SPEED))
    elif (( TEMP < TARGET_TEMP )) && (( CURRENT_FAN_SPEED > MIN_SPEED_PERCENT )); then
        TARGET_SPEED=$((CURRENT_FAN_SPEED - FAN_STEP))
        set_fan_speed $((TARGET_SPEED < MIN_SPEED_PERCENT ? MIN_SPEED_PERCENT : TARGET_SPEED))
    fi
    sleep 1
done
