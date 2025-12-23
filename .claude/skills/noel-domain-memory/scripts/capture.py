#!/usr/bin/env python3
"""
Learning capture wrapper for Noel domain memory.

Wraps the noel-capture bash function with state management integration.
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional


# Import state utilities
from state import load_state, save_state, increment_kpi


def capture_learning(
    project: str,
    title: str,
    content: str,
    learning_type: Optional[str] = None,
    confidence: Optional[str] = None,
    update_state: bool = True
) -> Optional[str]:
    """
    Capture a learning to Noel and optionally update session state.

    Args:
        project: Project name (typically "Noel")
        title: Learning title
        content: Learning content/description
        learning_type: Optional type (Pattern, Solution, Error, etc.)
        confidence: Optional confidence (High, Medium, Low)
        update_state: Whether to update session state KPIs

    Returns:
        Learning ID if successful, None if failed
    """
    # Build command
    cmd = [
        'bash', '-c',
        f'source /Users/murodos/Documents/_Mad_Panda_/Proyectos/Noel_SK/scripts/noel-helpers.sh && '
        f'noel-capture "{project}" "{title}" "{content}"'
    ]

    if learning_type:
        cmd[-1] += f' "{learning_type}"'
    if confidence:
        cmd[-1] += f' "{confidence}"'

    # Execute
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode != 0:
            print(f"Error capturing learning: {result.stderr}", file=sys.stderr)
            return None

        # Parse learning ID from output
        # noel-capture outputs: "✓ Learning captured: NOEL-XXX"
        learning_id = None
        for line in result.stdout.split('\n'):
            if 'Learning captured:' in line:
                parts = line.split(':')
                if len(parts) >= 2:
                    learning_id = parts[-1].strip()
                    break

        if not learning_id:
            # Try parsing JSON response
            try:
                # Find JSON in output (after ANSI codes)
                json_start = result.stdout.find('{')
                if json_start >= 0:
                    response = json.loads(result.stdout[json_start:])
                    learning_id = response.get('learning_id')
            except json.JSONDecodeError:
                pass

        if learning_id and update_state:
            # Update session state
            try:
                state = load_state()
                increment_kpi(state, 'learnings_captured')
                save_state('.noel/session-state.json', state)
            except FileNotFoundError:
                # State file doesn't exist yet, skip update
                pass

        return learning_id

    except subprocess.TimeoutExpired:
        print("Error: Capture timed out", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return None


def capture_with_session(
    project: str,
    title: str,
    content: str,
    learning_type: Optional[str] = None,
    confidence: Optional[str] = None
) -> Optional[str]:
    """
    Capture learning with automatic session ID from environment.

    Args:
        project: Project name
        title: Learning title
        content: Learning content
        learning_type: Optional type
        confidence: Optional confidence

    Returns:
        Learning ID if successful, None if failed
    """
    # Session ID should be in environment (set by noel-start-session or init.py)
    session_id = os.getenv('CURRENT_SESSION_ID')

    if not session_id:
        print("Warning: CURRENT_SESSION_ID not set. Learning won't be linked to session.", file=sys.stderr)

    # The bash helper noel-capture automatically includes CURRENT_SESSION_ID from env
    return capture_learning(project, title, content, learning_type, confidence, update_state=True)


def main():
    """CLI interface for capture script."""
    if len(sys.argv) < 4:
        print("Usage: capture.py <project> <title> <content> [type] [confidence]")
        print("\nExample:")
        print('  capture.py "Noel" "Pattern name" "Pattern description" "Pattern" "High"')
        sys.exit(1)

    project = sys.argv[1]
    title = sys.argv[2]
    content = sys.argv[3]
    learning_type = sys.argv[4] if len(sys.argv) > 4 else None
    confidence = sys.argv[5] if len(sys.argv) > 5 else None

    learning_id = capture_with_session(project, title, content, learning_type, confidence)

    if learning_id:
        print(f"✓ Captured: {learning_id}")
        sys.exit(0)
    else:
        print("✗ Capture failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
