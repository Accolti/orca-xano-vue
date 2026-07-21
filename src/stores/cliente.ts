import { ref } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import type { Cliente } from '@/types/cliente'

export const useClienteStore = defineStore('cliente', () => {
  const clientes = ref<Cliente[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function buscarClientes(termo?: string) {
    if (termo && termo.length < 3) return

    loading.value = true
    error.value = null

    try {
      const params = termo ? { busca: termo } : undefined
      const response = await xano.get('/api:-qqRIakp/cliente_user_busca', params)
      clientes.value = response.getBody().cliente
    } catch (err: unknown) {
      if (err instanceof XanoRequestError) {
        const body = err.getResponse().getBody()
        error.value = body?.message || err.message || 'Erro ao buscar clientes'
      } else {
        error.value = (err as Error).message || 'Erro inesperado'
      }
      clientes.value = []
    } finally {
      loading.value = false
    }
  }

  return {
    clientes,
    loading,
    error,
    buscarClientes,
  }
})
