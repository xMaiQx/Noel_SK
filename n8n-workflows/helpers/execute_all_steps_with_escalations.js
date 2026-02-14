// Execute All Steps - WITH ESCALATION SUPPORT
// Workflow: Noel Mission Engine (L1N50HpSI56N5WJU)
//
// This version adds:
// 1. [ESCALATION] marker detection in agent output
// 2. Writing escalations to Supabase
// 3. Polling for user response (5s intervals)
// 4. Timeout handling with default responses

const plan = $input.first().json;
const missionId = plan.mission_id;
const missionName = plan.mission_name;
const steps = plan.steps;
const totalSteps = plan.total_steps;

const BRIDGE_URL = "http://host.docker.internal:3456/execute";

const SB_URL = "https://sladetzgpogodrqwfamy.supabase.co";
const SB_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsYWRldHpncG9nb2RycXdmYW15Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU0NjEwNDcsImV4cCI6MjA2MTAzNzA0N30.0lgfAKOCwRHSKI5NjhIQz-nAh0ej44N6AZbHlo8WzAE";
const sbHeaders = {
  "apikey": SB_KEY,
  "Authorization": "Bearer " + SB_KEY,
  "Content-Type": "application/json",
  "Prefer": "return=representation"
};

// ==========================================
// ESCALATION HELPERS
// ==========================================

/**
 * Parse [ESCALATION] markers from agent output
 * Returns null if no escalation found, otherwise returns parsed escalation
 */
function parseEscalation(output) {
  if (!output) return null;

  // Match [ESCALATION - Agent Name] ... content
  const escalationMatch = output.match(/\[ESCALATION[^\]]*\]([\s\S]*?)(?=\[\/ESCALATION\]|$)/i);
  if (!escalationMatch) return null;

  const escalationText = escalationMatch[1];

  // Parse type
  const typeMatch = escalationText.match(/Type:\s*(checkpoint|question|broadcast)/i);
  // Parse message
  const messageMatch = escalationText.match(/Message:\s*([\s\S]*?)(?=Options:|Timeout:|$)/i);
  // Parse options
  const optionsMatch = escalationText.match(/Options:\s*([\s\S]*?)(?=Timeout:|$)/i);
  // Parse timeout
  const timeoutMatch = escalationText.match(/Timeout:\s*(\d+|wait indefinitely)/i);

  // Parse options into array if present
  let options = null;
  if (optionsMatch) {
    const optionsText = optionsMatch[1].trim();
    // Parse numbered options like "1. "Approve"" or bullet points
    const optionLines = optionsText.split('\n').filter(l => l.trim());
    options = optionLines.map(line => {
      const cleaned = line.replace(/^\s*[\d\-\*\.]+\s*["']?/, '').replace(/["']?\s*$/, '');
      return { label: cleaned, value: cleaned };
    });
  }

  return {
    type: typeMatch ? typeMatch[1].toLowerCase() : 'question',
    message: messageMatch ? messageMatch[1].trim() : escalationText.trim(),
    options: options,
    timeout_seconds: timeoutMatch && timeoutMatch[1] !== 'wait indefinitely'
      ? parseInt(timeoutMatch[1])
      : null // null = wait indefinitely
  };
}

/**
 * Write escalation to Supabase and return escalation_id
 */
async function writeEscalation(helpers, nodeId, agentName, escalation) {
  const expires_at = escalation.timeout_seconds
    ? new Date(Date.now() + (escalation.timeout_seconds * 1000)).toISOString()
    : null;

  const response = await helpers.httpRequest({
    url: SB_URL + "/rest/v1/escalations",
    method: "POST",
    headers: { ...sbHeaders, "Prefer": "return=representation" },
    body: {
      mission_id: missionId,
      node_id: nodeId,
      agent_id: agentName,
      type: escalation.type,
      message: escalation.message,
      options: escalation.options,
      timeout_seconds: escalation.timeout_seconds,
      expires_at: expires_at,
      status: 'pending'
    }
  });

  return response[0]?.escalation_id;
}

/**
 * Poll for escalation response
 * Returns { response, timed_out, status }
 */
async function waitForEscalationResponse(helpers, escalationId, maxWaitMs = 300000) {
  const POLL_INTERVAL_MS = 5000; // 5 seconds
  const startTime = Date.now();

  while (true) {
    // Check escalation status
    const result = await helpers.httpRequest({
      url: SB_URL + "/rest/v1/escalations?escalation_id=eq." + escalationId + "&select=status,response,default_response,expires_at",
      method: "GET",
      headers: sbHeaders
    });

    const escalation = result[0];
    if (!escalation) {
      return { response: null, timed_out: true, status: 'error' };
    }

    // User responded
    if (escalation.status === 'responded') {
      return { response: escalation.response, timed_out: false, status: 'responded' };
    }

    // Already timed out or auto-continued
    if (escalation.status === 'timed_out' || escalation.status === 'auto_continued') {
      return {
        response: escalation.response || escalation.default_response,
        timed_out: true,
        status: escalation.status
      };
    }

    // Check if we've waited too long (fallback max wait)
    if (maxWaitMs && (Date.now() - startTime) > maxWaitMs) {
      // Mark as timed out in DB
      await helpers.httpRequest({
        url: SB_URL + "/rest/v1/escalations?escalation_id=eq." + escalationId,
        method: "PATCH",
        headers: sbHeaders,
        body: { status: 'timed_out', responded_at: new Date().toISOString() }
      });
      return { response: null, timed_out: true, status: 'poll_timeout' };
    }

    // Wait before next poll
    await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL_MS));
  }
}

// ==========================================
// MAIN EXECUTION LOOP
// ==========================================

// Initialize all steps as pending
const stepResults = steps.map(s => ({
  node_id: s.node_id, label: s.label, status: 'pending', model: s.model,
  duration_ms: null, input_tokens: null, output_tokens: null,
  cost_usd: null, output: null, output_preview: null, error: null, tools: s.tools || [],
  cache_creation_tokens: null, cache_read_tokens: null,
  escalation_id: null, escalation_response: null // NEW: Track escalations
}));

// Write initial results to Supabase (triggers Realtime for frontend)
await this.helpers.httpRequest({
  url: SB_URL + "/rest/v1/missions?id=eq." + missionId,
  method: "PATCH",
  headers: sbHeaders,
  body: { results: { status: 'running', steps: stepResults, current_step: 0, total_steps: totalSteps, mission_name: missionName } }
});

const previousOutputs = [];

for (let i = 0; i < steps.length; i++) {
  const step = steps[i];
  stepResults[i].status = 'running';

  // Update Supabase with running status
  await this.helpers.httpRequest({
    url: SB_URL + "/rest/v1/missions?id=eq." + missionId,
    method: "PATCH",
    headers: sbHeaders,
    body: { results: { status: 'running', steps: stepResults, current_step: i, total_steps: totalSteps, mission_name: missionName } }
  });

  // Build prompt with escalation instructions
  let systemPrompt = '';
  if (step.node_type === 'teamLeader') {
    systemPrompt = 'You are a Team Leader AI orchestrating mission "' + missionName + '". Analyze the objective and coordinate the team.';
  } else if (step.node_type === 'specialist') {
    systemPrompt = 'You are a Specialist AI agent. Use your assigned tools and expertise to complete your task.';
  } else if (step.node_type === 'successCriteria') {
    systemPrompt = 'You are a Quality Validator. Evaluate whether the mission results meet the success criteria.';
  } else {
    systemPrompt = 'You are an AI agent executing step "' + step.label + '" in mission "' + missionName + '".';
  }

  // Add escalation instructions to system prompt
  systemPrompt += `

## Escalation Protocol
If you need user input, approval, or want to report status, use this format:

[ESCALATION - ${step.label}]
Type: checkpoint | question | broadcast
Message: <your message to the user>
Options: <optional numbered list of choices>
Timeout: <seconds or "wait indefinitely">
[/ESCALATION]

- Use "checkpoint" for approval gates (mission will wait)
- Use "question" for clarifications (can timeout with default)
- Use "broadcast" for status updates (no wait)`;

  let context = '';
  if (previousOutputs.length > 0) {
    context = '\n\n## Previous Step Results\n';
    for (const prev of previousOutputs) {
      context += '\n### ' + prev.label + ' (' + prev.status + ')\n' + (prev.output || prev.error || 'No output') + '\n';
      // Include escalation responses if any
      if (prev.escalation_response) {
        context += 'User Response: ' + prev.escalation_response + '\n';
      }
    }
  }

  const fullPrompt = systemPrompt + '\n\n## Your Task\n' + (step.prompt || step.label)
    + (step.tools?.length ? '\n\n## Available Tools\n' + step.tools.join(', ') : '')
    + (step.criteria ? '\n\n## Success Criteria\n' + step.criteria : '')
    + context + '\n\nProvide a clear, actionable response.';

  // Call Claude via HTTP bridge
  let bridgeResponse;
  try {
    bridgeResponse = await this.helpers.httpRequest({
      url: BRIDGE_URL,
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: { prompt: fullPrompt, max_turns: 3, output_format: "json" },
      timeout: 180000
    });
  } catch (e) {
    bridgeResponse = { stdout: '', stderr: e.message || 'Bridge request failed', exitCode: 1, duration_ms: 0 };
  }

  const stdout = bridgeResponse.stdout || '';
  const stderr = bridgeResponse.stderr || '';
  const exitCode = bridgeResponse.exitCode ?? 0;
  const elapsed = bridgeResponse.duration_ms || 0;

  // Parse result
  let result = {
    node_id: step.node_id, label: step.label,
    status: exitCode === 0 ? 'success' : 'error',
    model: step.model, output: '', output_preview: '',
    error: null, input_tokens: 0, output_tokens: 0,
    cost_usd: 0, duration_ms: elapsed, tools: step.tools || [],
    cache_creation_tokens: 0, cache_read_tokens: 0,
    escalation_id: null, escalation_response: null
  };

  try {
    if (stdout.trim()) {
      const parsed = JSON.parse(stdout);
      result.output = parsed.result || parsed.content || JSON.stringify(parsed);
      result.output_preview = result.output.substring(0, 200);
      result.input_tokens = parsed.usage?.input_tokens || 0;
      result.output_tokens = parsed.usage?.output_tokens || 0;
      result.cache_creation_tokens = parsed.usage?.cache_creation_input_tokens || 0;
      result.cache_read_tokens = parsed.usage?.cache_read_input_tokens || 0;
      result.cost_usd = parsed.total_cost_usd || parsed.cost_usd || 0;
      result.duration_ms = parsed.duration_ms || elapsed;
      result.model = parsed.model || step.model;
      if (parsed.is_error) {
        result.status = 'error';
        result.error = parsed.result || 'Claude returned an error';
      }
    }
  } catch (e) {
    result.output = stdout;
    result.output_preview = stdout.substring(0, 200);
  }

  if (exitCode !== 0 && !result.error) {
    result.error = stderr || 'Command failed with exit code ' + exitCode;
    result.status = 'error';
  }

  // ==========================================
  // ESCALATION DETECTION & HANDLING
  // ==========================================
  const escalation = parseEscalation(result.output);

  if (escalation && escalation.type !== 'broadcast') {
    // Update status to show waiting for user
    stepResults[i] = { ...result, status: 'waiting_user' };
    await this.helpers.httpRequest({
      url: SB_URL + "/rest/v1/missions?id=eq." + missionId,
      method: "PATCH",
      headers: sbHeaders,
      body: {
        results: {
          status: 'waiting_user',
          steps: stepResults,
          current_step: i,
          total_steps: totalSteps,
          mission_name: missionName,
          pending_escalation: true
        }
      }
    });

    // Write escalation to DB
    const escalationId = await writeEscalation(
      this.helpers,
      step.node_id,
      step.label,
      escalation
    );
    result.escalation_id = escalationId;

    // Poll for response (max 5 minutes, or custom timeout)
    const maxWait = escalation.timeout_seconds
      ? escalation.timeout_seconds * 1000
      : 300000; // 5 min default

    const escalationResult = await waitForEscalationResponse(
      this.helpers,
      escalationId,
      maxWait
    );

    result.escalation_response = escalationResult.response;

    if (escalationResult.timed_out && !escalationResult.response) {
      // No default response and timed out - mark step as needs attention
      result.status = 'timeout';
      result.error = 'Escalation timed out without response';
    }
  } else if (escalation && escalation.type === 'broadcast') {
    // Broadcast: Write to DB but don't wait
    const escalationId = await writeEscalation(
      this.helpers,
      step.node_id,
      step.label,
      escalation
    );
    result.escalation_id = escalationId;
    // Mark as auto-continued immediately
    await this.helpers.httpRequest({
      url: SB_URL + "/rest/v1/escalations?escalation_id=eq." + escalationId,
      method: "PATCH",
      headers: sbHeaders,
      body: { status: 'auto_continued', responded_at: new Date().toISOString() }
    });
  }
  // ==========================================

  stepResults[i] = result;
  previousOutputs.push({
    label: result.label,
    status: result.status,
    output: result.output_preview,
    error: result.error,
    escalation_response: result.escalation_response
  });

  // Update Supabase with step result
  await this.helpers.httpRequest({
    url: SB_URL + "/rest/v1/missions?id=eq." + missionId,
    method: "PATCH",
    headers: sbHeaders,
    body: {
      results: {
        status: 'running',
        steps: stepResults,
        current_step: i + 1,
        total_steps: totalSteps,
        mission_name: missionName,
        pending_escalation: false
      }
    }
  });

  // === SUBSCRIPTION USAGE TRACKING ===
  try {
    await this.helpers.httpRequest({
      url: SB_URL + "/rest/v1/rpc/log_subscription_usage",
      method: "POST",
      headers: sbHeaders,
      body: {
        p_model: result.model || step.model || 'unknown',
        p_input_tokens: result.input_tokens || 0,
        p_output_tokens: result.output_tokens || 0,
        p_cache_creation_tokens: result.cache_creation_tokens || 0,
        p_cache_read_tokens: result.cache_read_tokens || 0
      }
    });
  } catch (e) {
    // Non-blocking
  }

  // === PHASE 9: Log tool execution for XP ===
  if (step.tools && step.tools.length > 0) {
    for (const toolName of step.tools) {
      try {
        const toolLookup = await this.helpers.httpRequest({
          url: SB_URL + "/rest/v1/tools?name=eq." + encodeURIComponent(toolName) + "&select=id",
          method: "GET",
          headers: sbHeaders
        });
        if (toolLookup && toolLookup.length > 0) {
          await this.helpers.httpRequest({
            url: SB_URL + "/rest/v1/rpc/log_tool_execution",
            method: "POST",
            headers: sbHeaders,
            body: {
              p_tool_id: toolLookup[0].id,
              p_status: result.status,
              p_model: result.model || null,
              p_mission_id: missionId,
              p_agent_name: step.label || null,
              p_duration_ms: result.duration_ms || null,
              p_input_summary: (step.prompt || "").substring(0, 200),
              p_output_summary: result.output_preview || null,
              p_error_message: result.error || null,
              p_input_tokens: result.input_tokens || 0,
              p_output_tokens: result.output_tokens || 0,
              p_cost_usd: result.cost_usd || 0
            }
          });
        }
      } catch (e) {
        // Non-blocking
      }
    }
  }
}

// Compute final status
const hasErrors = stepResults.some(s => s.status === 'error');
const hasTimeouts = stepResults.some(s => s.status === 'timeout');
const finalStatus = hasErrors ? 'partial' : (hasTimeouts ? 'partial' : 'success');
const totalCost = stepResults.reduce((sum, s) => sum + (s.cost_usd || 0), 0);

return [{ json: {
  mission_id: missionId,
  mission_name: missionName,
  status: finalStatus,
  total_cost_usd: totalCost,
  results: {
    status: finalStatus,
    steps: stepResults,
    current_step: totalSteps,
    total_steps: totalSteps,
    mission_name: missionName
  }
} }];
