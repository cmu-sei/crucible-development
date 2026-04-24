#!/bin/bash
# Copyright 2025 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

ENV_FILE=".devcontainer/local-llm.env"

# Skip if already configured
if [ -f "$ENV_FILE" ] && [ -s "$ENV_FILE" ]; then
  echo "Local LLM provider already configured ($ENV_FILE exists)."
  echo "Delete it and rebuild to reconfigure."
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
  echo "  .devcontainer/setup-local-llm.sh"
  exit 0
fi

echo ""
read -p "API base URL (e.g., https://your-llm-endpoint.example.com/api): " BASE_URL
read -p "API key: " -s API_KEY
echo ""
read -p "Default model ID (e.g., Qwen/Qwen3-Coder-Next-FP8): " MODEL_ID

cat > "$ENV_FILE" <<EOF
LOCAL_LLM_BASE_URL=$BASE_URL
LOCAL_LLM_API_KEY=$API_KEY
LOCAL_LLM_MODEL=$MODEL_ID
EOF

echo ""
echo "Saved to $ENV_FILE"
echo "opencode and openclaude will be configured when the container starts."
