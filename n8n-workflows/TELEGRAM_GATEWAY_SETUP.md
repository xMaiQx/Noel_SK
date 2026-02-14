# Noel Telegram Gateway - Setup Guide

## Prerequisites

1. **Telegram Bot Token** from @BotFather
2. **n8n WEBHOOK_URL** set to your ngrok URL (for Telegram webhook registration)
3. **User's Telegram chat_id** (see Step 1 below)
4. **Notion "Source Channel" property** added to Learnings DB (see Step 2)

---

## Step 1: Get Your Telegram chat_id

1. Open Telegram and find your bot (search by its @username)
2. Send `/start` or any message to the bot
3. Open in browser: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
4. Find `"chat":{"id":XXXXXXX}` in the response - that's your chat_id

## Step 2: Add "Source Channel" to Notion Learnings DB

1. Open Notion > Learnings database
2. Click "+" to add a new property
3. Property type: **Select**
4. Property name: **Source Channel**
5. Add options: `telegram`, `slack`, `cli`, `claude-code`, `api`

## Step 3: Add Telegram Credential to n8n

1. Go to n8n > Settings > Credentials
2. Click "Add Credential"
3. Search for "Telegram API"
4. Name: `Noel Telegram Bot`
5. Paste your bot token
6. Save

## Step 4: Set n8n WEBHOOK_URL

The Telegram Trigger node needs n8n to register a webhook with Telegram. n8n uses the `WEBHOOK_URL` environment variable for this.

```bash
# If running n8n in Docker:
docker exec <container> env | grep WEBHOOK

# Set it to your ngrok URL (without /webhook/noel):
# In docker-compose.yml or .env:
WEBHOOK_URL=https://xxxx.ngrok-free.app
```

**Important**: This must be set BEFORE activating the workflow.

## Step 5: Import the Workflow

### Option A: Import JSON (Recommended)

1. Open n8n
2. Go to Workflows > Import from File
3. Select `n8n-workflows/noel_telegram_gateway.json`
4. Update credential references:
   - Search for `TELEGRAM_CREDENTIAL_ID` and replace with your Telegram credential ID
   - The Supabase anon key is already embedded in the HTTP Request nodes

### Option B: Build Manually

Follow the node-by-node guide below.

---

## Workflow Architecture

```
Telegram Trigger
  -> Parse Message (Code)
  -> Auth Check (HTTP Request -> Supabase RPC)
  -> IF Authorized
    -> Command Router (Switch: help|capture|query|status|projects|default)
      /help     -> Help Text (Code) -> Send Response (Telegram)
      /capture  -> Parse Capture (Code) -> IF Valid -> HTTP Noel -> Format -> Send Response
      /query    -> Parse Query (Code) -> IF Valid -> HTTP Noel -> Format -> Send Response
      /status   -> HTTP Stats RPC -> Format Stats (Code) -> Send Response
      /projects -> HTTP Projects RPC -> Format Projects (Code) -> Send Response
      default   -> Unknown Command (Code) -> Send Response
    NOT authorized -> Send Unauthorized (Telegram)
```

## Node Configuration Details

### 1. Telegram Trigger
- **Type**: Telegram Trigger
- **Updates**: message
- **Credential**: Noel Telegram Bot

### 2. Parse Message (Code)
Extracts chat_id, username, command, and args from Telegram message.

### 3. Auth Check (HTTP Request)
- **Method**: POST
- **URL**: `https://sladetzgpogodrqwfamy.supabase.co/rest/v1/rpc/validate_telegram_chat`
- **Headers**: apikey (Supabase anon key), Content-Type: application/json
- **Body**: `{"p_chat_id": "{{ $json.chat_id }}"}`

### 4. IF Authorized
- Condition: `$json[0].is_authorized === true`
- True -> Command Router
- False -> Send Unauthorized

### 5. Command Router (Switch)
- 5 named outputs + 1 fallback
- Routes on `$('Parse Message').item.json.command`

### 6-18. Command Handlers
See the JSON file for full Code node implementations.

### 19. Send Response (Telegram)
- **Chat ID**: `{{ $('Parse Message').item.json.chat_id }}`
- **Text**: `{{ $json.text }}`
- **Parse Mode**: Markdown

---

## Seed Your chat_id

After getting your chat_id from Step 1, run this SQL:

```sql
INSERT INTO channel_configs (channel_type, channel_id, config, default_project, is_active)
VALUES ('telegram', 'YOUR_CHAT_ID', '{"username":"YOUR_USERNAME"}', 'Noel_SK', true);
```

## Activate & Test

1. Activate the workflow in n8n
2. Send `/help` to your bot in Telegram
3. Expected: Command reference message
4. Send `/status` -> System stats
5. Send `/capture Test Learning | WHY: testing\nWHAT: telegram capture\nHOW: sent via bot`
6. Send `/query test` -> Should find the just-captured learning
