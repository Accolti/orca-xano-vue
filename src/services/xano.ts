import { XanoClient, XanoRequestError } from '@xano/js-sdk'

const baseUrl = import.meta.env.DEV ? '/' : import.meta.env.VITE_XANO_BASE_URL

const client = new XanoClient({
  instanceBaseUrl: baseUrl,
})

// Callback global disparado quando qualquer chamada retorna 401 (token expirado/inválido).
// Registrado no main.ts para fazer logout + redirecionar para /login.
let unauthorizedHandler: (() => void) | null = null
let unauthorizedFired = false

export function setUnauthorizedHandler(fn: (() => void) | null) {
  unauthorizedHandler = fn
  unauthorizedFired = false
}

async function wrapRequest<T>(promise: Promise<T>): Promise<T> {
  try {
    return await promise
  } catch (err: unknown) {
    if (err instanceof XanoRequestError) {
      try {
        const status = err.getResponse().getStatusCode()
        if (status === 401 && !unauthorizedFired) {
          unauthorizedFired = true
          unauthorizedHandler?.()
        }
      } catch {
        /* response indisponível — propaga o erro original */
      }
    }
    throw err
  }
}

export const xano = {
  setAuthToken: (authToken: string | null) => {
    // Novo token = nova sessão → reabilita a detecção de 401
    if (authToken) unauthorizedFired = false
    return client.setAuthToken(authToken)
  },
  get: (...args: Parameters<typeof client.get>) => wrapRequest(client.get(...args)),
  post: (...args: Parameters<typeof client.post>) => wrapRequest(client.post(...args)),
  put: (...args: Parameters<typeof client.put>) => wrapRequest(client.put(...args)),
  patch: (...args: Parameters<typeof client.patch>) => wrapRequest(client.patch(...args)),
  delete: (...args: Parameters<typeof client.delete>) => wrapRequest(client.delete(...args)),
}
