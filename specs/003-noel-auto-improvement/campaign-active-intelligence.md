# Campaign: Noel Active Intelligence

> Transform Noel from passive knowledge store to active, multi-channel, self-improving companion.

## Campaign Record

| Field | Value |
|-------|-------|
| **Campaign ID** | `ff800b3d-32c3-441b-b40f-ed4e933baeed` |
| **Status** | Active |
| **Project** | Noel (`5f0db558-55bf-4452-947f-2d90f15dfcc1`) |
| **Success Criteria** | Evaluator runs weekly, proactive memory surfaces context, Telegram capture/query works |

## Three Missions

All three launch simultaneously (no blocking dependencies between them).

### Mission 1: Build Cron-Driven Skill Evaluator

| Field | Value |
|-------|-------|
| **Mission ID** | `f44a03d7-1bda-4476-9204-f85db68ac410` |
| **Template ID** | `55873a90-c532-4910-81f9-436dd18411c5` |
| **Category** | noel-infrastructure |
| **Tags** | auto-improvement, effectiveness, cron, n8n, supabase, notion |

**Objective**: Auto-improvement engine with weekly evaluation of learning effectiveness, AI-generated improvement proposals, user approval flow, and regression tracking.

**Team**:
- **DB Architect** (Team Leader): Creates Evaluations Notion DB + `evaluation_cycles` Supabase table
- **n8n Workflow Builder** (Specialist): Builds evaluation cron + approval webhook branches
- **Regression Tracker** (Specialist): Post-approval monitoring + bash helpers

**API Contracts**:

| Endpoint | Input | Output |
|----------|-------|--------|
| `run_evaluation` | `{scope, min_usage, improvement_threshold, unproven_age_days}` | `{cycle_id, learnings_evaluated, proposals_generated, categories}` |
| `list_proposals` | `{status, project?}` | Array of proposals |
| `approve_proposal` | `{evaluation_id, reason?}` | `{success, learning_updated, vector_regenerated}` |
| `reject_proposal` | `{evaluation_id, reason?}` | `{success, status:"rejected"}` |

**Supabase Table**: `evaluation_cycles` (created via migration `create_evaluation_cycles_table`)

**Bash Helpers** (in `scripts/noel-helpers.sh`):
- `noel-evaluate` - Trigger evaluation cycle
- `noel-proposals` - List pending proposals
- `noel-approve EVAL-ID [reason]` - Approve proposal
- `noel-reject EVAL-ID [reason]` - Reject proposal

**Success Criteria**:
1. `run_evaluation` returns cycle_id with categorized learnings
2. Proposals appear in Evaluations Notion DB with diagnosis + diff
3. `approve_proposal` updates learning in Notion + regenerates vector
4. `reject_proposal` stores reason and updates status
5. Cron fires on schedule (test with 1-min interval first)
6. Post-approval tracking detects regressions after 2 weeks
7. Bash helpers work end-to-end

---

### Mission 2: Build Proactive Memory System

| Field | Value |
|-------|-------|
| **Mission ID** | `a4faa3ee-dff5-4ffd-ae17-4af78d0fae0a` |
| **Template ID** | `bba64d41-2add-4319-97a3-e5eb8caba9dd` |
| **Category** | noel-infrastructure |
| **Tags** | proactive, context, hooks, git, re-ranking, claude-code |

**Objective**: Transform Noel from reactive to proactive with smart session init, event-triggered surfacing, and context-aware re-ranking.

**Team**:
- **Context Analyst** (Team Leader): Designs keyword extraction + Supabase schema
- **Hook Developer** (Specialist): Smart session init + Claude Code event hooks
- **n8n Re-Ranker** (Specialist): Context-aware re-ranking in query_learnings

**New Endpoints**:

| Endpoint | Input | Output |
|----------|-------|--------|
| `log_context_signal` | `{session_id, signal_type, signal_data, extracted_keywords, query_generated}` | `{success, signal_id}` |
| `query_learnings` (extended) | existing + optional `context: {branch, recent_files, recent_technologies}` | Results with `boost_applied` field |

**Supabase Tables** (created via migration `create_context_signals_tables`):
- `context_signals` - Logs signal events with keywords
- `session_context` - Accumulated context per session

**Scripts**:
- `scripts/noel-context-init.sh` - Smart context extraction (`extract_git_context`, `smart_query`, `log_context_signal`)
- `~/.claude/noel-quick.sh` updated with `noel-smart` command and auto-load of context init

**Success Criteria**:
1. Session on branch `feature/auth-refresh` auto-surfaces auth learnings
2. Bare directory gracefully falls back to project + recent patterns
3. Smart init results more relevant than baseline `noel-q recent`
4. Test failure auto-queries for relevant error-fixing learnings
5. New file creation auto-queries for patterns
6. No-match events stay silent (no noise)
7. Query with context re-ranks auth results higher on auth branch
8. `context_signals` table logs signals with keywords

---

### Mission 3: Build Multi-Channel Gateway

| Field | Value |
|-------|-------|
| **Mission ID** | `65c00507-9b5a-4b18-af7b-0e4cab8b9cb3` |
| **Template ID** | `61d1ac98-5e16-4d93-92b8-a3c3834b1c1a` |
| **Category** | noel-infrastructure |
| **Tags** | telegram, slack, multi-channel, mobile, n8n, bot |

**Objective**: Capture and query Noel from Telegram (mobile) and Slack (team) via n8n native channel nodes.

**Team**:
- **Bot Architect** (Team Leader): Telegram bot setup + security + channel_configs table
- **n8n Gateway Builder** (Specialist): Telegram command routing workflow
- **Channel Metadata Extender** (Specialist): Add source_channel tracking to all captures

**Telegram Bot Commands**:
- `/capture Title | Content` - Capture learning
- `/query search terms` - Search learnings
- `/status` - System stats
- `/help` - Command reference
- `/projects` - List active projects

**Supabase Table**: `channel_configs` (created via migration `create_channel_configs_table`)

**Success Criteria**:
1. `/help` returns command list with formats
2. `/capture Test | Content` creates learning with `source_channel='telegram'`
3. `/query test capture` returns the just-captured learning
4. `/status` shows correct total learnings and active projects
5. `/projects` lists active projects with counts
6. Malformed `/capture` returns usage instructions (not error)
7. `/query` with no results returns friendly message
8. Unauthorized chat_id gets blocked

---

## Dependency Matrix

```
Mission 1 (Evaluator)  ──── independent ────  Mission 2 (Proactive Memory)
       │                                                │
       │  Benefits from 2's context signals             │  Benefits from 1's effectiveness
       │                                                │  data for smarter re-ranking
       └──────────── both independent of ───────────────┘
                              │
                    Mission 3 (Multi-Channel)
                    More captures → more data for 1 + 2

All three launch simultaneously.
```

## Inter-Session Coordination

Sessions communicate via Noel captures:
```bash
noel-c "TEAM: [Feature] - [Subject]" "WHY/WHAT/HOW"
```
Check updates with:
```bash
noel-q "TEAM feature development"
```

## Database Migrations Applied

| Migration | Table | Purpose |
|-----------|-------|---------|
| `create_campaigns_table` | `campaigns` + `missions.campaign_id` | Campaign hierarchy |
| `create_evaluation_cycles_table` | `evaluation_cycles` | Evaluator tracking |
| `create_context_signals_tables` | `context_signals`, `session_context` | Proactive memory analytics |
| `create_channel_configs_table` | `channel_configs` | Multi-channel configuration |

## Verification (End-to-End)

After all three missions complete:
1. `/capture` via Telegram -> learning in Notion with `source_channel: "telegram"`
2. Start Claude Code session -> proactive memory surfaces the Telegram-captured learning
3. Weekly evaluation fires -> learning gets evaluated
4. Evaluator proposes improvement -> approve -> learning updates + vector regenerates
5. Query improved learning via CLI and Telegram -> consistent results
