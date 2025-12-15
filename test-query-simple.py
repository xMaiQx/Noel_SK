#!/usr/bin/env python3
import requests

WEBHOOK_URL = "https://272485010cfe.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

headers = {
    "Content-Type": "application/json",
    "Authorization": AUTH_TOKEN
}

payload = {
    "endpoint": "query_learnings",
    "query": "PostgreSQL vectors",
    "limit": 3
}

print("Testing query_learnings...")
response = requests.post(WEBHOOK_URL, headers=headers, json=payload)

print(f"Status: {response.status_code}")
print(f"Headers: {dict(response.headers)}")
print(f"Response length: {len(response.text)} bytes")
print(f"Response text: '{response.text}'")
print(f"Response repr: {repr(response.text)}")
