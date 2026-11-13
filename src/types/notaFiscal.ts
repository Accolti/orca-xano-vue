export interface NotaFiscalItem {
  codigo: string
  descricao: string
  ncm: string
  cfop: string
  qtd: number
  valor_unit: number
  valor_total: number
}

export interface NotaFiscal {
  id?: number
  created_at?: string
  user_id?: number
  orca_id?: number | null
  chave: string
  numero?: string
  serie?: string
  data_emissao?: string | null
  tp_nf?: number | null
  natureza_operacao?: string
  emitente_cnpj?: string
  emitente_nome?: string
  emitente_ie?: string
  destinatario_cnpj?: string
  destinatario_nome?: string
  valor_total?: number | null
  valor_produtos?: number | null
  valor_frete?: number | null
  valor_ipi?: number | null
  valor_icms?: number | null
  itens?: NotaFiscalItem[]
  xml?: string
}
