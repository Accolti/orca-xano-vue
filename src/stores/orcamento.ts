import { ref, computed, watch } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import { useAuthStore } from './auth'
import type {
  Material,
  Linha,
  Tipo,
  Nivel,
  Borda,
  OrcamentoResult,
  Func1,
  OrcamentoInsertPayload,
} from '@/types/orcamento'

interface DropdownCacheEntry {
  linhas: Linha[]
  tipos: Tipo[]
  niveis: Nivel[]
  bordas: Borda[]
}

const dropdownCache = new Map<number, DropdownCacheEntry>()

export const useOrcamentoStore = defineStore('orcamento', () => {
  const materiais = ref<Material[]>([])
  const linhas = ref<Linha[]>([])
  const tipos = ref<Tipo[]>([])
  const niveis = ref<Nivel[]>([])
  const bordas = ref<Borda[]>([])

  const materialSelecionado = ref<Material | null>(null)
  const linhaSelecionada = ref<Linha | null>(null)
  const tipoSelecionado = ref<Tipo | null>(null)
  const nivelSelecionado = ref<Nivel | null>(null)
  const bordaSelecionada = ref<Borda | null>(null)

  const largura = ref<number>(0)
  const comprimento = ref<number>(0)
  const quantidade = ref<number>(1)

  const resultado = ref<OrcamentoResult | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  const numeroOrcamento = ref<string | null>(null)
  const inserindo = ref(false)
  const itensInseridos = ref<any[]>([])
  const orcamentoHeader = ref<any | null>(null)

  const areaNominal = computed(() => largura.value * comprimento.value)

  watch(
    [largura, comprimento, quantidade, linhaSelecionada, tipoSelecionado, nivelSelecionado, bordaSelecionada],
    () => {
      resultado.value = null
    },
  )

  const func1 = computed<Func1 | null>(() => resultado.value?.func_1 ?? null)

  const mostrarLinha = computed(() => {
    if (!materialSelecionado.value?.suc) return false
    return materialSelecionado.value.suc.Linha > 0
  })

  const mostrarTipo = computed(() => {
    if (!materialSelecionado.value?.suc) return false
    return materialSelecionado.value.suc.Tipo > 0
  })

  const mostrarNivel = computed(() => {
    if (!materialSelecionado.value?.suc) return false
    return materialSelecionado.value.suc.Nivel > 0
  })

  const mostrarBorda = computed(() => {
    if (!materialSelecionado.value?.suc) return false
    return materialSelecionado.value.suc.Borda > 0
  })

  async function carregarMateriais() {
    try {
      const response = await xano.get('/api:-qqRIakp/material')
      const body = response.getBody() as any
      const data: Material[] = body?.material ?? body
      materiais.value = (Array.isArray(data) ? data : [])
        .filter((m) => m.ativo)
        .sort((a, b) => a.Ordenacao - b.Ordenacao)
    } catch (err: any) {
      console.error('Erro ao carregar materiais:', err)
    }
  }

  async function selecionarMaterial(material: Material) {
    materialSelecionado.value = material
    linhaSelecionada.value = null
    tipoSelecionado.value = null
    nivelSelecionado.value = null
    bordaSelecionada.value = null
    linhas.value = []
    tipos.value = []
    niveis.value = []
    bordas.value = []
    resultado.value = null

    const cached = dropdownCache.get(material.id)

    if (material.suc?.Linha && material.suc.Linha > 0) {
      if (cached?.linhas) {
        linhas.value = cached.linhas
      } else {
        try {
          const response = await xano.get('/api:-qqRIakp/linha', { material_id: material.id })
          linhas.value = response.getBody() as Linha[]
        } catch (err: any) {
          console.error('Erro ao carregar linhas:', err)
        }
      }
    }
    if (material.suc?.Tipo && material.suc.Tipo > 0) {
      if (cached?.tipos) {
        tipos.value = cached.tipos
      } else {
        try {
          const response = await xano.get('/api:-qqRIakp/tipo_por_material', {
            material_id: material.id,
          })
          tipos.value = response.getBody() as Tipo[]
        } catch (err: any) {
          console.error('Erro ao carregar tipos:', err)
        }
      }
    }
    if (material.suc?.Nivel && material.suc.Nivel > 0) {
      if (cached?.niveis) {
        niveis.value = cached.niveis
      } else {
        try {
          const response = await xano.get('/api:-qqRIakp/nivel_por_material', {
            material_id: material.id,
          })
          niveis.value = response.getBody() as Nivel[]
        } catch (err: any) {
          console.error('Erro ao carregar niveis:', err)
        }
      }
    }
    if (material.suc?.Borda && material.suc.Borda > 0) {
      if (cached?.bordas) {
        bordas.value = cached.bordas
      } else {
        try {
          const response = await xano.get('/api:-qqRIakp/borda_por_material', {
            material_id: material.id,
          })
          bordas.value = response.getBody() as Borda[]
        } catch (err: any) {
          console.error('Erro ao carregar bordas:', err)
        }
      }
    }

    if (!cached) {
      dropdownCache.set(material.id, {
        linhas: linhas.value,
        tipos: tipos.value,
        niveis: niveis.value,
        bordas: bordas.value,
      })
    }
  }

  function limparMaterial() {
    materialSelecionado.value = null
    linhaSelecionada.value = null
    tipoSelecionado.value = null
    nivelSelecionado.value = null
    bordaSelecionada.value = null
    linhas.value = []
    tipos.value = []
    niveis.value = []
    bordas.value = []
    resultado.value = null
  }

  function getNomeBorda(): string {
    return bordaSelecionada.value?.nome || ''
  }

  function getNomeLinha(): string {
    return linhaSelecionada.value?.nome || ''
  }

  function getNomeTipo(): string {
    return tipoSelecionado.value?.nome || ''
  }

  function getNomeNivel(): string {
    return nivelSelecionado.value?.nome || ''
  }

  function getNomeClassificacao(): string {
    return 'personalizado'
  }

  async function calcular(bSimulaMargens: boolean) {
    const material = materialSelecionado.value
    if (!material) { error.value = 'Selecione um material'; return }
    if (!largura.value || largura.value <= 0) { error.value = 'Preencha a largura'; return }
    if (!comprimento.value || comprimento.value <= 0) { error.value = 'Preencha o comprimento'; return }
    if (!quantidade.value || quantidade.value < 1) { error.value = 'Informe a quantidade'; return }
    if (mostrarLinha.value && linhas.value.length && !linhaSelecionada.value) { error.value = 'Selecione a linha'; return }
    if (mostrarTipo.value && tipos.value.length && !tipoSelecionado.value) { error.value = 'Selecione o tipo'; return }
    if (mostrarNivel.value && niveis.value.length && !nivelSelecionado.value) { error.value = 'Selecione o nível'; return }
    if (mostrarBorda.value && bordas.value.length && !bordaSelecionada.value) { error.value = 'Selecione a borda'; return }

    loading.value = true
    error.value = null

    const authIns = useAuthStore()

    try {
      const response = await xano.get('/api:-qqRIakp/CalculoValorVenda_IDs', {
        comp: String(comprimento.value),
        larg: String(largura.value),
        nmMaterial: material.nome,
        nmClassificacao: getNomeClassificacao(),
        nmTipo: getNomeTipo(),
        nmLinha: getNomeLinha(),
        nmNivel: getNomeNivel(),
        nmBorda: getNomeBorda(),
        margem: String(authIns.user?.margem ?? 0),
        frete_b2b: String(authIns.user?.frtB2B ?? 0),
        quantidade: String(quantidade.value),
        IPI: String(material.ipi || 0),
        IMP: String(material.imp || 0),
        bSimulaMargens: String(bSimulaMargens),
      })
      resultado.value = response.getBody() as OrcamentoResult
    } catch (err: any) {
      console.error('Erro ao calcular:', err)
      error.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao calcular'
    } finally {
      loading.value = false
    }
  }

  async function gerarNumeroOrcamento() {
    if (numeroOrcamento.value) return
    try {
      const authIns = useAuthStore()
      const response = await xano.get('/api:-qqRIakp/Novo_Numero_Orcamento', {
        id_do_Usuario: authIns.user?.id,
      })
      numeroOrcamento.value = response.getBody().result_1?.newOrca
    } catch (err: any) {
      console.error('Erro ao gerar número do orçamento:', err)
      throw new Error('Erro ao gerar número do orçamento')
    }
  }

  async function inserirOrcamento(cliente_id: number, descricao: string) {
    if (!resultado.value) { error.value = 'Calcule o orçamento primeiro'; return }

    inserindo.value = true
    error.value = null

    try {
      await gerarNumeroOrcamento()
      if (!numeroOrcamento.value) { throw new Error('Número do orçamento não gerado') }

      const authIns = useAuthStore()
      const r = resultado.value
      const produto = r.Produto_2[0]
      if (!produto) { throw new Error('Produto não encontrado no resultado') }
      const fator = r.Tipo_Fator_1[0]
      if (!fator) { throw new Error('Fator de corte não encontrado no resultado') }

      const hoje = new Date()
      const dias = authIns.user?.DiasVencimentoOrcamento ?? 15
      const venc = new Date(hoje.getTime() + dias * 86400000)
      const validade = venc.toLocaleDateString('en-US')

      const payload: OrcamentoInsertPayload = {
        cod_orca: numeroOrcamento.value!,
        cliente_id: String(cliente_id),
        frtB2B: authIns.user?.frtB2B ?? null,
        frtB2C: null,
        validade,
        margem: authIns.user?.margem ?? 0,
        produto_id: produto.id,
        ipi: materialSelecionado.value?.ipi ?? null,
        imp: materialSelecionado.value?.imp ?? null,
        vlr_custo: produto.valor,
        und_produto: produto.Unidade,
        larg: largura.value,
        comp: comprimento.value,
        larg_fc: r.LargFC,
        comp_fc: r.CompFC,
        borda_id: String(bordaSelecionada.value?.id ?? 0),
        vlr_cst_borda: r.cst_borda,
        und_borda: bordaSelecionada.value?.Unidade ?? '',
        tipo_fator_id: fator.id,
        fator_de_corte_id: fator.fator_de_corte_id,
        detalhe_id: produto.detalhe_id,
        variacao_id: 0,
        qtd: String(quantidade.value),
        vlr_cst_unit: r.func_1.Valor_Custo_Unit,
        vlr_cst_unit_ipi: r.func_1.Valor_Custo_IPI ?? null,
        vlr_cst_unit_imp: r.func_1.Valor_Custo_IMP ?? null,
        vlr_vnd_unit: r.func_1.Valor_Venda_Unit,
        vlr_vnd_unit_ipi: r.func_1.valor_venda_ipi_tot ?? 0,
        vlr_vnd_unit_imp: r.func_1.valor_venda_imp_tot ?? 0,
        vlr_vnd_unit_b2b: r.func_1.Valor_Venda_Unit_B2B,
        descricao,
        area_user: areaNominal.value,
        area_calc: r.func_1.AreaFC,
      }

      const response = await xano.post('/api:-qqRIakp/OrcamentoItem_Inserir', payload)
      const body = response.getBody()
      itensInseridos.value = body?.ORC?.itemS ?? []
      orcamentoHeader.value = body?.ORC?.ORCA_1 ?? null
      numeroOrcamento.value = body?.ORC?.ORCA_1?.cod_orca ?? numeroOrcamento.value
      limparFormItem()
    } catch (err: any) {
      console.error('Erro ao inserir orçamento:', err)
      error.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao inserir orçamento'
      throw err
    } finally {
      inserindo.value = false
    }
  }

  function limparFormItem() {
    materialSelecionado.value = null
    linhaSelecionada.value = null
    tipoSelecionado.value = null
    nivelSelecionado.value = null
    bordaSelecionada.value = null
    linhas.value = []
    tipos.value = []
    niveis.value = []
    bordas.value = []
    largura.value = 0
    comprimento.value = 0
    quantidade.value = 1
    resultado.value = null
    error.value = null
  }

  function resetar() {
    limparFormItem()
    numeroOrcamento.value = null
    itensInseridos.value = []
    orcamentoHeader.value = null
  }

  return {
    materiais,
    linhas,
    tipos,
    niveis,
    bordas,
    materialSelecionado,
    linhaSelecionada,
    tipoSelecionado,
    nivelSelecionado,
    bordaSelecionada,
    largura,
    comprimento,
    quantidade,
    resultado,
    loading,
    error,
    numeroOrcamento,
    inserindo,
    itensInseridos,
    orcamentoHeader,
    areaNominal,
    func1,
    mostrarLinha,
    mostrarTipo,
    mostrarNivel,
    mostrarBorda,
    carregarMateriais,
    selecionarMaterial,
    limparMaterial,
    calcular,
    gerarNumeroOrcamento,
    inserirOrcamento,
    resetar,
  }
})
