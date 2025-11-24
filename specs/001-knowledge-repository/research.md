# Research: Noel Knowledge Repository System

**Feature**: 001-knowledge-repository
**Date**: 2025-11-20
**Phase**: 0 - Research & Design Decisions

## Overview

This document captures technology choices, architectural patterns, and implementation strategies for the Noel knowledge repository system. All design decisions documented here resolve the "NEEDS CLARIFICATION" markers from the technical context and provide rationale for chosen approaches.

## Technology Stack Decisions

### 1. Workflow Orchestration: n8n

**Decision**: Use n8n Community Edition for webhook orchestration and workflow automation

**Rationale**:
- Visual workflow builder reduces development time
- Built-in integrations for Notion, OpenAI, HTTP webhooks
- JavaScript code nodes for custom logic
- Free community edition supports all required features
- Easier to modify workflows without code deployment
- JSON export enables version control

**Alternatives Considered**:
- **Custom Node.js/Express API**: More flexible but slower development, requires deployment infrastructure
- **Zapier/Make.com**: Limited free tier, vendor lock-in, harder to version control
- **AWS Step Functions**: Overkill for single-user system, cost implications

**Implementation Notes**:
- Use webhook trigger nodes for all API endpoints
- Implement error handling with retry logic
- Store credentials securely in n8n credential manager
- Export workflows as JSON to repository for backup

### 2. Structured Storage: Notion

**Decision**: Use Notion databases (API v2022-06-28) for Projects, Learnings, and Sessions

**Rationale**:
- Native support for relational data (relations, rollups)
- Rich text formatting for learning content
- User-friendly UI for manual data review and editing
- Robust API with SDKs
- No additional database setup required
- Free personal plan supports unlimited databases

**Alternatives Considered**:
- **PostgreSQL/MySQL**: More powerful querying but requires hosting, no rich text UI
- **MongoDB**: Good for document storage but lacks relational features and UI
- **Airtable**: Similar to Notion but more expensive, less developer-friendly API

**Implementation Notes**:
- Create three databases: Projects, Learnings, Sessions
- Use relations for Projects ↔ Learnings, Sessions ↔ Learnings, Sessions ↔ Projects
- Use rollup properties for computed counts (learning_count, session_count)
- Implement rate limit handling (3 req/s with exponential backoff)
- Document all property types and formulas in data-model.md

### 3. Vector Search: Supabase with pgvector

**Decision**: Use Supabase PostgreSQL with pgvector extension for semantic search

**Rationale**:
- pgvector is production-ready PostgreSQL extension
- Supabase provides managed PostgreSQL with pgvector pre-installed
- Free tier supports 500MB database (enough for 5000+ learnings)
- Built-in authentication and RLS (if needed later)
- REST and JavaScript client APIs
- Cosine similarity search with indexing support

**Alternatives Considered**:
- **Pinecone**: Dedicated vector DB but limited free tier (1 index, 100k vectors)
- **Weaviate**: Powerful but requires self-hosting or paid cloud
- **Qdrant**: Good performance but requires Docker self-hosting
- **ChromaDB**: Simple but Python-only, harder to integrate with n8n

**Implementation Notes**:
- Use IVFFlat index for cosine similarity (good balance of speed/accuracy)
- Store 1536-dimension embeddings from text-embedding-3-small
- Include metadata (project, type, dev_stream, status) for filtering
- Index on learning_id for fast lookups
- Set up Row Level Security (RLS) policies for future multi-user support

### 4. AI Services: OpenAI API

**Decision**: Use OpenAI API for embeddings and AI enrichment

**Models Selected**:
- **text-embedding-3-small** (1536 dimensions): Cost-efficient, sufficient quality
- **gpt-4o-mini**: Fast and cheap for categorization/tagging tasks

**Rationale**:
- text-embedding-3-small: 5x cheaper than ada-002, better performance
- gpt-4o-mini: 80% cheaper than GPT-4 with good accuracy for structured tasks
- Wide adoption and stable APIs
- Easy integration with n8n OpenAI nodes

**Alternatives Considered**:
- **Cohere**: Good embeddings but less mature ecosystem
- **Anthropic (Claude)**: Expensive for embeddings, no native embedding endpoint
- **Open-source (Sentence Transformers)**: Requires self-hosting inference

**Cost Estimates** (per 1000 learnings):
- Embeddings: $0.013 (1000 learnings × 1000 tokens avg × $0.00002/1k tokens × 2 for queries)
- AI Enrichment: $0.60 (1000 learnings × 200 tokens × $0.000003/1k tokens)
- **Total**: ~$0.61 per 1000 learnings

### 5. Webhook Tunnel: ngrok

**Decision**: Use ngrok for exposing local n8n webhooks during development

**Rationale**:
- Simple setup (single command to start tunnel)
- Free tier supports HTTP tunnels
- Stable tunnel URLs (change on restart but predictable)
- No firewall configuration needed

**Alternatives Considered**:
- **Cloudflare Tunnel**: More stable URLs but more complex setup
- **serveo.sh**: Simple but less reliable uptime
- **localtunnel**: Similar to ngrok but less polished

**Production Alternative**:
- Deploy n8n to cloud (Railway, Render, DigitalOcean) with public domain
- Use custom domain with SSL for stable webhook URLs

## Architectural Patterns

### 1. Webhook Endpoint Design

**Pattern**: Single n8n workflow with multiple webhook triggers

**Structure**:
```
Webhook Trigger (POST /capture_learning)
  → Validate Input
  → Generate Learning ID
  → AI Enrichment (parallel)
  → Store in Notion
  → Generate Embedding
  → Store in Supabase
  → Return Response

Webhook Trigger (POST /query_learnings)
  → Validate Input
  → Generate Query Embedding
  → Supabase Similarity Search
  → Fetch Notion Details
  → Format Response
  → Return Results
```

**Benefits**:
- Single workflow easier to manage than multiple
- Shared helper functions reduce duplication
- Visual flow makes debugging easier
- Can test individual branches independently

### 2. Learning ID Generation

**Pattern**: `PROJECT_PREFIX-###` format with Notion-based sequence tracking

**Algorithm**:
```javascript
function generateLearningID(projectName, notionAPI) {
  // 1. Extract prefix from project name
  const prefix = extractPrefix(projectName); // "Briseno" → "BR"

  // 2. Query Notion for learnings with this prefix
  const existingLearnings = queryNotionByPrefix(prefix);

  // 3. Find highest number
  const maxNum = existingLearnings
    .map(l => parseInt(l.learning_id.split('-')[1]))
    .reduce((max, n) => Math.max(max, n), 0);

  // 4. Return next ID with zero-padding
  return `${prefix}-${String(maxNum + 1).padStart(3, '0')}`;
}
```

**Prefix Extraction Rules**:
- Single word: First 2-4 consonants (Noel → NL, Briseno → BR)
- Multi-word: First letter of each word (Claude Code → CC)
- All caps: Use as-is (API → API)

**Collision Handling**:
- Extremely unlikely with timestamp appended if needed
- Manual correction possible via Notion UI

### 3. AI Enrichment Prompt

**Prompt Template**:
```
You are a learning categorization system. Analyze the following development learning and suggest metadata.

Learning Content:
"""
{content}
"""

Context:
"""
{context}
"""

Your task:
1. Suggest 1-3 dev streams from: Back-end, Front-end, UI/UX, n8n, Database, API, DevOps, Architecture, Performance, Security
2. Confirm or suggest learning type from: Pattern, Solution, Error, Decision, Insight, Anti-Pattern, Best Practice
3. Extract 3-5 relevant tags (technologies, patterns, concepts)

Respond in JSON format:
{
  "dev_streams": ["stream1", "stream2"],
  "type": "suggested type",
  "tags": ["tag1", "tag2", "tag3"],
  "confidence": "high|medium|low"
}
```

**Response Handling**:
- Parse JSON response
- Merge with user-provided metadata (don't override, append)
- Store AI confidence in metadata for quality tracking

### 4. Vector Similarity Search

**Algorithm**:
```sql
-- Generate query embedding (via OpenAI API)
-- Then execute similarity search

SELECT
  learning_id,
  content,
  metadata,
  1 - (embedding <=> $query_embedding) as similarity_score
FROM learnings_vectors
WHERE
  -- Apply metadata filters
  (metadata->>'status' != 'Deprecated' OR $include_deprecated)
  AND ($project_filter IS NULL OR metadata->>'project' = $project_filter)
  AND ($dev_stream_filter IS NULL OR metadata->'dev_streams' ? $dev_stream_filter)
ORDER BY embedding <=> $query_embedding
LIMIT 10;
```

**Key Optimizations**:
- Use cosine distance operator `<=>` for speed
- IVFFlat index reduces search time
- Metadata filters applied post-similarity (more flexible)
- Return top 10 only (balance relevance vs choice)

### 5. Session Tracking Integration

**Recording Script Integration**:
```bash
# User starts session (manually or via alias)
record-claude noel

# Script flow:
1. Start asciinema recording → ~/coding-sessions/[timestamp]-claude-noel.cast
2. POST to /create_session with:
   {
     "projects": ["Noel"],
     "goals": "Implement session tracking",
     "recording_file_path": "~/coding-sessions/[timestamp]-claude-noel.cast",
     "ai_type": "Claude"
   }
3. Receive session_id → store in shell environment
4. All learning captures include session_id
5. On exit, POST to /end_session with session_id
```

**Recording File Management**:
- System stores path only (not file content)
- User responsible for file retention and access
- Consider periodic backups to cloud storage (Dropbox, Google Drive)
- Document path conventions in quickstart guide

## Data Validation Rules

### Learning Capture
- **Required**: project, title, content
- **Optional**: type, dev_stream, context, tags, confidence, session_id
- **Validation**:
  - project: non-empty string
  - title: 5-200 characters
  - content: 10-50,000 characters
  - type: enum (Pattern|Solution|Error|Decision|Insight|Anti-Pattern|Best Practice)
  - dev_stream: array of enum (Back-end|Front-end|UI/UX|n8n|Database|API|DevOps|Architecture|Performance|Security)
  - confidence: enum (High|Medium|Low)

### Session Creation
- **Required**: projects (array), goals
- **Optional**: recording_file_path, ai_type
- **Validation**:
  - projects: non-empty array of strings
  - goals: 10-1000 characters
  - ai_type: enum (Claude|Gemini|Other)

### Query Learnings
- **Required**: query (natural language)
- **Optional**: filters (project, dev_stream, type, tags, confidence, status)
- **Validation**:
  - query: 3-500 characters
  - filters: all enum values validated

## Error Handling Strategy

### HTTP Status Codes
- **200**: Success (includes empty query results)
- **400**: Bad request (validation failed, malformed JSON)
- **401**: Unauthorized (invalid API key if implemented)
- **429**: Rate limit exceeded (Notion API limit hit)
- **500**: Internal error (API failures, database errors)

### Retry Logic
- **Transient errors**: Retry up to 3 times with exponential backoff
  - Notion API rate limits
  - Supabase connection errors
  - OpenAI API timeouts
- **Permanent errors**: Fail immediately with clear error message
  - Invalid input data
  - Missing required fields
  - Authentication failures

### Partial Failures
- **Scenario**: Learning stored in Notion but embedding generation fails
- **Handling**: Mark learning for background retry, return success to user
- **Recovery**: Periodic job scans for learnings missing embeddings

## Performance Optimizations

### 1. Caching Strategy
- **Query Embeddings**: Cache for 5 minutes (same query likely repeated)
- **Project Metadata**: Cache for 1 hour (changes infrequently)
- **AI Enrichment**: Don't cache (each learning unique)

### 2. Batch Operations
- **Future Enhancement**: Batch learning captures (capture 5-10 at once)
- **Benefit**: Reduce API calls, lower costs
- **Implementation**: Collect learnings in array, batch embed, batch store

### 3. Index Tuning
- **Supabase**: IVFFlat index with lists parameter tuned based on data size
  - <1000 vectors: lists = 10
  - 1000-10000 vectors: lists = 100
  - >10000 vectors: lists = 1000

## Security Considerations

### 1. API Authentication
- **v1 (MVP)**: Ngrok URL obscurity (no public links shared)
- **v2 (Production)**: API key in header (`X-API-Key`)
- **Future**: OAuth2 for team sharing

### 2. Credential Management
- **n8n Credentials Store**: All API keys (Notion, Supabase, OpenAI)
- **Never**: Hardcode keys in workflows or JavaScript functions
- **Environment Variables**: For local testing outside n8n

### 3. Data Privacy
- **Learning Content**: May contain sensitive code snippets
- **Access Control**: Currently single-user, no RLS policies needed
- **Future**: Implement Supabase RLS for team workspaces

## Testing Strategy

### 1. Manual Testing
- **Tools**: curl, Postman, or custom bash scripts
- **Test Cases**:
  - Capture learning with minimal fields
  - Capture learning with all fields
  - Query learnings by natural language
  - Query learnings with filters
  - Create and end session
  - Error scenarios (missing fields, invalid data)

### 2. Integration Testing
- **Real Usage**: Capture learnings during actual development sessions
- **Validation**: Verify data in Notion, test search relevance
- **Session Replay**: Test asciinema playback of recordings

### 3. Load Testing (Future)
- **Concurrent Captures**: 10+ simultaneous learning captures
- **Large Queries**: Search across 1000+ learnings
- **Measure**: Response times, error rates, API costs

## Migration Strategy

### Initial Data Seeding
- **Briseno Learnings**: Manual export from existing documentation
- **Process**: Convert markdown notes to learning objects, POST to capture endpoint
- **Script**: Create `scripts/seed-briseno-learnings.sh` for automation

### Future Migrations
- **Schema Changes**: Add new Notion properties, backfill with defaults
- **Embedding Model Upgrades**: Re-generate all embeddings (batch job)
- **Data Cleanup**: Periodic review for deprecated learnings, session cleanup

## Open Questions & Future Enhancements

### Potential Additions (Out of v1 Scope)
1. **Telegram Bot**: Quick capture from mobile via Telegram commands
2. **Learning Templates**: Structured formats for common learning types
3. **Cross-Project Insights**: AI-generated connections between learnings
4. **Learning Graphs**: Visual knowledge map showing relationships
5. **Export Functionality**: Generate PDF or markdown reports
6. **Version History**: Track learning edits over time
7. **Team Collaboration**: Share learnings, comments, reactions

### Research Needed for v2
- **Advanced RAG**: Re-ranking, hybrid search (vector + keyword)
- **Learning Quality Scores**: ML model to assess learning value
- **Auto-Tagging**: Improve AI categorization with feedback loop
- **Session Analytics**: Time tracking, productivity metrics

## References

### Documentation
- [Notion API Reference](https://developers.notion.com/reference)
- [Supabase pgvector Guide](https://supabase.com/docs/guides/ai/vector-embeddings)
- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings)
- [n8n Documentation](https://docs.n8n.io/)
- [asciinema Format Spec](https://github.com/asciinema/asciinema/blob/develop/doc/asciicast-v2.md)

### Best Practices
- [RAG Best Practices (OpenAI)](https://platform.openai.com/docs/guides/embeddings/use-cases)
- [Notion Database Design Patterns](https://www.notion.so/help/guides/database-design)
- [pgvector Performance Tuning](https://github.com/pgvector/pgvector#performance)

## Conclusion

All technical decisions documented in this research phase resolve uncertainties from the technical context. The chosen stack (n8n + Notion + Supabase + OpenAI) balances ease of development, cost efficiency, and functionality. Ready to proceed to Phase 1: Data Models & Contracts.
