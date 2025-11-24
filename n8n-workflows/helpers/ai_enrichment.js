/**
 * AI Enrichment Prompt for Learning Categorization
 *
 * Usage: Paste into n8n OpenAI node or Function node
 * to generate the enrichment prompt
 */

/**
 * Generate AI enrichment prompt for a learning
 */
function generateEnrichmentPrompt(title, content, context = '') {
  const prompt = `You are a learning categorization system for a development knowledge repository. Analyze the following development learning and suggest metadata.

Learning Title:
"""
${title}
"""

Learning Content:
"""
${content}
"""

${context ? `Context:\n"""\n${context}\n"""\n` : ''}

Your task:
1. Suggest 1-3 development streams from this list: Back-end, Front-end, UI/UX, n8n, Database, API, DevOps, Architecture, Performance, Security
2. Suggest the most appropriate learning type from: Pattern, Solution, Error, Decision, Insight, Anti-Pattern, Best Practice
3. Extract 3-5 relevant tags (technologies, patterns, concepts, frameworks)
4. Assess your confidence in these suggestions: high, medium, or low

Respond ONLY with valid JSON in this exact format:
{
  "dev_streams": ["stream1", "stream2"],
  "type": "suggested type",
  "tags": ["tag1", "tag2", "tag3"],
  "confidence": "high|medium|low"
}

Do not include any explanations or text outside the JSON object.`;

  return prompt;
}

/**
 * Parse AI enrichment response
 */
function parseEnrichmentResponse(aiResponse) {
  try {
    // Clean the response (remove markdown code blocks if present)
    let cleanResponse = aiResponse.trim();

    if (cleanResponse.startsWith('```json')) {
      cleanResponse = cleanResponse.substring(7);
    }
    if (cleanResponse.startsWith('```')) {
      cleanResponse = cleanResponse.substring(3);
    }
    if (cleanResponse.endsWith('```')) {
      cleanResponse = cleanResponse.substring(0, cleanResponse.length - 3);
    }

    cleanResponse = cleanResponse.trim();

    // Parse JSON
    const parsed = JSON.parse(cleanResponse);

    // Validate structure
    if (!parsed.dev_streams || !Array.isArray(parsed.dev_streams)) {
      throw new Error('Invalid response: dev_streams must be an array');
    }
    if (!parsed.type || typeof parsed.type !== 'string') {
      throw new Error('Invalid response: type must be a string');
    }
    if (!parsed.tags || !Array.isArray(parsed.tags)) {
      throw new Error('Invalid response: tags must be an array');
    }
    if (!parsed.confidence || typeof parsed.confidence !== 'string') {
      throw new Error('Invalid response: confidence must be a string');
    }

    // Normalize confidence
    const confidenceMap = {
      'high': 'High',
      'medium': 'Medium',
      'low': 'Low'
    };
    parsed.confidence = confidenceMap[parsed.confidence.toLowerCase()] || 'Medium';

    return parsed;
  } catch (error) {
    console.error('Failed to parse AI enrichment response:', error.message);
    // Return default values on parse failure
    return {
      dev_streams: [],
      type: 'Insight',
      tags: [],
      confidence: 'Low',
      parse_error: error.message
    };
  }
}

/**
 * Merge AI suggestions with user-provided metadata
 * (Append, don't replace)
 */
function mergeMetadata(userProvided, aiSuggested) {
  const merged = { ...userProvided };

  // Merge dev_streams (append, deduplicate)
  if (aiSuggested.dev_streams && aiSuggested.dev_streams.length > 0) {
    const existingStreams = merged.dev_stream || [];
    merged.dev_stream = [...new Set([...existingStreams, ...aiSuggested.dev_streams])];
  }

  // Use AI type only if user didn't provide one
  if (!merged.type && aiSuggested.type) {
    merged.type = aiSuggested.type;
  }

  // Merge tags (append, deduplicate)
  if (aiSuggested.tags && aiSuggested.tags.length > 0) {
    const existingTags = merged.tags || [];
    merged.tags = [...new Set([...existingTags, ...aiSuggested.tags])];
  }

  // Use AI confidence only if user didn't provide one
  if (!merged.confidence && aiSuggested.confidence) {
    merged.confidence = aiSuggested.confidence;
  }

  return merged;
}

/**
 * USAGE IN N8N:
 *
 * === Option 1: Using OpenAI Chat Node ===
 *
 * 1. Add OpenAI Chat node after learning creation
 * 2. Model: gpt-4o-mini (cost-efficient)
 * 3. In "Messages" section, add User Message:
 *    Paste the output from generateEnrichmentPrompt() function
 *
 * 4. In next Function node, parse response:
 *
 * const aiResponse = $input.item.json.message.content;
 * const enrichment = parseEnrichmentResponse(aiResponse);
 *
 * const userProvided = {
 *   type: $json.type,
 *   dev_stream: $json.dev_stream,
 *   tags: $json.tags,
 *   confidence: $json.confidence
 * };
 *
 * const merged = mergeMetadata(userProvided, enrichment);
 *
 * return [{
 *   json: {
 *     ...$json,
 *     ...merged,
 *     ai_suggested: true,
 *     ai_enrichment: enrichment
 *   }
 * }];
 *
 * === Option 2: Using HTTP Request Node (OpenAI API) ===
 *
 * 1. Add Function node to generate prompt:
 * const prompt = generateEnrichmentPrompt(
 *   $json.title,
 *   $json.content,
 *   $json.context
 * );
 *
 * return [{
 *   json: {
 *     ...$json,
 *     enrichment_prompt: prompt
 *   }
 * }];
 *
 * 2. Add HTTP Request node:
 * - Method: POST
 * - URL: https://api.openai.com/v1/chat/completions
 * - Authentication: Use OpenAI credential
 * - Body:
 * {
 *   "model": "gpt-4o-mini",
 *   "messages": [
 *     {"role": "user", "content": "{{$json.enrichment_prompt}}"}
 *   ],
 *   "temperature": 0.3,
 *   "max_tokens": 500
 * }
 *
 * 3. Add Function node to parse (same as Option 1)
 */
