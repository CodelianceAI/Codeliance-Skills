import { expect, mock, test } from 'claude-code/testing'

const TOOL = 'mcp__continue-session__continueInNewSession'

// Stand in for the engine: record registrations, /clear runs and submitted prompts.
function engine(on: any) {
  const log: string[] = []
  on('tool.register', (_$: any, e: any) => { log.push(`register:${e.name}`); return { value: { tool: TOOL } } })
  on('command.register', () => ({ value: undefined }))
  on('command.run', { command: 'clear' }, () => { log.push('clear'); return {} })
  on('prompt.submit', (_$: any, e: any) => { log.push(`submit:${e.text}:${e.origin?.asUser ?? false}`); return { text: e.text } })
  on('tool.call', { tool: 'Read' }, () => ({ result: 'file contents' }))
  on('session.start', (_$: any, e: any) => e)
  on('ui.log', () => ({ value: undefined }))
  on('ui.toast', () => ({ value: undefined }))
  return log
}

test('queues /clear then submits the prompt as the user', async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const log = engine(on)
  await $.session.start({ cwd: '/repo' } as any)
  expect(log).toContain(`register:continueInNewSession`)

  const r: any = await $.tool.call({ tool: TOOL, prompt: 'Take on plan openspec/changes/foo' })
  expect(String(r.result ?? r.text)).toContain('Handoff queued')
  expect(log).not.toContain('clear')        // nothing happens inside the tool call itself

  await clock.advance(0)
  const i = log.indexOf('clear')
  expect(i).toBeGreaterThan(-1)
  expect(log[i + 1]).toBe('submit:Take on plan openspec/changes/foo:true')
})

test('denies other tools while a handoff is queued, and a second handoff', async ($, on) => {
  mock.clock(on)
  mock.store(on)
  engine(on)
  await $.session.start({ cwd: '/repo' } as any)
  await $.tool.call({ tool: TOOL, prompt: 'next' })
  const read: any = await $.tool.call({ tool: 'Read', file_path: 'a.md' })
  expect(String(read.text ?? read.deny)).toContain('handoff')
  const again: any = await $.tool.call({ tool: TOOL, prompt: 'again' })
  expect(String(again.text ?? again.deny)).toContain('already queued')
})

test('rejects an empty prompt', async ($, on) => {
  mock.clock(on)
  mock.store(on)
  engine(on)
  await $.session.start({ cwd: '/repo' } as any)
  const r: any = await $.tool.call({ tool: TOOL, prompt: '   ' })
  expect(String(r.text ?? r.deny)).toContain('non-empty')
})

test('stops after maxChain handoffs without the user', { options: { maxChain: 2 } }, async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const log = engine(on)
  await $.session.start({ cwd: '/repo' } as any)
  for (let k = 0; k < 2; k++) {
    await $.tool.call({ tool: TOOL, prompt: `step ${k}` })
    await clock.advance(0)
  }
  const third: any = await $.tool.call({ tool: TOOL, prompt: 'step 2' })
  expect(String(third.text ?? third.deny)).toContain('limit')
  expect(log.filter(l => l === 'clear').length).toBe(2)
})

test('a message typed by the user resets the chain', { options: { maxChain: 1 } }, async ($, on) => {
  const clock = mock.clock(on)
  mock.store(on)
  const log = engine(on)
  await $.session.start({ cwd: '/repo' } as any)
  await $.tool.call({ tool: TOOL, prompt: 'one' })
  await clock.advance(0)
  await $.prompt.submit({ text: 'keep going', origin: { kind: 'composer' } } as any)
  await $.tool.call({ tool: TOOL, prompt: 'two' })
  await clock.advance(0)
  expect(log.filter(l => l === 'clear').length).toBe(2)
})
