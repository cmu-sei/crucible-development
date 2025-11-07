#!/bin/bash

start_minikube() {
    local output_file=$1
    local cmd="minikube start --mount-string=\"/mnt/data/terraform:/mnt/data/terraform\" --embed-certs"

    if [ -n "$output_file" ]; then
        # use script to preserve colorized terminal output while capturing to a file
        script -q -e -c "$cmd" "$output_file"
    else
        eval "$cmd"
    fi
}

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

if ! start_minikube "$TMPFILE"; then
    if grep -q "GUEST_MOUNT_CONFLICT" "$TMPFILE"; then
        echo "⚠️   Detected mount conflict — recreating minikube cluster ..."
        minikube delete
        start_minikube
    fi
fi
