#!/bin/bash
### BEGIN INIT INFO
# Provides:          google
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Execute virtual machine startup script
# Description:       This script executes the virtual machine startup script
#                    downloaded from the metadata server or provided url.
### END INIT INFO

#
# Author: Google Inc.
#

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
declare -r DESC="Google Virtual Machine Startup Script"
NAME=google
declare -r SCRIPTNAME=/etc/init.d/${NAME}
declare -r LOCKFILE=/var/run/google.lock
declare -r STARTUP_SCRIPT_FILE=/var/run/google.startup.script
declare -r LOGFILE=/var/log/google.log
declare -r STARTUP_SCRIPT_KEY=startup-script
declare -r STARTUP_SCRIPT_URL_KEY=startup-script-url
declare -r TMP_TEMPLATE=/tmp/google.startup_script.XXXXXXXX
declare -r BOTO_SETUP_SCRIPT=/usr/share/boto_compute_adapter/boot_setup.py
declare -r WGET_MAX_RETRIES=10
declare -r WGET_TIMEOUT=10

# Base Metadata HTTP Server URI for this VM.
declare -r MDS=http://metadata.google.internal/0.1/meta-data

# Read configuration variable file if it is present
[ -r /etc/default/${NAME} ] && . /etc/default/${NAME}

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions

function wait_for_networking() {
  local instanceid
  while [[ 1 ]]; do
    instanceid=$(wget -a ${LOGFILE} -O - ${MDS}/instance-id)
    if [[ $? == 0 ]]; then
      break;  ## Success.  Networking has come up.
    fi
    sleep 0.2
  done
}

function download_url() {
  local url filename
  url=$1
  filename=$2
  echo Downloading url from ${url} to ${filename} >> ${LOGFILE}
  wget -T ${WGET_TIMEOUT} -t ${WGET_MAX_RETRIES} -a ${LOGFILE} -O ${filename} - ${url}
  return $?
}

function get_metadata_value() {
  local varname
  varname=$1
  wget -T ${WGET_TIMEOUT} -t ${WGET_MAX_RETRIES} -a ${LOGFILE} -O - \
    ${MDS}/attributes/${varname}
  return $?
}

#
# Function that starts the daemon/service
#

function run_startup_script()
{
  local filepath
  filepath=$1
  echo Running startup script ${filepath} >> ${LOGFILE}
  [ -e ${filepath} ] || return 0
  chmod 700 ${filepath}
  # filepath contains absolute path
  ${filepath} &>> ${LOGFILE}
}

function run_command_with_retry() {
  local SLEEP=1
  local readonly NUM_RETRY=$1
  shift
  for i in $(seq 1 ${NUM_RETRY}); do
    $* && return || echo "retrying after ${SLEEP} sec..."
    sleep ${SLEEP}
    SLEEP=$((${SLEEP} * 2))
  done
  echo failed to execute $*
  exit 1
}

function update_apt() {
  local readonly APT_COMMAND="
     /usr/bin/apt-get -q -y --force-yes -o DPkg::Options::=--force-confold"
  run_command_with_retry 5 ${APT_COMMAND} update --fix-missing
  run_command_with_retry 5 ${APT_COMMAND} upgrade
  # Make sure ssh is still running.
  service ssh restart
}

function do_start()
{
  echo Starting >> ${LOGFILE}
  # Return
  #   0 if daemon has been started
  #   1 if daemon was already running
  #   2 if daemon could not be started
  [ -e ${LOCKFILE} ] && return 1

  # Prevent future executions.  Note that this is in /var/run by
  # default and that is a tmpfs filesystem.  As such this will get
  # forgotten on reboot.
  touch ${LOCKFILE}

  # Make sure that networking is up.
  wait_for_networking

  # If it exists, run the boto bootstrap script.  This will set things
  # up so that gsutil will just work with any provisioned service
  # account.
  if [ -e ${BOTO_SETUP_SCRIPT} ]; then
    echo Running Boto setup script at ${BOTO_SETUP_SCRIPT} >> $LOGFILE
    ${BOTO_SETUP_SCRIPT} &>> $LOGFILE
  fi

  # Try to use the startup-script-url, then the startup-script metadata.
  # Check the startup script url first.
  URL=$(get_metadata_value ${STARTUP_SCRIPT_URL_KEY})
  if [[ $? == 0 ]]; then
    # TODO: When gsutil supports robot auth, use that instead.
    case ${URL} in
      gs://*)
        /usr/bin/google_storage_download \
          ${URL} ${STARTUP_SCRIPT_FILE} 2>> ${LOGFILE};;
      *) download_url ${URL} ${STARTUP_SCRIPT_FILE};;
    esac
    if [[ $? != 0 ]]; then
      echo Could not download startup script ${URL} >> ${LOGFILE}
    fi
  else
    get_metadata_value ${STARTUP_SCRIPT_KEY} > ${STARTUP_SCRIPT_FILE}
    if [[ $? != 0 ]]; then
      echo No startup script specified. >> ${LOGFILE}
    fi
  fi

  if [[ -f ${STARTUP_SCRIPT_FILE} ]]; then
    run_startup_script ${STARTUP_SCRIPT_FILE}
  fi

  return 0
}

#
# Function that stops the daemon/service
#
function do_stop()
{
  echo Stopping >> ${LOGFILE}

  # Return
  #   0 if daemon has been stopped
  #   1 if daemon was already stopped
  #   2 if daemon could not be stopped
  #   other if a failure occurred
  if [[ -e ${LOCKFILE} ]] ; then
    rm ${LOCKFILE}
    return 0
  else
    echo "Lock file doesn't exist on stop" >> ${LOGFILE}
    return 1
  fi
}

echo $(date) "${DESC}" > ${LOGFILE}

case "$1" in
  start)
    [ "${VERBOSE}" != no ] && log_daemon_msg "Starting ${DESC}" "${NAME}"
    do_start
    case "$?" in
      0|1) [ "${VERBOSE}" != no ] && log_end_msg 0 ;;
        2) [ "${VERBOSE}" != no ] && log_end_msg 1 ;;
    esac
    ;;
  stop)
    [ "${VERBOSE}" != no ] && log_daemon_msg "Stopping ${DESC}" "${NAME}"
    do_stop
    case "$?" in
      0|1) [ "${VERBOSE}" != no ] && log_end_msg 0 ;;
        2) [ "${VERBOSE}" != no ] && log_end_msg 1 ;;
    esac
    ;;
  status)
    exit 0
    ;;
  restart|force-reload)
    log_daemon_msg "Restarting ${DESC}" "${NAME}"
    do_stop
    case "$?" in
      0|1)
        do_start
        case "$?" in
          0) log_end_msg 0 ;;
          1) log_end_msg 1 ;; # Old process is still running
          *) log_end_msg 1 ;; # Failed to start
        esac
        ;;
      *)
        # Failed to stop
        log_end_msg 1
        ;;
    esac
    ;;
  *)
    echo "Usage: ${SCRIPTNAME} {start|stop|status|restart|force-reload}"
    exit 3
    ;;
esac

:
