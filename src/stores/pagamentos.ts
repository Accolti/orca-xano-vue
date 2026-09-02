import { ref } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import type { ParcelaFinanceira } from '@/utils/pagamentos'

export interface PagamentoRow {
  id: number
  orca_id?: number
  vencimento?: string
  pagamento?: string | null
  valor?: number
  forma_pagamento_id?: number
  user_id?: number
  cod_orca?: string
  eh_pedido?: boolean
  forma?: string
  cliente_id?: number
}

export const usePagamentoStore = defineStore('pagamentos', () => {
  const parcelas = ref<PagamentoRow[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  function msgErro(err: unknown): string {
    if (err instanceof XanoRequestError) {
      try {
        const body = err.getResponse().getBody()
        if (body?.message) return body.message
      } catch {
        /* ignore */
      }
    }
    return (err as Error).message || 'Erro inesperado'
  }

  async function carregar() {
    loading.value = true
    error.value = null
    try {
      const resp = await xano.get('/api:-qqRIakp/pagamentos')
      parcelas.value = resp.getBody() ?? []
    } catch (err) {
      error.value = msgErro(err)
      parcelas.value = []
    } finally {
      loading.value = false
    }
  }

  async function carregarPorOrca(orcaId: number): Promise<PagamentoRow[]> {
    const resp = await xano.get('/api:-qqRIakp/pagamentos', { orca_id: orcaId })
    return resp.getBody() ?? []
  }

  async function salvarParcelas(orcaId: number, lista: ParcelaFinanceira[]) {
    await xano.post('/api:-qqRIakp/pagamento_salvar', {
      orca_id: orcaId,
      parcelas: lista.map((p) => ({
        valor: p.valor,
        vencimento: p.vencimento,
        forma_pagamento_id: p.forma_pagamento_id,
      })),
    })
  }

  async function baixar(id: number, pagamento?: string) {
    await xano.post('/api:-qqRIakp/pagamento_baixa', {
      boleto_id: id,
      pagamento: pagamento ?? 'today',
    })
  }

  async function estornar(id: number) {
    await xano.post('/api:-qqRIakp/pagamento_baixa', { boleto_id: id, estornar: true })
  }

  async function excluir(id: number) {
    await xano.post('/api:-qqRIakp/pagamento_excluir', { boleto_id: id })
  }

  return {
    parcelas,
    loading,
    error,
    carregar,
    carregarPorOrca,
    salvarParcelas,
    baixar,
    estornar,
    excluir,
  }
})
