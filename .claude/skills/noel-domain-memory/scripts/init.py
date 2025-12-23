#!/usr/bin/env python3
"""
Initializer agent for Noel domain memory.

This script runs the "BIOS boot" sequence:
1. Validate environment
2. Query Noel for relevant learnings
3. Create session state
4. Register session in Noel
5. Display boot summary
"""

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional


# Terminal colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color


def print_header():
    """Print the BIOS boot header."""
    print(f"{BLUE}{'='*60}{NC}")
    print(f"{GREEN}[Noel Domain Memory BIOS v1.0]{NC}")
    print(f"{BLUE}{'='*60}{NC}\n")


def check_environment() -> Dict[str, Any]:
    """
    Validate environment configuration.

    Returns:
        Dict with environment check results
    """
    print(f"{BLUE}Environment Check:{NC}")

    results = {
        'webhook_url': None,
        'ngrok_active': False,
        'n8n_responsive': False,
        'all_passed': False
    }

    # Check NOEL_WEBHOOK_URL
    webhook_url = os.getenv('NOEL_WEBHOOK_URL')
    if webhook_url:
        print(f"{GREEN}✓{NC} NOEL_WEBHOOK_URL configured")
        results['webhook_url'] = webhook_url
    else:
        print(f"{RED}✗{NC} NOEL_WEBHOOK_URL not set")
        print(f"{YELLOW}  Set with: export NOEL_WEBHOOK_URL='https://your-ngrok-url.ngrok-free.app/webhook'{NC}")
        return results

    # Test ngrok tunnel (basic connectivity)
    try:
        result = subprocess.run(
            ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', f"{webhook_url}/list_projects"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 and result.stdout in ['200', '201']:
            ngrok_host = webhook_url.split('/')[2]
            print(f"{GREEN}✓{NC} ngrok tunnel active ({ngrok_host})")
            results['ngrok_active'] = True
        else:
            print(f"{YELLOW}⚠{NC} ngrok tunnel not responding (HTTP {result.stdout})")
    except (subprocess.TimeoutExpired, Exception) as e:
        print(f"{YELLOW}⚠{NC} Could not verify ngrok tunnel: {e}")

    # Test n8n workflow (try to list projects)
    try:
        result = subprocess.run(
            ['curl', '-s', '-X', 'POST', f"{webhook_url}/list_projects",
             '-H', 'Content-Type: application/json',
             '-d', '{"filters":{}}'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            response = json.loads(result.stdout)
            if response.get('success'):
                print(f"{GREEN}✓{NC} n8n workflow responsive")
                results['n8n_responsive'] = True
            else:
                print(f"{YELLOW}⚠{NC} n8n workflow returned error: {response.get('error', 'unknown')}")
        else:
            print(f"{YELLOW}⚠{NC} n8n workflow not responding")
    except (json.JSONDecodeError, subprocess.TimeoutExpired, Exception) as e:
        print(f"{YELLOW}⚠{NC} Could not verify n8n workflow: {e}")

    results['all_passed'] = results['webhook_url'] and results['ngrok_active'] and results['n8n_responsive']

    return results


def query_noel_learnings(webhook_url: str, query: str = "Recent Noel development patterns", limit: int = 5) -> List[Dict[str, Any]]:
    """
    Query Noel for relevant learnings.

    Args:
        webhook_url: Noel webhook URL
        query: Search query
        limit: Max number of learnings to return

    Returns:
        List of learning dictionaries
    """
    print(f"\n{BLUE}Context Query:{NC}")
    print(f"  Querying Noel: \"{query}\"...")

    payload = {
        'query': query,
        'filters': {'project': 'Noel'},
        'limit': limit
    }

    try:
        result = subprocess.run(
            ['curl', '-s', '-X', 'POST', f"{webhook_url}/query_learnings",
             '-H', 'Content-Type: application/json',
             '-d', json.dumps(payload)],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode != 0:
            print(f"{YELLOW}⚠{NC} Query failed (curl error)")
            return []

        response = json.loads(result.stdout)

        if not response.get('success'):
            print(f"{YELLOW}⚠{NC} Query failed: {response.get('error', 'unknown')}")
            return []

        results = response.get('results', [])
        count = response.get('count', 0)

        print(f"{GREEN}✓{NC} Found {count} relevant learnings")

        # Format learnings for state
        learnings = []
        for r in results[:limit]:
            learnings.append({
                'learning_id': r.get('learning_id'),
                'title': r.get('title'),
                'key_insight': r.get('content', '')[:200],  # First 200 chars
                'similarity_score': r.get('similarity_score', 0),
                'captured_at': r.get('created_at', ''),
                'applied_count': 0
            })

        return learnings

    except (json.JSONDecodeError, subprocess.TimeoutExpired, Exception) as e:
        print(f"{YELLOW}⚠{NC} Query error: {e}")
        return []


def create_session_state(
    session_id: str,
    goals: str,
    learnings: List[Dict[str, Any]],
    env_results: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Create initial session state from template.

    Args:
        session_id: Generated session ID
        goals: Session goals from user
        learnings: Loaded learnings from Noel
        env_results: Environment check results

    Returns:
        Initialized state dictionary
    """
    print(f"\n{BLUE}State Initialization:{NC}")

    # Load template
    template_path = Path(__file__).parent.parent / 'assets' / 'state-template.json'
    with open(template_path) as f:
        state = json.load(f)

    # Get current git branch
    try:
        result = subprocess.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                              capture_output=True, text=True, timeout=2)
        branch = result.stdout.strip() if result.returncode == 0 else 'unknown'
    except Exception:
        branch = 'unknown'

    # Fill in metadata
    now = datetime.utcnow().isoformat() + 'Z'
    state['metadata']['session_id'] = session_id
    state['metadata']['created_at'] = now
    state['metadata']['last_updated'] = now

    # Fill in session context
    state['session_context']['goals'] = goals
    state['session_context']['current_task'] = goals  # Initial task = goals
    state['session_context']['branch'] = branch
    state['session_context']['ngrok_url'] = env_results.get('webhook_url', '').replace('/webhook', '')

    # Add loaded learnings
    state['relevant_learnings'] = learnings
    state['kpis']['learnings_loaded'] = len(learnings)

    # Create .noel directory structure
    noel_dir = Path('.noel')
    noel_dir.mkdir(exist_ok=True)
    (noel_dir / 'sessions').mkdir(exist_ok=True)
    (noel_dir / 'debug').mkdir(exist_ok=True)

    # Save state
    state_path = noel_dir / 'session-state.json'
    with open(state_path, 'w') as f:
        json.dump(state, f, indent=2)

    print(f"{GREEN}✓{NC} Created .noel/ directory structure")
    print(f"{GREEN}✓{NC} Generated session ID: {session_id}")
    print(f"{GREEN}✓{NC} Wrote state to .noel/session-state.json")

    return state


def display_boot_summary(state: Dict[str, Any]):
    """
    Display formatted boot summary.

    Args:
        state: Initialized session state
    """
    print(f"\n{BLUE}{'='*60}{NC}")
    print(f"{GREEN}Loaded Learnings ({len(state['relevant_learnings'])}):{NC}")

    if not state['relevant_learnings']:
        print(f"{YELLOW}  (No relevant learnings found - starting fresh){NC}")
    else:
        for learning in state['relevant_learnings']:
            score = learning['similarity_score']
            score_pct = int(score * 100) if isinstance(score, float) else 0
            print(f"  {BLUE}[{learning['learning_id']}]{NC} {learning['title']} ({score_pct}% match)")
            insight = learning['key_insight'][:80]
            if len(learning['key_insight']) > 80:
                insight += '...'
            print(f"    → {insight}")

    print(f"\n{GREEN}Active Blockers ({len(state['active_blockers'])}):{NC}")
    if not state['active_blockers']:
        print(f"{GREEN}  (No active blockers){NC}")
    else:
        for blocker in state['active_blockers']:
            print(f"  {YELLOW}[{blocker['blocker_id']}]{NC} {blocker['description']}")
            print(f"    Impact: {blocker['impact']}")
            print(f"    Status: {blocker['status']}")

    print(f"\n{GREEN}Session Started:{NC}")
    print(f"  ID: {state['metadata']['session_id']}")
    print(f"  Goals: {state['session_context']['goals']}")
    print(f"  Branch: {state['session_context']['branch']}")

    print(f"\n{GREEN}KPIs Initialized:{NC}")
    kpis = state['kpis']
    print(f"  Learnings loaded: {kpis['learnings_loaded']}")
    print(f"  Atomic steps: {kpis['atomic_steps_completed']}")
    print(f"  Debug files: {kpis['debug_files_created']}")

    print(f"\n{BLUE}{'='*60}{NC}")
    print(f"{GREEN}Ready for atomic progress.{NC}")
    print(f"{BLUE}{'='*60}{NC}\n")


def generate_session_id() -> str:
    """
    Generate session ID in format: SESSION-YYYYMMDD-NNN

    Returns:
        Session ID string
    """
    today = datetime.utcnow().strftime('%Y%m%d')

    # Check existing sessions for today
    sessions_dir = Path('.noel/sessions')
    if sessions_dir.exists():
        today_sessions = list(sessions_dir.glob(f"SESSION-{today}-*.json"))
        if today_sessions:
            # Extract numbers and get max
            numbers = []
            for session_file in today_sessions:
                try:
                    num = int(session_file.stem.split('-')[-1])
                    numbers.append(num)
                except (ValueError, IndexError):
                    pass
            next_num = max(numbers) + 1 if numbers else 1
        else:
            next_num = 1
    else:
        next_num = 1

    return f"SESSION-{today}-{next_num:03d}"


def main():
    """Main initialization sequence."""
    print_header()

    # 1. Environment Check
    env_results = check_environment()

    if not env_results['webhook_url']:
        print(f"\n{RED}✗ Environment check failed. Please configure NOEL_WEBHOOK_URL.{NC}\n")
        sys.exit(1)

    if not env_results['all_passed']:
        print(f"\n{YELLOW}⚠ Some environment checks failed. Proceeding anyway...{NC}")

    # 2. Context Query
    webhook_url = env_results['webhook_url']
    learnings = query_noel_learnings(webhook_url)

    # 3. Generate session ID
    session_id = generate_session_id()

    # 4. Get session goals (from environment or default)
    goals = os.getenv('NOEL_SESSION_GOALS', 'Noel development session')

    # 5. Create session state
    state = create_session_state(session_id, goals, learnings, env_results)

    # 6. Display boot summary
    display_boot_summary(state)

    # 7. Export session ID to environment
    print(f"{BLUE}To register this session in Noel, run:{NC}")
    print(f"  export CURRENT_SESSION_ID=\"{session_id}\"")
    print(f"  noel-start-session \"Noel\" \"{goals}\"\n")


if __name__ == '__main__':
    main()
