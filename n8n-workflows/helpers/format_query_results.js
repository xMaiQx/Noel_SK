// Format query results - Updated to include project_name
const searchResults = $input.all();

return [{
    json: {
        success: true,
        count: searchResults.length,
        results: searchResults.map(item => ({
            learning_id: item.json.learning_id,
            content: item.json.content,
            similarity: item.json.similarity,
            metadata: item.json.metadata,
            project_name: item.json.project_name  // Add the new field
        }))
    }
}];
