#!/usr/bin/env python3
"""
Backfill structured embeddings for all learnings in learnings_vectors.

Parses each learning's content into 4 sections:
  - title: from metadata.title
  - problem: WHY section (or first 500 chars fallback)
  - solution: WHAT+HOW sections (or full content fallback)
  - context: composed natural language from metadata fields

Generates 4 embeddings per learning via OpenAI text-embedding-3-small
(single API call with array input) and updates the row.

Usage:
  python3 scripts/backfill_structured_embeddings.py
  python3 scripts/backfill_structured_embeddings.py --dry-run
  python3 scripts/backfill_structured_embeddings.py --force  # re-embed even if already done
"""

import json
import os
import re
import sys
import time
import requests
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

def load_env():
    """Load .env file from project root."""
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        print(f"ERROR: .env file not found at {env_path}")
        sys.exit(1)

    env = {}
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            # Resolve ${VAR} references
            for ref_key, ref_val in env.items():
                value = value.replace(f"${{{ref_key}}}", ref_val)
            env[key] = value
    return env


ENV = load_env()
SUPABASE_URL = ENV["SUPABASE_URL"]
SUPABASE_KEY = ENV["SUPABASE_ANON_KEY"]
OPENAI_API_KEY = ENV["OPENAI_API_KEY"]

BATCH_SIZE = 20
BATCH_DELAY = 1.0  # seconds between batches
EMBEDDING_MODEL = "text-embedding-3-small"

# ---------------------------------------------------------------------------
# Supabase REST helpers
# ---------------------------------------------------------------------------

HEADERS_SB = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}


def sb_get(path, params=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    r = requests.get(url, headers={**HEADERS_SB, "Prefer": ""}, params=params)
    r.raise_for_status()
    return r.json()


def sb_patch(path, data, match_filter):
    """PATCH a row in Supabase. match_filter is like 'learning_id=eq.XXX'."""
    url = f"{SUPABASE_URL}/rest/v1/{path}?{match_filter}"
    r = requests.patch(url, headers=HEADERS_SB, json=data)
    if r.status_code not in (200, 204):
        print(f"  PATCH error {r.status_code}: {r.text[:300]}")
        return False
    return True


# ---------------------------------------------------------------------------
# OpenAI embedding helper
# ---------------------------------------------------------------------------

def get_embeddings(texts: list[str]) -> list[list[float]]:
    """Get embeddings for multiple texts in a single API call."""
    url = "https://api.openai.com/v1/embeddings"
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": EMBEDDING_MODEL,
        "input": texts,
    }
    r = requests.post(url, headers=headers, json=payload)
    r.raise_for_status()
    data = r.json()["data"]
    # Sort by index to ensure correct order
    data.sort(key=lambda x: x["index"])
    return [item["embedding"] for item in data]


# ---------------------------------------------------------------------------
# Content parsing
# ---------------------------------------------------------------------------

def parse_sections(content: str, metadata: dict) -> dict:
    """Parse a learning's content into title, problem, solution, context."""
    title = metadata.get("title", "Untitled")

    # Parse WHY section
    why_match = re.search(r'WHY:([\s\S]*?)(?=\nWHAT:|\n\nWHAT:|$)', content, re.IGNORECASE)
    # Parse WHAT+HOW section
    what_match = re.search(r'WHAT:([\s\S]*$)', content, re.IGNORECASE)

    if why_match:
        problem = why_match.group(1).strip()
    else:
        problem = content[:500].strip()

    if what_match:
        solution = what_match.group(1).strip()
    else:
        solution = content.strip()

    # Compose context from metadata
    project = metadata.get("project", "Unknown")
    mtype = metadata.get("type", "Unknown")
    tags = metadata.get("tags", [])
    dev_stream = metadata.get("dev_stream", [])
    applies_to = metadata.get("applies_to", "General")
    scope = metadata.get("scope", "Project-Specific")
    discipline = metadata.get("discipline", [])

    # Handle tags/dev_stream/discipline that may be strings or lists
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",")]
    if isinstance(dev_stream, str):
        dev_stream = [d.strip() for d in dev_stream.split(",")]
    if isinstance(discipline, str):
        discipline = [d.strip() for d in discipline.split(",")]

    context_parts = [
        f"Project: {project}",
        f"Type: {mtype}",
        f"Scope: {scope}",
    ]
    if tags:
        context_parts.append(f"Tags: {', '.join(tags)}")
    if dev_stream:
        context_parts.append(f"Dev Stream: {', '.join(dev_stream)}")
    if discipline:
        context_parts.append(f"Discipline: {', '.join(discipline)}")
    if applies_to and applies_to != "General":
        context_parts.append(f"Applies to: {applies_to}")

    context_text = ". ".join(context_parts) + "."

    return {
        "title": title,
        "problem": problem,
        "solution": solution,
        "context": context_text,
    }


# ---------------------------------------------------------------------------
# Main backfill
# ---------------------------------------------------------------------------

def main():
    dry_run = "--dry-run" in sys.argv
    force = "--force" in sys.argv

    print(f"{'DRY RUN — ' if dry_run else ''}Backfill Structured Embeddings")
    print(f"  Model: {EMBEDDING_MODEL}")
    print(f"  Batch size: {BATCH_SIZE}")
    print(f"  Force re-embed: {force}")
    print()

    # Fetch all learnings
    print("Fetching learnings from Supabase...")
    learnings = sb_get(
        "learnings_vectors",
        params={
            "select": "learning_id,content,metadata,title_embedding,problem_embedding,solution_embedding,context_embedding",
            "order": "created_at.asc",
        },
    )
    print(f"  Found {len(learnings)} learnings")

    # Filter: skip rows that already have all 4 embeddings (unless --force)
    if not force:
        to_process = [
            l for l in learnings
            if not (l.get("title_embedding") and l.get("problem_embedding")
                    and l.get("solution_embedding") and l.get("context_embedding"))
        ]
    else:
        to_process = learnings

    print(f"  To process: {len(to_process)} (skipping {len(learnings) - len(to_process)} already done)")
    print()

    if not to_process:
        print("Nothing to do!")
        return

    # Process in batches
    total = len(to_process)
    success = 0
    errors = 0

    for batch_start in range(0, total, BATCH_SIZE):
        batch = to_process[batch_start : batch_start + BATCH_SIZE]
        batch_num = batch_start // BATCH_SIZE + 1
        total_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE
        print(f"Batch {batch_num}/{total_batches} ({len(batch)} learnings)")

        for learning in batch:
            lid = learning["learning_id"]
            content = learning["content"] or ""
            metadata = learning["metadata"] or {}

            sections = parse_sections(content, metadata)

            # Truncate very long sections to avoid token limits
            texts = [
                sections["title"][:500],
                sections["problem"][:2000],
                sections["solution"][:2000],
                sections["context"][:1000],
            ]

            print(f"  {lid}: title={len(texts[0])}c problem={len(texts[1])}c "
                  f"solution={len(texts[2])}c context={len(texts[3])}c", end="")

            if dry_run:
                print(" [dry-run skip]")
                success += 1
                continue

            try:
                embeddings = get_embeddings(texts)

                # Format embeddings as PostgreSQL vector strings
                update_data = {
                    "title_embedding": json.dumps(embeddings[0]),
                    "problem_embedding": json.dumps(embeddings[1]),
                    "solution_embedding": json.dumps(embeddings[2]),
                    "context_embedding": json.dumps(embeddings[3]),
                }

                ok = sb_patch(
                    "learnings_vectors",
                    update_data,
                    f"learning_id=eq.{lid}",
                )
                if ok:
                    print(" OK")
                    success += 1
                else:
                    print(" PATCH FAILED")
                    errors += 1

            except Exception as e:
                print(f" ERROR: {e}")
                errors += 1

        # Delay between batches (except last)
        if batch_start + BATCH_SIZE < total:
            print(f"  Waiting {BATCH_DELAY}s...")
            time.sleep(BATCH_DELAY)

    print()
    print(f"Done! Success: {success}, Errors: {errors}, Total: {total}")

    if errors > 0:
        print("\nRe-run the script to retry failed learnings (idempotent).")
        sys.exit(1)


if __name__ == "__main__":
    main()
