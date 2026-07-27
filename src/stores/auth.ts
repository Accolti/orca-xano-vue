import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import { useCatalogoStore } from './catalogo'

export interface User {
  id: number
  created_at: string
  name: string
  name_first: string
  name_last: string
  email: string
  frtB2B: number
  margem: number
  DiasVencimentoOrcamento: number
  organizacao_id: number
  razao: string
  fantasia: string
  cnpj: string
  ie: string
  cpf: string
  isPJ: number
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const token = ref<string | null>(localStorage.getItem('authToken'))
  const loading = ref(false)
  const error = ref<string | null>(null)

  const isAuthenticated = computed(() => !!token.value)

  if (token.value) {
    xano.setAuthToken(token.value)
  }

  function getErrorMessage(err: unknown): string {
    if (err instanceof XanoRequestError) {
      try {
        const body = err.getResponse().getBody()
        if (typeof body === 'string') return body
        if (body?.message) return body.message
        if (body?.error?.message) return body.error.message
      } catch {
        /* ignore */
      }
    }
    return (err as Error).message || 'Erro inesperado'
  }

  async function login(email: string, password: string) {
    loading.value = true
    error.value = null
    try {
      const response = await xano.post('/api:-qqRIakp/auth/login', { email, password })
      const data = response.getBody()
      token.value = data.authToken
      localStorage.setItem('authToken', data.authToken)
      xano.setAuthToken(data.authToken)
      await fetchMe()
    } catch (err) {
      console.error('[auth/login]', err)
      if (err instanceof XanoRequestError) {
        console.error('[auth/login] status:', err.getResponse().getStatusCode())
        console.error('[auth/login] body:', err.getResponse().getBody())
      }
      const msg = getErrorMessage(err)
      error.value = msg
      throw new Error(msg)
    } finally {
      loading.value = false
    }
  }

  async function signup(email: string, password: string, name_first: string, name_last: string) {
    loading.value = true
    error.value = null
    try {
      const response = await xano.post('/api:-qqRIakp/auth/signup', {
        email,
        password,
        name_first,
        name_last,
      })
      const data = response.getBody()
      token.value = data.authToken
      localStorage.setItem('authToken', data.authToken)
      xano.setAuthToken(data.authToken)
      await fetchMe()
    } catch (err) {
      console.error('[auth/signup]', err)
      if (err instanceof XanoRequestError) {
        console.error('[auth/signup] status:', err.getResponse().getStatusCode())
        console.error('[auth/signup] body:', err.getResponse().getBody())
      }
      const msg = getErrorMessage(err)
      error.value = msg
      throw new Error(msg)
    } finally {
      loading.value = false
    }
  }

  async function fetchMe() {
    try {
      const response = await xano.get('/api:-qqRIakp/auth/me')
      user.value = response.getBody()
    } catch (err) {
      console.error('[auth/me]', err)
      if (err instanceof XanoRequestError) {
        console.error('[auth/me] status:', err.getResponse().getStatusCode())
        console.error('[auth/me] body:', err.getResponse().getBody())
      }
      if (err instanceof XanoRequestError && err.getResponse().getStatusCode() === 401) {
        logout()
        throw new Error('Sessão expirada. Faça login novamente.')
      }
      logout()
      throw new Error('Sessão expirada. Faça login novamente.')
    }
  }

  function logout() {
    token.value = null
    user.value = null
    localStorage.removeItem('authToken')
    xano.setAuthToken(null)
    useCatalogoStore().resetarSessao()
  }

  return {
    user,
    token,
    loading,
    error,
    isAuthenticated,
    login,
    signup,
    fetchMe,
    logout,
  }
})
