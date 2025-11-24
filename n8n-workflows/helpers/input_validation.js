/**
 * Input Validation Functions for n8n
 *
 * Usage: Paste relevant function into n8n Function nodes
 * for each webhook endpoint
 */

/**
 * Validate Capture Learning Input
 */
function validateCaptureLearning(input) {
  const errors = [];

  // Required fields
  if (!input.project || typeof input.project !== 'string' || input.project.trim() === '') {
    errors.push('project is required and must be a non-empty string');
  }

  if (!input.title || typeof input.title !== 'string') {
    errors.push('title is required and must be a string');
  } else if (input.title.length < 5 || input.title.length > 200) {
    errors.push('title must be between 5 and 200 characters');
  }

  if (!input.content || typeof input.content !== 'string') {
    errors.push('content is required and must be a string');
  } else if (input.content.length < 10 || input.content.length > 50000) {
    errors.push('content must be between 10 and 50,000 characters');
  }

  // Optional field validations
  const validTypes = ['Pattern', 'Solution', 'Error', 'Decision', 'Insight', 'Anti-Pattern', 'Best Practice'];
  if (input.type && !validTypes.includes(input.type)) {
    errors.push(`type must be one of: ${validTypes.join(', ')}`);
  }

  const validDevStreams = ['Back-end', 'Front-end', 'UI/UX', 'n8n', 'Database', 'API', 'DevOps', 'Architecture', 'Performance', 'Security'];
  if (input.dev_stream && Array.isArray(input.dev_stream)) {
    const invalidStreams = input.dev_stream.filter(s => !validDevStreams.includes(s));
    if (invalidStreams.length > 0) {
      errors.push(`Invalid dev_stream values: ${invalidStreams.join(', ')}`);
    }
  }

  const validConfidence = ['High', 'Medium', 'Low'];
  if (input.confidence && !validConfidence.includes(input.confidence)) {
    errors.push(`confidence must be one of: ${validConfidence.join(', ')}`);
  }

  if (errors.length > 0) {
    throw new Error(`Validation failed:\n${errors.join('\n')}`);
  }

  return true;
}

/**
 * Validate Update Learning Input
 */
function validateUpdateLearning(input) {
  const errors = [];

  // Required field
  if (!input.learning_id || typeof input.learning_id !== 'string' || input.learning_id.trim() === '') {
    errors.push('learning_id is required and must be a non-empty string');
  }

  // At least one field to update must be provided
  const updateFields = ['title', 'content', 'type', 'dev_stream', 'tags', 'confidence', 'status', 'context', 'ai_accepted'];
  const hasUpdates = updateFields.some(field => input[field] !== undefined);

  if (!hasUpdates) {
    errors.push('At least one field to update must be provided');
  }

  // Status transition validation
  const validStatuses = ['Validated', 'Hypothesis', 'Deprecated'];
  if (input.status && !validStatuses.includes(input.status)) {
    errors.push(`status must be one of: ${validStatuses.join(', ')}`);
  }

  if (errors.length > 0) {
    throw new Error(`Validation failed:\n${errors.join('\n')}`);
  }

  return true;
}

/**
 * Validate Query Learnings Input
 */
function validateQueryLearnings(input) {
  const errors = [];

  // Required field
  if (!input.query || typeof input.query !== 'string') {
    errors.push('query is required and must be a string');
  } else if (input.query.length < 3 || input.query.length > 500) {
    errors.push('query must be between 3 and 500 characters');
  }

  // Optional filters validation
  if (input.filters && typeof input.filters === 'object') {
    const validDevStreams = ['Back-end', 'Front-end', 'UI/UX', 'n8n', 'Database', 'API', 'DevOps', 'Architecture', 'Performance', 'Security'];
    if (input.filters.dev_stream && !validDevStreams.includes(input.filters.dev_stream)) {
      errors.push(`filters.dev_stream must be one of: ${validDevStreams.join(', ')}`);
    }

    const validStatuses = ['Validated', 'Hypothesis', 'Deprecated'];
    if (input.filters.status && !validStatuses.includes(input.filters.status)) {
      errors.push(`filters.status must be one of: ${validStatuses.join(', ')}`);
    }
  }

  if (errors.length > 0) {
    throw new Error(`Validation failed:\n${errors.join('\n')}`);
  }

  return true;
}

/**
 * Validate Create Session Input
 */
function validateCreateSession(input) {
  const errors = [];

  // Required fields
  if (!input.projects || !Array.isArray(input.projects) || input.projects.length === 0) {
    errors.push('projects is required and must be a non-empty array');
  }

  if (!input.goals || typeof input.goals !== 'string') {
    errors.push('goals is required and must be a string');
  } else if (input.goals.length < 10 || input.goals.length > 1000) {
    errors.push('goals must be between 10 and 1,000 characters');
  }

  // Optional field validation
  const validAITypes = ['Claude', 'Gemini', 'Other'];
  if (input.ai_type && !validAITypes.includes(input.ai_type)) {
    errors.push(`ai_type must be one of: ${validAITypes.join(', ')}`);
  }

  if (errors.length > 0) {
    throw new Error(`Validation failed:\n${errors.join('\n')}`);
  }

  return true;
}

/**
 * Validate End Session Input
 */
function validateEndSession(input) {
  const errors = [];

  // Required field
  if (!input.session_id || typeof input.session_id !== 'string' || input.session_id.trim() === '') {
    errors.push('session_id is required and must be a non-empty string');
  }

  if (errors.length > 0) {
    throw new Error(`Validation failed:\n${errors.join('\n')}`);
  }

  return true;
}

/**
 * USAGE IN N8N:
 *
 * 1. Add a Function node immediately after each Webhook Trigger
 * 2. Paste the appropriate validation function
 * 3. Call the validation function:
 *
 * const input = $input.item.json;
 *
 * try {
 *   validateCaptureLearning(input); // Or appropriate validator
 *   return [input]; // Pass through if valid
 * } catch (error) {
 *   // Respond with error
 *   return [{
 *     json: {
 *       success: false,
 *       error: error.message,
 *       timestamp: new Date().toISOString()
 *     }
 *   }];
 * }
 */

// Export for use in n8n
// In n8n, just paste the relevant function and call it as shown above
