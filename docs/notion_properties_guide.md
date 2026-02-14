# Notion Properties Setup Guide - Phase 1 Usage Tracking

**Feature:** Active Coordinator - Usage Tracking
**Database:** Learnings
**Date:** 2025-12-22

## Overview

This guide walks through adding 4 new properties to the Learnings database in Notion to support usage tracking and metrics display.

## Properties to Add

### 1. Usage Count

**Property Type:** Number
**Property Name:** `Usage Count`

**Configuration:**
- Number format: Number (not percentage or currency)
- Default value: 0

**Purpose:** Displays total number of times this learning has been used across all sessions.

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header to add new property
3. Name: "Usage Count"
4. Type: Number
5. Format: Number
6. Save

---

### 2. Helpful Rate

**Property Type:** Number
**Property Name:** `Helpful Rate`

**Configuration:**
- Number format: Number
- Default value: 0
- Display as percentage (optional, but recommended)

**Purpose:** Shows percentage (0-100) of times users marked this learning as helpful when used.

**Formula:** `(helpful_count / total_feedback_responses) * 100`

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header
3. Name: "Helpful Rate"
4. Type: Number
5. Format: Number (or Percent if you want automatic % display)
6. Save

**Note:** This will be populated by n8n workflow, not calculated in Notion.

---

### 3. Success Rate

**Property Type:** Number
**Property Name:** `Success Rate`

**Configuration:**
- Number format: Number
- Default value: 0
- Display as percentage (optional)

**Purpose:** Shows percentage (0-100) of times users successfully applied this learning.

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header
3. Name: "Success Rate"
4. Type: Number
5. Format: Number (or Percent)
6. Save

---

### 4. Last Used

**Property Type:** Date
**Property Name:** `Last Used`

**Configuration:**
- Include time: Yes (recommended)
- Allow empty: Yes

**Purpose:** Shows when this learning was most recently accessed/used.

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header
3. Name: "Last Used"
4. Type: Date
5. Check "Include time"
6. Save

---

### 5. Effectiveness Score

**Property Type:** Number
**Property Name:** `Effectiveness Score`

**Configuration:**
- Number format: Number
- Default value: 0

**Purpose:** Weighted score combining helpful rate, success rate, and usage count. Higher = more valuable learning.

**Formula (in Supabase):** `(helpful_rate/100 * 0.6 + success_rate/100 * 0.4) * total_uses`

**How to add:**
1. Open Learnings database in Notion
2. Click `+` button in table header
3. Name: "Effectiveness Score"
4. Type: Number
5. Format: Number with 2 decimal places
6. Save

**Note:** This will be populated by n8n workflow from Supabase metrics.

---

## Optional: Create Notion Formula Property

If you want Notion to calculate an estimated effectiveness score before Supabase data syncs, you can create a formula property:

**Property Type:** Formula
**Property Name:** `Effectiveness (Estimated)`

**Formula:**
```
round((prop("Helpful Rate") * 0.6 + prop("Success Rate") * 0.4) * prop("Usage Count") / 100, 2)
```

This gives you a Notion-only calculation that approximates the Supabase value.

---

## Verification Checklist

After adding all properties, verify:

- [ ] All 5 properties appear in Learnings database
- [ ] Property types match specifications
- [ ] "Last Used" includes time
- [ ] Number properties show correct format
- [ ] Properties are editable (not read-only)
- [ ] Default values are set (0 for numbers, empty for date)

---

## Next Steps

After adding these properties:

1. **Test Property Access:** Create a test learning and manually set values
2. **Update n8n Workflow:** Modify the `update_learning` endpoint to sync these properties from Supabase
3. **Test Sync:** Insert usage data in Supabase, sync to Notion, verify properties update

---

## Property Relationship to Supabase

| Notion Property | Supabase Source | Updated By |
|----------------|-----------------|------------|
| Usage Count | `learning_metrics.total_uses` | n8n sync |
| Helpful Rate | `learning_metrics.helpful_rate` | n8n sync |
| Success Rate | `learning_metrics.success_rate` | n8n sync |
| Last Used | `learning_metrics.last_used` | n8n sync |
| Effectiveness Score | `learning_metrics.effectiveness_score` | n8n sync |

---

## Troubleshooting

**Problem:** Can't add property
**Solution:** Make sure you're in the database view (table/board), not a page. Look for the `+` button in the column headers.

**Problem:** Number format wrong
**Solution:** Click property name → Type → Number → Format → Select "Number" or "Percent"

**Problem:** Properties not syncing from n8n
**Solution:** Verify property names match exactly (case-sensitive). Check n8n workflow has Notion API access.

---

## Screenshot Locations

For reference, here's where to find property settings:

1. **Add Property:** Click `+` in table header (far right)
2. **Edit Property:** Click property name → Configure
3. **Property Type:** Dropdown when creating/editing
4. **Number Format:** Type → Number → Format dropdown

---

## Time Estimate

Adding all 5 properties: **~5 minutes**

---

## Support

If you encounter issues:
1. Check Notion API documentation: https://developers.notion.com/reference/property-object
2. Verify database permissions (must be able to edit structure)
3. Test with a single property first before adding all

---

**Last Updated:** 2025-12-22
**Phase:** 1 - Usage Tracking
**Status:** Ready for implementation
