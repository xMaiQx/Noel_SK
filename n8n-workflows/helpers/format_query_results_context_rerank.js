/**
 * Format Query Results with Context Re-Ranking
 *
 * n8n Code node: Replaces "Format Query Results" AFTER the Supabase RPC call.
 * When a `context` object is present in the original query, applies a boost
 * (max +0.15) based on keyword overlap between context signals and result metadata.
 *
 * Backward compatible: Without `context`, boost is 0 and output is identical
 * to format_query_results_hybrid.js.
 *
 * Context boost rules:
 *   - Branch keyword in title/content: +0.06 per keyword (max 2 keywords = +0.12)
 *   - Tag match: +0.02
 *   - Project match: +0.03
 *   - Total cap: +0.15
 */

const searchResults = $input.all();
const prepareNode = $('Prepare Vector Search');
const context = prepareNode ? prepareNode.item.json.context : null;

// Handle empty results
if (!searchResults || searchResults.length === 0) {
  return [{
    json: {
      success: true,
      count: 0,
      results: [],
      context_applied: !!context,
      message: "No matching learnings found"
    }
  }];
}

const BOOST_CAP = 0.15;
const BRANCH_KEYWORD_BOOST = 0.06;
const BRANCH_KEYWORD_MAX = 2;
const TAG_MATCH_BOOST = 0.02;
const PROJECT_MATCH_BOOST = 0.03;

/**
 * Calculate context boost for a single result
 */
function calculateContextBoost(result, ctx) {
  if (!ctx) return { boost: 0, applied: false, details: {} };

  let totalBoost = 0;
  const details = {};

  const metadata = result.metadata || {};
  const title = (metadata.title || '').toLowerCase();
  const content = (result.content || '').toLowerCase();
  const tags = (metadata.tags || []).map(t => t.toLowerCase());
  const project = (metadata.project || '').toLowerCase();

  // Branch keyword matches (max 2 keywords, +0.06 each)
  const branchKeywords = (ctx.branch_keywords || []).map(k => k.toLowerCase());
  let keywordMatches = 0;
  const matchedKeywords = [];

  for (const kw of branchKeywords) {
    if (keywordMatches >= BRANCH_KEYWORD_MAX) break;
    if (title.includes(kw) || content.includes(kw)) {
      keywordMatches++;
      matchedKeywords.push(kw);
      totalBoost += BRANCH_KEYWORD_BOOST;
    }
  }
  if (matchedKeywords.length > 0) {
    details.branch_keywords = matchedKeywords;
  }

  // Tag match: any tech_signal or domain_signal matches a tag
  const contextSignals = [
    ...(ctx.tech_signals || []),
    ...(ctx.domain_signals || [])
  ].map(s => s.toLowerCase());

  const tagMatch = contextSignals.some(sig => tags.includes(sig));
  if (tagMatch) {
    totalBoost += TAG_MATCH_BOOST;
    details.tag_match = true;
  }

  // Project match
  const contextProject = (ctx.project || '').toLowerCase();
  if (contextProject && project === contextProject) {
    totalBoost += PROJECT_MATCH_BOOST;
    details.project_match = true;
  }

  // Apply cap
  totalBoost = Math.min(totalBoost, BOOST_CAP);

  return {
    boost: parseFloat(totalBoost.toFixed(3)),
    applied: totalBoost > 0,
    details
  };
}

/**
 * Determine which field primarily drove the match
 */
function determineMatchReason(r) {
  const scores = {
    title: r.title_similarity || 0,
    problem: r.problem_similarity || 0,
    solution: r.solution_similarity || 0,
    context: r.context_similarity || 0
  };

  let maxField = 'title';
  let maxScore = scores.title;

  for (const [field, score] of Object.entries(scores)) {
    if (score > maxScore) {
      maxScore = score;
      maxField = field;
    }
  }

  const textBoost = r.text_match_boost || 0;
  if (textBoost >= 0.3) return 'Exact title match';
  if (textBoost >= 0.15) return 'Keyword in content';

  const fieldReasons = {
    title: 'Title match',
    problem: 'Similar problem/error',
    solution: 'Related solution',
    context: 'Project/technology context'
  };

  return fieldReasons[maxField] || 'Semantic similarity';
}

// Format each result with context boost
const formattedResults = searchResults.map((item, index) => {
  const r = item.json;
  const metadata = r.metadata || {};

  const content = r.content || '';
  const excerpt = content.length > 300
    ? content.substring(0, 300) + '...'
    : content;

  const baseScore = parseFloat((r.combined_score || 0).toFixed(3));
  const ctxBoost = calculateContextBoost(r, context);

  return {
    rank: index + 1,
    learning_id: r.learning_id,
    title: metadata.title || 'Untitled',
    project: metadata.project || 'Unknown',
    type: metadata.type || 'Unknown',
    content_excerpt: excerpt,
    similarity: {
      title: parseFloat((r.title_similarity || 0).toFixed(3)),
      problem: parseFloat((r.problem_similarity || 0).toFixed(3)),
      solution: parseFloat((r.solution_similarity || 0).toFixed(3)),
      context: parseFloat((r.context_similarity || 0).toFixed(3)),
      text_boost: parseFloat((r.text_match_boost || 0).toFixed(3))
    },
    combined_score: baseScore,
    context_boost: ctxBoost.boost,
    boost_applied: ctxBoost.applied,
    boosted_score: parseFloat((baseScore + ctxBoost.boost).toFixed(3)),
    match_reason: determineMatchReason(r),
    content: content,
    metadata: metadata
  };
});

// Re-sort by boosted_score descending
formattedResults.sort((a, b) => b.boosted_score - a.boosted_score);

// Re-assign ranks after sort
formattedResults.forEach((r, i) => { r.rank = i + 1; });

return [{
  json: {
    success: true,
    count: formattedResults.length,
    context_applied: !!context,
    results: formattedResults
  }
}];
