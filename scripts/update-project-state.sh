#!/bin/bash
# Auto-update PROJECT_STATE.md with current status

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$PROJECT_ROOT/PROJECT_STATE.md"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

echo "Updating PROJECT_STATE.md..."

# Update timestamp
sed -i.bak "s/\*\*Last Updated\*\*:.*/\*\*Last Updated\*\*: $TIMESTAMP (Auto-updated)/" "$STATE_FILE"

echo "✓ Updated timestamp to $TIMESTAMP"

# Optional: Capture to Noel
read -p "Capture update to Noel? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Describe what changed: " CHANGE_DESC

    curl -s https://18f625ebc1f0.ngrok-free.app/webhook/noel \
      -H 'Content-Type: application/json' \
      -H 'Authorization: 1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6' \
      -d "{
        \"endpoint\": \"capture_learning\",
        \"project\": \"Noel\",
        \"title\": \"PROJECT_STATE Updated: $CHANGE_DESC\",
        \"content\": \"Updated PROJECT_STATE.md on $TIMESTAMP\\n\\nChanges: $CHANGE_DESC\\n\\nView: $STATE_FILE\",
        \"type\": \"Pattern\",
        \"tags\": [\"project-state\", \"progress-update\"]
      }" | jq -r '.[] | "✓ Captured: \(.title)"'
fi

echo "✓ Done"
