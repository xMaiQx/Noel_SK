/**
 * Log Context Signal - Validate and prepare for Supabase insert
 *
 * n8n Code node: Place AFTER Route Endpoint switch (output #13 for log_context_signal).
 * Validates signal_type and signal_data, builds Supabase insert payload.
 *
 * Wiring: Route Endpoint -> Log Context Signal Logic -> IF Signal Valid
 *   true  -> Insert Context Signal -> Format Signal Response -> Respond to Webhook
 *   false -> Format Validation Error -> Respond to Webhook
 *
 * Input (from Parse Request payload):
 *   - signal_type: string (required, must be one of allowed types)
 *   - signal_data: object (required)
 *   - session_id: string (optional)
 *   - extracted_keywords: string[] (optional)
 *   - query_generated: string (optional)
 *
 * Output:
 *   - supabase_body: object ready for POST to /rest/v1/context_signals
 *   - is_valid: boolean
 *   - error: string (if invalid)
 */

const input = $('Parse Request').first().json.payload;

const VALID_SIGNAL_TYPES = [
  'git_branch',
  'recent_files',
  'test_failure',
  'file_creation',
  'technology_detected',
  'custom'
];

// Validate signal_type
const signalType = input.signal_type;
if (!signalType || !VALID_SIGNAL_TYPES.includes(signalType)) {
  return [{
    json: {
      is_valid: false,
      error: `Invalid signal_type: "${signalType}". Must be one of: ${VALID_SIGNAL_TYPES.join(', ')}`,
      http_status: 400
    }
  }];
}

// Validate signal_data
const signalData = input.signal_data;
if (!signalData || typeof signalData !== 'object' || Array.isArray(signalData)) {
  return [{
    json: {
      is_valid: false,
      error: 'signal_data is required and must be a JSON object',
      http_status: 400
    }
  }];
}

// Build Supabase insert payload matching context_signals table schema
const supabaseBody = {
  signal_type: signalType,
  signal_data: signalData,
  results_surfaced: 0,
  results_helpful: 0
};

// Optional fields
if (input.session_id) {
  supabaseBody.session_id = input.session_id;
}

if (Array.isArray(input.extracted_keywords) && input.extracted_keywords.length > 0) {
  supabaseBody.extracted_keywords = input.extracted_keywords;
}

if (input.query_generated) {
  supabaseBody.query_generated = input.query_generated;
}

return [{
  json: {
    is_valid: true,
    supabase_body: supabaseBody
  }
}];
