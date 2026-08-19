import { ref, computed, watch } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import { useAuthStore } from './auth'
import { useCatalogoStore } from './catalogo'
import type {
  Material,
  Linha,
  Tipo,
  Nivel,
  Borda,
  Variacao,
  OrcamentoResult,
  OrcamentoNovoResult,
  Func1,
  OrcamentoInsertPayload,
} from '@/types/orcamento'

export const useOrcamentoStore = defineStore('orcamento', () => {
  const catalogo = useCatalogoStore()

  const materiais = computed(() => catalogo.materiais)
  const linhas = computed(() =>
    materialSelecionado.value?.suc?.Linha ? catalogo.linhasFiltradas : [],
  )
  const tipos = computed(() =>
    materialSelecionado.value?.suc?.Tipo ? catalogo.tiposFiltrados : [],
  )
  const niveis = computed(() =>
    materialSelecionado.value?.suc?.Nivel ? catalogo.niveisFiltrados : [],
  )
  const bordas = computed(() =>
    materialSelecionado.value?.suc?.Borda ? catalogo.bordasFiltradas : [],
  )

  const materialSelecionado = ref<Material | null>(null)
  const linhaSelecionada = ref<Linha | null>(null)
  const tipoSelecionado = ref<Tipo | null>(null)
  const nivelSelecionado = ref<Nivel | null>(null)
  const bordaSelecionada = ref<Borda | null>(null)
  const variacaoSelecionada = ref<Variacao | null>(null)

  const largura = ref<number>(0)
  const comprimento = ref<number>(0)
  const quantidade = ref<number>(1)
  // Área em m² para produtos ML (metro linear)
  const areaML = ref<number>(0)

  const resultado = ref<OrcamentoResult | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  const numeroOrcamento = ref<string | null>(null)
  const inserindo = ref(false)
  const itensInseridos = ref<any[]>([])
  const orcamentoHeader = ref<any | null>(null)
  const carregandoOrcamento = ref(false)
  const margemPersonalizada = ref<number | null>(null)
  const fretePersonalizado = ref<number | null>(null)

  // Totais derivados do header (fonte única — sem estado duplicado).
  const totaisRecalculo = computed(() => {
    const h = orcamentoHeader.value
    if (!h) return null
    const cst = Number(h.cst_tot) || 0
    const vnd = Number(h.vnd_tot) || 0
    const luc = Number(h.luc_tot) || 0
    return {
      cst_tot: cst,
      venda_bruta_tot: Number(h.venda_bruta_tot) ?? 0,
      vnd_tot: vnd,
      luc_tot: luc,
      vnd_B2B_tot: Number(h.vnd_B2B_tot) ?? vnd,
      vnd_B2B_B2C_tot: Number(h.vnd_B2B_B2C_tot) ?? vnd,
      margem: cst > 0 ? round4(((vnd - cst) / cst) * 100) : 0,
      markup_alvo: Number(h.margem) || 0,
      markup_efetivo: Number(h.markup_efetivo) ?? 0,
      margem_real_total: vnd > 0 ? round4((luc / vnd) * 100) : 0,
      frete_b2b_total: Number(h.frtB2B) || 0,
      desconto: Number(h.desconto) || 0,
      frtB2C: Number(h.frtB2C) || 0,
      mao_de_obra: Number(h.mao_de_obra) || 0,
      ipi_tot: Number(h.vlr_ipi_tot) || 0,
      st_tot: Number(h.vlr_st_tot) || 0,
      difal_tot: Number(h.valor_difal_tot) || 0,
      credito_icms_tot: Number(h.vlr_credito_icms_tot) || 0,
      total_itens: itensInseridos.value.length,
    }
  })

  function round4(n: number) {
    return Math.round(n * 10000) / 10000
  }

  const areaNominal = computed(() => largura.value * comprimento.value)

  watch(
    [
      largura,
      comprimento,
      quantidade,
      linhaSelecionada,
      tipoSelecionado,
      nivelSelecionado,
      bordaSelecionada,
    ],
    () => {
      resultado.value = null
    },
  )

  const func1 = computed<Func1 | null>(() => resultado.value?.func_1 ?? null)

  // suc efetivo: usa o sucFiltrado (seleção linha/tipo) quando disponível,
  // senão o suc carregado no catálogo
  const sucAtual = computed(() => {
    if (catalogo.sucFiltrado) return catalogo.sucFiltrado
    return materialSelecionado.value?.suc ?? null
  })

  // Quando a seleção de linha/tipo muda, refina o suc no servidor
  watch([linhaSelecionada, tipoSelecionado], ([linha, tipo]) => {
    const m = materialSelecionado.value
    if (!m) {
      catalogo.sucFiltrado = null
      return
    }
    catalogo.filtrarSuc(m.id, linha?.id, tipo?.id)
  })

  const mostrarLinha = computed(() => {
    if (!sucAtual.value) return false
    return sucAtual.value.Linha > 0
  })

  const mostrarTipo = computed(() => {
    if (!sucAtual.value) return false
    return sucAtual.value.Tipo > 0
  })

  const mostrarNivel = computed(() => {
    const m = materialSelecionado.value
    if (!m) return false
    if (!sucAtual.value) return false
    if (sucAtual.value.Nivel <= 0) return false

    const linhaNome = linhaSelecionada.value?.nome ?? ''
    const tipoNome = tipoSelecionado.value?.nome ?? ''

    const isVinil = /vinil/i.test(m.nome)
    const isGoldOuAltTrafego = /^(gold|alto\s*tr[áa]fego)$/i.test(linhaNome)
    const isLiso = /^liso$/i.test(tipoNome)

    if (isVinil && isGoldOuAltTrafego && isLiso) return false

    return true
  })

  watch(mostrarNivel, (val) => {
    if (!val) nivelSelecionado.value = null
  })

  const mostrarBorda = computed(() => {
    if (!sucAtual.value) return false
    return sucAtual.value.Borda > 0
  })

  const variacoes = computed<Variacao[]>(() => {
    const m = materialSelecionado.value
    if (!m) return []

    const linhaId = linhaSelecionada.value?.id ?? 0
    const tipoId = tipoSelecionado.value?.id ?? 0
    const nivelId = nivelSelecionado.value?.id ?? 0

    const vistos = new Set<number>()
    const lista: Variacao[] = []

    for (const p of catalogo.allProdutos) {
      if (
        p.material_id === m.id &&
        p.linha_id === linhaId &&
        p.tipo_id === tipoId &&
        p.nivel_id === nivelId
      ) {
        for (const v of p._variacao ?? []) {
          if (!vistos.has(v.id)) {
            vistos.add(v.id)
            lista.push(v)
          }
        }
      }
    }

    return lista.sort((a, b) => a.ordem - b.ordem || a.id - b.id)
  })

  const mostrarVariacao = computed(() => variacoes.value.length > 0)

  watch(mostrarVariacao, (val) => {
    if (!val) variacaoSelecionada.value = null
  })

  watch(variacoes, (lista) => {
    const sel = variacaoSelecionada.value
    if (sel && !lista.some((v) => v.id === sel.id)) {
      variacaoSelecionada.value = null
    }
  })

  // Produto encontrado pelas FKs da seleção atual (material/linha/tipo/nivel).
  // Usado para descobrir a Unidade de venda (M2/ML/KIT/UND) e definir os inputs.
  // FK com valor 0 significa "qualquer" — aceita produto que não tenha a FK preenchida
  // quando o usuário também não a selecionou.
  const produtoSelecionado = computed(() => {
    const m = materialSelecionado.value
    if (!m) return null
    const linhaId = linhaSelecionada.value?.id ?? 0
    const tipoId = tipoSelecionado.value?.id ?? 0
    const nivelId = nivelSelecionado.value?.id ?? 0
    const matchFk = (produtoVal: number | undefined, selecionado: number) =>
      selecionado === 0 || (produtoVal ?? 0) === 0 || produtoVal === selecionado
    return (
      catalogo.allProdutos.find(
        (p) =>
          p.material_id === m.id &&
          matchFk(p.linha_id, linhaId) &&
          matchFk(p.tipo_id, tipoId) &&
          matchFk(p.nivel_id, nivelId),
      ) ?? null
    )
  })

  // Unidade de venda do produto selecionado (default M2).
  // Base_de_Calculo define COMO vender (M2/ML/KIT/UND); Unidade é a unidade do custo
  // (ex.: Grama tem Unidade=M2 para o custo da Kapazi, mas Base_de_Calculo=ML).
  const unidadeSelecionada = computed(() => {
    const p = produtoSelecionado.value
    const base = p?.Base_de_Calculo?.toUpperCase() ?? 'M2'
    if (base === 'ML' || base === 'KIT' || base === 'UND') return base
    return 'M2'
  })

  // true quando o produto é vendido por metro linear (mostra campo Área)
  const ehML = computed(() => unidadeSelecionada.value === 'ML')

  // resultado do Orcamento_Orquestrador (novo fluxo)
  const resultadoNovo = ref<any | null>(null)

  async function carregarMateriais() {
    await catalogo.fetchCatalogo()
  }

  function selecionarMaterial(material: Material) {
    materialSelecionado.value = material
    catalogo.selectedMaterialId = material.id
    linhaSelecionada.value = null
    tipoSelecionado.value = null
    nivelSelecionado.value = null
    bordaSelecionada.value = null
    variacaoSelecionada.value = null
    catalogo.sucFiltrado = null
    resultado.value = null
    resultadoNovo.value = null
    areaML.value = 0
  }

  function limparMaterial() {
    materialSelecionado.value = null
    catalogo.selectedMaterialId = null
    linhaSelecionada.value = null
    tipoSelecionado.value = null
    nivelSelecionado.value = null
    bordaSelecionada.value = null
    variacaoSelecionada.value = null
    catalogo.sucFiltrado = null
    resultado.value = null
    resultadoNovo.value = null
    areaML.value = 0
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
    if (!material) {
      error.value = 'Selecione um material'
      return
    }
    if (!largura.value || largura.value <= 0) {
      error.value = 'Preencha a largura'
      return
    }
    if (!comprimento.value || comprimento.value <= 0) {
      error.value = 'Preencha o comprimento'
      return
    }
    if (!quantidade.value || quantidade.value < 1) {
      error.value = 'Informe a quantidade'
      return
    }
    if (mostrarLinha.value && linhas.value.length && !linhaSelecionada.value) {
      error.value = 'Selecione a linha'
      return
    }
    if (mostrarTipo.value && tipos.value.length && !tipoSelecionado.value) {
      error.value = 'Selecione o tipo'
      return
    }
    if (mostrarNivel.value && niveis.value.length && !nivelSelecionado.value) {
      error.value = 'Selecione o nível'
      return
    }
    if (mostrarBorda.value && bordas.value.length && !bordaSelecionada.value) {
      error.value = 'Selecione a borda'
      return
    }
    if (mostrarVariacao.value && !variacaoSelecionada.value) {
      error.value = 'Selecione a variação'
      return
    }

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
        margem: String(margemPersonalizada.value ?? authIns.user?.margem ?? 0),
        frete_b2b: String(fretePersonalizado.value ?? authIns.user?.frtB2B ?? 0),
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

  // Calcula a precificação via Orcamento_Orquestrador (M2/ML/KIT/UND por IDs).
  // Usado no novo fluxo — substitui o calcular() legado por nomes.
  async function calcularOrquestrador(modoEntrada: 'area' | 'dimensoes' = 'dimensoes') {
    const material = materialSelecionado.value
    if (!material) {
      error.value = 'Selecione um material'
      return
    }
    if (mostrarLinha.value && linhas.value.length && !linhaSelecionada.value) {
      error.value = 'Selecione a linha'
      return
    }
    if (mostrarTipo.value && tipos.value.length && !tipoSelecionado.value) {
      error.value = 'Selecione o tipo'
      return
    }
    if (mostrarNivel.value && niveis.value.length && !nivelSelecionado.value) {
      error.value = 'Selecione o nível'
      return
    }
    if (mostrarBorda.value && bordas.value.length && !bordaSelecionada.value) {
      error.value = 'Selecione a borda'
      return
    }
    if (mostrarVariacao.value && !variacaoSelecionada.value) {
      error.value = 'Selecione a variação'
      return
    }
    if (!produtoSelecionado.value?.produto_id) {
      error.value = 'Produto não identificado'
      return
    }
    if (unidadeSelecionada.value === 'UND') {
      if (!quantidade.value || quantidade.value < 1) {
        error.value = 'Informe a quantidade'
        return
      }
    } else if (ehML.value) {
      const temArea = areaML.value > 0
      const temDims = largura.value > 0 && comprimento.value > 0
      if (!temArea && !temDims) {
        error.value = 'Preencha a área ou as dimensões'
        return
      }
    } else {
      if (!largura.value || largura.value <= 0) {
        error.value = 'Preencha a largura'
        return
      }
      if (!comprimento.value || comprimento.value <= 0) {
        error.value = 'Preencha o comprimento'
        return
      }
    }

    loading.value = true
    error.value = null

    const authIns = useAuthStore()
    const user = authIns.user
    const produto = produtoSelecionado.value

    // markup: 1º item (sem orca) usa user.margem; com orca usa a margem do header
    const markup = orcamentoHeader.value?.margem ?? margemPersonalizada.value ?? user?.margem ?? 100

    const payload: Record<string, any> = {
      produto_id: produto?.produto_id ?? 0,
      borda_id: bordaSelecionada.value?.id ?? 0,
      variacao_id: variacaoSelecionada.value?.id ?? 0,
      markup,
      orca_id: orcamentoHeader.value?.id ?? 0,
      uf_destino: user?.uf ?? 'SP',
      regime_id: user?.regime_id ?? 0,
    }

    // Área: largura=0 e quantidade=0. Dimensões: comprimento_ou_area=comp, largura=larg
    if (modoEntrada === 'area' && areaML.value > 0) {
      payload.comprimento_ou_area = areaML.value
      payload.largura = 0
      payload.quantidade = 0
    } else {
      payload.comprimento_ou_area = comprimento.value
      payload.largura = largura.value
      payload.quantidade = quantidade.value
    }

    try {
      const response = await xano.post('/api:-qqRIakp/orcamento_calcular', payload)
      resultadoNovo.value = response.getBody()
    } catch (err: any) {
      console.error('Erro ao calcular (orquestrador):', err)
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

  // Monta os campos do item a partir do resultado novo (orquestrador flat).
  // Usado pelo inserir e pelo atualizar (não inclui cod_orca/cliente/frete/validade).
  function montarPayloadItem(descricao: string, margemBase: number) {
    const it = resultadoNovo.value as OrcamentoNovoResult
    const undVenda = it.base_calculo || 'M2'
    const undBorda =
      catalogo.allBordas.find((b) => b.id === (bordaSelecionada.value?.id ?? 0))?.Unidade ??
      bordaSelecionada.value?.Unidade ??
      ''
    return {
      margem: margemBase,
      produto_id: it.produto_id ?? 0,
      ipi: it.ipi ?? materialSelecionado.value?.ipi ?? null,
      imp: 0,
      vlr_custo: it.vlr_cst_materia_prima ?? 0,
      und_produto: undVenda,
      larg: it.larg ?? 0,
      comp: it.comp ?? 0,
      larg_fc: it.larg_fc ?? 0,
      comp_fc: it.comp_fc ?? 0,
      borda_id: String(it.borda_id ?? 0),
      vlr_cst_borda: it.vlr_cst_borda ?? 0,
      und_borda: undBorda,
      tipo_fator_id: it.tipo_fator_id ?? 0,
      fator_de_corte_id: it.fator_de_corte_id ?? 0,
      detalhe_id: 0,
      variacao_id: it.variacao_id ?? 0,
      qtd: String(it.qtd ?? 1),
      vlr_cst_unit: it.vlr_cst_unit ?? 0,
      vlr_cst_unit_ipi: null,
      vlr_cst_unit_imp: null,
      vlr_vnd_unit: it.vlr_vnd_unit ?? 0,
      vlr_vnd_unit_ipi: 0,
      vlr_vnd_unit_imp: 0,
      vlr_vnd_unit_b2b: it.vlr_vnd_unit ?? 0,
      vlr_lucro_unit: it.vlr_lucro_unit ?? 0,
      descricao,
      area_user: areaNominal.value,
      area_calc: it.qtd ?? 0,
      base_calculo: undVenda,
      vlr_cst_nota_unit: it.vlr_custo_nota_unit ?? 0,
      vlr_cst_entrada_unit: it.vlr_cst_entrada_unit ?? 0,
      valor_difal_unit: it.vlr_difal_unit ?? 0,
      vlr_credito_icms_unit: it.vlr_credito_icms_unit ?? 0,
      aliq_inter: it.vlr_aliq_inter ?? 0,
      aliq_interna: it.vlr_aliq_interna ?? 0,
      perc_difal: it.vlr_perc_difal ?? 0,
      vlr_frete_b2b_unit: it.frete_b2b ?? 0,
      vlr_st_unit: it.vlr_st_unit ?? 0,
      vlr_custo_fiscal_unit: it.vlr_custo_fiscal_unit ?? 0,
      eh_importado: it.eh_importado ?? false,
      perc_margem_real: it.perc_marguem_real ?? 0,
      fc: it.fc ?? [],
    }
  }

  async function inserirOrcamento(
    cliente_id: number,
    descricao: string,
    existingCodOrca?: string,
    observacao?: string,
  ) {
    if (!resultado.value && !resultadoNovo.value) {
      error.value = 'Calcule o orçamento primeiro'
      return
    }

    inserindo.value = true
    error.value = null

    try {
      if (existingCodOrca) {
        numeroOrcamento.value = existingCodOrca
      } else {
        await gerarNumeroOrcamento()
      }
      if (!numeroOrcamento.value) {
        throw new Error('Número do orçamento não gerado')
      }

      const authIns = useAuthStore()

      const hoje = new Date()
      const dias = authIns.user?.DiasVencimentoOrcamento ?? 15
      const venc = new Date(hoje.getTime() + dias * 86400000)
      const validade = venc.toLocaleDateString('en-US')

      // Monta o payload a partir do resultado (legado por nomes) OU do novo orquestrador (flat)
      let payload: OrcamentoInsertPayload

      if (resultadoNovo.value) {
        const it = resultadoNovo.value as OrcamentoNovoResult
        // unidade de venda (Base_de_Calculo)
        const undVenda = it.base_calculo || 'M2'
        const undBorda =
          catalogo.allBordas.find((b) => b.id === (bordaSelecionada.value?.id ?? 0))?.Unidade ??
          bordaSelecionada.value?.Unidade ??
          ''
        payload = {
          cod_orca: numeroOrcamento.value!,
          cliente_id: String(cliente_id),
          frtB2B: fretePersonalizado.value ?? authIns.user?.frtB2B ?? null,
          frtB2C: null,
          validade,
          margem:
            (existingCodOrca ? orcamentoHeader.value?.margem : null) ??
            margemPersonalizada.value ??
            authIns.user?.margem ??
            0,
          observacao: observacao ?? '',
          produto_id: it.produto_id ?? 0,
          ipi: it.ipi ?? materialSelecionado.value?.ipi ?? null,
          imp: 0,
          vlr_custo: it.vlr_cst_materia_prima ?? 0,
          und_produto: undVenda,
          larg: it.larg ?? 0,
          comp: it.comp ?? 0,
          larg_fc: it.larg_fc ?? 0,
          comp_fc: it.comp_fc ?? 0,
          borda_id: String(it.borda_id ?? 0),
          vlr_cst_borda: it.vlr_cst_borda ?? 0,
          und_borda: undBorda,
          tipo_fator_id: it.tipo_fator_id ?? 0,
          fator_de_corte_id: it.fator_de_corte_id ?? 0,
          detalhe_id: 0,
          variacao_id: it.variacao_id ?? 0,
          qtd: String(it.qtd ?? 1),
          vlr_cst_unit: it.vlr_cst_unit ?? 0,
          vlr_cst_unit_ipi: null,
          vlr_cst_unit_imp: null,
          vlr_vnd_unit: it.vlr_vnd_unit ?? 0,
          vlr_vnd_unit_ipi: 0,
          vlr_vnd_unit_imp: 0,
          vlr_vnd_unit_b2b: it.vlr_vnd_unit ?? 0,
          vlr_lucro_unit: it.vlr_lucro_unit ?? 0,
          descricao,
          area_user: areaNominal.value,
          area_calc: it.qtd ?? 0,
          base_calculo: undVenda,
          vlr_cst_nota_unit: it.vlr_custo_nota_unit ?? 0,
          vlr_cst_entrada_unit: it.vlr_cst_entrada_unit ?? 0,
          valor_difal_unit: it.vlr_difal_unit ?? 0,
          vlr_credito_icms_unit: it.vlr_credito_icms_unit ?? 0,
          aliq_inter: it.vlr_aliq_inter ?? 0,
          aliq_interna: it.vlr_aliq_interna ?? 0,
          perc_difal: it.vlr_perc_difal ?? 0,
          vlr_frete_b2b_unit: it.frete_b2b ?? 0,
          vlr_st_unit: it.vlr_st_unit ?? 0,
          vlr_custo_fiscal_unit: it.vlr_custo_fiscal_unit ?? 0,
          eh_importado: it.eh_importado ?? false,
          perc_margem_real: it.perc_marguem_real ?? 0,
          fc: it.fc ?? [],
        }
      } else {
        const r = resultado.value!
        const produto = r.Produto_2[0]
        if (!produto) {
          throw new Error('Produto não encontrado no resultado')
        }
        const fator = r.Tipo_Fator_1[0]
        if (!fator) {
          throw new Error('Fator de corte não encontrado no resultado')
        }
        payload = {
          cod_orca: numeroOrcamento.value!,
          cliente_id: String(cliente_id),
          frtB2B: fretePersonalizado.value ?? authIns.user?.frtB2B ?? null,
          frtB2C: null,
          validade,
          margem:
            (existingCodOrca ? orcamentoHeader.value?.margem : null) ??
            margemPersonalizada.value ??
            authIns.user?.margem ??
            0,
          observacao: observacao ?? '',
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
          variacao_id: variacaoSelecionada.value?.id ?? 0,
          qtd: String(quantidade.value),
          vlr_cst_unit: r.func_1.Valor_Custo_Unit,
          vlr_cst_unit_ipi: r.func_1.Valor_Custo_IPI ?? null,
          vlr_cst_unit_imp: r.func_1.Valor_Custo_IMP ?? null,
          vlr_vnd_unit: r.func_1.Valor_Venda_Unit,
          vlr_vnd_unit_ipi: r.func_1.valor_venda_ipi_tot ?? 0,
          vlr_vnd_unit_imp: r.func_1.valor_venda_imp_tot ?? 0,
          vlr_vnd_unit_b2b: r.func_1.Valor_Venda_Unit_B2B,
          vlr_lucro_unit: r.func_1.Valor_Lucro_Unit ?? 0,
          descricao,
          area_user: areaNominal.value,
          area_calc: r.func_1.AreaFC,
          base_calculo: produto.Base_de_Calculo || produto.Unidade,
          vlr_cst_nota_unit: r.func_1.Valor_Custo_Unit ?? 0,
          vlr_cst_entrada_unit: r.func_1.Valor_Custo_Unit ?? 0,
          valor_difal_unit: 0,
          vlr_credito_icms_unit: 0,
          aliq_inter: 0,
          aliq_interna: 0,
          perc_difal: 0,
          vlr_frete_b2b_unit: 0,
          vlr_st_unit: 0,
          vlr_custo_fiscal_unit: r.func_1.Valor_Custo_Unit ?? 0,
          eh_importado: false,
          perc_margem_real: 0,
          fc: fator?._fator_de_corte?.valor ?? [],
        }
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

  // Atualiza um item existente (edição de características) no mesmo registro.
  async function atualizarItem(itemId: number, descricao: string) {
    if (!resultado.value && !resultadoNovo.value) {
      error.value = 'Calcule o orçamento primeiro'
      return
    }
    inserindo.value = true
    error.value = null
    try {
      const margemBase =
        orcamentoHeader.value?.margem ??
        margemPersonalizada.value ??
        useAuthStore().user?.margem ??
        0
      const payload = montarPayloadItem(descricao, margemBase)
      const response = await xano.post('/api:-qqRIakp/OrcamentoItem_Atualizar', {
        item_id: itemId,
        ...payload,
      })
      const body = response.getBody() as any
      orcamentoHeader.value = body?.ORCA_1 ?? null
      itensInseridos.value = body?.itemS ?? []
      numeroOrcamento.value = body?.ORCA_1?.cod_orca ?? numeroOrcamento.value
      limparFormItem()
    } catch (err: any) {
      console.error('Erro ao atualizar item:', err)
      error.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao atualizar item'
      throw err
    } finally {
      inserindo.value = false
    }
  }

  function limparFormItem() {
    materialSelecionado.value = null
    catalogo.selectedMaterialId = null
    linhaSelecionada.value = null
    tipoSelecionado.value = null
    nivelSelecionado.value = null
    bordaSelecionada.value = null
    variacaoSelecionada.value = null
    catalogo.sucFiltrado = null
    largura.value = 0
    comprimento.value = 0
    quantidade.value = 1
    areaML.value = 0
    resultado.value = null
    resultadoNovo.value = null
    error.value = null
  }

  function resetar() {
    limparFormItem()
    numeroOrcamento.value = null
    itensInseridos.value = []
    orcamentoHeader.value = null
    carregandoOrcamento.value = false
    limparPersonalizacoes()
  }

  async function carregarOrcamento(codOrca: string, newMargem?: number) {
    carregandoOrcamento.value = true
    try {
      // Leitura read-only: 1 chamada, sem recalcular e sem escrever no banco.
      const response = await xano.get('/api:-qqRIakp/orca_detalhes', {
        cod_orca: codOrca,
      })
      const body = response.getBody() as any
      const header = body?.ORCA_1 ?? null
      if (!header?.id) {
        throw new Error('Orçamento não encontrado')
      }
      orcamentoHeader.value = header
      itensInseridos.value = body?.itemS ?? []
      numeroOrcamento.value = header?.cod_orca ?? codOrca
    } catch (err: any) {
      console.error('Erro ao carregar orçamento:', err)
      throw new Error(err?.getResponse?.()?.getBody?.()?.message || 'Erro ao carregar orçamento')
    } finally {
      carregandoOrcamento.value = false
    }
  }

  async function deleteOrcamento(orcaId: number) {
    try {
      await xano.delete('/api:-qqRIakp/orcamento_deletar', {
        orca_id: orcaId,
      })
    } catch (err: any) {
      console.error('Erro ao excluir orçamento:', err)
      throw new Error(err?.getResponse?.()?.getBody?.()?.message || 'Erro ao excluir orçamento')
    }
  }

  function definirMargemPersonalizada(valor: number | null) {
    margemPersonalizada.value = valor != null ? parseFloat(valor.toFixed(4)) : null
    resultado.value = null
  }

  function definirFretePersonalizado(valor: number | null) {
    fretePersonalizado.value = valor != null ? parseFloat(valor.toFixed(2)) : null
    resultado.value = null
  }

  function limparPersonalizacoes() {
    margemPersonalizada.value = null
    fretePersonalizado.value = null
  }

  // Recálculo dinâmico por somatório (markup efetivo, frete B2C, desconto, mão de obra)
  async function recalcularTotais(
    orcaId: number,
    opts?: {
      newMargem?: number
      frtB2C?: number
      desconto?: number
      maoDeObra?: number
      observacao?: string
      condicoesPagamento?: string
    },
  ) {
    carregandoOrcamento.value = true
    error.value = null
    try {
      const response = await xano.post('/api:-qqRIakp/orcamento_recalcular', {
        orca_id: orcaId,
        newMargem: opts?.newMargem,
        frtB2C: opts?.frtB2C,
        desconto: opts?.desconto,
        maoDeObra: opts?.maoDeObra,
        observacao: opts?.observacao,
        condicoesPagamento: opts?.condicoesPagamento,
      })
      const body = response.getBody() as any
      console.log('[recalcularTotais] resposta', {
        frtB2C: body?.ORCA_1?.frtB2C,
        desconto: body?.ORCA_1?.desconto,
        vnd_B2B_B2C_tot: body?.ORCA_1?.vnd_B2B_B2C_tot,
      })
      orcamentoHeader.value = body?.ORCA_1 ?? null
      itensInseridos.value = body?.itemS ?? []
      numeroOrcamento.value = body?.ORCA_1?.cod_orca ?? numeroOrcamento.value
    } catch (err: any) {
      console.error('Erro ao recalcular:', err)
      error.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao recalcular'
      throw err
    } finally {
      carregandoOrcamento.value = false
    }
  }

  // Remove um item e recalcula os totais
  async function removerItem(itemId: number) {
    try {
      const response = await xano.delete('/api:-qqRIakp/orcamento_item_deletar', {
        item_id: itemId,
      })
      const body = response.getBody() as any
      orcamentoHeader.value = body?.ORCA_1 ?? null
      itensInseridos.value = (itensInseridos.value ?? []).filter((i) => i.id !== itemId)
      resultadoNovo.value = null
      resultado.value = null
    } catch (err: any) {
      console.error('Erro ao remover item:', err)
      error.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao remover item'
      throw err
    }
  }

  // Define frete B2C e recalcula (negociação)
  async function definirFreteB2C(orcaId: number, valor: number) {
    await recalcularTotais(orcaId, { frtB2C: valor })
  }

  // Define desconto e recalcula (negociação)
  async function definirDesconto(orcaId: number, valor: number) {
    await recalcularTotais(orcaId, { desconto: valor })
  }

  // Atualiza o status do orçamento (RASCUNHO → AGUARDANDO_RETORNO → APROVADO → FATURADO)
  async function atualizarStatus(orcaId: number, status: string) {
    try {
      const response = await xano.post('/api:-qqRIakp/orcamento_status', {
        orca_id: orcaId,
        status,
      })
      const body = response.getBody() as any
      orcamentoHeader.value = body?.ORCA_1 ?? orcamentoHeader.value
    } catch (err: any) {
      console.error('Erro ao atualizar status:', err)
      error.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao atualizar status'
      throw err
    }
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
    variacaoSelecionada,
    variacoes,
    largura,
    comprimento,
    quantidade,
    areaML,
    resultado,
    resultadoNovo,
    produtoSelecionado,
    unidadeSelecionada,
    ehML,
    loading,
    error,
    numeroOrcamento,
    inserindo,
    itensInseridos,
    orcamentoHeader,
    totaisRecalculo,
    carregandoOrcamento,
    margemPersonalizada,
    fretePersonalizado,
    areaNominal,
    func1,
    mostrarLinha,
    mostrarTipo,
    mostrarNivel,
    mostrarBorda,
    mostrarVariacao,
    carregarMateriais,
    selecionarMaterial,
    limparMaterial,
    calcular,
    calcularOrquestrador,
    gerarNumeroOrcamento,
    inserirOrcamento,
    atualizarItem,
    resetar,
    carregarOrcamento,
    deleteOrcamento,
    recalcularTotais,
    removerItem,
    definirFreteB2C,
    definirDesconto,
    atualizarStatus,
    definirMargemPersonalizada,
    definirFretePersonalizado,
    limparPersonalizacoes,
    limparFormItem,
  }
})
