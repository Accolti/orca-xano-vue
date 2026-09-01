export interface TelefoneEntry {
  tipo: string
  numero: string
  id?: number
}

export interface ClienteForm {
  tipo_pessoa: 'CNPJ' | 'CPF'
  contato: string
  ramo_atividade: string
  tipo_mercado: string
  regime_tributario: string
  beneficio_fiscal: string
  razao_social: string
  nome_fantasia: string
  cnpj_cpf: string
  inscricao_estadual: string
  cep: string
  email: string
  logradouro: string
  numero: string
  complemento: string
  bairro: string
  uf: string
  cidade: string
  telefones: TelefoneEntry[]
  observacoes: string
}

export interface Cliente {
  id: number
  tipo_pessoa?: string
  razao_social: string
  nome_fantasia: string
  contato: string
  cpf: string
  nome_cpf: string
  cnpj: string
  inscricao_estadual: string
  'e-mail': string
  contribui_icms: boolean
  isento: boolean
  observacao: string
  user_id: number
  beneficio_fiscal_id: number
  mercado_id: number
  ramo_id: number
  regime_id: number
  created_at: number
  _enderecos?: Array<{
    id?: number
    Tipo?: string
    endereco?: string
    numero?: string
    complemento?: string
    cep?: string
    bairro?: string
    cidade?: string
    estado?: string
  }>
  _telefone_cliente_of_cliente?: Array<{
    id: number
    cliente_id?: number
    tipo_telefone_id: number
    telefone: string
    descricao?: string
  }>
}

export const defaultForm: ClienteForm = {
  tipo_pessoa: 'CNPJ',
  contato: '',
  ramo_atividade: '',
  tipo_mercado: '',
  regime_tributario: '',
  beneficio_fiscal: '',
  razao_social: '',
  nome_fantasia: '',
  cnpj_cpf: '',
  inscricao_estadual: '',
  cep: '',
  email: '',
  logradouro: '',
  numero: '',
  complemento: '',
  bairro: '',
  uf: '',
  cidade: '',
  telefones: [],
  observacoes: '',
}
