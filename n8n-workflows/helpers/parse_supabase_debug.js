// Debug: Let's see what we're actually receiving
const input = $input.item.json;

console.log("=== DEBUG: INPUT TO PARSE NODE ===");
console.log("Type:", typeof input);
console.log("Keys:", Object.keys(input));
console.log("Full input:", JSON.stringify(input, null, 2));

// Try to find the data in various possible locations
const possibleData = [
  input,
  input.body,
  input.data,
  input.json,
  input.response,
  input.result
];

for (const data of possibleData) {
  if (data && Array.isArray(data)) {
    console.log("Found array at:", data);
    return data.map(item => ({
      json: {
        learning_id: item.learning_id,
        content: item.content,
        metadata: item.metadata,
        similarity: item.similarity,
        project_name: item.project_name
      }
    }));
  }
}

// If nothing found, return the input as-is to see it in the output
return [{ json: input }];
