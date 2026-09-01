import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import type { Cliente } from '@/types/cliente'

export const useClienteStore = defineStore('cliente', () => {
  const clientes = ref<Cliente[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)
  const pagina = ref(1)
  const total = ref(0)
  const limite = 15
  const buscaAtual = ref<string | undefined>(undefined)

  const totalPaginas = computed(() => Math.max(1, Math.ceil(total.value / limite)))

  async function buscarClientes(termo?: string, pg = 1) {
    if (termo && termo.length < 3) return

    buscaAtual.value = termo || undefined
    loading.value = true
    error.value = null

    try {
      const params: Record<string, string | number> = { pagina: pg }
      if (buscaAtual.value) params.busca = buscaAtual.value
      const response = await xano.get('/api:-qqRIakp/cliente_user_busca', params)
      const body = response.getBody()
      clientes.value = body.cliente ?? []
      total.value = Number(body.total) || clientes.value.length
      pagina.value = pg
    } catch (err: unknown) {
      if (err instanceof XanoRequestError) {
        const body = err.getResponse().getBody()
        error.value = body?.message || err.message || 'Erro ao buscar clientes'
      } else {
        error.value = (err as Error).message || 'Erro inesperado'
      }
      clientes.value = []
      total.value = 0
    } finally {
      loading.value = false
    }
  }

  function trocarPagina(pg: number) {
    if (pg < 1 || pg > totalPaginas.value || pg === pagina.value) return
    buscarClientes(buscaAtual.value, pg)
  }

  return {
    clientes,
    loading,
    error,
    pagina,
    total,
    limite,
    totalPaginas,
    buscarClientes,
    trocarPagina,
  }
})
