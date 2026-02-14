# Multi-Dimensional Metadata Setup Guide

**Feature:** Enhanced Learning Classification
**Database:** Learnings
**Date:** 2025-12-30

## Overview

This guide adds 3 new properties to enable multi-dimensional learning classification: Scope, Discipline, and Applies To. These properties allow learnings to be categorized beyond just project/tags, enabling better discovery of universal principles and cross-domain patterns.

## Properties to Add

### 1. Scope

**Property Type:** Select (single choice)
**Property Name:** `Scope`

**Configuration:**
- Type: Select
- Options (add in this order):
  1. `Project-Specific` (make this the default)
  2. `Universal`
  3. `Domain-Specific`
- Default value: `Project-Specific`

**Purpose:** Defines the applicability level of the learning:
- **Project-Specific**: Only applies to this specific project
- **Universal**: Applies across all projects/domains (architectural principles, UX patterns)
- **Domain-Specific**: Applies to a specific technology domain (e.g., "all React projects")

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header (far right)
3. Name: "Scope"
4. Type: Select
5. Add options: "Project-Specific", "Universal", "Domain-Specific"
6. Click "Project-Specific" → Set as default
7. Save

**Examples:**
- Noel webhook routing → `Project-Specific`
- Keep UI databases under 2000 chars → `Universal`
- React useEffect dependencies → `Domain-Specific`

---

### 2. Discipline

**Property Type:** Multi-select
**Property Name:** `Discipline`

**Configuration:**
- Type: Multi-select
- Options (add all):
  1. `Architecture`
  2. `UX/UI`
  3. `Backend`
  4. `Frontend`
  5. `Database`
  6. `DevOps`
  7. `Security`
  8. `Performance`
  9. `Testing`
  10. `Documentation`
- Allow empty: Yes

**Purpose:** Categorizes learning by professional discipline/domain. A learning can belong to multiple disciplines.

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header
3. Name: "Discipline"
4. Type: Multi-select
5. Add all 10 options listed above
6. Save

**Examples:**
- Notion 2000-char limit fix → `Architecture`, `UX/UI`, `Database`
- Git-first development → `DevOps`, `Architecture`
- Supabase upsert pattern → `Database`, `Backend`

---

### 3. Applies To

**Property Type:** Rich Text
**Property Name:** `Applies To`

**Configuration:**
- Type: Rich Text
- Allow empty: Yes

**Purpose:** Free-form description of contexts, scenarios, or situations where this learning is relevant. Think: "When should I remember this learning?"

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header
3. Name: "Applies To"
4. Type: Rich Text
5. Save

**Format Guidelines:**
- Comma-separated list or short sentences
- Be specific about contexts
- Max ~500 chars recommended (keep UI-friendly)
- Think: "Show this when someone is..."

**Examples:**
- "Notion database design, UI architecture decisions, content display planning"
- "Implementing authentication, designing API security, user session management"
- "React component optimization, debugging render loops, performance tuning"
- "n8n workflow debugging, execution log analysis, error pattern identification"

---

## Verification Checklist

After adding all properties, verify:

- [ ] "Scope" property exists with 3 options (Project-Specific is default)
- [ ] "Discipline" property exists with 10 options
- [ ] "Applies To" property exists as Rich Text
- [ ] All properties appear in database table view
- [ ] Properties are editable (not read-only)
- [ ] You can select multiple Disciplines on one learning
- [ ] You can type free-form text in Applies To

---

## Test the Properties

Create a test learning and set values:

**Test Learning:**
- Title: "Test Multi-Dimensional Metadata"
- Scope: `Universal`
- Discipline: `Architecture`, `UX/UI`
- Applies To: "Test context 1, test context 2"

If this works, the properties are correctly configured!

---

## Property Mapping for n8n Workflow

Once properties are added, the n8n workflow will populate them:

| Notion Property | API Field | Example |
|----------------|-----------|---------|
| Scope | `scope` | "Universal" |
| Discipline | `discipline` | ["Architecture", "UX/UI"] |
| Applies To | `applies_to` | "Notion database design, UI decisions" |

---

## Next Steps

**After you've added these 3 properties in Notion:**

1. ✅ Reply "properties added"
2. I will update the n8n workflow to populate these fields
3. We'll test by capturing a learning with the new metadata
4. Verify the properties appear correctly in Notion

---

## Time Estimate

Adding all 3 properties: **~3-5 minutes**

---

## Troubleshooting

**Problem:** Can't find where to add properties
**Solution:** Make sure you're viewing the database in table/board view. The `+` button appears in the column headers (scroll right if needed).

**Problem:** Can't set default for Scope
**Solution:** After creating the Select property with options, click on "Project-Specific" option → "Set as default" should appear.

**Problem:** Multi-select not working for Discipline
**Solution:** Verify property type is "Multi-select" (not "Select"). Multi-select allows multiple choices.

---

## Benefits of These Properties

Once implemented, you'll be able to:

✅ Query "universal architecture principles" across all projects
✅ Find "all UX/UI learnings" regardless of where discovered
✅ Search "learnings that apply to Notion implementation"
✅ Filter by discipline when making design decisions
✅ Separate project-specific details from universal patterns

---

**Last Updated:** 2025-12-30
**Status:** Ready for implementation
**Next:** Add properties in Notion, then update n8n workflow
