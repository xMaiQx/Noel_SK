# Project Registration Guide

**Date**: 2025-01-04
**Status**: ⚠️ **DESIGNED BUT NOT YET IMPLEMENTED**

---

## 🚧 Implementation Status

**Current State**:
- ✅ API contract designed (`specs/001-knowledge-repository/contracts/create-project.json`)
- ✅ Helper function ready (`noel-register-project` in `scripts/noel-helpers.sh`)
- ✅ Backfill script ready (`scripts/backfill-missing-projects.sh`)
- ❌ **n8n workflow NOT yet updated** - endpoint does not exist

**Before Using**:
You must first implement the `create_project` endpoint in the n8n workflow. See "n8n Implementation Guide" section below.

**Temporary Workaround**:
Manually create projects in Notion's Projects database until the endpoint is implemented.

---

## 🚨 Critical Issue Identified

**Problem**: The "lazy registration" approach for projects has FAILED.

**Impact**:
- Only **1 project** exists in the Projects database
- But **dozens of projects** are referenced in learnings
- Breaks referential integrity
- Analytics and project-based filtering are broken
- Learning counts per project are inaccurate

**Root Cause**: Learnings were captured without ensuring the project existed first.

---

## ✅ Solution: Explicit Project Registration

### Before This Fix (BROKEN)

```bash
# Old workflow - DO NOT USE
NOEL_PROJECT="MyProject"
noel-capture "$NOEL_PROJECT" "Learning title" "Content"  # ❌ Project might not exist!
```

### After This Fix (CORRECT)

```bash
# New workflow - USE THIS
NOEL_PROJECT="MyProject"

# 1. Register project FIRST (idempotent - safe to call multiple times)
noel-register-project "$NOEL_PROJECT"

# 2. THEN capture learnings
noel-capture "$NOEL_PROJECT" "Learning title" "Content"  # ✅ Project guaranteed to exist
```

---

## 📋 New Endpoint: `create_project`

### Purpose

Explicitly register a project in Notion's Projects database before capturing learnings.

### API Specification

**Endpoint**: `create_project`

**Request**:
```json
{
  "endpoint": "create_project",
  "name": "ProjectName",              // REQUIRED - Must match project used in learnings
  "description": "Project description", // Optional
  "status": "Active",                  // Optional (default: Active)
  "priority": "P2-Medium",             // Optional (default: P2-Medium)
  "tech_stack": ["Tech1", "Tech2"],   // Optional
  "repository_url": "https://...",    // Optional
  "started": "2025-01-04"              // Optional (default: today)
}
```

**Response**:
```json
{
  "success": true,
  "project_name": "ProjectName",
  "notion_page_id": "abc-123...",
  "message": "Project 'ProjectName' registered successfully"
}
```

**Note**: The endpoint is **idempotent** - calling it multiple times with the same project name returns success without creating duplicates.

---

## 🔧 Helper Function: `noel-register-project`

### Installation

The function is already included in `scripts/noel-helpers.sh`. Just source it:

```bash
source scripts/noel-helpers.sh
```

### Usage

**Minimal (auto-detects project from git repo or directory):**
```bash
noel-register-project
```

**With project name:**
```bash
noel-register-project "MyProject"
```

**With full metadata:**
```bash
noel-register-project "Insurance Platform" \
  --description "Multi-tenant insurance SaaS platform" \
  --priority "P1-High" \
  --tech-stack "React,Node.js,PostgreSQL,Redis" \
  --repo-url "https://github.com/company/insurance-platform" \
  --status "Active"
```

### Output

**First time (new project):**
```
Registering project: Insurance Platform...
✓ Project 'Insurance Platform' registered successfully
  → New project created in Notion Projects database
```

**Subsequent calls (idempotent):**
```
Registering project: Insurance Platform...
✓ Project 'Insurance Platform' already exists
  → Project was already registered (idempotent operation)
```

---

## 🔄 Updated Session Start Workflow

### Old Workflow (BROKEN)

```bash
# DON'T USE THIS ANYMORE
source ~/.claude/noel-quick.sh
noel-query "recent patterns"
noel-capture "MyProject" "..." "..."  # ❌ Project might not exist!
```

### New Workflow (CORRECT)

```bash
# 1. Load Noel helpers
source ~/.claude/noel-quick.sh

# 2. Register current project (MANDATORY - new step as of 2025-01-04)
noel-register-project

# 3. Query learnings
noel-query "recent patterns"

# 4. Capture learnings (project is guaranteed to exist)
noel-capture "MyProject" "..." "..."
```

---

## 🔨 Backfilling Missing Projects

If you already have learnings with unregistered projects, use the backfill script:

### Dry Run (see what would be registered)

```bash
./scripts/backfill-missing-projects.sh --dry-run
```

### Actual Backfill

```bash
./scripts/backfill-missing-projects.sh
```

### What It Does

1. Queries all learnings to find unique project names
2. Queries all registered projects
3. Finds the difference (projects in learnings but not in Projects database)
4. Registers each missing project with minimal metadata
5. Reports summary

### Example Output

```
╔═══════════════════════════════════════════════════════════════╗
║          Noel - Backfill Missing Projects Script             ║
╚═══════════════════════════════════════════════════════════════╝

Step 1: Querying all learnings to find unique project names...
✓ Found 47 unique projects in learnings

Step 2: Querying registered projects...
✓ Found 1 registered projects

Step 3: Finding missing projects...
⚠ Found 46 unregistered projects:

     1  Insurance-Platform
     2  Noel_SK
     3  MyReactApp
     ...

Step 4: Registering missing projects...

Registering: Insurance-Platform
  ✓ Project 'Insurance-Platform' registered successfully

Registering: Noel_SK
  ✓ Project 'Noel_SK' registered successfully

...

╔═══════════════════════════════════════════════════════════════╗
║                      Backfill Summary                         ║
╚═══════════════════════════════════════════════════════════════╝

  Total projects in learnings:    47
  Previously registered:          1
  Missing (to backfill):          46
  Successfully registered:        46
  Failed:                         0

✓ Backfill complete! All projects are now registered.
```

---

## 📚 Documentation Updates

All documentation has been updated to reflect the new mandatory project registration:

1. **Global CLAUDE.md** (`~/.claude/CLAUDE.md`):
   - New section: "PROJECT REGISTRATION - MANDATORY BEFORE CAPTURING LEARNINGS"
   - Updated "SESSION START CHECKLIST"

2. **Helper Scripts** (`scripts/noel-helpers.sh`):
   - New function: `noel-register-project`
   - Updated help text and examples

3. **Noel Domain Memory Skill** (`.claude/skills/noel-domain-memory/SKILL.md`):
   - Updated initialization sequence
   - Added project registration as step 4

4. **API Contracts** (`specs/001-knowledge-repository/contracts/`):
   - New contract: `create-project.json`

---

## ✅ Checklist for Users

- [ ] Update to latest `scripts/noel-helpers.sh`
- [ ] Update `~/.claude/CLAUDE.md` with new project registration section
- [ ] Run backfill script to register existing projects: `./scripts/backfill-missing-projects.sh`
- [ ] Add `noel-register-project` to session start workflow
- [ ] Update any automation/scripts to register projects before capturing learnings

---

## 🎯 Key Takeaways

1. **ALWAYS register projects BEFORE capturing learnings**
2. Use `noel-register-project` at the start of every session
3. The endpoint is idempotent - safe to call multiple times
4. Run backfill script once to fix existing data
5. Updated workflow prevents future referential integrity issues

---

## 📞 Questions?

If you encounter issues:

1. Check that `NOEL_WEBHOOK_URL` and `NOEL_AUTH_TOKEN` are set
2. Verify n8n workflow is running
3. Test endpoint directly:
   ```bash
   curl -s "$NOEL_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -H "Authorization: $NOEL_AUTH_TOKEN" \
     -d '{"endpoint":"list_projects","limit":10}'
   ```
4. Check `noel-help` for command reference

---

## 🔧 n8n Implementation Guide

When you're ready to implement the `create_project` endpoint in n8n:

### Step 1: Add Switch Case

In your main Noel n8n workflow, add a new case to the webhook router switch:

```javascript
// In the Switch node that routes based on endpoint field
case 'create_project':
  return 8;  // Route to create_project branch (adjust number as needed)
```

### Step 2: Create Project Creation Branch

Add these nodes in sequence:

1. **Validate Input** (Code node):
   ```javascript
   // Validate required field
   const data = $input.item.json;

   if (!data.name) {
     return {
       success: false,
       error: "Missing required field: name"
     };
   }

   return {
     name: data.name,
     description: data.description || "",
     status: data.status || "Active",
     priority: data.priority || "P2-Medium",
     tech_stack: data.tech_stack || [],
     repository_url: data.repository_url || "",
     started: data.started || new Date().toISOString().split('T')[0]
   };
   ```

2. **Check if Project Exists** (Notion node):
   - Operation: Query Database
   - Database: Projects
   - Filter: `Name equals {{$json.name}}`

3. **Branch on Exists** (IF node):
   - Condition: `{{$json.results.length}} > 0`

4. **Create Project** (Notion node - if NOT exists):
   - Operation: Create Page
   - Database: Projects
   - Properties:
     - Name: `{{$json.name}}`
     - Description: `{{$json.description}}`
     - Status: `{{$json.status}}`
     - Priority: `{{$json.priority}}`
     - Tech Stack: `{{$json.tech_stack}}`
     - Repository URL: `{{$json.repository_url}}`
     - Started: `{{$json.started}}`

5. **Format Response** (Code node):
   ```javascript
   const existed = $node["Branch on Exists"].json.results?.length > 0;
   const pageId = existed
     ? $node["Branch on Exists"].json.results[0].id
     : $json.id;

   return {
     success: true,
     project_name: $node["Validate Input"].json.name,
     notion_page_id: pageId,
     message: existed
       ? `Project '${$node["Validate Input"].json.name}' already exists`
       : `Project '${$node["Validate Input"].json.name}' registered successfully`
   };
   ```

### Step 3: Test the Endpoint

```bash
curl -s "$NOEL_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: $NOEL_AUTH_TOKEN" \
  -d '{
    "endpoint": "create_project",
    "name": "TestProject",
    "description": "Testing create_project endpoint"
  }'
```

Expected response:
```json
{
  "success": true,
  "project_name": "TestProject",
  "notion_page_id": "abc-123...",
  "message": "Project 'TestProject' registered successfully"
}
```

### Step 4: Run Backfill

Once the endpoint works:
```bash
./scripts/backfill-missing-projects.sh
```

---

## 📝 Temporary Workaround (Until Implemented)

### Manual Project Creation in Notion

1. Open Notion Projects database
2. Click "+ New" to create a page
3. Fill in properties:
   - **Name**: Exact project name used in learnings (e.g., "Noel_SK", "Insurance-Platform")
   - **Status**: Active
   - **Priority**: P2-Medium (or appropriate level)
   - **Started**: Today's date
   - **Description**: Brief description

4. Save the page

**Find projects to create manually**:
```bash
# Get unique project names from learnings
curl -s "$NOEL_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: $NOEL_AUTH_TOKEN" \
  -d '{"endpoint":"query_learnings","query":"all","limit":1000}' \
  | jq -r '.results[].metadata.project' | sort -u
```

Then create each one manually in Notion until the endpoint is implemented.

---

**Last Updated**: 2025-01-04
**Version**: 1.0.0 (Design phase - not yet implemented)
