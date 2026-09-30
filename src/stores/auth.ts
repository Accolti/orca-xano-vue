import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/services/supabase'
import { useCatalogoStore } from './catalogo'
import { useOrcamentoStore } from './orcamento'

export type UserRole = 'admin_geral' | 'admin' | 'vendedor_master' | 'vendedor'

export interface User {
  id: number
  created_at: string
  name: string
  name_first: string
  name_last: string
  email: string
  frtB2B: number
  margem: number
  DiasVencimentoOrcamento: number
  organizacao_id: number
  razao: string
  fantasia: string
  cnpj: string
  ie: string
  cpf: string
  isPJ: number
  uf?: string
  regime_id?: number
  role?: UserRole | null
  vendedor_pai_id?: number | null
  percentual_comissao?: number | null
  desconto_livre_perc?: number | null
  desconto_max_perc?: number | null
  plano?: string | null
  super_admin?: boolean
  ativo?: boolean
  ativo_efetivo?: boolean
  _telefones?: Array<{ id: number; telefone: string; tipo_telefone?: string }>
  _endereco_user?: {
    id?: number
    endereco?: string
    numero?: string
    complemento?: string
    cep?: string
    bairro?: string
    cidade?: string
    estado?: string
    preferencial?: boolean
  } | null
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const session = ref<any | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  const token = computed(() => session.value?.access_token ?? null)
  const isAuthenticated = computed(() => !!session.value)

  // Role efetiva: contas sem role (legado) com vendedor_pai_id contam como vendedor;
  // sem role e sem pai → admin.
  const role = computed<UserRole>(() => {
    const r = user.value?.role as UserRole | null | undefined
    if (r) return r
    if (!user.value) return 'admin'
    if (user.value.vendedor_pai_id) return 'vendedor'
    return 'admin'
  })
  const isAdminGeral = computed(() => role.value === 'admin_geral')
  const isAdmin = computed(() => role.value === 'admin' || role.value === 'admin_geral')
  const isVendedorMaster = computed(() => role.value === 'vendedor_master')
  const isVendedor = computed(() => role.value === 'vendedor')
  // Config da empresa dona (filhos herdam do pai no runtime)
  const empresaEfetiva = ref<Partial<User> | null>(null)
  const userEfetivo = computed<User | null>(() =>
    user.value ? ({ ...user.value, ...(empresaEfetiva.value ?? {}) } as User) : null,
  )
  const ehFilho = computed(() => isVendedor.value || isVendedorMaster.value)
  // Serviço de comissões: habilitado pelo plano da empresa (filhos herdam do topo).
  const temComissoes = computed(() => (userEfetivo.value?.plano ?? user.value?.plano) === 'plus')

  // Acompanha o estado da sessão (login/refresh/logout). O carregamento do perfil
  // (usuarios) é feito explicitamente em init()/login/fetchMe.
  supabase?.auth.onAuthStateChange((event, sess) => {
    session.value = sess
    if (event === 'SIGNED_OUT') {
      user.value = null
      empresaEfetiva.value = null
    }
  })

  function getErrorMessage(err: unknown): string {
    return (err as Error)?.message || 'Erro inesperado'
  }

  async function init() {
    if (!supabase) return
    const { data } = await supabase.auth.getSession()
    session.value = data.session
    if (data.session) {
      await fetchMe().catch(() => {})
    }
  }

  async function loadPerfilEfetivo() {
    if (!user.value) return
    try {
      const { data, error: err } = await supabase!.rpc('perfil_efetivo', {
        p_user_id: user.value.id,
      })
      if (err) throw err
      empresaEfetiva.value = (data ?? null) as Partial<User> | null
    } catch {
      empresaEfetiva.value = null
    }
  }

  async function login(email: string, password: string) {
    if (!supabase) throw new Error('Supabase não configurado')
    loading.value = true
    error.value = null
    try {
      const { error: err } = await supabase.auth.signInWithPassword({ email, password })
      if (err) throw new Error(err.message)
      await fetchMe()
    } catch (err) {
      console.error('[auth/login]', err)
      const msg = getErrorMessage(err)
      error.value = msg
      throw new Error(msg)
    } finally {
      loading.value = false
    }
  }

  // Cadastro fechado: usuários são criados pelo admin (via /equipe) com convite.
  async function signup() {
    loading.value = true
    error.value = null
    try {
      throw new Error('Cadastro por convite. Entre em contato para liberar seu acesso.')
    } catch (err) {
      const msg = getErrorMessage(err)
      error.value = msg
      throw new Error(msg)
    } finally {
      loading.value = false
    }
  }

  // Dispara o fluxo Google OAuth (Supabase). Redireciona para o Google.
  async function googleLogin() {
    if (!supabase) throw new Error('Supabase não configurado')
    loading.value = true
    error.value = null
    try {
      const { error: err } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${window.location.origin}/oauth/callback`,
          queryParams: { prompt: 'select_account' },
        },
      })
      if (err) throw new Error(err.message)
    } catch (err) {
      console.error('[oauth/google]', err)
      error.value = getErrorMessage(err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // Envia o e-mail de redefinição de senha (fluxo "Esqueci a senha").
  async function resetPassword(email: string) {
    if (!supabase) throw new Error('Supabase não configurado')
    loading.value = true
    error.value = null
    try {
      const { error: err } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      })
      if (err) throw new Error(err.message)
    } catch (err) {
      error.value = getErrorMessage(err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // Define a nova senha após o link de redefinição (sessão de recuperação ativa).
  async function updatePassword(newPassword: string) {
    if (!supabase) throw new Error('Supabase não configurado')
    loading.value = true
    error.value = null
    try {
      const { error: err } = await supabase.auth.updateUser({ password: newPassword })
      if (err) throw new Error(err.message)
    } catch (err) {
      error.value = getErrorMessage(err)
      throw err
    } finally {
      loading.value = false
    }
  }

  // Troca a senha do usuário logado (verifica a atual via login antes de atualizar).
  async function changePassword(currentPassword: string, newPassword: string) {
    if (!supabase) throw new Error('Supabase não configurado')
    const email = user.value?.email
    if (!email) throw new Error('Usuário não identificado.')
    const { error: errAtual } = await supabase.auth.signInWithPassword({
      email,
      password: currentPassword,
    })
    if (errAtual) throw new Error('Senha atual incorreta.')
    const { error: errNova } = await supabase.auth.updateUser({ password: newPassword })
    if (errNova) throw new Error(errNova.message)
  }

  async function fetchMe() {
    if (!supabase) throw new Error('Supabase não configurado')
    try {
      const { data, error: err } = await supabase.auth.getUser()
      if (err || !data?.user) throw new Error('Sessão expirada. Faça login novamente.')

      const { data: me, error: rpcErr } = await supabase.rpc('auth_me')
      if (rpcErr) throw new Error(rpcErr.message)
      if (!me) throw new Error('Usuário não cadastrado.')

      user.value = me as User
    } catch (err) {
      console.error('[auth/me]', err)
      logout()
      throw new Error(getErrorMessage(err) || 'Sessão expirada. Faça login novamente.')
    }
    // Conta desativada pela empresa (ou um "pai" desativado) não pode operar.
    const u = user.value
    if (u && (u.ativo === false || u.ativo_efetivo === false)) {
      logout()
      throw new Error('Conta inativa. Fale com o administrador.')
    }
    await loadPerfilEfetivo()
  }

  function logout() {
    session.value = null
    user.value = null
    empresaEfetiva.value = null
    supabase?.auth.signOut().catch(() => {})
    useCatalogoStore().resetarSessao()
    // Limpa o orçamento em edição (número/cabeçalho/resultado) para o próximo usuário
    // não herdar dados da conta anterior (ex.: número de um pedido convertido).
    useOrcamentoStore().resetar()
  }

  return {
    user,
    session,
    token,
    loading,
    error,
    isAuthenticated,
    role,
    isAdminGeral,
    isAdmin,
    isVendedorMaster,
    isVendedor,
    ehFilho,
    temComissoes,
    empresaEfetiva,
    userEfetivo,
    init,
    login,
    signup,
    fetchMe,
    googleLogin,
    resetPassword,
    updatePassword,
    changePassword,
    logout,
  }
})
