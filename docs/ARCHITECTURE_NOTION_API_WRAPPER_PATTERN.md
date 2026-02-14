# Notion API Wrapper Pattern - Architectural Decision

**Date**: 2025-01-10
**Context**: Noel Knowledge Repository
**Decision**: NEVER use direct Notion nodes - ALWAYS use Execute Workflow pattern

---

## 🎯 The Pattern

**DON'T** ❌: Use Notion nodes directly in workflows
**DO** ✅: Use Execute Workflow nodes that call the centralized Notion API Wrapper

---

## 🏗️ Architecture

```
Main Workflow
  └─> Code Node (Prepare query/body)
       └─> Execute Workflow Node
            └─> Calls: 00_MyCFO_Notion_API_Wrapper (ID: ckclnbJYoUvb7WQm)
                 └─> Returns: Notion API response
```

### Standard Data Format

**ALL Notion operations** use this structure:

```javascript
{
  json: {
    query: {
      endpoint: 'query_data_source' | 'create_page' | 'update_page' | 'retrieve_database',
      id: 'DATA_SOURCE_ID or DATABASE_ID'
    },
    body: {
      // Endpoint-specific parameters
      // Examples: filters, page_size, properties, etc.
    }
  }
}
```

---

## 📋 Examples

### Example 1: Query Projects Database

```javascript
// Code node: "Prepare Check Query"
return {
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
      page_size: 1
    }
  }
};

// Then: Execute Workflow → 00_MyCFO_Notion_API_Wrapper
```

### Example 2: Create Page in Database

```javascript
// Code node: "Prepare Create Payload"
return {
  json: {
    query: {
      endpoint: 'create_page',
      id: '2b23d603-acb6-80df-9e44-000bdb264067'
    },
    body: {
      parent: { database_id: '2b23d603-acb6-80df-9e44-000bdb264067' },
      properties: {
        'Name': {
          title: [{ text: { content: 'New Project' } }]
        },
        'Status': {
          select: { name: 'Active' }
        }
      }
    }
  }
};

// Then: Execute Workflow → 00_MyCFO_Notion_API_Wrapper
```

### Example 3: Update Page

```javascript
// Code node: "Prepare Update Payload"
return {
  json: {
    query: {
      endpoint: 'update_page',
      id: 'PAGE_ID'  // Specific page to update
    },
    body: {
      properties: {
        'Status': {
          select: { name: 'Completed' }
        }
      }
    }
  }
};

// Then: Execute Workflow → 00_MyCFO_Notion_API_Wrapper
```

---

## 💡 WHY This Pattern?

### Benefits

1. **Centralized Notion Logic**
   - One place to update Notion API calls
   - Consistent error handling
   - Unified authentication

2. **Reusability**
   - Same wrapper used by ALL workflows
   - No duplicate Notion credential configuration
   - Easier to maintain

3. **Abstraction**
   - Main workflow doesn't care about Notion API details
   - Swappable backend (could switch to Airtable, etc.)
   - Clear separation of concerns

4. **Debugging**
   - Single workflow to debug Notion issues
   - Easier to add logging/monitoring
   - Clear data flow

### Drawbacks of Direct Notion Nodes

- ❌ Scattered Notion credential configuration
- ❌ Inconsistent error handling across workflows
- ❌ Hard to change Notion logic globally
- ❌ Tightly coupled to Notion API
- ❌ More nodes to maintain

---

## 🔑 Key Database IDs

### Projects Database
- **Data Source ID**: `2b23d603-acb6-80df-9e44-000bdb264067`
- **Use for**: Querying, creating project pages

### Learnings Database
- **Data Source ID**: `2b23d603-acb6-8001-983a-000b5df4e3b7`
- **Use for**: Querying, creating learning pages

### Sessions Database
- **Data Source ID**: `2b43d603-acb6-8064-82f9-000b343a2e1c`
- **Use for**: Querying, creating session pages

**Note**: Data Source IDs are used for querying/creating pages. Database IDs are different (used for schema operations).

---

## 📐 Implementation Template

When adding ANY Notion operation to a workflow:

### Step 1: Code Node - Prepare Data

```javascript
// Always format as query/body structure
const yourData = $input.item.json;

return {
  json: {
    query: {
      endpoint: 'YOUR_ENDPOINT',
      id: 'YOUR_DATA_SOURCE_ID'
    },
    body: {
      // Your endpoint-specific parameters
    }
  }
};
```

### Step 2: Execute Workflow Node

- **Node Type**: Execute Workflow
- **Source**: By ID
- **Workflow ID**: `ckclnbJYoUvb7WQm` (00_MyCFO_Notion_API_Wrapper)

### Step 3: Process Response

The wrapper returns Notion API response directly. Access with `$input.item.json`.

---

## 🚫 Anti-Patterns to Avoid

### ❌ WRONG: Direct Notion Node

```
Workflow
  └─> Notion Node (Query Database)
       └─> Directly configured with credentials
```

**Why wrong**: Bypasses centralized wrapper, creates maintenance burden.

### ❌ WRONG: Mixed Approach

```
Workflow
  ├─> Some operations use Execute Workflow ✓
  └─> Some operations use Notion Node ✗
```

**Why wrong**: Inconsistent, confusing, defeats purpose of wrapper.

### ✅ CORRECT: Always Use Wrapper

```
Workflow
  └─> Code Node (Prepare)
       └─> Execute Workflow (Wrapper)
            └─> Process Response
```

**Why correct**: Consistent, maintainable, follows architecture.

---

## 📝 Checklist for New Notion Operations

Before adding Notion functionality to a workflow:

- [ ] Will I use Execute Workflow? (NOT direct Notion node)
- [ ] Do I have the correct Data Source ID?
- [ ] Am I using query/body structure?
- [ ] Is my endpoint correct? (query_data_source, create_page, etc.)
- [ ] Am I preserving data flow correctly? (validated_data pattern)
- [ ] Did I test with the wrapper workflow?

---

## 🔗 Related Documentation

- **Notion API Querying Skill**: `.claude/skills/notion-api-querying/SKILL.md`
- **n8n Management Skill**: `.claude/skills/n8n-management/SKILL.md`
- **Wrapper Workflow**: n8n → `00_MyCFO_Notion_API_Wrapper`

---

## 🎓 Summary

**Golden Rule**: If you're about to add a Notion node to a workflow, STOP. Use the Execute Workflow pattern instead.

**Quick Reference**:
1. Code node → Prepare query/body structure
2. Execute Workflow → Call `ckclnbJYoUvb7WQm`
3. Process response → Use `$input.item.json`

**Remember**: This pattern applies to ALL Notion operations in ALL workflows in this project.
