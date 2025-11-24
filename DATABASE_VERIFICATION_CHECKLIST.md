# Notion Database Verification Checklist

Use this checklist to verify your Notion databases match the specification in `data-model.md`.

**Your Database IDs**:
- Projects: `2b23d603-acb6-80da-a7e4-eec141600a49`
- Learnings: `2b23d603-acb6-8048-bb0d-cde2ff691943`
- Sessions: `2b43d603-acb6-8015-80a8-fbccc06246b6`

---

## Projects Database Verification

**Database Name**: Should be "Projects" or similar

### Required Properties (10 total)

Check each property exists with the correct type:

- [ ] **Name** (Title) - Project name
- [ ] **Status** (Select) - Options: Active, On Hold, Planning, Completed, Archived
- [ ] **Priority** (Select) - Options: P0-Critical, P1-High, P2-Medium, P3-Low
- [ ] **Tech Stack** (Multi-select) - Tags for technologies
- [ ] **Description** (Rich Text) - Project overview
- [ ] **Started** (Date) - Project start date
- [ ] **Last Activity** (Date) - Most recent learning timestamp
- [ ] **Learning Count** (Rollup)
  - Related to: Learnings database
  - Property: Title
  - Calculate: Count
- [ ] **Session Count** (Rollup)
  - Related to: Sessions database
  - Property: Session ID (or any property)
  - Calculate: Count
- [ ] **Total Session Hours** (Rollup)
  - Related to: Sessions database
  - Property: Duration
  - Calculate: Sum

### Status Select Options

Verify these exact values exist:
- [ ] Active
- [ ] On Hold
- [ ] Planning
- [ ] Completed
- [ ] Archived

### Priority Select Options

Verify these exact values exist:
- [ ] P0-Critical
- [ ] P1-High
- [ ] P2-Medium
- [ ] P3-Low

---

## Learnings Database Verification

**Database Name**: Should be "Learnings" or similar

### Required Properties (14 total)

Check each property exists with the correct type:

- [ ] **Title** (Title) - Short descriptive title
- [ ] **Learning ID** (Rich Text) - Unique ID in format PROJECT-###
- [ ] **Project** (Relation)
  - To database: Projects
  - Show on Projects as: Learnings (or auto-named)
- [ ] **Type** (Select) - Options: Pattern, Solution, Error, Decision, Insight, Anti-Pattern, Best Practice
- [ ] **Dev Stream** (Multi-select) - Options: Back-end, Front-end, UI/UX, n8n, Database, API, DevOps, Architecture, Performance, Security
- [ ] **Content** (Rich Text) - Full learning content
- [ ] **Context** (Rich Text) - How learning was discovered
- [ ] **Tags** (Multi-select) - Dynamic tags for filtering
- [ ] **Related Files** (Rich Text) - File paths or references
- [ ] **Confidence** (Select) - Options: High, Medium, Low
- [ ] **Status** (Select) - Options: Validated, Hypothesis, Deprecated
- [ ] **Timestamp** (Date) - Creation timestamp (include time: Yes)
- [ ] **Last Modified** (Date) - Last edit timestamp (include time: Yes)
- [ ] **Session** (Relation)
  - To database: Sessions
  - Allow empty: Yes
- [ ] **AI Suggested** (Checkbox) - Metadata was AI-generated
- [ ] **AI Accepted** (Checkbox) - User accepted AI suggestions

### Type Select Options

Verify these exact values exist:
- [ ] Pattern
- [ ] Solution
- [ ] Error
- [ ] Decision
- [ ] Insight
- [ ] Anti-Pattern
- [ ] Best Practice

### Dev Stream Multi-select Options

Verify these exact values exist:
- [ ] Back-end
- [ ] Front-end
- [ ] UI/UX
- [ ] n8n
- [ ] Database
- [ ] API
- [ ] DevOps
- [ ] Architecture
- [ ] Performance
- [ ] Security

### Confidence Select Options

Verify these exact values exist:
- [ ] High
- [ ] Medium
- [ ] Low

### Status Select Options

Verify these exact values exist:
- [ ] Validated
- [ ] Hypothesis
- [ ] Deprecated

---

## Sessions Database Verification

**Database Name**: Should be "Sessions" or similar

### Required Properties (11 total)

Check each property exists with the correct type:

- [ ] **Session ID** (Title) - Unique ID in format SESSION-YYYYMMDD-###
- [ ] **Projects** (Relation)
  - To database: Projects
  - Allow multiple: Yes
  - Show on Projects as: Sessions (or auto-named)
- [ ] **Goals** (Rich Text) - Session objectives
- [ ] **Start Time** (Date) - Session start (include time: Yes)
- [ ] **End Time** (Date) - Session end (include time: Yes, allow empty: Yes)
- [ ] **Status** (Select) - Options: Active, Completed, Abandoned
- [ ] **AI Type** (Select) - Options: Claude, Gemini, Other
- [ ] **Recording File Path** (Rich Text) - Path to .cast file
- [ ] **Recording Format** (Select) - Options: asciinema, other
- [ ] **Learning Count** (Rollup)
  - Related to: Learnings database (via Session relation)
  - Property: Title
  - Calculate: Count
- [ ] **Duration** (Formula) - Calculate session duration in minutes
  - Formula: `if(empty(prop("End Time")), dateBetween(now(), prop("Start Time"), "minutes"), dateBetween(prop("End Time"), prop("Start Time"), "minutes"))`

### Status Select Options

Verify these exact values exist:
- [ ] Active
- [ ] Completed
- [ ] Abandoned

### AI Type Select Options

Verify these exact values exist:
- [ ] Claude
- [ ] Gemini
- [ ] Other

### Recording Format Select Options

Verify these exact values exist:
- [ ] asciinema
- [ ] other

---

## Relationship Verification

### Projects ↔ Learnings

- [ ] In Learnings database, "Project" relation points to Projects database
- [ ] In Projects database, reverse relation appears (may be named "Learnings" or "Related to Learnings")
- [ ] Relation type is One-to-Many (one project, many learnings)

### Projects ↔ Sessions

- [ ] In Sessions database, "Projects" relation points to Projects database
- [ ] "Allow multiple" is enabled (one session can link to multiple projects)
- [ ] In Projects database, reverse relation appears
- [ ] Relation type is Many-to-Many

### Sessions ↔ Learnings

- [ ] In Learnings database, "Session" relation points to Sessions database
- [ ] "Allow empty" is enabled (learnings can exist without a session)
- [ ] In Sessions database, reverse relation appears
- [ ] Relation type is One-to-Many (one session, many learnings)

---

## Quick Visual Check

### Projects Database

Expected to see these columns when viewing:
```
Name | Status | Priority | Tech Stack | Description | Started | Last Activity | Learning Count | Session Count | Total Session Hours
```

### Learnings Database

Expected to see these columns when viewing:
```
Title | Learning ID | Project | Type | Dev Stream | Content | Context | Tags | Related Files | Confidence | Status | Timestamp | Last Modified | Session | AI Suggested | AI Accepted
```

### Sessions Database

Expected to see these columns when viewing:
```
Session ID | Projects | Goals | Start Time | End Time | Status | AI Type | Recording File Path | Recording Format | Learning Count | Duration
```

---

## Testing with Sample Data

### Create Test Project

In Projects database, create:
```
Name: "Noel"
Status: "Active"
Priority: "P1-High"
Tech Stack: ["n8n", "Notion", "Supabase"]
Description: "Knowledge repository system"
Started: Today's date
```

**Verify**:
- [ ] All fields accept values correctly
- [ ] Select dropdowns show correct options
- [ ] Multi-select allows multiple tags
- [ ] Learning Count shows 0 (no learnings yet)

### Create Test Learning

In Learnings database, create:
```
Title: "Test learning"
Learning ID: "NOEL-001"
Project: Select "Noel" from relation
Type: "Pattern"
Dev Stream: ["n8n"]
Content: "This is a test learning"
Confidence: "High"
Status: "Hypothesis"
Timestamp: Now
```

**Verify**:
- [ ] All fields accept values correctly
- [ ] Project relation connects to Noel
- [ ] After creation, Projects.Learning Count = 1
- [ ] AI Suggested and AI Accepted are unchecked by default

### Create Test Session

In Sessions database, create:
```
Session ID: "SESSION-20251121-001"
Projects: Select "Noel" from relation
Goals: "Testing session tracking"
Start Time: Now
Status: "Active"
AI Type: "Claude"
```

**Verify**:
- [ ] All fields accept values correctly
- [ ] Projects relation allows selecting Noel
- [ ] Duration formula calculates automatically
- [ ] End Time can be left empty
- [ ] After creation, Projects.Session Count = 1

---

## Common Issues & Fixes

### ❌ "Relation property not showing database"

**Fix**: Share the target database with your Notion integration
1. Open target database (e.g., Projects)
2. Click "..." menu → "Connections" → "Add connections"
3. Select your integration

### ❌ "Select options don't match"

**Fix**: Add missing options to select property
1. Click property name
2. Click "Edit property"
3. Add missing options exactly as specified above
4. Option names are case-sensitive!

### ❌ "Rollup not calculating"

**Fix**: Verify relation and rollup configuration
1. Relation must be connected first
2. Rollup property must specify: Related database, Property to aggregate, Calculation type
3. Test by adding related items

### ❌ "Formula not working"

**Fix**: Copy formula exactly from spec
- Duration formula is complex - copy from Sessions properties section above
- Formula syntax is Notion-specific
- Use prop("Property Name") not $property

---

## Verification Complete!

Once all checkboxes are ticked:

✅ **All databases created correctly**
✅ **All properties match specification**
✅ **All relations work**
✅ **Sample data validates structure**

**Next Steps**:
1. Get Data Source IDs from n8n when connecting databases
2. Update `.env` with Data Source IDs
3. Build n8n workflow using the databases
4. Test end-to-end with `test-endpoints.sh`

---

## Need Help?

If verification fails or you're unsure about a property:
1. Check `specs/001-knowledge-repository/data-model.md` for detailed specs
2. Compare your database to the property tables in that file
3. Use this checklist to identify missing/incorrect properties
4. Fix in Notion UI and re-verify

**Database IDs are configured in `.env`** - you're ready to proceed once all checks pass!
