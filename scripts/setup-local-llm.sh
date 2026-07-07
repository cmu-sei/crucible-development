#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

ENV_FILE=".devcontainer/local-llm.env"

# Skip if already configured (but ensure it's sourced)
if [ -f "$ENV_FILE" ] && [ -s "$ENV_FILE" ]; then
  echo "Local LLM provider already configured ($ENV_FILE exists)."

  # Ensure it's sourced in .zshrc and current shell
  if ! grep -q "source.*local-llm.env" ~/.zshrc 2>/dev/null; then
    echo "source /workspaces/crucible-development/$ENV_FILE" >> ~/.zshrc
  fi
  source "$ENV_FILE"

  echo "To reconfigure, delete the file and run this script again:"
  echo "  rm $ENV_FILE && scripts/setup-local-llm.sh"
  exit 0
fi

echo ""
echo "=== Local LLM Provider Setup ==="
echo ""
echo "The dev container supports OpenAI-compatible LLM endpoints for"
echo "opencode and openclaude (in addition to Claude Code on AWS Bedrock)."
echo ""
read -p "Do you have a local/on-premises LLM provider? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  touch "$ENV_FILE"
  echo "Skipped. You can configure later by running:"
  echo "  scripts/setup-local-llm.sh"
  exit 0
fi

echo ""
read -p "API base URL (e.g., https://your-llm-endpoint.example.com/api): " BASE_URL
printf "API key: "
API_KEY=""
while IFS= read -r -s -n 1 char; do
  if [[ -z "$char" ]]; then
    break
  elif [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
    if [[ -n "$API_KEY" ]]; then
      API_KEY="${API_KEY%?}"
      printf '\b \b'
    fi
  else
    API_KEY+="$char"
    printf '*'
  fi
done
echo ""
read -p "Default model ID (e.g., Qwen/Qwen3-Coder-Next-FP8): " MODEL_ID

cat > "$ENV_FILE" <<EOF
LOCAL_LLM_BASE_URL=$BASE_URL
LOCAL_LLM_API_KEY=$API_KEY
LOCAL_LLM_MODEL=$MODEL_ID
EOF

echo ""
echo "Saved to $ENV_FILE"

# Source into current shell and add to .zshrc for future shells
if ! grep -q "source.*local-llm.env" ~/.zshrc 2>/dev/null; then
  echo "source /workspaces/crucible-development/$ENV_FILE" >> ~/.zshrc
fi
source "$ENV_FILE"

echo "Environment variables loaded. opencode and openclaude are ready to use."
echo "To reconfigure, run: rm $ENV_FILE && scripts/setup-local-llm.sh"
