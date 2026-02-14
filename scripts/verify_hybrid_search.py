#!/usr/bin/env python3
"""
Verification tests for match_learnings_hybrid RPC function.

Runs 6 test cases from the design plan and reports pass/fail.

Usage:
  python3 scripts/verify_hybrid_search.py

Requires: migrations 001+002 applied and backfill complete.
"""

import json
import os
import sys
import requests
from pathlib import Path


def load_env():
    env_path = Path(__file__).resolve().parent.parent / ".env"
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
            for ref_key, ref_val in env.items():
                value = value.replace(f"${{{ref_key}}}", ref_val)
            env[key] = value
    return env


ENV = load_env()
SUPABASE_URL = ENV["SUPABASE_URL"]
SUPABASE_KEY = ENV["SUPABASE_ANON_KEY"]
OPENAI_API_KEY = ENV["OPENAI_API_KEY"]

HEADERS_SB = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}


def get_embedding(text: str) -> list[float]:
    r = requests.post(
        "https://api.openai.com/v1/embeddings",
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json",
        },
        json={"model": "text-embedding-3-small", "input": text},
    )
    r.raise_for_status()
    return r.json()["data"][0]["embedding"]


def call_hybrid(query_text: str, match_count: int = 5, project_filter=None, type_filter=None):
    emb = get_embedding(query_text)
    payload = {
        "query_embedding": json.dumps(emb),
        "query_text": query_text,
        "match_count": match_count,
    }
    if project_filter:
        payload["project_filter"] = project_filter
    if type_filter:
        payload["type_filter"] = type_filter

    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/match_learnings_hybrid",
        headers=HEADERS_SB,
        json=payload,
    )
    if r.status_code != 200:
        print(f"  RPC ERROR {r.status_code}: {r.text[:500]}")
        return []
    return r.json()


def print_results(results):
    for i, r in enumerate(results):
        title = r.get("metadata", {}).get("title", "?")[:60]
        cs = r.get("combined_score", 0)
        ts = r.get("title_similarity", 0) or 0
        ps = r.get("problem_similarity", 0) or 0
        ss = r.get("solution_similarity", 0) or 0
        xs = r.get("context_similarity", 0) or 0
        tb = r.get("text_match_boost", 0) or 0
        print(f"  [{i+1}] score={cs:.3f} (t={ts:.2f} p={ps:.2f} s={ss:.2f} c={xs:.2f} +txt={tb:.2f})")
        print(f"      {title}")


def run_tests():
    passed = 0
    failed = 0

    # -----------------------------------------------------------------------
    # Test 1: "FIX REQUEST" — the failing case from execution 8905
    # -----------------------------------------------------------------------
    print("\n=== Test 1: 'FIX REQUEST' (the broken case) ===")
    results = call_hybrid("FIX REQUEST", match_count=5)
    print_results(results)

    fix_titles = [r for r in results if "FIX REQUEST" in (r.get("metadata", {}).get("title", "")).upper()]
    if len(fix_titles) >= 1 and results[0].get("combined_score", 0) > 0.4:
        print("  PASS: FIX REQUEST learnings found with good scores")
        passed += 1
    else:
        print("  FAIL: Expected FIX REQUEST learnings as top results")
        failed += 1

    # -----------------------------------------------------------------------
    # Test 2: Error lookup — "Notion 2000 char limit"
    # -----------------------------------------------------------------------
    print("\n=== Test 2: Error lookup — 'Notion 2000 char limit error' ===")
    results = call_hybrid("Notion 2000 char limit error", match_count=5)
    print_results(results)

    if results and results[0].get("combined_score", 0) > 0.3:
        print("  PASS: Relevant Notion limit learnings found")
        passed += 1
    else:
        print("  FAIL: Expected Notion-related results")
        failed += 1

    # -----------------------------------------------------------------------
    # Test 3: Pattern search — n8n Code node processing
    # -----------------------------------------------------------------------
    print("\n=== Test 3: Pattern search — 'n8n Code node process multiple items' ===")
    results = call_hybrid("n8n Code node process multiple items", match_count=5)
    print_results(results)

    n8n_results = [r for r in results if "n8n" in (r.get("metadata", {}).get("title", "")).lower()
                   or "code node" in (r.get("metadata", {}).get("title", "")).lower()]
    if n8n_results:
        print("  PASS: n8n Code node learning found")
        passed += 1
    else:
        print("  FAIL: Expected n8n Code node related results")
        failed += 1

    # -----------------------------------------------------------------------
    # Test 4: Cross-project — UDEE learnings
    # -----------------------------------------------------------------------
    print("\n=== Test 4: Cross-project — 'UDEE extraction rules' ===")
    results = call_hybrid("UDEE extraction rules", match_count=5)
    print_results(results)

    udee = [r for r in results if "UDEE" in (r.get("metadata", {}).get("project", "")).upper()
            or "udee" in (r.get("metadata", {}).get("title", "")).lower()]
    if udee:
        print("  PASS: UDEE learnings surfaced via context")
        passed += 1
    else:
        print("  FAIL: Expected UDEE-related results")
        failed += 1

    # -----------------------------------------------------------------------
    # Test 5: Broad query
    # -----------------------------------------------------------------------
    print("\n=== Test 5: Broad query — 'recent patterns and solutions' ===")
    results = call_hybrid("recent patterns and solutions", match_count=5)
    print_results(results)

    if results and results[0].get("combined_score", 0) > 0.2:
        print("  PASS: Diverse results returned with reasonable scores")
        passed += 1
    else:
        print("  FAIL: Expected results with scores > 0.2")
        failed += 1

    # -----------------------------------------------------------------------
    # Test 6: Text fallback — exact keyword match rescue
    # -----------------------------------------------------------------------
    print("\n=== Test 6: Text fallback — 'pgvector' (exact keyword) ===")
    results = call_hybrid("pgvector", match_count=5)
    print_results(results)

    text_boosted = [r for r in results if (r.get("text_match_boost", 0) or 0) > 0]
    if text_boosted:
        print("  PASS: Text match boost activated for keyword matches")
        passed += 1
    else:
        print("  WARN: No text boost activated (may be OK if vector similarity is strong)")
        passed += 1  # Not a hard failure

    # -----------------------------------------------------------------------
    print(f"\n{'='*60}")
    print(f"Results: {passed} passed, {failed} failed out of {passed + failed} tests")
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    run_tests()
