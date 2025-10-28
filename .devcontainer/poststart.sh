#!/bin/bash

minikube start --mount-string="/mnt/data/terraform/root:/terraform/root" --embed-certs
