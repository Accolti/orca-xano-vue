// Checklist do perfil do usuário (o que afeta a corretude do orçamento e do documento).
// Crítico = sem isso o cálculo pode sair errado (UF/regime). Recomendado = afeta o
// documento/experiência (empresa, margem, frete, validade). Não bloqueia — só avisa.
import type { User } from '@/stores/auth'

export interface PendenciaPerfil {
  id: string
  critico: boolean
  rotulo: string
}

export function pendenciasPerfil(u: User | null | undefined): PendenciaPerfil[] {
  const lista: PendenciaPerfil[] = []

  const uf = (u?.uf || '').trim()
  if (!uf) {
    lista.push({ id: 'uf', critico: true, rotulo: 'UF (destino da venda)' })
  }

  if (!u?.regime_id) {
    lista.push({ id: 'regime', critico: true, rotulo: 'Regime Tributário' })
  }

  if (!(u?.razao || '').trim()) {
    lista.push({ id: 'razao', critico: false, rotulo: 'Razão Social' })
  }

  if (!(u?.cnpj || '').trim()) {
    lista.push({ id: 'cnpj', critico: false, rotulo: 'CNPJ' })
  }

  const margem = Number(u?.margem)
  if (u?.margem == null || Number.isNaN(margem) || margem <= 0) {
    lista.push({ id: 'margem', critico: false, rotulo: 'Margem padrão (%)' })
  }

  const frete = Number(u?.frtB2B)
  if (u?.frtB2B == null || Number.isNaN(frete) || frete <= 0) {
    lista.push({ id: 'frete', critico: false, rotulo: 'Frete B2B mínimo (R$)' })
  }

  const dias = Number(u?.DiasVencimentoOrcamento)
  if (!u?.DiasVencimentoOrcamento || Number.isNaN(dias) || dias <= 0) {
    lista.push({ id: 'validade', critico: false, rotulo: 'Validade do orçamento (dias)' })
  }

  return lista
}

export function criticas(u: User | null | undefined): PendenciaPerfil[] {
  return pendenciasPerfil(u).filter((p) => p.critico)
}

export function recomendadas(u: User | null | undefined): PendenciaPerfil[] {
  return pendenciasPerfil(u).filter((p) => !p.critico)
}
