// Motor de precificação (Fase 2A) — port 1:1 das funções Xano.
// Este módulo é agnóstico de runtime (Deno/Node): recebe o client `sb` como
// parâmetro e não importa @supabase/supabase-js diretamente.

export type SbClient = any

const round2 = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100
const round4 = (n: number) => Math.round((n + Number.EPSILON) * 10000) / 10000

// ---------------------------------------------------------------------------
// Tipos
// ---------------------------------------------------------------------------
export interface CalcularInput {
  produto_id: number
  borda_id: number
  variacao_id: number
  markup: number
  orca_id: number
  item_id: number
  uf_destino: string
  regime_id: number
  com_medida_exata: boolean
  rampa_larg1?: boolean
  rampa_comp1?: boolean
  rampa_larg2?: boolean
  rampa_comp2?: boolean
  qtd_cantos?: number
  comprimento_ou_area: number
  largura: number
  quantidade: number
  user_id: number
}

export interface ProdutoCtx {
  id: number
  material_id: number
  classificacao_id: number
  linha_id: number | null
  tipo_id: number | null
  nivel_id: number | null
  valor: number
  com_medida_exata: boolean
  porcentagem_acrescimo: number
  Unidade: string
  Base_de_Calculo: string
  tipo_composto: string
  detalhe_id: number
  fator_de_corte_id: number
  ativo: boolean
  // joins
  borda_id: number | null
  borda_nome: string | null
  borda_valor: number
  borda_unidade: string | null
  material_nome: string | null
  linha_nome: string | null
  tipo_nome: string | null
  nivel_nome: string | null
  ncm: string | null
  imp: number
  ipi: number
  eh_importado: boolean
  st: boolean
  mva_padrao: number
  aliq_st_interna: number
  // variacao (para ML/KIT/UND)
  variacao_id: number | null
  variacao_custo: number | null
  variacao_fc_id: number | null
  variacao: any | null
  fator_de_corte_variacao: any | null
}

export interface PerfilEfetivo {
  id: number
  name: string | null
  razao: string | null
  fantasia: string | null
  cnpj: string | null
  ie: string | null
  cpf: string | null
  isPJ: boolean
  uf: string | null
  regime_id: number | null
  organizacao_id: number | null
  margem: number | null
  frtB2B: number | null
  DiasVencimentoOrcamento: number | null
  logo: any
  role: string | null
  desconto_livre_perc: number | null
  desconto_max_perc: number | null
  plano: string | null
}

export interface Mod1 {
  descricao: string
  quantidade: number
  largura: number | null
  comprimento: number | null
  largura_fc: number | null
  comprimento_fc: number | null
  ncm: string | null
  fc: number[]
  fator_de_corte_id: number
  tipo_fator_id: number
  com_medida_exata: boolean
  acrescimo_medida_exata: number
  detalhes_calculo: any
  valores: {
    custo_materia_prima: number
    custo_borda: number
    custo_total: number
    aliquota_ipi: number
    valor_ipi_tot: number
    valor_ipi_unit: number
    custo_nota_tot: number
    custo_nota_unit: number
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function joinDescricao(partes: (string | null | undefined)[]): string {
  return partes.filter(Boolean).join(' ')
}

// f_empresa_id: sobe a cadeia até o admin (topo).
export async function empresaId(sb: SbClient, userId: number): Promise<number> {
  const { data: me } = await sb.from('usuarios').select('id, role, vendedor_pai_id').eq('id', userId).single()
  if (!me) return userId
  if (me.role === 'vendedor' || me.role === 'vendedor_master') {
    const paiId = me.vendedor_pai_id ?? 0
    if (paiId > 0) {
      const { data: pai } = await sb.from('usuarios').select('id, role, vendedor_pai_id').eq('id', paiId).single()
      if (pai && pai.role === 'vendedor_master' && pai.vendedor_pai_id && pai.vendedor_pai_id > 0) {
        return pai.vendedor_pai_id
      }
      return pai ? pai.id : userId
    }
    return userId
  }
  return userId
}

// f_perfil_efetivo: configuração do topo da cadeia (admin).
export async function perfilEfetivo(sb: SbClient, userId: number): Promise<PerfilEfetivo | null> {
  const topId = await empresaId(sb, userId)
  const { data } = await sb
    .from('usuarios')
    .select(
      'id, name, razao, fantasia, cnpj, ie, cpf, is_pj, uf, regime_id, organizacao_id, margem, frt_b2b, dias_vencimento_orcamento, logo, role, desconto_livre_perc, desconto_max_perc, plano',
    )
    .eq('id', topId)
    .single()
  if (!data) return null
  return {
    id: data.id,
    name: data.name,
    razao: data.razao,
    fantasia: data.fantasia,
    cnpj: data.cnpj,
    ie: data.ie,
    cpf: data.cpf,
    isPJ: data.is_pj,
    uf: data.uf,
    regime_id: data.regime_id,
    organizacao_id: data.organizacao_id,
    margem: data.margem,
    frtB2B: data.frt_b2b,
    DiasVencimentoOrcamento: data.dias_vencimento_orcamento,
    logo: data.logo,
    role: data.role,
    desconto_livre_perc: data.desconto_livre_perc,
    desconto_max_perc: data.desconto_max_perc,
    plano: data.plano,
  }
}

// ---------------------------------------------------------------------------
// f_buscador_produto: busca produto + material + borda + variacao + regra fiscal
// ---------------------------------------------------------------------------
export async function buscarProduto(
  sb: SbClient,
  input: Pick<CalcularInput, 'produto_id' | 'borda_id' | 'variacao_id'>,
): Promise<ProdutoCtx | null> {
  const { data: produto } = await sb.from('produto').select('*').eq('id', input.produto_id).single()
  if (!produto) return null

  const materialId = produto.material_id
  const { data: material } = await sb.from('material').select('*').eq('id', materialId).single()

  const regraId = material?.regra_fiscal_id ?? 0
  const { data: regra } =
    regraId > 0 ? await sb.from('regra_fiscal').select('*').eq('id', regraId).single() : { data: null }

  let linhaNome: string | null = null
  let tipoNome: string | null = null
  let nivelNome: string | null = null
  if (produto.linha_id) {
    const { data: l } = await sb.from('linha').select('nome').eq('id', produto.linha_id).single()
    linhaNome = l?.nome ?? null
  }
  if (produto.tipo_id) {
    const { data: t } = await sb.from('tipo').select('nome').eq('id', produto.tipo_id).single()
    tipoNome = t?.nome ?? null
  }
  if (produto.nivel_id) {
    const { data: n } = await sb.from('nivel').select('nome').eq('id', produto.nivel_id).single()
    nivelNome = n?.nome ?? null
  }

  let borda: any = null
  if (input.borda_id && input.borda_id > 0) {
    const { data: b } = await sb.from('borda').select('*').eq('id', input.borda_id).single()
    borda = b
  }

  let variacao: any = null
  let fatorDeCorteVariacao: any = null
  if (input.variacao_id && input.variacao_id > 0) {
    const { data: v } = await sb.from('variacao').select('*').eq('id', input.variacao_id).single()
    variacao = v
    if (v?.fator_de_corte_id) {
      const { data: fc } = await sb
        .from('fator_de_corte')
        .select('*')
        .eq('id', v.fator_de_corte_id)
        .single()
      fatorDeCorteVariacao = fc
    }
  }

  return {
    id: produto.id,
    material_id: produto.material_id,
    classificacao_id: produto.classificacao_id,
    linha_id: produto.linha_id ?? null,
    tipo_id: produto.tipo_id ?? null,
    nivel_id: produto.nivel_id ?? null,
    valor: produto.valor ?? 0,
    com_medida_exata: produto.com_medida_exata ?? false,
    porcentagem_acrescimo: produto.porcentagem_acrescimo ?? 0,
    Unidade: produto.unidade ?? 'M2',
    Base_de_Calculo: produto.base_de_calculo ?? 'M2',
    tipo_composto: produto.tipo_composto ?? '',
    detalhe_id: produto.detalhe_id ?? 0,
    fator_de_corte_id: produto.fator_de_corte_id ?? 0,
    ativo: produto.ativo ?? true,
    borda_id: borda?.id ?? null,
    borda_nome: borda?.nome ?? null,
    borda_valor: borda?.valor ?? 0,
    borda_unidade: borda?.unidade ?? null,
    material_nome: material?.nome ?? null,
    linha_nome: linhaNome,
    tipo_nome: tipoNome,
    nivel_nome: nivelNome,
    ncm: material?.ncm ?? null,
    imp: material?.imp ?? 0,
    ipi: material?.ipi ?? 0,
    eh_importado: material?.importado ?? false,
    st: regra?.tem_st ?? false,
    mva_padrao: regra?.mva_padrao ?? 0,
    aliq_st_interna: regra?.aliq_st_interna ?? 0,
    variacao_id: variacao?.id ?? null,
    variacao_custo: variacao?.valor_custo ?? null,
    variacao_fc_id: variacao?.fator_de_corte_id ?? null,
    variacao,
    fator_de_corte_variacao: fatorDeCorteVariacao,
  }
}

// ---------------------------------------------------------------------------
// f_retorna_fc (port)
// ---------------------------------------------------------------------------
export function retornaFc(
  comp: number,
  larg: number,
  fc: number[],
  modoCorte: string,
  passo: number,
): { new_comp: number; new_larg: number } {
  if (modoCorte === 'passo' && passo > 0) {
    const roundUp = (v: number) => (v > 0 ? Math.ceil(v / passo) * passo : 0)
    const cUp = roundUp(comp)
    const lUp = roundUp(larg)
    if (cUp * larg <= comp * lUp) return { new_comp: cUp, new_larg: larg }
    return { new_comp: comp, new_larg: lUp }
  }
  if (!fc || !fc.length) return { new_comp: comp, new_larg: larg }
  const fc_max = fc[fc.length - 1]
  const larg_maior = fc.find((v) => v >= larg) || 0
  const comp_maior = fc.find((v) => v >= comp) || 0
  if (comp > fc_max && larg > fc_max) return { new_comp: comp, new_larg: larg }
  if (comp_maior && larg_maior) {
    return comp_maior * larg > larg_maior * comp
      ? { new_comp: comp, new_larg: larg_maior }
      : { new_comp: comp_maior, new_larg: larg }
  }
  return comp_maior === 0
    ? { new_comp: comp, new_larg: larg_maior }
    : { new_comp: comp_maior, new_larg: larg }
}

// ---------------------------------------------------------------------------
// fCalculaFrete (port)
// ---------------------------------------------------------------------------
export function calcularFrete(valorPedido: number, minimo: number): number {
  if (valorPedido >= 1000) return 0
  if (valorPedido >= 300) return round2(valorPedido * 0.1)
  if (valorPedido <= 0) return 0
  return minimo || 50
}

// ---------------------------------------------------------------------------
// Precificar (port)
// ---------------------------------------------------------------------------
export async function precificar(
  sb: SbClient,
  p: {
    custo_nota: number
    uf_origem: string
    uf_destino: string
    regime_id: number
    eh_importado: boolean
    tem_st: boolean
    mva_padrao: number
    aliq_st_interna: number
  },
): Promise<any> {
  const { data: dest } = await sb.from('aliquotas_icms').select('*').eq('uf', p.uf_destino).single()
  const { data: orig } = await sb.from('aliquotas_icms').select('*').eq('uf', p.uf_origem).single()
  const estado_destino = dest || { aliquota_modal: 0, regiao: '' }
  const estado_origem = orig || { regiao: '' }

  let regime = ''
  if (p.regime_id && p.regime_id > 0) {
    const { data: r } = await sb.from('regime').select('slug').eq('id', p.regime_id).single()
    regime = (r?.slug || '').toUpperCase()
  }

  // 1. alíquota interestadual
  let aliq_inter = 12
  if (p.eh_importado) aliq_inter = 4
  else if (
    (estado_origem.regiao || '').toUpperCase() === 'SUL_SUDESTE' &&
    (estado_destino.regiao || '').toUpperCase() === 'OUTROS'
  )
    aliq_inter = 7

  // 2. DIFAL
  let perc_difal = 0
  let valor_difal = 0
  if ((p.uf_origem || '').toUpperCase() !== (p.uf_destino || '').toUpperCase()) {
    const difal_bruto = (estado_destino.aliquota_modal || 0) - aliq_inter
    if (difal_bruto > 0) {
      perc_difal = difal_bruto
      valor_difal = round2(p.custo_nota * (difal_bruto / 100))
    }
  }

  // 3. ST
  let valor_st = 0
  if (p.tem_st && regime !== 'MEI') {
    let aliq_st = p.aliq_st_interna
    if (!aliq_st) aliq_st = estado_destino.aliquota_modal
    const base_st = p.custo_nota * (1 + (p.mva_padrao || 0) / 100)
    const icms_st_bruto = base_st * ((aliq_st || 0) / 100)
    const icms_proprio = p.custo_nota * (aliq_inter / 100)
    const st_calculado = round2(icms_st_bruto - icms_proprio)
    if (st_calculado > 0) valor_st = st_calculado
  }

  // 4. crédito + custo fiscal
  let credito_icms = 0
  let custo_fiscal = p.custo_nota
  if (regime === 'MEI' || regime === 'SIMPLES' || regime === 'SIMPLES_NACIONAL') {
    custo_fiscal = round2(p.custo_nota + valor_difal + valor_st)
  } else {
    credito_icms = round2(p.custo_nota * (aliq_inter / 100))
    custo_fiscal = round2(p.custo_nota - credito_icms + valor_st)
  }

  return {
    valor_difal,
    valor_st,
    credito_icms,
    perc_difal,
    aliq_inter,
    aliq_interna: estado_destino.aliquota_modal,
    custo_fiscal,
    regime,
    uf_origem: (p.uf_origem || '').toUpperCase(),
    uf_destino: (p.uf_destino || '').toUpperCase(),
  }
}

// ---------------------------------------------------------------------------
// f_valor_custo_m2 (port)
// ---------------------------------------------------------------------------
export async function custoM2(
  sb: SbClient,
  produto: ProdutoCtx,
  input: CalcularInput,
): Promise<Mod1> {
  const comprimento = input.comprimento_ou_area
  const largura = input.largura
  const quantidade = input.quantidade

  let fator_corte: number[] = []
  let fator_de_corte_id = 0
  let tipo_fator_id = 0
  let modo_corte = 'lista'
  let passo_corte = 0

  if (produto.fator_de_corte_id && produto.fator_de_corte_id > 0) {
    const { data: fc } = await sb.from('fator_de_corte').select('*').eq('id', produto.fator_de_corte_id).single()
    fator_corte = fc?.valor || []
    fator_de_corte_id = fc?.id || 0
    modo_corte = fc?.modo_corte || 'lista'
    passo_corte = fc?.comp_corte || 0
  } else {
    let q = sb.from('tipo_fator').select('*').eq('material_id', produto.material_id)
    q = produto.linha_id == null ? q.is('linha_id', null) : q.eq('linha_id', produto.linha_id)
    q = produto.borda_id == null ? q.is('borda_id', null) : q.eq('borda_id', produto.borda_id)
    const { data: tf } = await q.maybeSingle()
    if (tf) {
      tipo_fator_id = tf.id
      fator_de_corte_id = tf.fator_de_corte_id || 0
      const { data: fc } = await sb.from('fator_de_corte').select('*').eq('id', tf.fator_de_corte_id).single()
      fator_corte = fc?.valor || []
      modo_corte = fc?.modo_corte || 'lista'
      passo_corte = fc?.comp_corte || 0
    }
  }

  const var_fc = retornaFc(comprimento, largura, fator_corte, modo_corte, passo_corte)
  const comprimento_fc = var_fc.new_comp
  const largura_fc = var_fc.new_larg
  const area_total_fc = comprimento_fc * largura_fc * quantidade

  let materia_prima_mais_borda = (produto.valor || 0) + (produto.borda_valor || 0)
  let acrescimo = 0
  if (input.com_medida_exata && produto.com_medida_exata) {
    materia_prima_mais_borda = materia_prima_mais_borda * (1 + (produto.porcentagem_acrescimo || 0) / 100)
    acrescimo = produto.porcentagem_acrescimo || 0
  }
  const vlr_ipi_total = round2((materia_prima_mais_borda * area_total_fc * (produto.ipi || 0)) / 100)
  const custo_nota_total = round2(materia_prima_mais_borda * area_total_fc + vlr_ipi_total)

  return {
    descricao: joinDescricao([produto.material_nome, produto.linha_nome, produto.tipo_nome, produto.nivel_nome, produto.borda_nome]),
    quantidade,
    largura,
    comprimento,
    largura_fc,
    comprimento_fc,
    ncm: produto.ncm,
    fc: fator_corte,
    fator_de_corte_id,
    tipo_fator_id,
    com_medida_exata: input.com_medida_exata === true && produto.com_medida_exata === true,
    acrescimo_medida_exata: acrescimo,
    detalhes_calculo: null,
    valores: {
      custo_materia_prima: produto.valor || 0,
      custo_borda: produto.borda_valor || 0,
      custo_total: round2(materia_prima_mais_borda * area_total_fc),
      aliquota_ipi: produto.ipi || 0,
      valor_ipi_tot: vlr_ipi_total,
      valor_ipi_unit: round2(vlr_ipi_total / quantidade),
      custo_nota_tot: custo_nota_total,
      custo_nota_unit: round2(custo_nota_total / quantidade),
    },
  }
}

// ---------------------------------------------------------------------------
// f_valor_custo_ml (port)
// ---------------------------------------------------------------------------
export async function custoML(sb: SbClient, produto: ProdutoCtx, input: CalcularInput): Promise<Mod1> {
  const variacao = produto.variacao || {}
  const fc = produto.fator_de_corte_variacao || {}
  const larg_fixa = Number(fc.larg_base) || 0
  const tam_rolo = Number(fc.tam_total) || 0
  const valor_custo = Number(variacao.valor_custo) || 0
  const tipo_preco = (produto.Unidade || '').toLowerCase()
  const fator_corte = Number(fc.comp_corte) || 0
  const aliquota_ipi = Number(produto.ipi) || 0
  const unidade_borda = (produto.borda_unidade || '').toLowerCase()
  const custo_borda = Number(produto.borda_valor) || 0

  const comprimentoOrArea = Number(input.comprimento_ou_area) || 0
  const largura = Number(input.largura) || 0

  // 1. conversão de preço M² -> ML
  let valor_ml = tipo_preco === 'm2' || tipo_preco === 'm²' ? valor_custo * larg_fixa : valor_custo
  if (unidade_borda === 'ml') valor_ml = valor_ml + custo_borda

  const medidaExata = input.com_medida_exata === true && produto.com_medida_exata === true
  if (medidaExata) {
    const perc = Number(produto.porcentagem_acrescimo) || 0
    valor_ml = valor_ml * (1 + perc / 100)
  }

  let totalMlNecessario = 0
  let orientacao = ''

  if (!largura || largura === 0) {
    // MODO ÁREA LÍQUIDA
    const areaTotal = comprimentoOrArea
    const mlBruto = areaTotal / larg_fixa
    totalMlNecessario = Math.ceil(mlBruto / fator_corte) * fator_corte
    orientacao = `Cálculo baseado em área total líquida (${areaTotal} m²) - Sem paginação`
  } else {
    // MODO PAGINAÇÃO INTELIGENTE
    const comprimento = comprimentoOrArea
    const faixas1 = Math.ceil(largura / larg_fixa)
    const compFaixa1 = Math.ceil(comprimento / fator_corte) * fator_corte
    const totalMl1 = faixas1 * compFaixa1
    const faixas2 = Math.ceil(comprimento / larg_fixa)
    const compFaixa2 = Math.ceil(largura / fator_corte) * fator_corte
    const totalMl2 = faixas2 * compFaixa2
    if (totalMl1 <= totalMl2) {
      totalMlNecessario = totalMl1
      orientacao = `Passar a faixa no sentido do comprimento (${comprimento} m)`
    } else {
      totalMlNecessario = totalMl2
      orientacao = `Passar a faixa no sentido da largura (${largura} m)`
    }
    totalMlNecessario = Math.ceil(totalMlNecessario / fator_corte) * fator_corte
  }

  const rolosInteiros = Math.floor(totalMlNecessario / tam_rolo)
  const mlRestante = totalMlNecessario % tam_rolo
  const custoTotal = totalMlNecessario * valor_ml
  let custo_nota = custoTotal
  const vlr_ipi = custo_nota * (aliquota_ipi / 100)
  custo_nota = round2(custo_nota + vlr_ipi)
  const cst_borda_total = totalMlNecessario * custo_borda

  const quantidade = totalMlNecessario

  return {
    descricao: joinDescricao([produto.material_nome, produto.linha_nome, produto.tipo_nome, produto.nivel_nome, produto.borda_nome]),
    quantidade,
    largura,
    comprimento: comprimentoOrArea,
    largura_fc: larg_fixa,
    comprimento_fc: totalMlNecessario,
    ncm: produto.ncm,
    fc: [],
    fator_de_corte_id: 0,
    tipo_fator_id: 0,
    com_medida_exata: medidaExata,
    acrescimo_medida_exata: medidaExata ? Number(produto.porcentagem_acrescimo) || 0 : 0,
    detalhes_calculo: {
      ml: {
        totalMetrosLineares: totalMlNecessario,
        rolosFechados: rolosInteiros,
        metrosFracionados: mlRestante,
        orientacaoIdeal: orientacao,
        valor_ml,
        custoBordaTotalIncluso: cst_borda_total,
        largura_fixa: larg_fixa,
        tam_rolo,
        fator_corte,
        resumoTexto: `${rolosInteiros} rolo(s) e ${mlRestante}m do produto. Valor total: R$ ${custo_nota.toFixed(2)}`,
      },
    },
    valores: {
      custo_materia_prima: valor_custo,
      custo_borda,
      custo_total: round2(custoTotal),
      aliquota_ipi,
      valor_ipi_tot: round2(vlr_ipi),
      valor_ipi_unit: round2(vlr_ipi / quantidade),
      custo_nota_tot: custo_nota,
      custo_nota_unit: round2(custo_nota / quantidade),
    },
  }
}

// ---------------------------------------------------------------------------
// f_valor_custo_und (port)
// ---------------------------------------------------------------------------
export function custoUND(produto: ProdutoCtx, input: CalcularInput): Mod1 {
  const qtd = Number(input.quantidade) || 0
  const cst_materia_prima = Number(produto.variacao?.valor_custo) || 0
  const cst_borda = Number(produto.borda_valor) || 0
  const aliquota_ipi = Number(produto.ipi) || 0

  const materia_prima_mais_borda_total = round2((cst_materia_prima + cst_borda) * qtd)
  const vlr_ipi_total = round2((materia_prima_mais_borda_total * aliquota_ipi) / 100)
  const custo_nota_total = round2(materia_prima_mais_borda_total + vlr_ipi_total)

  return {
    descricao: joinDescricao([produto.material_nome, produto.linha_nome, produto.tipo_nome, produto.nivel_nome, produto.borda_nome]),
    quantidade: qtd,
    largura: produto.variacao?.larg ?? null,
    comprimento: produto.variacao?.comp ?? null,
    largura_fc: produto.variacao?.larg ?? null,
    comprimento_fc: produto.variacao?.comp ?? null,
    ncm: produto.ncm,
    fc: [],
    fator_de_corte_id: 0,
    tipo_fator_id: 0,
    com_medida_exata: false,
    acrescimo_medida_exata: 0,
    detalhes_calculo: null,
    valores: {
      custo_materia_prima: cst_materia_prima,
      custo_borda: cst_borda,
      custo_total: materia_prima_mais_borda_total,
      aliquota_ipi,
      valor_ipi_tot: vlr_ipi_total,
      valor_ipi_unit: qtd > 0 ? round2(vlr_ipi_total / qtd) : 0,
      custo_nota_tot: custo_nota_total,
      custo_nota_unit: qtd > 0 ? round2(custo_nota_total / qtd) : 0,
    },
  }
}

// ---------------------------------------------------------------------------
// f_valor_custo_kit (port)
// ---------------------------------------------------------------------------
export function custoKIT(produto: ProdutoCtx, input: CalcularInput): Mod1 {
  const compOuArea = Number(input.comprimento_ou_area) || 0
  const largInput = Number(input.largura) || 0
  const variacao = produto.variacao || {}
  const custoKit = Number(variacao.valor_custo) || 0
  const largKit = Number(variacao.larg) || 0.3
  const compKit = Number(variacao.comp) || 0.3
  const qtdPecasKit = Number(variacao.qtd_kit) || 1
  const cstBorda = Number(produto.borda_valor) || 0
  const ipi = Number(produto.ipi) || 0

  const areaPeca = largKit * compKit
  let largFC = 0
  let compFC = 0
  let totalPecasNecessarias = 0

  if (compOuArea > 0 && largInput > 0) {
    const pecasNoComp = Math.ceil(compOuArea / compKit)
    const pecasNaLarg = Math.ceil(largInput / largKit)
    compFC = round2(pecasNoComp * compKit)
    largFC = round2(pecasNaLarg * largKit)
    totalPecasNecessarias = pecasNoComp * pecasNaLarg
  } else if (compOuArea > 0 && largInput === 0) {
    totalPecasNecessarias = areaPeca > 0 ? Math.ceil(compOuArea / areaPeca) : 0
    compFC = round2(totalPecasNecessarias * areaPeca)
    largFC = 0
  }

  const qtdKits = qtdPecasKit > 0 ? Math.ceil(totalPecasNecessarias / qtdPecasKit) : 0
  const materiaPrimaMaisBordaTotal = round2((custoKit + cstBorda) * qtdKits)
  const vlrIpiTotal = round2((materiaPrimaMaisBordaTotal * ipi) / 100)
  const custoNotaTotal = round2(materiaPrimaMaisBordaTotal + vlrIpiTotal)

  return {
    descricao: joinDescricao([produto.material_nome, produto.linha_nome, produto.tipo_nome, produto.nivel_nome, produto.borda_nome]),
    quantidade: qtdKits,
    largura: largInput,
    comprimento: compOuArea,
    largura_fc: largFC,
    comprimento_fc: compFC,
    ncm: produto.ncm,
    fc: [],
    fator_de_corte_id: 0,
    tipo_fator_id: 0,
    com_medida_exata: false,
    acrescimo_medida_exata: 0,
    detalhes_calculo: null,
    valores: {
      custo_materia_prima: custoKit,
      custo_borda: cstBorda,
      custo_total: materiaPrimaMaisBordaTotal,
      aliquota_ipi: ipi,
      valor_ipi_tot: vlrIpiTotal,
      valor_ipi_unit: qtdKits > 0 ? round2(vlrIpiTotal / qtdKits) : 0,
      custo_nota_tot: custoNotaTotal,
      custo_nota_unit: qtdKits > 0 ? round2(custoNotaTotal / qtdKits) : 0,
    },
  }
}

// ---------------------------------------------------------------------------
// f_valor_custo_playkap (port)
// ---------------------------------------------------------------------------
export async function custoPlaykap(sb: SbClient, produto: ProdutoCtx, input: CalcularInput): Promise<Mod1> {
  const rampaLarg1 = input.rampa_larg1 === true
  const rampaComp1 = input.rampa_comp1 === true
  const rampaLarg2 = input.rampa_larg2 === true
  const rampaComp2 = input.rampa_comp2 === true
  const qtdCantos = Number(input.qtd_cantos) || 0

  const { data: variacoes } = await sb
    .from('variacao')
    .select('id, tipo_variacao_id, comp, larg, qtd_kit, valor_custo, tipo_variacao:tipo_variacao_id(descricao)')
    .eq('detalhe_id', produto.detalhe_id)

  const TAMANHO_PLACA = 0.3
  let comp = Number(input.comprimento_ou_area) || 0
  let larg = Number(input.largura) || 0
  if (larg <= 0 && comp > 0) {
    const lado = Math.sqrt(comp)
    comp = lado
    larg = lado
  }

  const getV = (nome: string) => {
    const v = (variacoes || []).find((x: any) =>
      ((x.tipo_variacao?.descricao) || '').toLowerCase().includes(nome.toLowerCase()),
    )
    return v
  }
  const COMPRA_MINIMA = Number(getV('placa')?.qtd_kit) || 11
  const custoPlaca = Number(getV('placa')?.valor_custo) || 0
  const custoRampa = Number(getV('rampa')?.valor_custo) || 0
  const custoCantoneira = Number(getV('cantoneira')?.valor_custo) || 0

  const placasComp = comp > 0 ? Math.ceil(comp / TAMANHO_PLACA) : 0
  const placasLarg = larg > 0 ? Math.ceil(larg / TAMANHO_PLACA) : 0
  let totalPlacas = Math.max(1, placasComp) * Math.max(1, placasLarg)
  const compAjustadoM = round2(Math.max(1, placasComp) * TAMANHO_PLACA)
  const largAjustadoM = round2(Math.max(1, placasLarg) * TAMANHO_PLACA)
  const areaRealM2 = round2(compAjustadoM * largAjustadoM)
  const compraMinimaAplicada = totalPlacas < COMPRA_MINIMA
  if (compraMinimaAplicada) totalPlacas = COMPRA_MINIMA

  const pc = Math.max(1, placasComp)
  const pl = Math.max(1, placasLarg)
  const totalRampas =
    (rampaLarg1 ? pl : 0) + (rampaComp1 ? pc : 0) + (rampaLarg2 ? pl : 0) + (rampaComp2 ? pc : 0)
  const rampasMacho = Math.ceil(totalRampas / 2)
  const rampasFemea = Math.floor(totalRampas / 2)
  const totalCantoneiras = Math.min(4, Math.max(0, qtdCantos))

  const custoPlacas = round2(totalPlacas * custoPlaca)
  const custoRampas = round2(totalRampas * custoRampa)
  const custoCantoneiras = round2(totalCantoneiras * custoCantoneira)
  const custoTotal = round2(custoPlacas + custoRampas + custoCantoneiras)

  const ipi = Number(produto.ipi) || 0
  const vlrIpi = round2((custoTotal * ipi) / 100)
  const custoNota = round2(custoTotal + vlrIpi)
  const totalPecas = totalPlacas + totalRampas + totalCantoneiras

  return {
    descricao: 'PLAYKAP',
    quantidade: totalPecas,
    largura: round2(larg),
    comprimento: round2(comp),
    largura_fc: largAjustadoM,
    comprimento_fc: compAjustadoM,
    ncm: produto.ncm,
    fc: [],
    fator_de_corte_id: 0,
    tipo_fator_id: 0,
    com_medida_exata: false,
    acrescimo_medida_exata: 0,
    valores: {
      custo_materia_prima: custoTotal,
      custo_borda: 0,
      custo_total: custoTotal,
      aliquota_ipi: ipi,
      valor_ipi_tot: vlrIpi,
      valor_ipi_unit: totalPecas > 0 ? round2(vlrIpi / totalPecas) : 0,
      custo_nota_tot: custoNota,
      custo_nota_unit: totalPecas > 0 ? round2(custoNota / totalPecas) : 0,
    },
    detalhes_calculo: {
      playkap: {
        placas: totalPlacas,
        rampas_total: totalRampas,
        rampas_macho: rampasMacho,
        rampas_femea: rampasFemea,
        cantoneiras: totalCantoneiras,
        lados: { rampa_larg1: rampaLarg1, rampa_comp1: rampaComp1, rampa_larg2: rampaLarg2, rampa_comp2: rampaComp2 },
        area_m2: areaRealM2,
        compra_minima_aplicada: compraMinimaAplicada,
        custos: { placas: custoPlacas, rampas: custoRampas, cantoneiras: custoCantoneiras },
      },
    },
  }
}

// ---------------------------------------------------------------------------
// SumarizaItensOrcamento: soma vlr_cst_nota_unit * qtd dos itens da orca
// (excluindo o item em edição), base do frete B2B.
// ---------------------------------------------------------------------------
export async function somarItensCustoNota(sb: SbClient, orcaId: number, excludeItemId: number): Promise<number> {
  if (!orcaId || orcaId <= 0) return 0
  let query = sb.from('item').select('vlr_cst_nota_unit, qtd').eq('orca_id', orcaId)
  if (excludeItemId && excludeItemId > 0) query = query.neq('id', excludeItemId)
  const { data } = await query
  const soma = (data || []).reduce((acc: number, i: any) => acc + (Number(i.vlr_cst_nota_unit) || 0) * (Number(i.qtd) || 1), 0)
  return soma
}

// ---------------------------------------------------------------------------
// Orquestrador (f_Orcamento_Orquestrador)
// ---------------------------------------------------------------------------
export async function calcular(sb: SbClient, input: CalcularInput): Promise<any> {
  const produto = await buscarProduto(sb, input)
  if (!produto) throw new Error('Produto não encontrado para a seleção. Confira o catálogo.')

  const perfil = await perfilEfetivo(sb, input.user_id)

  // UF origem (fornecedor/organização) — default PR
  let uf_origem = 'PR'
  if (perfil?.organizacao_id) {
    const { data: org } = await sb.from('organizacao').select('uf').eq('id', perfil.organizacao_id).single()
    if (org?.uf) uf_origem = org.uf.toUpperCase()
  }

  const tipo_calculo = (produto.Base_de_Calculo || 'M2').toUpperCase()

  let mod1: Mod1
  if (tipo_calculo === 'M2') mod1 = await custoM2(sb, produto, input)
  else if (tipo_calculo === 'ML') mod1 = await custoML(sb, produto, input)
  else if (tipo_calculo === 'UND') mod1 = custoUND(produto, input)
  else if (tipo_calculo === 'KIT') mod1 = custoKIT(produto, input)
  else if (tipo_calculo === 'COMPOSTO') {
    if ((produto.tipo_composto || '').toUpperCase() === 'PLAYKAP') mod1 = await custoPlaykap(sb, produto, input)
    else throw new Error(`Não foi possível calcular o custo do produto (base ${tipo_calculo}).`)
  } else {
    throw new Error(`Não foi possível calcular o custo do produto (base ${tipo_calculo}).`)
  }

  const qtd = mod1.quantidade
  const custo_nota_tot = mod1.valores.custo_nota_tot

  // Soma dos itens já gravados (para o frete)
  const somaItens = await somarItensCustoNota(sb, input.orca_id, input.item_id)
  const custo_nota_total_para_frete = somaItens + custo_nota_tot

  // Precificar (fiscal)
  const precif = await precificar(sb, {
    custo_nota: custo_nota_tot,
    uf_origem,
    uf_destino: input.uf_destino || perfil?.uf || 'SP',
    regime_id: input.regime_id || perfil?.regime_id || 0,
    eh_importado: produto.eh_importado,
    tem_st: produto.st,
    mva_padrao: produto.mva_padrao,
    aliq_st_interna: produto.aliq_st_interna,
  })

  // Frete B2B
  const frete_b2b = calcularFrete(custo_nota_total_para_frete, perfil?.frtB2B ?? 0)
  const frete_rateado_tot = custo_nota_total_para_frete > 0 ? frete_b2b * (custo_nota_tot / custo_nota_total_para_frete) : 0

  const custo_fiscal_tot = precif.custo_fiscal
  const custo_real_entrada_tot = custo_fiscal_tot + frete_rateado_tot

  const markup = Number(input.markup) || 0
  const valor_venda_tot = custo_real_entrada_tot * (1 + markup / 100)
  const lucro_tot = valor_venda_tot - custo_real_entrada_tot
  const margem_real = valor_venda_tot > 0 ? (lucro_tot / valor_venda_tot) * 100 : 0

  const div = (v: number) => (qtd > 0 ? v / qtd : 0)

  return {
    produto_id: input.produto_id,
    borda_id: input.borda_id,
    variacao_id: input.variacao_id,
    qtd,
    comp: mod1.comprimento ?? 0,
    larg: mod1.largura ?? 0,
    comp_fc: mod1.comprimento_fc ?? 0,
    larg_fc: mod1.largura_fc ?? 0,
    vlr_cst_unit: round4(div(custo_nota_tot)),
    vlr_custo_nota_unit: round4(div(custo_nota_tot)),
    vlr_custo_nota_tot: round4(custo_nota_tot),
    vlr_difal_unit: round4(div(precif.valor_difal)),
    vlr_difal_tot: round4(precif.valor_difal),
    vlr_st_unit: round4(div(precif.valor_st)),
    vlr_st_tot: round4(precif.valor_st),
    vlr_credito_icms_unit: round4(div(precif.credito_icms)),
    vlr_credito_icms_tot: round4(precif.credito_icms),
    vlr_custo_fiscal_unit: round4(div(custo_fiscal_tot)),
    vlr_custo_fiscal_tot: round4(custo_fiscal_tot),
    eh_importado: produto.eh_importado,
    frete_b2b: round2(frete_b2b),
    vlr_frete_b2b_unit: round4(div(frete_rateado_tot)),
    vlr_cst_entrada_unit: round4(div(custo_real_entrada_tot)),
    vlr_cst_entrada_tot: round4(custo_real_entrada_tot),
    vlr_vnd_unit: round4(div(valor_venda_tot)),
    vlr_vnd_tot: round4(valor_venda_tot),
    vlr_lucro_unit: round4(div(lucro_tot)),
    vlr_lucro_tot: round4(lucro_tot),
    perc_marguem_real: round4(margem_real),
    margem: markup,
    ipi: produto.ipi || 0,
    base_calculo: tipo_calculo,
    und_produto: produto.Unidade,
    und_borda: produto.borda_unidade || '',
    vlr_cst_materia_prima: mod1.valores.custo_materia_prima,
    vlr_cst_borda: mod1.valores.custo_borda,
    vlr_ipi_unit: mod1.valores.valor_ipi_unit,
    vlr_perc_difal: precif.perc_difal,
    vlr_aliq_inter: precif.aliq_inter,
    vlr_aliq_interna: precif.aliq_interna,
    uf_origem: precif.uf_origem,
    uf_destino: precif.uf_destino,
    regime_id: perfil?.regime_id ?? 0,
    fc: mod1.fc,
    fator_de_corte_id: mod1.fator_de_corte_id,
    tipo_fator_id: mod1.tipo_fator_id,
    com_medida_exata: mod1.com_medida_exata,
    porcentagem_acrescimo: mod1.acrescimo_medida_exata,
    detalhes_calculo: mod1.detalhes_calculo,
  }
}
