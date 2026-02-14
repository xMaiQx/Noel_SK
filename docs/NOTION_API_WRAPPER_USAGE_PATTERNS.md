# Notion API Wrapper Usage Patterns

**Learned from**: Noel_Knowledge_Repository workflow
**Wrapper ID**: ckclnbJYoUvb7WQm (00_MyCFO_Notion_API_Wrapper)

---

## 🎯 General Pattern

ALL calls to the Notion API wrapper follow this structure:

```javascript
{
  query: {
    endpoint: 'ENDPOINT_NAME',
    id: 'DATA_SOURCE_ID or null'
  },
  body: {
    // Endpoint-specific parameters
  }
}
```

---

## 📋 Pattern 1: Query Data Source (Read Records)

**Use for**: Querying/searching records in a database

**Example from**: List Projects Logic, Update Learning Logic

```javascript
return [{
  json: {
    query: {
      endpoint: 'query_data_source',
      id: '2b23d603-acb6-80df-9e44-000bdb264067'  // Projects data source ID
    },
    body: {
      filter: {
        property: 'Name',
        title: {
          equals: 'ProjectName'
        }
      },
      page_size: 20
    }
  }
}];
```

**Key Points**:
- Use `query.id` = data source ID
- `body.filter` for filtering results
- `body.page_size` to limit results

**Common Filters**:
```javascript
// Title field (exact match)
filter: {
  property: 'Name',
  title: { equals: 'value' }
}

// Select field
filter: {
  property: 'Status',
  select: { equals: 'Active' }
}

// Date field
filter: {
  property: 'Started',
  date: { on_or_after: '2025-01-01' }
}
```

---

## 📋 Pattern 2: Create Page (Write Record)

**Use for**: Creating a new page in a database

**Example from**: Start Session Logic → Prepare Create Page Call

```javascript
// Step 1: Build notion_payload
const notion_payload = {
  parent: {
    data_source_id: '2b23d603-acb6-80df-9e44-000bdb264067'  // ⚠️ Use data_source_id NOT database_id
  },
  properties: {
    'Name': {
      title: [{ text: { content: 'Project Name' } }]
    },
    'Status': {
      select: { name: 'Active' }
    },
    'Priority': {
      select: { name: 'P2-Medium' }
    },
    'Started': {
      date: { start: '2025-01-10' }
    },
    'Description': {
      rich_text: [{ text: { content: 'Description text' } }]
    },
    'Repository URL': {
      url: 'https://github.com/user/repo'
    },
    'Tech Stack': {
      multi_select: [{ name: 'React' }, { name: 'Node.js' }]
    }
  }
};

// Step 2: Wrap for API wrapper
return [{
  json: {
    query: {
      endpoint: 'create_page',
      id: null  // Not used for create_page
    },
    body: notion_payload
  }
}];
```

**CRITICAL**:
- Use `parent: { data_source_id }` NOT `parent: { database_id }`
- Set `query.id: null` (not used)
- Put entire `notion_payload` in `body`

**Property Types**:
```javascript
// Title (only one title property per database)
'Name': { title: [{ text: { content: 'Text' } }] }

// Rich Text
'Description': { rich_text: [{ text: { content: 'Text' } }] }

// Select (single choice)
'Status': { select: { name: 'Active' } }

// Multi-select
'Tags': { multi_select: [{ name: 'tag1' }, { name: 'tag2' }] }

// Date
'Started': { date: { start: '2025-01-10' } }

// URL
'Repository URL': { url: 'https://example.com' }

// Checkbox
'AI Suggested': { checkbox: true }

// Relation (link to another database)
'Projects': { relation: [{ id: 'page-id-here' }] }
```

---

## 📋 Pattern 3: Update Page (Modify Record)

**Use for**: Updating properties of an existing page

**Example from**: Update Learning Logic → Call API Wrapper (Update Page)

```javascript
return [{
  json: {
    query: {
      endpoint: 'update_page',
      id: 'PAGE_ID'  // The specific page to update
    },
    body: {
      properties: {
        'Status': {
          select: { name: 'Completed' }
        },
        'Last Modified': {
          date: { start: new Date().toISOString() }
        }
      }
    }
  }
}];
```

**Key Points**:
- Use `query.id` = page ID (not data source ID)
- Only include properties you want to change
- Omitted properties remain unchanged

---

## 🔑 Database Reference (Data Source IDs)

**Projects Database**:
- Data Source ID: `2b23d603-acb6-80df-9e44-000bdb264067`
- Use for: Querying projects, creating project pages

**Learnings Database**:
- Data Source ID: `2b23d603-acb6-8001-983a-000b5df4e3b7`
- Use for: Querying learnings, creating learning pages

**Sessions Database**:
- Data Source ID: `2b43d603-acb6-8064-82f9-000b343a2e1c`
- Use for: Querying sessions, creating session pages

---

## 🚫 Common Mistakes

### ❌ MISTAKE 1: Using database_id instead of data_source_id

**WRONG**:
```javascript
parent: { database_id: '2b23d603...' }  // ❌ Won't work
```

**CORRECT**:
```javascript
parent: { data_source_id: '2b23d603...' }  // ✅ Works
```

### ❌ MISTAKE 2: Setting query.id for create_page

**WRONG**:
```javascript
query: {
  endpoint: 'create_page',
  id: '2b23d603...'  // ❌ Not used, confusing
}
```

**CORRECT**:
```javascript
query: {
  endpoint: 'create_page',
  id: null  // ✅ Explicit that it's not used
}
```

### ❌ MISTAKE 3: Wrapping body incorrectly

**WRONG**:
```javascript
body: {
  parent: { data_source_id: '...' },
  properties: { ... }
}
// Then in API wrapper call:
body: {
  parent: ...,  // ❌ Double-wrapped
  properties: ...
}
```

**CORRECT**:
```javascript
// Build notion_payload first
const notion_payload = {
  parent: { data_source_id: '...' },
  properties: { ... }
};

// Then wrap once
return {
  json: {
    query: { ... },
    body: notion_payload  // ✅ Single wrapper
  }
};
```

---

## 📝 Complete Implementation Example

Here's a complete example showing both query and create:

```javascript
// Code Node 1: Prepare Check Query
const projectName = $input.item.json.name;

return {
  json: {
    query: {
      endpoint: 'query_data_source',
      id: '2b23d603-acb6-80df-9e44-000bdb264067'
    },
    body: {
      filter: {
        property: 'Name',
        title: { equals: projectName }
      },
      page_size: 1
    },
    validated_data: $input.item.json  // Preserve for later
  }
};

// → Execute Workflow (ckclnbJYoUvb7WQm)
// → IF Project Exists

// Code Node 2: Prepare Create Payload (if project doesn't exist)
const validatedData = $('Code Node 1').item.json.validated_data;

const notion_payload = {
  parent: { data_source_id: '2b23d603-acb6-80df-9e44-000bdb264067' },
  properties: {
    'Name': {
      title: [{ text: { content: validatedData.name } }]
    },
    'Status': {
      select: { name: 'Active' }
    }
  }
};

return {
  json: {
    query: {
      endpoint: 'create_page',
      id: null
    },
    body: notion_payload
  }
};

// → Execute Workflow (ckclnbJYoUvb7WQm)
```

---

## 🎓 Summary

**For Queries**:
- Use `endpoint: 'query_data_source'`
- Set `id` to data source ID
- Put filters/page_size in `body`

**For Creates**:
- Use `endpoint: 'create_page'`
- Set `id: null`
- Build `notion_payload` with `parent: { data_source_id }` and `properties`
- Put entire `notion_payload` in `body`

**For Updates**:
- Use `endpoint: 'update_page'`
- Set `id` to specific page ID
- Put only changed properties in `body.properties`

**Always**:
- Use data_source_id (not database_id)
- Wrap in query/body structure
- Call Execute Workflow → ckclnbJYoUvb7WQm
