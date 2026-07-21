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
  Varejo: 1,
  Industria: 1,
  Servicos: 1,
  Outro: 1,
}

export const mercadoMap: Record<string, number> = {
  Nacional: 1,
  Internacional: 1,
}

export const regimeMap: Record<string, number> = {
  Normal: 1,
  'Simples Nacional': 1,
  MEI: 1,
}

export const beneficioMap: Record<string, number> = {
  Nenhum: 1,
  Desoneração: 1,
  Suspensão: 1,
  Isenção: 1,
  Diferimento: 1,
}

export const tipoTelMap: Record<string, number> = {
  Celular: 1,
  Comercial: 1,
  Residencial: 1,
  WhatsApp: 1,
}
