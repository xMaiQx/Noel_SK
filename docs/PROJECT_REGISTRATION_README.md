# Project Registration - What Your Friend Needs to Know

**TL;DR**: We designed a solution but **haven't implemented it in n8n yet**. For now, manually create projects in Notion.

---

## 🎯 The Problem We Found

Only **1 project** exists in Notion's Projects database, but learnings reference **47+ different projects**. This breaks:
- Project-based filtering
- Learning counts per project
- Analytics and reporting

## ✅ What We Designed (But Haven't Built Yet)

We created:
- ✅ API contract for `create_project` endpoint
- ✅ Helper function `noel-register-project`
- ✅ Backfill script to register missing projects
- ✅ Full documentation

**But we DID NOT**:
- ❌ Implement the `create_project` endpoint in n8n workflow
- ❌ Test it with real API calls

**Bottom line**: The code is ready, but the n8n workflow doesn't have this endpoint yet.

---

## 🛠️ What to Do Right Now

### Option 1: Manual Creation (Recommended for Now)

**Step 1**: Find which projects need to be created

```bash
# Get all unique project names from learnings
curl -s "$NOEL_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: $NOEL_AUTH_TOKEN" \
  -d '{"endpoint":"query_learnings","query":"all","limit":1000}' \
  | jq -r '.results[].metadata.project' | sort -u
```

**Step 2**: Manually create each one in Notion

1. Open your Notion Projects database
2. Click "+ New" page
3. Fill in:
   - **Name**: Copy exact project name from step 1 (e.g., "Noel_SK", "Insurance-Platform")
   - **Status**: Active
   - **Priority**: P2-Medium
   - **Started**: Today's date
4. Save
5. Repeat for each project

Yes, it's tedious. But it only takes ~1 minute per project and you only do it once.

### Option 2: Wait for n8n Implementation

If you want to implement the endpoint first:

1. Read the n8n implementation guide in `docs/PROJECT_REGISTRATION_GUIDE.md`
2. Add the `create_project` case to your n8n workflow router
3. Build the project creation branch (5 nodes)
4. Test it with curl
5. Run the backfill script to auto-register all missing projects

This takes ~30 minutes to implement but then you can use `noel-register-project` forever.

---

## 🚀 Future Workflow (Once Implemented)

After you implement the endpoint, the workflow becomes:

```bash
# Load helpers
source ~/.claude/noel-quick.sh

# Register project (NEW - one command)
noel-register-project

# Query learnings
noel-q "recent patterns"

# Capture learnings (project guaranteed to exist)
noel-capture "MyProject" "..." "..."
```

The `noel-register-project` command:
- Auto-detects project from git repo or directory
- Calls the `create_project` endpoint
- Idempotent - safe to run every session
- Takes 1 second

---

## 📝 Summary for Your Friend

**Right now:**
- "The project registration endpoint doesn't exist yet in n8n"
- "You need to manually create projects in Notion or implement the endpoint first"
- "Run the curl command above to see which projects are missing"
- "Create them one by one in Notion (takes ~1 min each)"

**After n8n implementation:**
- "Just run `noel-register-project` at the start of every session"
- "Everything else works automatically"

**Documentation:**
- Full guide: `docs/PROJECT_REGISTRATION_GUIDE.md`
- n8n implementation steps included
- Helper function already written and ready to use

---

**Questions?**
- Implementation guide: `docs/PROJECT_REGISTRATION_GUIDE.md` (section: "n8n Implementation Guide")
- Helper function: Already in `scripts/noel-helpers.sh`
- API contract: `specs/001-knowledge-repository/contracts/create-project.json`
