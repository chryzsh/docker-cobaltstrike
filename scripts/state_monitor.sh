#!/bin/bash

# Read STDIN in a loop for supervisor events
while read line; do
    # Write event to state log
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $line" >>/var/log/supervisor/state.log

    # Parse the event
    if echo "$line" | grep -q "PROCESS_STATE_EXITED"; then
        process_name=$(echo "$line" | awk '{print $3}')
        exit_code=$(echo "$line" | awk '{print $5}')

        # Log process exit
        echo "Process $process_name exited with code $exit_code" >>/var/log/supervisor/state.log

        # Handle specific process failures
        case "$process_name" in
        cs_installer)
            if [ "$exit_code" != "0" ]; then
                echo "FATAL: Installer failed with code $exit_code" >>/var/log/supervisor/state.log
                kill -15 $(cat /var/run/supervisord.pid)
            fi
            ;;
        teamserver)
            if [ "$exit_code" != "0" ]; then
                echo "ERROR: Teamserver failed with code $exit_code" >>/var/log/supervisor/state.log
            fi
            ;;
        listener)
            if [ "$exit_code" != "0" ]; then
                echo "ERROR: Listener failed with code $exit_code" >>/var/log/supervisor/state.log
            fi
            ;;
        esac
    fi

    # Echo back OK to supervisor
    echo "READY"
done
