// Preencha os IDs conforme as tabelas no Xano
// Edite este arquivo sem precisar mexer nos componentes

export function reverseLookup(
  map: Record<string, number>,
  id: number | undefined | null,
): string | undefined {
  if (!id) return undefined
  return Object.entries(map).find(([, v]) => v === id)?.[0]
}

export const ramoMap: Record<string, number> = {
  Atacado: 1,
  Varejo: 2,
  Industria: 3,
  Servicos: 4,
  Outro: 5,
}

export const mercadoMap: Record<string, number> = {
  Nacional: 1,
  Internacional: 2,
  Outro: 3,
}

export const regimeMap: Record<string, number> = {
  Normal: 1,
  'Simples Nacional': 2,
  MEI: 3,
}

export const beneficioMap: Record<string, number> = {
  Nenhum: 1,
  'Zona Franca de Manaus': 2,
  'Zona Franca': 3,
  'Área Livre de Comércio': 4,
  'Amazonia Central': 5,
}

export const tipoTelMap: Record<string, number> = {
  'Whatsapp Com': 1,
  'Cel Com': 2,
  'Fixo Com': 3,
  'Cel Res': 4,
  'Fixo Res': 5,
  'Whatsapp Res': 6,
}

// Opções do dropdown na ordem exibida (valores = descrições reais da tabela Tipo_Telefone)
export const tiposTelefone: string[] = Object.keys(tipoTelMap)

// Normaliza o tipo vindo do autofill de CNPJ (strings livres da API externa)
// para uma das descrições reais.
export function normalizarTipoTelefone(tipo?: string | null): string {
  if (!tipo) return ''
  const t = tipo.trim().toLowerCase()
  if (t.includes('whatsapp')) return 'Whatsapp Com'
  if (t.includes('res')) return 'Cel Res'
  if (t.includes('cel')) return 'Cel Com'
  return 'Fixo Com'
}
