/**
 * Parse OpenAI Embeddings Response
 *
 * n8n Code node: Place AFTER the OpenAI HTTP Request node.
 * Extracts 4 embeddings from the array response and maps to column names.
 *
 * OpenAI API returns embeddings in the same order as input array:
 *   data[0] → title, data[1] → problem, data[2] → solution, data[3] → context
 */

const prevData = $('Prepare Structured Embeddings').item.json;
const openaiResponse = $input.item.json;

// Extract embeddings array from OpenAI response
const embeddings = openaiResponse.data || [];

if (embeddings.length < 4) {
  throw new Error(`Expected 4 embeddings, got ${embeddings.length}`);
}

// Sort by index to ensure correct order (OpenAI may return out of order)
embeddings.sort((a, b) => a.index - b.index);

// Extract embedding vectors
const titleEmbedding = embeddings[0].embedding;
const problemEmbedding = embeddings[1].embedding;
const solutionEmbedding = embeddings[2].embedding;
const contextEmbedding = embeddings[3].embedding;

return [{
  json: {
    // Pass through original payload
    ...prevData,

    // Structured embeddings ready for Supabase
    embeddings: {
      title_embedding: titleEmbedding,
      problem_embedding: problemEmbedding,
      solution_embedding: solutionEmbedding,
      context_embedding: contextEmbedding
    }
  }
}];
