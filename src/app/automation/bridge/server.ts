/**
 * Browser-side automation handler.
 *
 * Connects to the bridge via WebSocket, receives RPC requests,
 * executes them against the live EditorStore, and sends results back.
 */
import { AUTOMATION_WS_PORT } from '@open-pencil/core/constants'
import { randomHex } from '@open-pencil/core/random'

import { makeFigmaFromStore } from '@/app/automation/bridge/figma-factory'
import { createAutomationCommandHandlers } from '@/app/automation/bridge/handlers'
import type { EditorStore } from '@/app/editor/active-store'

function resolveWsUrl(): string {
  if (typeof window !== 'undefined' && window.location) {
    const params = new URLSearchParams(window.location.search)
    const mcpHost = params.get('mcp')
    if (mcpHost) {
      const proto = mcpHost.startsWith('localhost') || mcpHost.startsWith('127.0.0.1') ? 'ws:' : 'wss:'
      return `${proto}//${mcpHost}/ws`
    }
    if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
      return `${proto}//${window.location.host}/ws`
    }
  }
  return `ws://127.0.0.1:${AUTOMATION_WS_PORT}`
}

export function connectAutomation(getStore: () => EditorStore, authToken: string | null = null) {
  const token = authToken ?? randomHex(32)
  let ws: WebSocket | null = null
  let reconnectTimer: ReturnType<typeof setTimeout> | undefined
  let intentionalDisconnect = false

  function makeFigma() {
    return makeFigmaFromStore(getStore())
  }

  const { handleRequest: handleAutomationRequest } = createAutomationCommandHandlers(makeFigma)

  async function handleRequest(_id: string, command: string, args: unknown): Promise<unknown> {
    return handleAutomationRequest(getStore(), command, args)
  }

  function connect() {
    try {
      ws = new WebSocket(resolveWsUrl())
    } catch (e) {
      console.error(
        '[Automation] WebSocket constructor failed:',
        e instanceof Error ? e.message : e
      )
      scheduleReconnect()
      return
    }

    ws.onopen = () => {
      console.debug('[Automation] WebSocket connected to MCP server')
      ws?.send(JSON.stringify({ type: 'register', token }))
    }

    ws.onmessage = async (event) => {
      try {
        const msg = JSON.parse(event.data) as {
          type: string
          id: string
          command: string
          args?: unknown
        }
        if (msg.type !== 'request' || !msg.id) return
        try {
          const result = await handleRequest(msg.id, msg.command, msg.args)
          ws?.send(JSON.stringify({ type: 'response', id: msg.id, ...(result as object) }))
        } catch (e) {
          ws?.send(
            JSON.stringify({
              type: 'response',
              id: msg.id,
              ok: false,
              error: e instanceof Error ? e.message : String(e)
            })
          )
        }
      } catch (e) {
        console.warn('Failed to parse WebSocket message:', e)
      }
    }

    ws.onclose = (event) => {
      ws = null
      if (intentionalDisconnect || event.code === 1000) return
      console.error('[Automation] WebSocket closed:', `code=${event.code} reason=${event.reason}`)
      scheduleReconnect()
    }

    ws.onerror = (event) => {
      console.error('[Automation] WebSocket error:', event)
      ws?.close()
    }
  }

  function scheduleReconnect() {
    clearTimeout(reconnectTimer)
    reconnectTimer = setTimeout(connect, 2000)
  }

  function disconnect() {
    intentionalDisconnect = true
    clearTimeout(reconnectTimer)
    ws?.close()
    ws = null
  }

  connect()
  return { disconnect, token }
}
