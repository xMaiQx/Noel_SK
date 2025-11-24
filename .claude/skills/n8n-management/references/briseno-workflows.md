# Briseno Workflows Reference

This document catalogs the n8n workflows that comprise the Briseno productivity coach system.

## Core Workflow: Briseno_ProductivityCoach_v2

**Purpose**: Main agent providing productivity coaching via Telegram

**Key Components:**
- **Trigger**: Telegram (handles text, voice, images)
- **Input Processing**:
  - Text: Direct pass-through
  - Voice: Downloads → Transcribes (OpenAI Whisper)
  - Image: Downloads → Analyzes (GPT-4o-mini for social media scraping)
- **LLM**: GPT-4o
- **Memory**: PostgreSQL chat history (session-based by chat ID)
- **Vector Store**: Supabase with OpenAI embeddings + Cohere reranker
  - Tool description: "Analizar las ideas en el repositorio del usuario"
- **Output**: Telegram response

**System Prompt**:
> "You are a helpful assistant, your goal is to analyze the tasks or requests of the user and help logging in the task in the appropriate user's projects and tasks for follow up."

## Observability: Log_Agent_Outputs

**Purpose**: Track agent usage, token consumption, and costs

**Key Components:**
- **LLM**: GPT-4.1-mini via OpenRouter
- **Tools**: Send Email, Get Contacts (Airtable), Create Event (Google Calendar)
- **Logging**:
  - Success path: Logs to Google Sheets (Timestamp, Workflow, Input, Output, Actions, Tokens, Total Cost)
  - Error path: Separate error logging with error message
  - Custom JS code extracts token usage and calculates costs
- **Output**: Telegram response (success or error message)

**Note**: This pattern should be integrated into future Briseno implementations for cost tracking.

## Multi-Agent Architecture: __Personal_Assistant_AI_Agent_2_0

**Purpose**: Coordinator pattern demonstrating multi-agent delegation

**Architecture:**
- **Main Agent**: Orchestrates specialized sub-agents
- **LLM**: GPT-4o
- **Direct Tools**:
  - Send Slack Message
  - Contacts Data (Google Sheets)
  - Knowledge Base (Pinecone vector store)
  - Calculator
- **Sub-Agent Tools** (via toolWorkflow):
  - Calendar Agent
  - Email Agent
  - Projects Agent
  - Research Agent

**Pattern**: Each sub-agent returns structured response on success/error paths.

## Specialized Agents

### __Calendar_Agent

**Trigger**: Execute Workflow Trigger (called by parent)
**LLM**: GPT-4o
**Tools**:
- Create Event (assumes 60 min if no end time)
- Create Event with Attendee
- Get Events (with time range filters)
**Error Handling**: Success/Try Again paths

### __Email_Agent

**Trigger**: Execute Workflow Trigger
**LLM**: GPT-4o
**Tools**:
- Send Email (Gmail) - auto-signs messages
- Get Messages (with sender filter, default 5 emails)
**Error Handling**: Success/Try Again paths

### __Projects_Agent

**Trigger**: Execute Workflow Trigger
**LLM**: GPT-4o
**Tools**:
- Get Projects (Google Sheets)
- Update Projects (fields: Project, Notes, Status)
**Error Handling**: Success/Try Again paths

### __Research_Agent

**Trigger**: Execute Workflow Trigger
**LLM**: GPT-4o
**Tools**:
- Wikipedia
- Hacker News API
- SerpAPI (Google Search)
**Strategy**: Sequential fallback (Wikipedia → Hacker News → SerpAPI)
**Error Handling**: Success/Try Again paths

## Tech Stack Summary

**Platform**: n8n workflow automation

**Communication**: Telegram (primary interface)

**LLMs**:
- OpenAI (GPT-4o, GPT-4o-mini)
- OpenRouter (GPT-4.1-mini)

**Memory & Storage**:
- PostgreSQL (chat history)
- Supabase (vector store)
- Pinecone (vector store)
- Google Sheets (structured data)
- Airtable (contacts)

**Embeddings & Search**:
- OpenAI text-embedding-3-small
- Cohere reranker (multilingual-v3.0)

**Integrations**:
- Gmail
- Google Calendar
- Slack
- Wikipedia
- Hacker News
- SerpAPI

## Patterns for Future Development

### 1. Multi-Modal Input Processing
- Voice transcription via Whisper
- Image analysis for social media content extraction
- Text handling

### 2. Multi-Agent Coordination
- Parent agent delegates to specialized child agents
- Child agents exposed as tools via toolWorkflow
- Standardized success/error response pattern

### 3. Cost & Usage Tracking
- Log intermediate steps, tokens, and costs
- Store in Google Sheets for analysis
- Track per-workflow and per-request costs

### 4. Memory Management
- Session-based chat history (keyed by user/chat ID)
- Vector stores for knowledge retrieval
- RAG pattern with reranking

## Next Steps for Briseno Development

Based on current architecture:

1. **Notion Integration**: Add Notion as data backend for tasks/goals/projects
2. **Enhanced Memory**: Expand vector store with user goals, preferences, patterns
3. **Proactive Coaching**: Add triggers for reminders, suggestions, check-ins
4. **Multi-Agent Evolution**: Adapt specialized agents for Briseno use cases
5. **Cost Optimization**: Integrate logging pattern into main Briseno workflow

## Updating This Document

As new workflows are created or discovered:
1. Add workflow name and purpose
2. Document key components (trigger, LLM, tools)
3. Note any unique patterns or learnings
4. Update tech stack if new integrations are added
