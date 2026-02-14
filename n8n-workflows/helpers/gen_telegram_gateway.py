#!/usr/bin/env python3
"""Generate Noel Telegram Gateway workflow JSON for n8n import"""
import json, uuid

def uid():
    return str(uuid.uuid4())

TG_CRED = {"telegramApi": {"id": "yThtgY0qtsaAlq1w", "name": "Noel Telegram Bot"}}
SB_CRED = {"supabaseApi": {"id": "dzXo3zuY3CuxGiIo", "name": "Supabase account"}}

POS = {
    "Telegram Trigger": [0, 0],
    "Parse Message": [220, 0],
    "Auth Check": [440, 0],
    "IF Authorized": [660, 0],
    "Command Router": [880, 0],
    "Help Text": [1100, -400],
    "Parse Capture": [1100, -200],
    "IF Valid Capture": [1320, -200],
    "HTTP Noel Capture": [1540, -200],
    "Format Capture Result": [1760, -200],
    "Parse Query": [1100, 0],
    "IF Valid Query": [1320, 0],
    "HTTP Noel Query": [1540, 0],
    "Format Query Results": [1760, 0],
    "HTTP Stats RPC": [1100, 200],
    "Format Stats": [1320, 200],
    "HTTP Projects RPC": [1100, 400],
    "Format Projects": [1320, 400],
    "Unknown Command": [1100, 600],
    "Send Response": [2000, 0],
    "Send Error": [1540, -400],
    "Send Unauthorized": [880, 300],
}

nodes = []

# 1. Telegram Trigger
nodes.append({
    "parameters": {"updates": ["message"]},
    "id": uid(), "name": "Telegram Trigger",
    "type": "n8n-nodes-base.telegramTrigger",
    "typeVersion": 1.1, "position": POS["Telegram Trigger"],
    "credentials": TG_CRED, "webhookId": uid()
})

# 2. Parse Message
nodes.append({
    "parameters": {
        "jsCode": (
            "const message = $input.first().json.message || $input.first().json;\n"
            "const text = message.text || '';\n"
            "const chatId = String(message.chat?.id || message.from?.id || '');\n"
            "const username = message.from?.username || 'unknown';\n"
            "const commandMatch = text.match(/^\\/([\\w]+)(?:\\s+(.*))?$/s);\n"
            "return [{json: {\n"
            "  chat_id: chatId,\n"
            "  username: username,\n"
            "  message_id: message.message_id,\n"
            "  command: commandMatch ? commandMatch[1].toLowerCase() : 'unknown',\n"
            "  args: commandMatch ? (commandMatch[2] || '').trim() : text.trim(),\n"
            "  raw_text: text\n"
            "}}];"
        )
    },
    "id": uid(), "name": "Parse Message",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Parse Message"]
})

# 3. Auth Check (Supabase RPC)
nodes.append({
    "parameters": {
        "method": "POST",
        "url": "https://sladetzgpogodrqwfamy.supabase.co/rest/v1/rpc/validate_telegram_chat",
        "authentication": "predefinedCredentialType",
        "nodeCredentialType": "supabaseApi",
        "sendHeaders": True,
        "headerParameters": {"parameters": [{"name": "Content-Type", "value": "application/json"}]},
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": "={\"p_chat_id\": \"{{ $json.chat_id }}\"}",
        "options": {}
    },
    "id": uid(), "name": "Auth Check",
    "type": "n8n-nodes-base.httpRequest", "typeVersion": 4.2,
    "position": POS["Auth Check"], "credentials": SB_CRED
})

# 4. IF Authorized
nodes.append({
    "parameters": {
        "conditions": {
            "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "strict", "version": 2},
            "conditions": [{
                "id": uid(),
                "leftValue": "={{ $json[0].is_authorized }}",
                "rightValue": True,
                "operator": {"type": "boolean", "operation": "true"}
            }],
            "combinator": "and"
        },
        "options": {}
    },
    "id": uid(), "name": "IF Authorized",
    "type": "n8n-nodes-base.if", "typeVersion": 2.2,
    "position": POS["IF Authorized"]
})

# 5. Command Router (Switch)
def sw_cond(lv, rv):
    return {"conditions": {
        "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "strict", "version": 2},
        "conditions": [{"leftValue": lv, "rightValue": rv, "operator": {"type": "string", "operation": "equals"}, "id": uid()}],
        "combinator": "and"
    }}

cmd = "={{ $('Parse Message').item.json.command }}"
nodes.append({
    "parameters": {
        "rules": {"values": [sw_cond(cmd, "help"), sw_cond(cmd, "capture"), sw_cond(cmd, "query"), sw_cond(cmd, "status"), sw_cond(cmd, "projects")]},
        "options": {}
    },
    "id": uid(), "name": "Command Router",
    "type": "n8n-nodes-base.switch", "typeVersion": 3.3,
    "position": POS["Command Router"]
})

# 6. Help Text
nodes.append({
    "parameters": {
        "jsCode": (
            "return [{json: {\n"
            "  response_text: '\\ud83e\\udde0 *Noel Knowledge Bot*\\n\\n' +\n"
            "    'Commands:\\n' +\n"
            "    '/capture Title | Content - Capture a learning\\n' +\n"
            "    '/query search terms - Search learnings\\n' +\n"
            "    '/status - System statistics\\n' +\n"
            "    '/projects - List projects\\n' +\n"
            "    '/help - This reference\\n\\n' +\n"
            "    'Capture format:\\n' +\n"
            "    '`/capture Bug Fix | WHY: reason WHAT: solution HOW: steps`'\n"
            "}}];"
        )
    },
    "id": uid(), "name": "Help Text",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Help Text"]
})

# 7. Parse Capture
nodes.append({
    "parameters": {
        "jsCode": (
            "const args = $('Parse Message').item.json.args || '';\n"
            "const defaultProject = $('Auth Check').item.json[0]?.default_project || 'Noel_SK';\n"
            "const parts = args.split('|');\n"
            "if (parts.length < 2 || parts[0].trim().length < 5 || parts[1].trim().length < 10) {\n"
            "  return [{json: {is_error: true, error_message: 'Invalid format. Use:\\n/capture Title | Content\\n\\nTitle min 5 chars, Content min 10 chars.'}}];\n"
            "}\n"
            "return [{json: {\n"
            "  is_error: false,\n"
            "  noel_payload: {\n"
            "    endpoint: 'capture_learning',\n"
            "    project: defaultProject,\n"
            "    title: parts[0].trim(),\n"
            "    content: parts.slice(1).join('|').trim(),\n"
            "    type: 'Solution',\n"
            "    confidence: 'Medium',\n"
            "    source_channel: 'telegram',\n"
            "    tags: ['telegram-capture']\n"
            "  }\n"
            "}}];"
        )
    },
    "id": uid(), "name": "Parse Capture",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Parse Capture"]
})

# 8. IF Valid Capture (is_error == true -> output 0 = Send Error)
nodes.append({
    "parameters": {
        "conditions": {
            "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "strict", "version": 2},
            "conditions": [{"id": uid(), "leftValue": "={{ $json.is_error }}", "rightValue": True, "operator": {"type": "boolean", "operation": "true"}}],
            "combinator": "and"
        },
        "options": {}
    },
    "id": uid(), "name": "IF Valid Capture",
    "type": "n8n-nodes-base.if", "typeVersion": 2.2,
    "position": POS["IF Valid Capture"]
})

# 9. HTTP Noel Capture
nodes.append({
    "parameters": {
        "method": "POST",
        "url": "http://localhost:5678/webhook/noel",
        "authentication": "none",
        "sendHeaders": True,
        "headerParameters": {"parameters": [
            {"name": "Content-Type", "value": "application/json"},
            {"name": "Authorization", "value": "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"}
        ]},
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify($json.noel_payload) }}",
        "options": {}
    },
    "id": uid(), "name": "HTTP Noel Capture",
    "type": "n8n-nodes-base.httpRequest", "typeVersion": 4.2,
    "position": POS["HTTP Noel Capture"]
})

# 10. Format Capture Result
nodes.append({
    "parameters": {
        "jsCode": (
            "const res = $input.first().json;\n"
            "const data = Array.isArray(res) ? res[0] : res;\n"
            "let text;\n"
            "if (data.success || data.learning_id) {\n"
            "  text = '\\u2705 Learning captured!\\nID: ' + (data.learning_id || 'unknown') + '\\nTitle: ' + (data.title || 'saved');\n"
            "} else {\n"
            "  text = '\\u26a0\\ufe0f Capture response: ' + JSON.stringify(data).substring(0, 200);\n"
            "}\n"
            "return [{json: {response_text: text}}];"
        )
    },
    "id": uid(), "name": "Format Capture Result",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Format Capture Result"]
})

# 11. Parse Query
nodes.append({
    "parameters": {
        "jsCode": (
            "const args = $('Parse Message').item.json.args || '';\n"
            "if (args.length < 3) {\n"
            "  return [{json: {is_error: true, error_message: 'Query too short. Use:\\n/query search terms\\n\\nMin 3 characters.'}}];\n"
            "}\n"
            "return [{json: {\n"
            "  is_error: false,\n"
            "  noel_payload: {endpoint: 'query_learnings', query: args, limit: 5}\n"
            "}}];"
        )
    },
    "id": uid(), "name": "Parse Query",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Parse Query"]
})

# 12. IF Valid Query
nodes.append({
    "parameters": {
        "conditions": {
            "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "strict", "version": 2},
            "conditions": [{"id": uid(), "leftValue": "={{ $json.is_error }}", "rightValue": True, "operator": {"type": "boolean", "operation": "true"}}],
            "combinator": "and"
        },
        "options": {}
    },
    "id": uid(), "name": "IF Valid Query",
    "type": "n8n-nodes-base.if", "typeVersion": 2.2,
    "position": POS["IF Valid Query"]
})

# 13. HTTP Noel Query
nodes.append({
    "parameters": {
        "method": "POST",
        "url": "http://localhost:5678/webhook/noel",
        "authentication": "none",
        "sendHeaders": True,
        "headerParameters": {"parameters": [
            {"name": "Content-Type", "value": "application/json"},
            {"name": "Authorization", "value": "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"}
        ]},
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify($json.noel_payload) }}",
        "options": {}
    },
    "id": uid(), "name": "HTTP Noel Query",
    "type": "n8n-nodes-base.httpRequest", "typeVersion": 4.2,
    "position": POS["HTTP Noel Query"]
})

# 14. Format Query Results
nodes.append({
    "parameters": {
        "jsCode": (
            "const raw = $input.first().json;\n"
            "const data = Array.isArray(raw) ? raw[0] : raw;\n"
            "const results = data.results || [];\n"
            "const query = $('Parse Message').item.json.args || '';\n"
            "if (results.length === 0) {\n"
            "  return [{json: {response_text: 'No results for: ' + query + '\\n\\nTry different search terms.'}}];\n"
            "}\n"
            "let text = '\\ud83d\\udd0d Results for: ' + query + '\\n\\n';\n"
            "results.slice(0, 5).forEach((r, i) => {\n"
            "  const title = r.metadata?.title || r.title || 'Untitled';\n"
            "  const project = r.metadata?.project || '';\n"
            "  const score = r.similarity ? (r.similarity * 100).toFixed(0) + '%' : '';\n"
            "  const excerpt = (r.content || '').substring(0, 120).replace(/\\n/g, ' ');\n"
            "  text += (i+1) + '. *' + title + '*';\n"
            "  if (project) text += ' [' + project + ']';\n"
            "  if (score) text += ' (' + score + ')';\n"
            "  text += '\\n   ' + excerpt + '\\n\\n';\n"
            "});\n"
            "if (text.length > 4000) text = text.substring(0, 3990) + '\\n...truncated';\n"
            "return [{json: {response_text: text}}];"
        )
    },
    "id": uid(), "name": "Format Query Results",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Format Query Results"]
})

# 15. HTTP Stats RPC
nodes.append({
    "parameters": {
        "method": "POST",
        "url": "https://sladetzgpogodrqwfamy.supabase.co/rest/v1/rpc/get_noel_system_stats",
        "authentication": "predefinedCredentialType",
        "nodeCredentialType": "supabaseApi",
        "sendHeaders": True,
        "headerParameters": {"parameters": [{"name": "Content-Type", "value": "application/json"}]},
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": "{}",
        "options": {}
    },
    "id": uid(), "name": "HTTP Stats RPC",
    "type": "n8n-nodes-base.httpRequest", "typeVersion": 4.2,
    "position": POS["HTTP Stats RPC"], "credentials": SB_CRED
})

# 16. Format Stats
nodes.append({
    "parameters": {
        "jsCode": (
            "const raw = $input.first().json;\n"
            "const s = Array.isArray(raw) ? raw[0] : raw;\n"
            "const text = '\\ud83d\\udcca *Noel System Stats*\\n\\n' +\n"
            "  'Total Learnings: ' + (s.total_learnings || 0) + '\\n' +\n"
            "  'Active Projects: ' + (s.active_projects || 0) + '\\n' +\n"
            "  'Total Sessions: ' + (s.total_sessions || 0) + '\\n' +\n"
            "  'Learnings This Week: ' + (s.learnings_this_week || 0) + '\\n' +\n"
            "  'Top Project: ' + (s.top_project || 'N/A');\n"
            "return [{json: {response_text: text}}];"
        )
    },
    "id": uid(), "name": "Format Stats",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Format Stats"]
})

# 17. HTTP Projects RPC
nodes.append({
    "parameters": {
        "method": "POST",
        "url": "https://sladetzgpogodrqwfamy.supabase.co/rest/v1/rpc/get_project_learning_counts",
        "authentication": "predefinedCredentialType",
        "nodeCredentialType": "supabaseApi",
        "sendHeaders": True,
        "headerParameters": {"parameters": [{"name": "Content-Type", "value": "application/json"}]},
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": "{}",
        "options": {}
    },
    "id": uid(), "name": "HTTP Projects RPC",
    "type": "n8n-nodes-base.httpRequest", "typeVersion": 4.2,
    "position": POS["HTTP Projects RPC"], "credentials": SB_CRED
})

# 18. Format Projects
nodes.append({
    "parameters": {
        "jsCode": (
            "const raw = $input.first().json;\n"
            "const projects = Array.isArray(raw) ? raw : [raw];\n"
            "let text = '\\ud83d\\udcc1 *Projects*\\n\\n';\n"
            "projects.forEach(p => {\n"
            "  const name = p.project_name || 'Unknown';\n"
            "  const count = p.learning_count || 0;\n"
            "  const latest = p.latest_learning ? new Date(p.latest_learning).toLocaleDateString() : 'N/A';\n"
            "  text += '\\u2022 *' + name + '* - ' + count + ' learnings (latest: ' + latest + ')\\n';\n"
            "});\n"
            "if (text.length > 4000) text = text.substring(0, 3990) + '\\n...truncated';\n"
            "return [{json: {response_text: text}}];"
        )
    },
    "id": uid(), "name": "Format Projects",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Format Projects"]
})

# 19. Unknown Command
nodes.append({
    "parameters": {
        "jsCode": (
            "const cmd = $('Parse Message').item.json.command || 'unknown';\n"
            "return [{json: {\n"
            "  response_text: 'Unknown command: /' + cmd + '\\n\\nType /help for available commands.'\n"
            "}}];"
        )
    },
    "id": uid(), "name": "Unknown Command",
    "type": "n8n-nodes-base.code", "typeVersion": 2,
    "position": POS["Unknown Command"]
})

# 20. Send Response (Telegram)
nodes.append({
    "parameters": {
        "operation": "sendMessage",
        "chatId": "={{ $('Parse Message').item.json.chat_id }}",
        "text": "={{ $json.response_text }}",
        "additionalFields": {"parse_mode": "Markdown"}
    },
    "id": uid(), "name": "Send Response",
    "type": "n8n-nodes-base.telegram", "typeVersion": 1.2,
    "position": POS["Send Response"], "credentials": TG_CRED
})

# 21. Send Error (Telegram)
nodes.append({
    "parameters": {
        "operation": "sendMessage",
        "chatId": "={{ $('Parse Message').item.json.chat_id }}",
        "text": "={{ $json.error_message }}",
        "additionalFields": {}
    },
    "id": uid(), "name": "Send Error",
    "type": "n8n-nodes-base.telegram", "typeVersion": 1.2,
    "position": POS["Send Error"], "credentials": TG_CRED
})

# 22. Send Unauthorized (Telegram)
nodes.append({
    "parameters": {
        "operation": "sendMessage",
        "chatId": "={{ $('Parse Message').item.json.chat_id }}",
        "text": "Unauthorized. Your chat ID is not registered.",
        "additionalFields": {}
    },
    "id": uid(), "name": "Send Unauthorized",
    "type": "n8n-nodes-base.telegram", "typeVersion": 1.2,
    "position": POS["Send Unauthorized"], "credentials": TG_CRED
})

# ---- CONNECTIONS ----
connections = {}

def connect(from_name, to_name, from_output=0):
    if from_name not in connections:
        connections[from_name] = {"main": []}
    m = connections[from_name]["main"]
    while len(m) <= from_output:
        m.append([])
    m[from_output].append({"node": to_name, "type": "main", "index": 0})

# Main flow
connect("Telegram Trigger", "Parse Message")
connect("Parse Message", "Auth Check")
connect("Auth Check", "IF Authorized")
connect("IF Authorized", "Command Router", 0)   # true = authorized
connect("IF Authorized", "Send Unauthorized", 1) # false = unauthorized

# Command Router outputs (matching Switch rules order)
connect("Command Router", "Help Text", 0)        # /help
connect("Command Router", "Parse Capture", 1)     # /capture
connect("Command Router", "Parse Query", 2)       # /query
connect("Command Router", "HTTP Stats RPC", 3)    # /status
connect("Command Router", "HTTP Projects RPC", 4) # /projects
connect("Command Router", "Unknown Command", 5)   # fallback

# /help -> Send Response
connect("Help Text", "Send Response")

# /capture flow
connect("Parse Capture", "IF Valid Capture")
connect("IF Valid Capture", "Send Error", 0)        # true = is_error -> error
connect("IF Valid Capture", "HTTP Noel Capture", 1)  # false = valid -> proceed
connect("HTTP Noel Capture", "Format Capture Result")
connect("Format Capture Result", "Send Response")

# /query flow
connect("Parse Query", "IF Valid Query")
connect("IF Valid Query", "Send Error", 0)        # true = is_error -> error
connect("IF Valid Query", "HTTP Noel Query", 1)    # false = valid -> proceed
connect("HTTP Noel Query", "Format Query Results")
connect("Format Query Results", "Send Response")

# /status flow
connect("HTTP Stats RPC", "Format Stats")
connect("Format Stats", "Send Response")

# /projects flow
connect("HTTP Projects RPC", "Format Projects")
connect("Format Projects", "Send Response")

# Unknown command -> Send Response
connect("Unknown Command", "Send Response")

# ---- ASSEMBLE ----
workflow = {
    "name": "Noel Telegram Gateway",
    "nodes": nodes,
    "connections": connections,
    "settings": {"executionOrder": "v1"}
}

with open("/tmp/tg_gateway_final.json", "w") as f:
    json.dump(workflow, f, indent=2)

print(f"Generated workflow: {len(nodes)} nodes, {len(connections)} connection sources")
for n in nodes:
    cred = list(n.get("credentials", {}).keys())
    print(f"  {n['name']:25s} {n['type']:40s} v{n['typeVersion']}  cred={cred}")
