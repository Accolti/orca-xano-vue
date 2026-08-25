import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { xano } from '@/services/xano'
import { useOrcamentoStore } from '@/stores/orcamento'
import { useAuthStore } from '@/stores/auth'
import {
  gerarPdfOrcamento,
  gerarPdfPedidoVenda as gerarPdfPedidoVendaDoc,
  montarTextoWhatsApp,
  obterWhatsappCliente,
  copiarEabrirWhatsApp,
} from '@/services/pdf'
import type { Cliente } from '@/types/cliente'

export interface OrcamentoRow {
  id: number
  created_at: number
  cod_orca: string
  cliente_id: number
  nome_fantasia: string
  razao_social: string
  contato: string
  cpf: string
  cnpj: string
  inscricao_estadual: string
  vnd_tot: number
  vnd_B2B_tot: number
  vnd_B2B_B2C_tot: number
  cst_tot: number
  luc_tot: number
  margem: number
  validade: string
  eh_pedido?: boolean
  status?: string
  data_envio?: number
  data_aprovacao?: number
  total_itens?: number
  mao_de_obra?: number
}

export const STATUS_LABELS: Record<string, string> = {
  RASCUNHO: 'Rascunho',
  ENVIADO: 'Enviado',
  AGUARDANDO_RETORNO: 'Aguardando retorno',
  APROVADO: 'Aprovado',
  AGUARDANDO_FATURAMENTO: 'Aguardando faturamento',
  FATURADO: 'Faturado',
  ENTREGUE: 'Entregue',
  RECUSADO: 'Recusado',
  CANCELADO: 'Cancelado',
}

// Status possíveis de um pedido (Orca convertida) — sem APROVADO (pré-pedido)
export const STATUS_PEDIDO_FILTRO = [
  'AGUARDANDO_FATURAMENTO',
  'FATURADO',
  'ENTREGUE',
  'RECUSADO',
  'CANCELADO',
]

// Status possíveis de um orçamento (pré-pedido) — sem os de pedido convertido
export const STATUS_ORCAMENTO_FILTRO = [
  'RASCUNHO',
  'ENVIADO',
  'AGUARDANDO_RETORNO',
  'APROVADO',
  'RECUSADO',
  'CANCELADO',
]

export function statusLabel(status?: string): string {
  return STATUS_LABELS[status ?? ''] ?? status ?? 'Rascunho'
}

export function formatarMoeda(valor: number | string | null | undefined): string {
  return `R$ ${(Number(valor) || 0).toFixed(2).replace('.', ',')}`
}

export function formatarData(ts: number | string | null | undefined): string {
  if (!ts) return ''
  const d = typeof ts === 'number' ? new Date(ts) : new Date(ts)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleDateString('pt-BR')
}

export function montarClienteDoHeader(header: any): Cliente | null {
  const c = header?._cliente
  if (!c) return null
  return {
    id: c.id,
    razao_social: c.razao_social || '',
    nome_fantasia: c.nome_fantasia || '',
    contato: c.contato || '',
    cpf: c.cpf || '',
    nome_cpf: c.nome_cpf || '',
    cnpj: c.cnpj || '',
    inscricao_estadual: c.inscricao_estadual || '',
    'e-mail': c['e-mail'] || '',
    contribui_icms: c.contribui_icms ?? false,
    isento: c.isento ?? false,
    observacao: c.observacao || '',
    user_id: c.user_id ?? 0,
    beneficio_fiscal_id: c.beneficio_fiscal_id ?? null,
    mercado_id: c.mercado_id ?? null,
    ramo_id: c.ramo_id ?? null,
    regime_id: c.regime_id ?? null,
    created_at: c.created_at ?? 0,
    _enderecos: c._enderecos ?? [],
    _telefone_cliente_of_cliente: c._telefone_cliente_of_cliente ?? [],
  }
}

// Ações compartilhadas (PDF/WhatsApp) entre OrçamentosListView e PedidosView.
export function useOrcamentosListActions() {
  const router = useRouter()
  const orcamentoStore = useOrcamentoStore()
  const authStore = useAuthStore()

  const gerandoPdfDe = ref<number | null>(null)
  const enviandoWaDe = ref<number | null>(null)
  const toastMsg = ref('')
  let toastTimer: ReturnType<typeof setTimeout> | null = null

  function mostrarToast(msg: string) {
    toastMsg.value = msg
    if (toastTimer) clearTimeout(toastTimer)
    toastTimer = setTimeout(() => {
      toastMsg.value = ''
    }, 4000)
  }

  function editarOrcamento(row: OrcamentoRow, origem?: string) {
    router.push({
      path: `/orcamentos/${row.cod_orca}`,
      query: origem ? { origem } : undefined,
    })
  }

  function novoOrcamento() {
    router.push('/orcamentos/novo')
  }

  async function excluirOrcamento(row: OrcamentoRow, onRemovido?: () => void) {
    if (!confirm(`Excluir orçamento ${row.cod_orca}?`)) return
    try {
      await orcamentoStore.deleteOrcamento(row.id)
      onRemovido?.()
    } catch {
      /* erro silencioso */
    }
  }

  async function gerarPdf(row: OrcamentoRow) {
    gerandoPdfDe.value = row.id
    try {
      await orcamentoStore.carregarOrcamento(row.cod_orca)
      const header = orcamentoStore.orcamentoHeader
      const cliente = montarClienteDoHeader(header)
      gerarPdfOrcamento({
        header,
        itens: orcamentoStore.itensInseridos,
        cliente,
        user: authStore.user,
      })
    } catch {
      /* erro silencioso: header já fica no store */
    } finally {
      gerandoPdfDe.value = null
    }
  }

  async function gerarPdfPedidoVenda(row: OrcamentoRow) {
    gerandoPdfDe.value = row.id
    try {
      await orcamentoStore.carregarOrcamento(row.cod_orca)
      const header = orcamentoStore.orcamentoHeader
      const cliente = montarClienteDoHeader(header)
      gerarPdfPedidoVendaDoc({
        header,
        itens: orcamentoStore.itensInseridos,
        cliente,
        user: authStore.user,
      })
    } catch {
      /* erro silencioso: header já fica no store */
    } finally {
      gerandoPdfDe.value = null
    }
  }

  async function enviarWhatsApp(row: OrcamentoRow) {
    enviandoWaDe.value = row.id
    try {
      await orcamentoStore.carregarOrcamento(row.cod_orca)
      const header = orcamentoStore.orcamentoHeader
      const cliente = montarClienteDoHeader(header)
      const telefone = obterWhatsappCliente(cliente)
      if (!telefone) {
        mostrarToast(`Cliente sem telefone cadastrado (tipo 1) em ${row.cod_orca}`)
        return
      }
      const mensagem = montarTextoWhatsApp({
        header,
        itens: orcamentoStore.itensInseridos,
        cliente,
      })
      const status = await copiarEabrirWhatsApp(telefone, mensagem)
      if (status === 'shared') {
        mostrarToast('Mensagem enviada para compartilhamento. Escolha o WhatsApp.')
      } else if (status === 'copied') {
        mostrarToast('Mensagem copiada! Cole na conversa do WhatsApp (Ctrl+V / segure o campo).')
      } else {
        mostrarToast('Não foi possível copiar. A mensagem foi aberta no WhatsApp.')
      }
    } catch {
      mostrarToast('Erro ao gerar o WhatsApp')
    } finally {
      enviandoWaDe.value = null
    }
  }

  // Carrega a listagem paginada. soPedidos → só pedidos; somenteOrcamentos → só orçamentos;
  // nenhum → tudo. Devolve status mesclado.
  async function buscarLista(
    termo: string,
    page: number,
    perPage: number,
    soPedidos = false,
    somenteOrcamentos = false,
  ): Promise<{ items: OrcamentoRow[]; hasNext: boolean; hasPrev: boolean }> {
    const [buscaRes, statusRes] = await Promise.all([
      xano.get('/api:-qqRIakp/orca_por_cliente_busca', {
        busca: termo,
        page,
        per_page: perPage,
        so_pedidos: soPedidos || undefined,
        somente_orcamentos: somenteOrcamentos || undefined,
      }),
      xano.get('/api:-qqRIakp/orcamento_status_lista'),
    ])
    const body = buscaRes.getBody() as any
    const statusMap = new Map<number, string>()
    const statusList = (statusRes.getBody() as any[]) ?? []
    statusList.forEach((o: any) => {
      if (o?.id != null && o?.status) statusMap.set(Number(o.id), o.status)
    })
    const items = ((body?.items ?? []) as OrcamentoRow[]).map((row) => ({
      ...row,
      status: statusMap.get(Number(row.id)) ?? row.status ?? 'RASCUNHO',
    }))
    const itemsReceived = body?.itemsReceived ?? items.length
    return {
      items,
      hasNext: !!body.nextPage && itemsReceived >= perPage,
      hasPrev: !!body.prevPage,
    }
  }

  return {
    gerandoPdfDe,
    enviandoWaDe,
    toastMsg,
    mostrarToast,
    editarOrcamento,
    novoOrcamento,
    excluirOrcamento,
    gerarPdf,
    gerarPdfPedidoVenda,
    enviarWhatsApp,
    buscarLista,
  }
}
