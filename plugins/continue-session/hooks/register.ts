import type { EngineInterface, Register } from 'claude-code'

// continueInNewSession(prompt): the agent hands its follow-up work to a brand-new
// context. The tool only queues the handoff; once the current turn has ended the
// mod runs /clear and submits `prompt` as the fresh session's first user message.

const TOOL = 'continueInNewSession'
const FULL = 'mcp__continue-session__continueInNewSession'
const tag = '[continue-session]'
const CHAIN_KEY = 'chain'        // handoffs in a row since the person last typed
const PENDING_KEY = 'pending'    // prompt saved before /clear, removed once submitted
const DEFAULT_MAX_CHAIN = 10    // keep in step with userConfig.maxChain.default in plugin.json

const DESCRIPTION = [
  'End this session and continue the work in a brand-new session with an empty context.',
  'After your current turn ends, the conversation is cleared (/clear) and `prompt` is sent',
  'as the first user message of the new session. Nothing else from this session carries over,',
  'so `prompt` must be self-contained: point at the files, plans or specs to read.',
  'Use it when the current unit of work is finished and a follow-up should start fresh.',
  'Call it as your LAST action, then end your turn immediately without further tool calls.',
].join(' ')

// Module-level state: reset on reload, survives /clear (same process).
let queued: string | undefined

async function chain($: EngineInterface) {
  return Number((await $.store.get(CHAIN_KEY)) ?? 0)
}

async function registerTool($: EngineInterface) {
  await $.tool.register({
    name: TOOL,
    description: DESCRIPTION,
    inputSchema: {
      type: 'object',
      properties: {
        prompt: {
          type: 'string',
          description: 'The complete first message for the new session.',
        },
      },
      required: ['prompt'],
      additionalProperties: false,
    },
  })
}

async function handoff($: EngineInterface, prompt: string) {
  await $.store.set(PENDING_KEY, prompt)
  try {
    // Queued by the engine until the session is idle, i.e. after the current turn.
    await $.command.run({ command: 'clear' })
  } catch (err) {
    await $.store.delete(PENDING_KEY)
    $.ui.log(`${tag} /clear failed, staying in this session: ${String(err)}`)
    $.ui.toast(`${tag} handoff failed (/clear)`)
    return
  }
  try {
    const r = await $.prompt.submit({ text: prompt, asUser: true })
    if ((r as { drop?: string }).drop !== undefined) throw new Error(`dropped: ${(r as { drop?: string }).drop}`)
    await $.store.delete(PENDING_KEY)
  } catch (err) {
    $.ui.log(`${tag} submit failed after /clear: ${String(err)}. Run /continue-resend to retry.`)
    $.ui.toast(`${tag} handoff prompt not sent; /continue-resend`)
  }
}

export const register: Register = (on, options) => {
  queued = undefined
  const maxChain = Number((options as { maxChain?: number }).maxChain ?? DEFAULT_MAX_CHAIN)

  on('session.start', async ($, e, next) => {
    await registerTool($)
    await $.command.register({
      name: 'continue-resend',
      description: 'Re-send a continueInNewSession prompt that was not delivered',
    })
    return next(e)
  })

  // session.start does not fire after /clear; re-registering replaces the tool,
  // so this is harmless if the registration already survived.
  on('classic.SessionStart', async ($, e, next) => {
    const out = await next(e)
    if (e.source === 'clear') {
      try { await registerTool($) } catch (err) { $.ui.log(`${tag} re-register after /clear failed: ${String(err)}`) }
    }
    return out
  })

  on('tool.call', { tool: 'mcp__continue-session__continueInNewSession' }, async ($, e) => {
    if (e.agentId !== undefined) {
      return { deny: 'Only the main session can hand off; subagents should return their result instead.' }
    }
    const prompt = typeof e.prompt === 'string' ? e.prompt.trim() : ''
    if (!prompt) return { deny: '`prompt` must be a non-empty, self-contained message.' }
    if (queued !== undefined) return { deny: 'A handoff is already queued. End your turn now.' }

    const n = await chain($)
    if (n >= maxChain) {
      $.ui.toast(`${tag} chain limit (${maxChain}) reached; not handing off`)
      return { deny: `Handoff limit reached (${maxChain} in a row without the user). Stop and summarise for the user instead.` }
    }
    await $.store.set(CHAIN_KEY, n + 1)

    // Run outside this hook: $.command.run rejects inside a hook the turn waits on.
    $.clock.after(0, () => {
      void handoff($, prompt).finally(() => { queued = undefined })
    })
    // Set only once the timer that clears it exists, so a failure above can't leave every tool denied.
    queued = prompt
    $.ui.log(`${tag} handoff ${n + 1}/${maxChain} queued; /clear runs when this turn ends`)
    return { result: 'Handoff queued. The session will be cleared and the new session started with your prompt as soon as this turn ends. Do not call any more tools; end your turn now.' }
  }).catch(() => (
    // Fail closed: without this a hook that threw (say, the store) is skipped and the chain limit with it.
    { deny: 'The handoff could not be queued (internal error). Stay in this session and tell the user.' }
  ))

  // Anything the agent tries after queuing a handoff would be wiped by /clear anyway.
  // No .catch here or on prompt.submit below: skipped on failure is right, neither should block the person's work.
  on('tool.call', async ($, e, next) => {
    if (queued !== undefined && e.agentId === undefined && e.tool !== FULL) {
      return { deny: 'A handoff to a new session is queued; this session is about to be cleared. End your turn now.' }
    }
    return next(e)
  })

  // A message the person typed (not our own asUser submit) resets the chain.
  on('prompt.submit', async ($, e, next) => {
    if (e.origin.kind === 'composer' || e.origin.kind === 'bridge') {
      if (!e.text.trimStart().startsWith('/')) await $.store.set(CHAIN_KEY, 0)
    }
    return next(e)
  })

  on('command.run', { command: 'continue-resend' }, async $ => {
    const pending = await $.store.get(PENDING_KEY)
    if (typeof pending !== 'string') return { text: `${tag} nothing to re-send` }
    $.clock.after(0, () => {
      void $.prompt.submit({ text: pending, asUser: true })
        .then(() => $.store.delete(PENDING_KEY))
        .catch(err => $.ui.log(`${tag} re-send failed: ${String(err)}`))
    })
    return { text: `${tag} re-sending the pending handoff prompt` }
  })
}
