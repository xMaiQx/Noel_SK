#!/usr/bin/env python3
"""
Capture the GitHub email privacy learning
"""
import requests
import json

WEBHOOK_URL = "https://272485010cfe.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

headers = {
    "Content-Type": "application/json",
    "Authorization": AUTH_TOKEN
}

learning = {
    "endpoint": "capture_learning",
    "project": "Noel_SK",
    "title": "GitHub Email Privacy Protection Blocks Pushes",
    "content": """GitHub's email privacy protection blocks git pushes when using a private email in commits.

**The Problem:**
```
remote: error: GH007: Your push would publish a private email address.
remote: You can make your email public or disable this protection by visiting:
remote: https://github.com/settings/emails
```

**Root Cause:**
When git user.email is set to a private email (e.g., miguel@madpanda.mx) and GitHub has "Keep my email addresses private" enabled, pushes are rejected.

**The Fix (Temporary Workaround):**
```bash
# Set to GitHub noreply email
git config user.email "USERNAME@users.noreply.github.com"

# Amend the commit with new author
git commit --amend --reset-author --no-edit

# Push successfully
git push origin branch-name

# Restore original email
git config user.email "original@email.com"
```

**Permanent Solutions:**
1. **Use GitHub noreply email globally:**
   ```bash
   git config --global user.email "USERNAME@users.noreply.github.com"
   ```

2. **Disable email privacy protection:**
   - Visit https://github.com/settings/emails
   - Uncheck "Keep my email addresses private"
   - Make your email public (not recommended)

3. **Set per-repository:**
   ```bash
   cd /path/to/repo
   git config user.email "USERNAME@users.noreply.github.com"
   ```

**Best Practice:**
Use GitHub's noreply email from the start to avoid this issue. GitHub provides a unique noreply email for each user that keeps your real email private while allowing pushes.

**How to Find Your GitHub Noreply Email:**
1. Go to https://github.com/settings/emails
2. Look for: `USERNAME@users.noreply.github.com`
3. Or use: `ID+USERNAME@users.noreply.github.com` (numeric ID)""",
    "context": "Encountered multiple times during this session when trying to push commits to GitHub. Had to repeatedly use the temporary workaround. This is a common issue when using Claude Code or any git automation with personal email addresses.",
    "type": "Solution",
    "dev_stream": "DevOps",
    "tags": ["git", "github", "email-privacy", "push-protection", "commits", "automation"],
    "confidence": "High",
    "impact": "Prevents workflow interruption - this issue blocks all pushes until resolved",
    "related_files": "All git operations in the repository"
}

print("Recording GitHub email privacy learning...")
response = requests.post(WEBHOOK_URL, headers=headers, json=learning)

if response.status_code == 200:
    result = response.json()
    if isinstance(result, list):
        result = result[0]

    if result.get("success"):
        print(f"✓ Learning recorded: {result.get('learning_id')}")
        print(f"  URL: {result.get('url')}")
    else:
        print(f"✗ Failed: {result}")
else:
    print(f"✗ HTTP {response.status_code}: {response.text}")
