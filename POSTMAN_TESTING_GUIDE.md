# Postman Testing Guide for Noel

## Setup

1. **Import the Collection**
   - Open Postman
   - Click "Import" button (top left)
   - Select `n8n-workflows/Noel_Postman_Collection.json`
   - Collection will appear in your sidebar

2. **Collection Variables** (Already configured)
   - `base_url`: `https://9e527c57b6c1.ngrok-free.app/webhook/noel`
   - `auth_token`: `1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6`

   **To update when ngrok restarts:**
   - Click on collection name → Variables tab
   - Update `base_url` with new ngrok URL

## Testing Workflow

### Test 1: Capture Learning
1. Open "1. Capture Learning" request
2. Click "Send"
3. **Expected Response:**
   ```json
   {
     "success": true,
     "learning_id": "20251124-HHMM-noel-sk-test-learning-from",
     "message": "Learning 20251124-HHMM-... created successfully"
   }
   ```
4. **Copy the `learning_id`** for the next test

### Test 2: Update Learning
1. Open "2. Update Learning" request
2. **Replace** `PASTE_LEARNING_ID_HERE` with the actual learning_id from Test 1
3. Click "Send"
4. **Expected Response:**
   ```json
   {
     "success": true,
     "message": "Updated successfully"
   }
   ```

### Test 3: Start Session
1. Open "4. Start Session" request
2. Click "Send"
3. **Expected Response:**
   ```json
   {
     "success": true,
     "session_id": "20251124-HHMM-noel-sk",
     "message": "Session 20251124-HHMM-noel-sk started successfully"
   }
   ```
4. **Copy the `session_id`** for the next test

### Test 4: End Session
1. Open "5. End Session" request
2. **Replace** `PASTE_SESSION_ID_HERE` with the actual session_id from Test 3
3. Click "Send"
4. **Expected Response:**
   ```json
   {
     "success": true,
     "message": "Updated successfully"
   }
   ```

### Test 5: List Projects
1. Open "7. List Projects" request
2. Click "Send"
3. **Expected Response:**
   ```json
   {
     "success": true,
     "count": 1,
     "message": "Retrieved 1 items",
     "data": {
       "results": [...]
     }
   }
   ```

### Test 6: List Sessions
1. Open "6. List Sessions" request
2. Click "Send"
3. **Expected Response:**
   ```json
   {
     "success": true,
     "count": 2,
     "message": "Retrieved 2 items",
     "data": {
       "results": [...]
     }
   }
   ```

## Not Implemented Yet

These endpoints return placeholder responses:

- **3. Query Learnings** - Requires Supabase vector database setup
- **8. Query Feedback** - Requires Supabase feedback table setup

**Expected Response:**
```json
{
  "error": "Vector search not yet implemented",
  "message": "This endpoint requires Supabase setup"
}
```

## Troubleshooting

### Issue: "Unauthorized" or 403 error
**Solution:** Check that the Authorization header is set correctly
- Collection Variables → `auth_token` matches your `.env` AUTH_TOKEN

### Issue: ngrok offline error
**Solution:** Update the base_url
1. Check if ngrok is running: `curl https://9e527c57b6c1.ngrok-free.app`
2. If ngrok restarted, get new URL and update Collection Variables

### Issue: Workflow not triggering
**Solution:** Verify workflow is active in n8n
1. Open n8n UI
2. Check "Noel_Knowledge_Repository" workflow is Active (toggle on)
3. Webhook node should show the webhook URL

### Issue: Wrong endpoint executing
**Solution:** Check the Switch node routing
1. Open workflow in n8n
2. Click "Route Endpoint" (Switch) node
3. Verify all 8 conditions are configured correctly
4. Test the workflow manually in n8n first

## Viewing Results in Notion

After successful requests:

1. **Learnings Database:** Open in Notion to see captured/updated learnings
2. **Sessions Database:** Open in Notion to see started/ended sessions
3. **Projects Database:** Query via "List Projects" endpoint

## Quick Test Sequence

Run these in order to test the full flow:

1. **Start Session** → Copy `session_id`
2. **Capture Learning** → Copy `learning_id`
3. **Update Learning** (with `learning_id`)
4. **List Projects**
5. **List Sessions**
6. **End Session** (with `session_id`)

This validates all working endpoints!
