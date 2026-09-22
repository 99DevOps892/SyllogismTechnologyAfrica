'use strict';

const TOOL_ALLOWLIST = new Set([
  'advisor_chat',
  'portfolio_summary',
  'plan_lookup',
  'goal_projection',
  'risk_profile',
]);

const ROLE_TOOLS = {
  guest: new Set(['advisor_chat']),
  member: new Set(['advisor_chat', 'portfolio_summary', 'goal_projection']),
  advisor: new Set(['advisor_chat', 'portfolio_summary', 'plan_lookup', 'goal_projection', 'risk_profile']),
};

const APPROVAL_REQUIRED = new Set(['portfolio_summary', 'risk_profile']);

const INJECTION_MARKERS = [
  'ignore previous instructions',
  'ignore all prior instructions',
  'system prompt',
  'developer message',
  'you are now',
  'jailbreak',
  'reveal your instructions',
  'output your system prompt',
  'forget everything',
];

function guard({ systemPrompt, userPrompt, delimiter = '=====' }) {
  let text = String(userPrompt || '');
  const lowered = text.toLowerCase();
  const flagged = INJECTION_MARKERS.filter((marker) => lowered.includes(marker));
  const guarded = flagged.length === 0;
  const boxed = `${delimiter}\n${systemPrompt}\n${delimiter}\n\n${text}`;
  return { system_prompt: boxed, guarded, flagged, guardrails: true };
}

function sanitizePrompt(userText) {
  return guard({ systemPrompt: 'You are a secure advisory assistant.', userPrompt: userText });
}

function authorizeTool(toolName, role, tenantId) {
  if (!TOOL_ALLOWLIST.has(toolName)) {
    return { allowed: false, reason: 'not in allowlist', tool_choice: 'advisor_chat' };
  }
  const allowedTools = ROLE_TOOLS[role] || ROLE_TOOLS.guest;
  if (!allowedTools.has(toolName)) {
    return { allowed: false, reason: 'role lacks permission', permission_check: 'denied' };
  }
  if (APPROVAL_REQUIRED.has(toolName)) {
    return { allowed: false, reason: 'human-in-the-loop approval required' };
  }
  return { allowed: true, reason: 'permitted', tenantId };
}

function gateToolCall(toolName, role, tenantId, approver = null) {
  const verdict = authorizeTool(toolName, role, tenantId);
  if (verdict.allowed) return verdict;
  if (verdict.reason === 'human-in-the-loop approval required' && approver && approver.role === 'advisor') {
    return { allowed: true, reason: 'approved by human in the loop', tenantId };
  }
  return verdict;
}

module.exports = {
  TOOL_ALLOWLIST,
  ROLE_TOOLS,
  guard,
  sanitizePrompt,
  authorizeTool,
  gateToolCall,
};