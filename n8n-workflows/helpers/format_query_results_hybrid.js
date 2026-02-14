/**
 * Format Hybrid Query Results
 *
 * n8n Code node: Place AFTER the Supabase RPC call to match_learnings_hybrid.
 * Formats results for both agent consumption and human UI display.
 *
 * Returns:
 *   - Human-readable fields (title, project, type, excerpt)
 *   - Per-field similarity breakdown (for UI "why this matched")
 *   - Full content and metadata (for agents)
 */

const searchResults = $input.all();

// Handle empty results
if (!searchResults || searchResults.length === 0) {
  return [{
    json: {
      success: true,
      count: 0,
      results: [],
      message: "No matching learnings found"
    }
  }];
}

// Format each result
const formattedResults = searchResults.map((item, index) => {
  const r = item.json;
  const metadata = r.metadata || {};

  // Extract content excerpt for UI preview (first 300 chars)
  const content = r.content || '';
  const excerpt = content.length > 300
    ? content.substring(0, 300) + '...'
    : content;

  return {
    // Ranking
    rank: index + 1,

    // Human-readable identifiers
    learning_id: r.learning_id,
    title: metadata.title || 'Untitled',
    project: metadata.project || 'Unknown',
    type: metadata.type || 'Unknown',

    // UI preview
    content_excerpt: excerpt,

    // Per-field similarity breakdown (for UI "why this matched" display)
    similarity: {
      title: parseFloat((r.title_similarity || 0).toFixed(3)),
      problem: parseFloat((r.problem_similarity || 0).toFixed(3)),
      solution: parseFloat((r.solution_similarity || 0).toFixed(3)),
      context: parseFloat((r.context_similarity || 0).toFixed(3)),
      text_boost: parseFloat((r.text_match_boost || 0).toFixed(3))
    },

    // Combined score (primary ranking metric)
    combined_score: parseFloat((r.combined_score || 0).toFixed(3)),

    // Determine which field drove the match (for UI badges)
    match_reason: determineMatchReason(r),

    // Full content for agent processing
    content: content,

    // Full metadata for agent processing
    metadata: metadata
  };
});

// Sort by combined_score descending (should already be sorted, but ensure)
formattedResults.sort((a, b) => b.combined_score - a.combined_score);

return [{
  json: {
    success: true,
    count: formattedResults.length,
    results: formattedResults
  }
}];

/**
 * Determine which field primarily drove the match
 * Returns a human-readable reason for UI display
 */
function determineMatchReason(r) {
  const scores = {
    title: r.title_similarity || 0,
    problem: r.problem_similarity || 0,
    solution: r.solution_similarity || 0,
    context: r.context_similarity || 0
  };

  // Find the highest scoring field
  let maxField = 'title';
  let maxScore = scores.title;

  for (const [field, score] of Object.entries(scores)) {
    if (score > maxScore) {
      maxScore = score;
      maxField = field;
    }
  }

  // Check if text boost was significant
  const textBoost = r.text_match_boost || 0;
  if (textBoost >= 0.3) {
    return 'Exact title match';
  } else if (textBoost >= 0.15) {
    return 'Keyword in content';
  }

  // Map field names to human-readable reasons
  const fieldReasons = {
    title: 'Title match',
    problem: 'Similar problem/error',
    solution: 'Related solution',
    context: 'Project/technology context'
  };

  return fieldReasons[maxField] || 'Semantic similarity';
}
