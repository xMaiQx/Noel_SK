#!/usr/bin/env python3
"""
State management utilities for Noel domain memory.

Provides functions to load, save, and update the session state file.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional


def load_state(path: str = '.noel/session-state.json') -> Dict[str, Any]:
    """
    Load session state from JSON file.

    Args:
        path: Path to state file

    Returns:
        State dictionary

    Raises:
        FileNotFoundError: If state file doesn't exist
        json.JSONDecodeError: If state file is invalid JSON
    """
    state_path = Path(path)

    if not state_path.exists():
        raise FileNotFoundError(f"State file not found: {path}")

    with open(state_path, 'r') as f:
        state = json.load(f)

    return state


def save_state(path: str, state: Dict[str, Any]) -> None:
    """
    Save session state to JSON file with pretty formatting.

    Args:
        path: Path to state file
        state: State dictionary to save
    """
    # Update last_updated timestamp
    state['metadata']['last_updated'] = datetime.utcnow().isoformat() + 'Z'

    # Ensure directory exists
    state_path = Path(path)
    state_path.parent.mkdir(parents=True, exist_ok=True)

    # Write with pretty formatting
    with open(state_path, 'w') as f:
        json.dump(state, f, indent=2)


def update_progress(
    state: Dict[str, Any],
    action: str,
    test: str,
    outcome: str,
    learning_id: Optional[str] = None
) -> None:
    """
    Append atomic progress entry to state.

    Args:
        state: Current state dictionary
        action: Description of what was done
        test: How the outcome was verified
        outcome: Result (typically "success" or "failed")
        learning_id: Optional learning ID if this step captured a learning
    """
    progress_entry = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'action': action,
        'test': test,
        'outcome': outcome,
        'learning_captured': learning_id is not None
    }

    if learning_id:
        progress_entry['learning_id'] = learning_id

    state['atomic_progress'].append(progress_entry)


def increment_kpi(state: Dict[str, Any], kpi_name: str, amount: int = 1) -> None:
    """
    Increment a KPI counter in state.

    Args:
        state: Current state dictionary
        kpi_name: Name of KPI to increment (must exist in state.kpis)
        amount: Amount to increment by (default 1)

    Raises:
        KeyError: If KPI name doesn't exist
    """
    if kpi_name not in state['kpis']:
        raise KeyError(f"Unknown KPI: {kpi_name}. Valid KPIs: {list(state['kpis'].keys())}")

    state['kpis'][kpi_name] += amount


def decrement_kpi(state: Dict[str, Any], kpi_name: str, amount: int = 1) -> None:
    """
    Decrement a KPI counter in state.

    Args:
        state: Current state dictionary
        kpi_name: Name of KPI to decrement (must exist in state.kpis)
        amount: Amount to decrement by (default 1)

    Raises:
        KeyError: If KPI name doesn't exist
    """
    if kpi_name not in state['kpis']:
        raise KeyError(f"Unknown KPI: {kpi_name}. Valid KPIs: {list(state['kpis'].keys())}")

    state['kpis'][kpi_name] -= amount

    # Don't allow negative KPIs
    if state['kpis'][kpi_name] < 0:
        state['kpis'][kpi_name] = 0


def get_kpi_summary(state: Dict[str, Any]) -> str:
    """
    Get formatted KPI summary string.

    Args:
        state: Current state dictionary

    Returns:
        Formatted string with all KPIs
    """
    kpis = state['kpis']
    return f"""KPIs:
  Learnings loaded: {kpis['learnings_loaded']}
  Learnings applied: {kpis['learnings_applied']}
  Learnings captured: {kpis['learnings_captured']}
  Atomic steps: {kpis['atomic_steps_completed']}
  Debug files: {kpis['debug_files_created']} {'✓' if kpis['debug_files_created'] == 0 else '⚠️'}"""


def archive_state(session_id: str, current_path: str = '.noel/session-state.json') -> str:
    """
    Archive current session state to sessions directory.

    Args:
        session_id: Session ID to use in archive filename
        current_path: Path to current state file

    Returns:
        Path to archived state file
    """
    archive_dir = Path('.noel/sessions')
    archive_dir.mkdir(parents=True, exist_ok=True)

    archive_path = archive_dir / f"{session_id}.json"

    # Load current state
    state = load_state(current_path)

    # Save to archive location
    with open(archive_path, 'w') as f:
        json.dump(state, f, indent=2)

    return str(archive_path)


if __name__ == '__main__':
    # Test state utilities
    print("Testing state utilities...")

    # Load template
    template_path = Path(__file__).parent.parent / 'assets' / 'state-template.json'
    with open(template_path) as f:
        test_state = json.load(f)

    # Test operations
    test_state['metadata']['session_id'] = 'TEST-001'
    test_state['metadata']['created_at'] = datetime.utcnow().isoformat() + 'Z'

    update_progress(test_state, 'Test action', 'Test verification', 'success')
    increment_kpi(test_state, 'atomic_steps_completed')

    print("✓ update_progress works")
    print("✓ increment_kpi works")

    # Test save/load
    test_path = '/tmp/test-state.json'
    save_state(test_path, test_state)
    loaded = load_state(test_path)

    assert loaded['atomic_progress'][0]['action'] == 'Test action'
    assert loaded['kpis']['atomic_steps_completed'] == 1

    print("✓ save_state works")
    print("✓ load_state works")

    # Test KPI summary
    summary = get_kpi_summary(test_state)
    print("\nKPI Summary:")
    print(summary)

    # Cleanup
    os.remove(test_path)

    print("\n✓ All state utilities tests passed!")
