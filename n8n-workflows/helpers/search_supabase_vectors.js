// Parse Supabase RPC Response
// Add this Code node AFTER the "Search Supabase Vectors" HTTP Request node
// to properly parse the response

const httpResponse = $input.item.json;

// Check if response has a body property (some HTTP nodes wrap the response)
const results = httpResponse.body || httpResponse;

// If results is already an array, map it
if (Array.isArray(results)) {
  return results.map(item => ({
    json: {
      learning_id: item.learning_id,
      content: item.content,
      metadata: item.metadata,
      similarity: item.similarity,
      project_name: item.project_name
    }
  }));
}

// If it's a single object that contains the results
if (results.length !== undefined) {
  return [{
    json: results
  }];
}

// Fallback: just return what we got
return [{
  json: httpResponse
}];
