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
  Celular: 1,
  Comercial: 1,
  Residencial: 1,
  WhatsApp: 1,
}
