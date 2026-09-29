import { ref } from 'vue'
import { defineStore } from 'pinia'
import {
  listarParcelas,
  salvarParcelas as apiSalvarParcelas,
  baixarParcela,
  estornarParcela,
  excluirParcela,
} from '@/services/pagamentoApi'
import { useAuthStore } from './auth'
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

  async function carregar() {
    loading.value = true
    error.value = null
    try {
      parcelas.value = await listarParcelas(useAuthStore().user?.id)
    } catch (err) {
      error.value = (err as Error).message || 'Erro inesperado'
      parcelas.value = []
    } finally {
      loading.value = false
    }
  }

  async function carregarPorOrca(orcaId: number): Promise<PagamentoRow[]> {
    return listarParcelas(useAuthStore().user?.id, orcaId)
  }

  async function salvarParcelas(orcaId: number, lista: ParcelaFinanceira[]) {
    await apiSalvarParcelas(orcaId, lista, useAuthStore().user?.id)
  }

  async function baixar(id: number, pagamento?: string) {
    await baixarParcela(id, pagamento, useAuthStore().user?.id)
  }

  async function estornar(id: number) {
    await estornarParcela(id, useAuthStore().user?.id)
  }

  async function excluir(id: number) {
    await excluirParcela(id, useAuthStore().user?.id)
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
