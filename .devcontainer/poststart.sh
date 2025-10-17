#!/bin/bash

npm install -g @angular/cli@latest
minikube start --mount-string="/mnt/data/terraform/root:/terraform/root" --embed-certs
