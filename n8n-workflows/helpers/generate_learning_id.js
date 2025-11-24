/**
 * Generate Learning ID Function for n8n
 *
 * Usage: Paste this into an n8n Function node
 * Input: projectName from previous node
 * Output: unique learning ID in format PROJECT-###
 *
 * Requires: Notion API credentials configured
 */

// Extract project prefix from project name
function extractPrefix(projectName) {
  // Remove special characters, convert to uppercase
  const clean = projectName.replace(/[^a-zA-Z\s]/g, '').toUpperCase();

  // Split into words
  const words = clean.split(/\s+/).filter(w => w.length > 0);

  if (words.length === 0) {
    return 'UNKN'; // Fallback
  }

  if (words.length === 1) {
    // Single word: First 2-4 consonants
    const consonants = words[0].replace(/[AEIOU]/g, '');
    if (consonants.length >= 2) {
      return consonants.slice(0, Math.min(4, consonants.length));
    }
    // If not enough consonants, use first 2-4 letters
    return words[0].slice(0, Math.min(4, words[0].length));
  } else {
    // Multiple words: First letter of each word (max 4)
    return words.map(w => w[0]).join('').slice(0, 4);
  }
}

// Get project name from input
const projectName = $input.item.json.project;

if (!projectName) {
  throw new Error('Project name is required to generate learning ID');
}

// Extract prefix
const prefix = extractPrefix(projectName);

// Note: The actual Notion query to find max sequence number
// must be done in a separate Notion node that queries the
// Learnings database with a filter for Learning IDs starting with this prefix
//
// This function just returns the prefix for use in the next node
return [{
  json: {
    prefix: prefix,
    projectName: projectName,
    // Pass through any other data from previous node
    ...$input.item.json
  }
}];

/**
 * IMPLEMENTATION NOTES FOR N8N:
 *
 * 1. Add this Function node after receiving project name
 * 2. Add Notion "Get All" node to query Learnings database:
 *    - Database: Learnings
 *    - Filter: Learning ID starts with {{$json.prefix}}
 *    - Simplify: No
 *    - Return all results
 *
 * 3. Add another Function node to calculate next ID:
 *
 * const prefix = $input.first().json.prefix;
 * const existingLearnings = $input.all();
 *
 * // Extract sequence numbers from existing learning IDs
 * const sequences = existingLearnings
 *   .map(item => {
 *     const learningId = item.json.properties?.['Learning ID']?.rich_text?.[0]?.plain_text || '';
 *     const match = learningId.match(new RegExp(`^${prefix}-(\\d+)$`));
 *     return match ? parseInt(match[1], 10) : 0;
 *   })
 *   .filter(n => n > 0);
 *
 * // Find max sequence number
 * const maxSeq = sequences.length > 0 ? Math.max(...sequences) : 0;
 * const nextSeq = maxSeq + 1;
 *
 * // Generate final learning ID
 * const learningId = `${prefix}-${String(nextSeq).padStart(3, '0')}`;
 *
 * return [{
 *   json: {
 *     learningId: learningId,
 *     prefix: prefix,
 *     sequence: nextSeq
 *   }
 * }];
 */
