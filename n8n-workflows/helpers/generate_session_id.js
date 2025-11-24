/**
 * Generate Session ID Function for n8n
 *
 * Usage: Paste this into an n8n Function node
 * Input: (no specific input required, uses current date)
 * Output: unique session ID in format SESSION-YYYYMMDD-###
 *
 * Requires: Notion API credentials configured
 */

// Get current date
const now = new Date();

// Format as YYYYMMDD
const year = now.getFullYear();
const month = String(now.getMonth() + 1).padStart(2, '0');
const day = String(now.getDate()).padStart(2, '0');
const dateStr = `${year}${month}${day}`;

// Return date string for use in Notion query
return [{
  json: {
    dateStr: dateStr,
    currentDate: now.toISOString(),
    // Pass through any other data from previous node
    ...$input.item.json
  }
}];

/**
 * IMPLEMENTATION NOTES FOR N8N:
 *
 * 1. Add this Function node when creating a new session
 * 2. Add Notion "Get All" node to query Sessions database:
 *    - Database: Sessions
 *    - Filter: Session ID starts with "SESSION-{{$json.dateStr}}"
 *    - Simplify: No
 *    - Return all results
 *
 * 3. Add another Function node to calculate next ID:
 *
 * const dateStr = $input.first().json.dateStr;
 * const existingSessions = $input.all();
 *
 * // Extract sequence numbers from existing session IDs for today
 * const sequences = existingSessions
 *   .map(item => {
 *     const sessionId = item.json.properties?.['Session ID']?.title?.[0]?.plain_text || '';
 *     const pattern = `SESSION-${dateStr}-`;
 *     if (sessionId.startsWith(pattern)) {
 *       const seqStr = sessionId.substring(pattern.length);
 *       return parseInt(seqStr, 10);
 *     }
 *     return 0;
 *   })
 *   .filter(n => n > 0);
 *
 * // Find max sequence number for today
 * const maxSeq = sequences.length > 0 ? Math.max(...sequences) : 0;
 * const nextSeq = maxSeq + 1;
 *
 * // Generate final session ID
 * const sessionId = `SESSION-${dateStr}-${String(nextSeq).padStart(3, '0')}`;
 *
 * return [{
 *   json: {
 *     sessionId: sessionId,
 *     dateStr: dateStr,
 *     sequence: nextSeq
 *   }
 * }];
 *
 * 4. Use this sessionId in the Notion "Create" node for Sessions database
 */
