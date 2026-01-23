#!/usr/bin/env zsh

# Block execution; allow sourcing
if [[ $ZSH_EVAL_CONTEXT != *:file ]]; then
  echo "This script must be sourced, not executed."
  echo "Run: source proxy_envs.sh"
  return 1 2>/dev/null || exit 1
fi

# Only enable these when you are connected over ethernet to the SEI network (i.e., wired in at the office)
HOST_TO_CHECK="aslan-core.sei.cmu.edu"
TARGET_IP="10.64.6.16"

# Use ping to resolve the host (1 packet, quiet output)
RESOLVED_IP=$(ping -c1 "$HOST_TO_CHECK" 2>/dev/null | sed -n 's/^PING [^(]*(\([0-9.]*\)).*/\1/p')
if [[ -z "$RESOLVED_IP" ]]; then
  echo "Could not resolve $HOST_TO_CHECK"
  return 1
fi

if [[ "$RESOLVED_IP" == "$TARGET_IP" ]]; then
  export http_proxy="http://cloudproxy.sei.cmu.edu:80"
  export https_proxy="http://cloudproxy.sei.cmu.edu:80"
  export ftp_proxy="http://cloudproxy.sei.cmu.edu:80"

  export HTTP_PROXY="http://cloudproxy.sei.cmu.edu:80"
  export HTTPS_PROXY="http://cloudproxy.sei.cmu.edu:80"
  export FTP_PROXY="http://cloudproxy.sei.cmu.edu:80"

  export all_proxy="http://cloudproxy.sei.cmu.edu:80"
  export ALL_PROXY="http://cloudproxy.sei.cmu.edu:80"

  export no_proxy="127.0.0.1,10.0.0.0/8,localhost,.sei.cmu.edu,.cert.org,.zscalergov.net,.zpagov.net,.duosecurity.com"
  export NO_PROXY="127.0.0.1,10.0.0.0/8,localhost,.sei.cmu.edu,.cert.org,.zscalergov.net,.zpagov.net,.duosecurity.com"
  echo "Matched $TARGET_IP — environment variables set"
else
  echo "Resolved to $RESOLVED_IP — no match"
fi
