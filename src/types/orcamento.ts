export interface Material {
  id: number
  nome: string
  Ordenacao: number
  created_at: number
  material_id: number
  ativo: boolean
  descricao: string
  ncm: string
  imp: number
  ipi: number
  peso: number
  st: boolean
  nac: boolean
  Observacao: string
  organizacao_id: number
  suc: {
    Linha: number
    Tipo: number
    Nivel: number
    Borda: number
  } | null
}

export interface Linha {
  id: number
  nome: string
  created_at: number
  material_id: number
}

export interface Tipo {
  id: number
  nome: string
  material_id: number
  created_at: number
}

export interface Nivel {
  id: number
  nome: string
  Descricao: string
  material_id: number
  created_at: number
}

export interface Borda {
  id: number
  nome: string
  Obs: string
  material_id: number
  valor: number
  Unidade: string
  created_at: number
}

export interface Func1 {
  Valor_Custo_Unit: number
  Valor_Venda_Unit: number
  Valor_Lucro_Unit: number
  Valor_Venda_Unit_B2B: number
  AreaFC: number
  Qtd_Unidades: number
  Valor_Custo_Total: number
  Valor_Venda_Total: number
  Valor_Lucro_Total: number
  Valor_Venda_Total_FRT_B2B: number
  Valor_Custo_IPI: number
  Valor_Custo_IMP: number
  valor_venda_ipi_tot: number
  valor_venda_imp_tot: number
  Valor_Venda_Total_B2B: number
  margem: number
}

export interface SimulacaoItem {
  Valor_Custo_Unit: number
  Valor_Venda_Unit: number
  Valor_Lucro_Unit: number
  Valor_Venda_Unit_B2B: number
  AreaFC: number
  Qtd_Unidades: number
  Valor_Custo_Total: number
  Valor_Venda_Total: number
  Valor_Lucro_Total: number
  Valor_Venda_Total_FRT_B2B: number
  Valor_Custo_IPI: number
  Valor_Custo_IMP: number
  valor_venda_ipi_tot: number
  valor_venda_imp_tot: number
  Valor_Venda_Total_B2B: number
  margem: number
}

export interface Produto2 {
  id: number
  material_id: number
  classificacao_id: number
  linha_id: number
  tipo_id: number
  nivel_id: number
  valor: number
  Unidade: string
  Base_de_Calculo: string
  created_at: number
  detalhe_id: number
  _borda_por_material?: {
    id: number
    nome: string
    Obs: string
    material_id: number
    valor: number
    Unidade: string
    created_at: number
    ativo: boolean
  }
}

export interface TipoFator1 {
  id: number
  fator_de_corte_id: number
  material_id: number
  linha_id: number
  borda_id: number
  created_at: number
  _fator_de_corte: {
    id: number
    nome: string
    created_at: number
    valor: number[]
    Larg_Multiplo: number
    Comp_Multiplo: number
  }
}

export interface OrcamentoResult {
  CompFC: number
  LargFC: number
  comp: number
  larg: number
  margem: number
  vlr_venda_m2: number
  cst_borda: number
  frete_b2b: number
  func_1: Func1
  Produto_2: Produto2[]
  Tipo_Fator_1: TipoFator1[]
  simulacao: SimulacaoItem[]
  mae_filhas: {
    Material_1: Array<{
      Material: string
      Linha: number
      Tipo: number
      Nivel: number
      Borda: number
    }>
  }
}

export interface OrcamentoInsertPayload {
  cod_orca: string
  cliente_id: string
  frtB2B: number | null
  frtB2C: number | null
  validade: string
  margem: number
  produto_id: number
  ipi: number | null
  imp: number | null
  vlr_custo: number
  und_produto: string
  larg: number
  comp: number
  larg_fc: number
  comp_fc: number
  borda_id: string
  vlr_cst_borda: number
  und_borda: string
  tipo_fator_id: number
  fator_de_corte_id: number
  detalhe_id: number
  variacao_id: number
  qtd: string
  vlr_cst_unit: number
  vlr_cst_unit_ipi: number | null
  vlr_cst_unit_imp: number | null
  vlr_vnd_unit: number
  vlr_vnd_unit_ipi: number
  vlr_vnd_unit_imp: number
  vlr_vnd_unit_b2b: number
  descricao: string
  area_user: number
  area_calc: number
}
