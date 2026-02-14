/**
 * Prepare Structured Embedding Data
 *
 * n8n Code node: Place AFTER validation, BEFORE OpenAI embedding call.
 * Parses learning content into 4 sections for multi-field embeddings.
 *
 * Input: Learning payload with title, content, and metadata fields
 * Output: 4 text sections ready for embedding + original payload
 */

// Get the validated learning payload
const payload = $input.item.json;

const title = payload.title || 'Untitled';
const content = payload.content || '';

// --- Parse WHY section (problem context) ---
const whyMatch = content.match(/WHY:([\s\S]*?)(?=\nWHAT:|\n\nWHAT:|$)/i);
const problem = whyMatch ? whyMatch[1].trim() : content.substring(0, 500).trim();

// --- Parse WHAT+HOW sections (solution) ---
const whatMatch = content.match(/WHAT:([\s\S]*$)/i);
const solution = whatMatch ? whatMatch[1].trim() : content.trim();

// --- Compose context from metadata ---
const project = payload.project || 'Unknown';
const type = payload.type || 'Unknown';
const tags = Array.isArray(payload.tags) ? payload.tags :
             (typeof payload.tags === 'string' ? payload.tags.split(',').map(t => t.trim()) : []);
const devStream = Array.isArray(payload.dev_stream) ? payload.dev_stream :
                  (typeof payload.dev_stream === 'string' ? payload.dev_stream.split(',').map(d => d.trim()) : []);
const appliesTo = payload.applies_to || 'General';
const scope = payload.scope || 'Project-Specific';
const discipline = Array.isArray(payload.discipline) ? payload.discipline :
                   (typeof payload.discipline === 'string' ? payload.discipline.split(',').map(d => d.trim()) : []);

const contextParts = [
  `Project: ${project}`,
  `Type: ${type}`,
  `Scope: ${scope}`
];

if (tags.length > 0) {
  contextParts.push(`Tags: ${tags.join(', ')}`);
}
if (devStream.length > 0) {
  contextParts.push(`Dev Stream: ${devStream.join(', ')}`);
}
if (discipline.length > 0) {
  contextParts.push(`Discipline: ${discipline.join(', ')}`);
}
if (appliesTo && appliesTo !== 'General') {
  contextParts.push(`Applies to: ${appliesTo}`);
}

const contextText = contextParts.join('. ') + '.';

// --- Truncate to avoid token limits ---
const maxTitleLen = 500;
const maxSectionLen = 2000;
const maxContextLen = 1000;

return [{
  json: {
    // Original payload (pass through)
    ...payload,

    // Parsed sections for embedding
    embedding_sections: {
      title: title.substring(0, maxTitleLen),
      problem: problem.substring(0, maxSectionLen),
      solution: solution.substring(0, maxSectionLen),
      context: contextText.substring(0, maxContextLen)
    },

    // Array format for single OpenAI API call
    texts_to_embed: [
      title.substring(0, maxTitleLen),
      problem.substring(0, maxSectionLen),
      solution.substring(0, maxSectionLen),
      contextText.substring(0, maxContextLen)
    ]
  }
}];
