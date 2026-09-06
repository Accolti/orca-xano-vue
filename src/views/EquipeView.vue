<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'

interface MembroEquipe {
  id: number
  name: string
  name_first?: string
  name_last?: string
  email: string
  role?: string | null
  vendedor_pai_id?: number | null
  percentual_comissao?: number | null
  ativo?: boolean
  created_at?: number | string
}

const authStore = useAuthStore()

const membros = ref<MembroEquipe[]>([])
const loading = ref(false)
const erro = ref<string | null>(null)
const okMsg = ref<string | null>(null)

const criarForm = reactive({
  name_first: '',
  name_last: '',
  email: '',
  password: '',
  percentual: 0,
})
const vincularForm = reactive({ email: '', percentual: 0 })

const salvandoCriar = ref(false)
const salvandoVincular = ref(false)

const editandoId = ref<number | null>(null)
const editPercentual = ref<number | null>(null)
const salvandoEdicao = ref(false)

function getErrorMessage(err: unknown): string {
  if (err instanceof XanoRequestError) {
    try {
      const body = err.getResponse().getBody()
      if (typeof body === 'string') return body
      if (body?.message) return body.message
      if (body?.error?.message) return body.error.message
    } catch {
      /* ignore */
    }
  }
  return (err as Error).message || 'Erro inesperado'
}

function avisarErro(err: unknown) {
  erro.value = getErrorMessage(err)
}

function avisarOk(msg: string) {
  okMsg.value = msg
  setTimeout(() => (okMsg.value = null), 3500)
}

async function carregar() {
  loading.value = true
  erro.value = null
  try {
    const resp = await xano.get('/api:-qqRIakp/equipe')
    membros.value = (resp.getBody() as MembroEquipe[]) ?? []
  } catch (err) {
    avisarErro(err)
  } finally {
    loading.value = false
  }
}

async function criarVendedor() {
  if (salvandoCriar.value) return
  if (!criarForm.name_first.trim() || !criarForm.email.trim()) {
    erro.value = 'Informe nome e e-mail.'
    return
  }
  if (criarForm.password.length < 8) {
    erro.value = 'A senha deve ter pelo menos 8 caracteres.'
    return
  }
  salvandoCriar.value = true
  erro.value = null
  try {
    await xano.post('/api:-qqRIakp/equipe_criar', {
      name_first: criarForm.name_first,
      name_last: criarForm.name_last,
      email: criarForm.email,
      password: criarForm.password,
      percentual_comissao: criarForm.percentual || undefined,
    })
    criarForm.name_first = ''
    criarForm.name_last = ''
    criarForm.email = ''
    criarForm.password = ''
    criarForm.percentual = 0
    avisarOk('Vendedor criado com sucesso.')
    await carregar()
  } catch (err) {
    avisarErro(err)
  } finally {
    salvandoCriar.value = false
  }
}

async function vincular() {
  if (salvandoVincular.value) return
  if (!vincularForm.email.trim()) {
    erro.value = 'Informe o e-mail da conta a vincular.'
    return
  }
  salvandoVincular.value = true
  erro.value = null
  try {
    await xano.post('/api:-qqRIakp/equipe_vincular', {
      email: vincularForm.email,
      percentual_comissao: vincularForm.percentual || undefined,
    })
    vincularForm.email = ''
    vincularForm.percentual = 0
    avisarOk('Conta vinculada como vendedor.')
    await carregar()
  } catch (err) {
    avisarErro(err)
  } finally {
    salvandoVincular.value = false
  }
}

function iniciarEdicao(m: MembroEquipe) {
  editandoId.value = m.id
  editPercentual.value = Number(m.percentual_comissao) || 0
  erro.value = null
}

function cancelarEdicao() {
  editandoId.value = null
  editPercentual.value = null
}

async function salvarEdicao(m: MembroEquipe) {
  if (salvandoEdicao.value) return
  salvandoEdicao.value = true
  erro.value = null
  try {
    await xano.post('/api:-qqRIakp/equipe_editar', {
      user_id: m.id,
      percentual_comissao: editPercentual.value ?? undefined,
    })
    editandoId.value = null
    editPercentual.value = null
    avisarOk('Dados do vendedor atualizados.')
    await carregar()
  } catch (err) {
    avisarErro(err)
  } finally {
    salvandoEdicao.value = false
  }
}

async function alternarAtivo(m: MembroEquipe) {
  try {
    await xano.post('/api:-qqRIakp/equipe_editar', {
      user_id: m.id,
      ativo: !(m.ativo ?? true),
    })
    await carregar()
  } catch (err) {
    avisarErro(err)
  }
}

function nomeMembro(m: MembroEquipe): string {
  return [m.name_first, m.name_last].filter(Boolean).join(' ').trim() || m.name || m.email
}

function fmtPct(n: number | null | undefined): string {
  const v = Number(n) || 0
  return v > 0 ? `${v}%` : '—'
}

onMounted(carregar)
</script>

<template>
  <main class="eqp">
    <header class="eqp-head">
      <h1>Equipe</h1>
      <p class="subtitle">Cadastre os vendedores da sua conta. Role atual: {{
        authStore.isAdminGeral ? 'Admin Geral' : authStore.isAdmin ? 'Admin' : 'Vendedor'
      }}</p>
    </header>

    <p v-if="!authStore.isAdmin" class="restrito">Acesso restrito a administradores.</p>

    <template v-else>
      <p v-if="loading" class="status"><span class="spinner" /> Carregando...</p>
      <p v-if="erro" class="erro" role="alert">{{ erro }}</p>
      <p v-if="okMsg" class="ok" role="status">{{ okMsg }}</p>

      <section class="form-cards">
        <div class="eqp-card">
          <h2>Novo vendedor</h2>
          <div class="field">
            <label for="eq-nome">Nome</label>
            <input id="eq-nome" v-model="criarForm.name_first" placeholder="Nome" />
          </div>
          <div class="field">
            <label for="eq-sobrenome">Sobrenome</label>
            <input id="eq-sobrenome" v-model="criarForm.name_last" placeholder="Sobrenome" />
          </div>
          <div class="field">
            <label for="eq-email">E-mail (login)</label>
            <input id="eq-email" v-model="criarForm.email" type="email" placeholder="email@exemplo.com" />
          </div>
          <div class="field">
            <label for="eq-senha">Senha inicial</label>
            <input
              id="eq-senha"
              v-model="criarForm.password"
              type="password"
              autocomplete="new-password"
              placeholder="Mín. 8 caracteres"
            />
          </div>
          <div class="field">
            <label for="eq-perc">Comissão (%)</label>
            <input
              id="eq-perc"
              v-model.number="criarForm.percentual"
              type="number"
              min="0"
              step="0.01"
              placeholder="0"
            />
          </div>
          <button class="btn btn-primary" :disabled="salvandoCriar" @click="criarVendedor">
            {{ salvandoCriar ? 'Criando…' : 'Criar vendedor' }}
          </button>
        </div>

        <div class="eqp-card">
          <h2>Vincular conta existente</h2>
          <p class="hint">Converte uma conta já criada em vendedor da sua equipe.</p>
          <div class="field">
            <label for="eq-vinc-email">E-mail da conta</label>
            <input id="eq-vinc-email" v-model="vincularForm.email" type="email" placeholder="email@exemplo.com" />
          </div>
          <div class="field">
            <label for="eq-vinc-perc">Comissão (%)</label>
            <input
              id="eq-vinc-perc"
              v-model.number="vincularForm.percentual"
              type="number"
              min="0"
              step="0.01"
              placeholder="0"
            />
          </div>
          <button class="btn btn-primary" :disabled="salvandoVincular" @click="vincular">
            {{ salvandoVincular ? 'Vinculando…' : 'Vincular como vendedor' }}
          </button>
        </div>
      </section>

      <section class="eqp-lista">
        <h2>Vendedores ({{ membros.length }})</h2>
        <div v-if="!membros.length && !loading" class="vazio">Nenhum vendedor cadastrado ainda.</div>
        <div v-else-if="membros.length" class="tabela-wrapper">
          <table class="tabela">
            <thead>
              <tr>
                <th>Nome</th>
                <th>E-mail</th>
                <th>Comissão</th>
                <th>Status</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in membros" :key="m.id">
                <td>{{ nomeMembro(m) }}</td>
                <td>{{ m.email }}</td>
                <td>
                  <template v-if="editandoId === m.id">
                    <input
                      v-model.number="editPercentual"
                      type="number"
                      min="0"
                      step="0.01"
                      class="edit-perc"
                    />
                  </template>
                  <template v-else>{{ fmtPct(m.percentual_comissao) }}</template>
                </td>
                <td>
                  <span :class="['badge-status', m.ativo !== false ? 'badge-aprovado' : 'badge-recusado']">
                    {{ m.ativo !== false ? 'Ativo' : 'Inativo' }}
                  </span>
                </td>
                <td class="cell-acoes">
                  <template v-if="editandoId === m.id">
                    <button class="btn btn-sm btn-primary" :disabled="salvandoEdicao" @click="salvarEdicao(m)">
                      Salvar
                    </button>
                    <button class="btn btn-sm btn-outline" @click="cancelarEdicao">✕</button>
                  </template>
                  <template v-else>
                    <button class="btn btn-sm btn-outline" @click="iniciarEdicao(m)">Editar %</button>
                    <button
                      class="btn btn-sm btn-outline"
                      @click="alternarAtivo(m)"
                    >
                      {{ m.ativo !== false ? 'Desativar' : 'Ativar' }}
                    </button>
                  </template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.eqp {
  padding: 1.5rem;
  max-width: 1100px;
  margin: 0 auto;
}

.eqp-head {
  margin-bottom: 1.25rem;
}

.eqp-head h1 {
  font-size: 1.45rem;
  margin-bottom: 0.15rem;
}

.subtitle {
  color: var(--text-secondary);
  font-size: 0.95rem;
  margin: 0;
}

.restrito {
  color: var(--danger);
}

.status {
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid var(--border-light);
  border-top-color: var(--primary-light);
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.erro {
  color: var(--danger);
}

.ok {
  color: #16a34a;
}

.form-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.eqp-card {
  padding: 1rem 1.1rem;
  border-radius: 12px;
  border: 1px solid var(--border-subtle);
  background: var(--card-bg);
  box-shadow: var(--shadow-card);
}

.eqp-card h2,
.eqp-lista h2 {
  font-size: 1rem;
  margin: 0 0 0.75rem;
}

.hint {
  font-size: 0.8rem;
  color: var(--text-secondary);
  margin-top: -0.4rem;
  margin-bottom: 0.75rem;
}

.field {
  margin-bottom: 0.75rem;
}

.field label {
  display: block;
  font-size: 0.83rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
  color: var(--text-primary);
}

.field input {
  width: 100%;
  padding: 0.45rem 0.55rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.9rem;
}

.field input:focus {
  outline: none;
  border-color: var(--primary);
}

.edit-perc {
  width: 90px;
  padding: 0.3rem 0.45rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
}

.tabela-wrapper {
  overflow-x: auto;
}

.tabela {
  width: 100%;
  border-collapse: collapse;
  font-family: var(--font-body, sans-serif);
  box-shadow: var(--shadow-card);
  border-radius: 10px;
  overflow: hidden;
}

.tabela th,
.tabela td {
  padding: 10px 12px;
  text-align: left;
  border-bottom: 1px solid var(--border-light);
  white-space: nowrap;
}

.tabela th {
  background-color: var(--primary);
  color: white;
  font-weight: 600;
}

.tabela tr:hover {
  background-color: var(--table-hover);
}

.cell-acoes {
  display: flex;
  gap: 0.4rem;
  align-items: center;
}

.vazio {
  color: var(--text-secondary);
  font-size: 0.85rem;
}

@media (max-width: 639px) {
  .eqp {
    padding: 1rem;
  }
}
</style>
