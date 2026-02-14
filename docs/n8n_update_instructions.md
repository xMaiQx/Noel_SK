# n8n Workflow Update: Add Usage Metrics Support

## What to Update

The **"Prepare Update Page Call"** node in your `Noel_Knowledge_Repository` workflow needs to support the new usage metric properties.

## How to Update

1. **Open n8n**: Go to http://localhost:5678
2. **Open workflow**: "Noel_Knowledge_Repository"
3. **Find node**: "Prepare Update Page Call" (Code node)
4. **Edit the code**: Add the following lines after the existing `if` statements (around line 70, before the `return` statement)

### Code to Add

Add this code right before the final `return` statement:

```javascript
// ============================================================================
// Usage Metrics Properties (added for Phase 1 - Usage Tracking)
// ============================================================================

if (updatePayload['Usage Count'] !== undefined) {
  properties['Usage Count'] = {
    number: updatePayload['Usage Count']
  };
}

if (updatePayload['Helpful Rate'] !== undefined) {
  properties['Helpful Rate'] = {
    number: updatePayload['Helpful Rate']
  };
}

if (updatePayload['Success Rate'] !== undefined) {
  properties['Success Rate'] = {
    number: updatePayload['Success Rate']
  };
}

if (updatePayload['Effectiveness Score'] !== undefined) {
  properties['Effectiveness Score'] = {
    number: updatePayload['Effectiveness Score']
  };
}

if (updatePayload['Last Used']) {
  properties['Last Used'] = {
    date: { start: updatePayload['Last Used'] }
  };
}
```

### Complete Updated Code

Here's the complete updated code for the "Prepare Update Page Call" node:

```javascript
// Step 2: Extract page_id from query result and prepare update
const input = $input.first().json;
const updatePayload = $('Update Learning Logic').first().json.update_payload;
const now = new Date().toISOString();

// Extract page_id from query result
if (!input.results || input.results.length === 0) {
  throw new Error(`Learning not found: ${updatePayload.learning_id}. ` +
    `Query returned ${input.results ? input.results.length : 0} results. ` +
    `Make sure the learning_id exactly matches the Notion page title.`);
}

const pageId = input.results[0].id;

// Build update properties
const properties = {
  'Last Modified': {
    date: { start: now }
  }
};

// Update only provided fields
if (updatePayload.title) {
  properties['Title'] = {
    title: [{ text: { content: updatePayload.title } }]
  };
}

if (updatePayload.type) {
  properties['Type'] = {
    select: { name: updatePayload.type }
  };
}

if (updatePayload.content) {
  properties['Content'] = {
    rich_text: [{ text: { content: updatePayload.content } }]
  };
}

if (updatePayload.context) {
  properties['Context'] = {
    rich_text: [{ text: { content: updatePayload.context } }]
  };
}

if (updatePayload.confidence) {
  properties['Confidence'] = {
    select: { name: updatePayload.confidence }
  };
}

if (updatePayload.status) {
  properties['Status'] = {
    select: { name: updatePayload.status }
  };
}

if (updatePayload.dev_stream && Array.isArray(updatePayload.dev_stream)) {
  properties['Dev Stream'] = {
    multi_select: updatePayload.dev_stream.map(s => ({ name: s }))
  };
}

if (updatePayload.tags && Array.isArray(updatePayload.tags)) {
  properties['Tags'] = {
    multi_select: updatePayload.tags.map(t => ({ name: t }))
  };
}

if (updatePayload.related_files) {
  properties['Related Files'] = {
    rich_text: [{ text: { content: updatePayload.related_files } }]
  };
}

if (updatePayload.ai_accepted !== undefined) {
  properties['AI Accepted'] = {
    checkbox: updatePayload.ai_accepted
  };
}

// ============================================================================
// Usage Metrics Properties (added for Phase 1 - Usage Tracking)
// ============================================================================

if (updatePayload['Usage Count'] !== undefined) {
  properties['Usage Count'] = {
    number: updatePayload['Usage Count']
  };
}

if (updatePayload['Helpful Rate'] !== undefined) {
  properties['Helpful Rate'] = {
    number: updatePayload['Helpful Rate']
  };
}

if (updatePayload['Success Rate'] !== undefined) {
  properties['Success Rate'] = {
    number: updatePayload['Success Rate']
  };
}

if (updatePayload['Effectiveness Score'] !== undefined) {
  properties['Effectiveness Score'] = {
    number: updatePayload['Effectiveness Score']
  };
}

if (updatePayload['Last Used']) {
  properties['Last Used'] = {
    date: { start: updatePayload['Last Used'] }
  };
}

return [{
  json: {
    query: {
      endpoint: 'update_page',
      id: pageId
    },
    body: {
      properties: properties
    }
  }
}];
```

## Steps to Apply

1. Copy the complete updated code above
2. Open n8n workflow editor
3. Click on the "Prepare Update Page Call" node
4. Replace the entire code with the updated version
5. Click "Execute Node" to test (optional)
6. Click "Save" in the top right
7. The workflow will auto-deploy

## Verification

Test that the update works:

```bash
curl -X POST https://18f625ebc1f0.ngrok-free.app/webhook/noel \
  -H "Content-Type: application/json" \
  -H "Authorization: 1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6" \
  -d '{
    "endpoint": "update_learning",
    "learning_id": "TEST-001",
    "Usage Count": 10,
    "Helpful Rate": 85.5,
    "Success Rate": 90.0,
    "Effectiveness Score": 8.8,
    "Last Used": "2025-12-23T10:30:00Z"
  }'
```

Check your Notion learning to verify the properties were updated!

---

**Time Estimate**: 2-3 minutes

**Status**: Ready to apply
