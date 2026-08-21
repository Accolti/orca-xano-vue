<script setup lang="ts">
import { ref, reactive, watch, computed } from 'vue'
import { xano } from '@/services/xano'
import { XanoRequestError } from '@xano/js-sdk'
import type { ClienteForm, TelefoneEntry } from '@/types/cliente'
import { defaultForm } from '@/types/cliente'
import {
  ramoMap,
  mercadoMap,
  regimeMap,
  beneficioMap,
  tipoTelMap,
  reverseLookup,
} from '@/data/mappings'

const props = defineProps<{
  modelValue: boolean
  clienteId?: number | null
  readonly?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  saved: []
}>()

const form = reactive<ClienteForm>({ ...defaultForm })
const editandoId = ref<number | null>(null)
const enderecoClienteId = ref<number | null>(null)
const carregandoCliente = ref(false)
const buscandoCNPJ = ref(false)
const buscandoCEP = ref(false)
const salvando = ref(false)
const erroSalvar = ref<string | null>(null)
const erroCNPJ = ref<string | null>(null)

const isCNPJ = computed(() => form.tipo_pessoa === 'CNPJ')
const editando = computed(() => editandoId.value !== null)

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    Object.assign(form, defaultForm)
    editandoId.value = props.clienteId ?? null
    enderecoClienteId.value = null
    erroSalvar.value = null

    if (props.clienteId) {
      carregandoCliente.value = true
      try {
        const resp = await xano.get(`/api:-qqRIakp/cliente/${props.clienteId}`)
        const data = resp.getBody()

        form.tipo_pessoa = data.cnpj ? 'CNPJ' : 'CPF'
        form.razao_social = data.razao_social ?? ''
        form.nome_fantasia = data.nome_fantasia ?? ''
        form.contato = data.contato ?? ''
        form.cnpj_cpf = data.cnpj || data.cpf || ''
        form.inscricao_estadual = data.inscricao_estadual ?? ''
        form.email = data['e-mail'] ?? ''
        form.observacoes = data.observacao ?? ''
        form.ramo_atividade = reverseLookup(ramoMap, data.ramo_id) ?? ''
        form.tipo_mercado = reverseLookup(mercadoMap, data.mercado_id) ?? ''
        form.regime_tributario = reverseLookup(regimeMap, data.regime_id) ?? ''
        form.beneficio_fiscal = reverseLookup(beneficioMap, data.beneficio_fiscal_id) ?? ''

        const addr = data._endereco_cliente?.[0]
        if (addr) {
          enderecoClienteId.value = addr.id
          form.logradouro = addr.endereco ?? ''
          form.numero = String(addr.numero ?? '')
          form.complemento = addr.complemento ?? ''
          form.cep = String(addr.cep ?? '')
          form.bairro = addr.bairro ?? ''
          form.cidade = addr.cidade ?? ''
          form.uf = addr.estado ?? ''
        }

        const tels = data._telefone_cliente_of_cliente ?? []
        form.telefones = tels.map((t: any) => ({
          id: t.id,
          numero: t.telefone ?? '',
          tipo: reverseLookup(tipoTelMap, t.tipo_telefone_id) ?? '',
        }))
      } catch (err) {
        console.error('Erro ao carregar cliente:', err)
        erroSalvar.value = 'Erro ao carregar dados do cliente'
      } finally {
        carregandoCliente.value = false
      }
    }
  },
)

function close() {
  emit('update:modelValue', false)
}

function adicionarTelefone() {
  form.telefones.push({ tipo: '', numero: '' })
}

function removerTelefone(idx: number) {
  form.telefones.splice(idx, 1)
}

function getErroMsg(err: unknown): string {
  if (err instanceof XanoRequestError) {
    try {
      const body = err.getResponse().getBody()
      if (typeof body === 'string') return body
      if (body?.message) return body.message
    } catch {
      /* ignore */
    }
  }
  return (err as Error).message || 'Erro inesperado'
}

function lookupId(map: Record<string, number>, key: string, label: string): number | undefined {
  if (!key) return undefined
  const id = map[key]
  if (id === undefined) {
    console.warn(`[mapping] ${label} "${key}" sem ID definido em src/data/mappings.ts`)
  }
  return id
}

async function submit() {
  salvando.value = true
  erroSalvar.value = null

  const payload: Record<string, any> = {
    razao_social: form.razao_social,
    nome_fantasia: form.nome_fantasia,
    contato: form.contato,
    inscricao_estadual: form.inscricao_estadual,
    observacao: form.observacoes,
    'e-mail': form.email,
    endereco: form.logradouro,
    numero: form.numero,
    complemento: form.complemento,
    cep: form.cep,
    bairro: form.bairro,
    cidade: form.cidade,
    estado: form.uf,
    contribui_icms: false,
    isento: false,
    objphone: form.telefones.map((t: TelefoneEntry) => ({
      telefone: t.numero,
      tipo: lookupId(tipoTelMap, t.tipo, 'Tipo Telefone') ?? 0,
      ...(t.id ? { telefone_id: t.id } : {}),
    })),
  }

  if (form.tipo_pessoa === 'CNPJ') {
    payload.cnpj = form.cnpj_cpf
  } else {
    payload.cpf = form.cnpj_cpf
    payload.nome_cpf = form.razao_social || form.nome_fantasia
  }

  if (editandoId.value) {
    payload.cliente_id = editandoId.value
    payload.endereco_cliente_id = enderecoClienteId.value
  }

  const ramo_id = lookupId(ramoMap, form.ramo_atividade, 'Ramo')
  if (ramo_id !== undefined) payload.ramo_id = ramo_id

  const mercado_id = lookupId(mercadoMap, form.tipo_mercado, 'Mercado')
  if (mercado_id !== undefined) payload.mercado_id = mercado_id

  const regime_id = lookupId(regimeMap, form.regime_tributario, 'Regime')
  if (regime_id !== undefined) payload.regime_id = regime_id

  const beneficio_id = lookupId(beneficioMap, form.beneficio_fiscal, 'Benefício Fiscal')
  if (beneficio_id !== undefined) payload.beneficio_fiscal_id = beneficio_id

  try {
    if (editandoId.value) {
      await xano.patch('/api:-qqRIakp/Cliente_Endereco_Telefone', payload)
    } else {
      await xano.post('/api:-qqRIakp/Cliente_Endereco_Telefone', payload)
    }
    emit('saved')
    close()
  } catch (err) {
    erroSalvar.value = getErroMsg(err)
  } finally {
    salvando.value = false
  }
}

async function buscarCNPJ() {
  const raw = form.cnpj_cpf.replace(/\D/g, '')
  if (raw.length !== 14) return

  buscandoCNPJ.value = true
  erroCNPJ.value = null
  try {
    const response = await xano.get('/api:-qqRIakp/capturarDados_CNPJ_IE', { cnpj: raw })
    const data = response.getBody() as any

    if (data?.razaoSocial) form.razao_social = data.razaoSocial
    if (data?.nomeFantasia) form.nome_fantasia = data.nomeFantasia

    if (data?.enderecoCompleto) {
      const a = data.enderecoCompleto
      if (a.cep) form.cep = a.cep
      if (a.rua) form.logradouro = a.rua
      if (a.numero) form.numero = String(a.numero)
      if (a.complemento) form.complemento = a.complemento
      if (a.bairro) form.bairro = a.bairro
      if (a.cidade) form.cidade = a.cidade
      if (a.estado) form.uf = a.estado
    }

    if (data?.IE) form.inscricao_estadual = data.IE

    if (data?.telefones?.length > 0) {
      form.telefones = data.telefones.map((p: any) => ({
        tipo: p.tipo || '',
        numero: (p.ddd || '') + p.numero,
      }))
    }

    if (data?.emails?.length > 0) {
      form.email = data.emails[0]
    }
  } catch (err: any) {
    console.error('Erro ao buscar CNPJ:', err)
    const body = err?.getResponse?.()?.getBody?.()
    erroCNPJ.value = body?.message || err?.message || 'Erro ao buscar CNPJ'
  } finally {
    buscandoCNPJ.value = false
  }
}

async function buscarCEP() {
  const raw = form.cep.replace(/\D/g, '')
  if (raw.length !== 8) return

  buscandoCEP.value = true
  try {
    const resp = await fetch(`https://viacep.com.br/ws/${raw}/json/`)
    const data = await resp.json()

    if (!data.erro) {
      if (data.logradouro) form.logradouro = data.logradouro
      if (data.bairro) form.bairro = data.bairro
      if (data.localidade) form.cidade = data.localidade
      if (data.uf) form.uf = data.uf
      if (data.complemento) form.complemento = data.complemento
    }
  } catch (err) {
    console.error('Erro ao buscar CEP:', err)
  } finally {
    buscandoCEP.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue" class="modal-overlay" @click="close">
        <div class="modal-card" @click.stop>
          <header class="modal-header">
            <h2>{{ editando ? 'Editar Cliente' : 'Cadastro de Cliente' }}</h2>
            <button class="modal-close" @click="close" aria-label="Fechar">&times;</button>
          </header>

          <div v-if="carregandoCliente" class="modal-body">
            <p class="loading-msg">Carregando dados do cliente...</p>
          </div>

          <div v-else class="modal-body">
            <fieldset :disabled="props.readonly">
              <!-- A. Classificação e Perfil Fiscal -->
              <section class="form-section">
                <h3>Classificação e Perfil Fiscal</h3>

                <div class="field-row">
                  <div class="field half">
                    <label for="tipo_pessoa">Tipo Pessoa</label>
                    <select id="tipo_pessoa" v-model="form.tipo_pessoa">
                      <option value="CNPJ">CNPJ</option>
                      <option value="CPF">CPF</option>
                    </select>
                  </div>
                  <div class="field half">
                    <label for="contato">Contato</label>
                    <input id="contato" v-model="form.contato" placeholder="Contato" />
                  </div>
                </div>

                <div class="field-row three">
                  <div class="field">
                    <label for="ramo_atividade">Ramo de Atividade</label>
                    <select id="ramo_atividade" v-model="form.ramo_atividade">
                      <option value="" disabled>Selecione</option>
                      <option value="Atacado">Atacado</option>
                      <option value="Varejo">Varejo</option>
                      <option value="Industria">Indústria</option>
                      <option value="Servicos">Serviços</option>
                      <option value="Outro">Outro</option>
                    </select>
                  </div>
                  <div class="field">
                    <label for="tipo_mercado">Tipo de Mercado</label>
                    <select id="tipo_mercado" v-model="form.tipo_mercado">
                      <option value="" disabled>Selecione</option>
                      <option value="Nacional">Nacional</option>
                      <option value="Internacional">Internacional</option>
                      <option value="Outro">Outro</option>
                    </select>
                  </div>
                  <div class="field">
                    <label for="regime_tributario">Regime Tributário</label>
                    <select id="regime_tributario" v-model="form.regime_tributario">
                      <option value="" disabled>Selecione</option>
                      <option value="Normal">Normal</option>
                      <option value="Simples Nacional">Simples Nacional</option>
                      <option value="MEI">MEI</option>
                    </select>
                  </div>
                </div>

                <div class="field">
                  <label for="beneficio_fiscal">Benefício Fiscal</label>
                  <select id="beneficio_fiscal" v-model="form.beneficio_fiscal">
                    <option value="" disabled>Selecione</option>
                    <option value="Nenhum">Nenhum</option>
                    <option value="Zona Franca de Manaus">Zona Franca de Manaus</option>
                    <option value="Zona Franca">Zona Franca</option>
                    <option value="Área Livre de Comércio">Área Livre de Comércio</option>
                    <option value="Amazonia Central">Amazonia Central</option>
                  </select>
                </div>
              </section>

              <!-- B. Dados Empresariais e Fiscais -->
              <section class="form-section">
                <h3>Dados Empresariais e Fiscais</h3>

                <template v-if="isCNPJ">
                  <div class="field">
                    <label for="razao_social">Razão Social</label>
                    <input
                      id="razao_social"
                      v-model="form.razao_social"
                      placeholder="Razão Social"
                    />
                  </div>
                </template>

                <div class="field">
                  <label for="nome_fantasia">Nome Fantasia</label>
                  <input
                    id="nome_fantasia"
                    v-model="form.nome_fantasia"
                    placeholder="Nome Fantasia..."
                  />
                </div>

                <div class="field">
                  <label for="cnpj_cpf">{{ isCNPJ ? 'CNPJ' : 'CPF' }}</label>
                  <input
                    id="cnpj_cpf"
                    v-model="form.cnpj_cpf"
                    :placeholder="isCNPJ ? '00.000.000/0001-00' : '000.000.000-00'"
                    maxlength="18"
                  />
                  <button
                    v-if="isCNPJ"
                    type="button"
                    class="btn-search"
                    :disabled="buscandoCNPJ || form.cnpj_cpf.replace(/\D/g, '').length !== 14"
                    @click="buscarCNPJ"
                  >
                    {{ buscandoCNPJ ? 'Buscando…' : 'Buscar' }}
                  </button>
                  <p v-if="erroCNPJ" class="cnpj-error">{{ erroCNPJ }}</p>
                </div>

                <template v-if="isCNPJ">
                  <div class="field">
                    <label for="inscricao_estadual">Insc. Estadual</label>
                    <input
                      id="inscricao_estadual"
                      v-model="form.inscricao_estadual"
                      placeholder="Inscrição Estadual"
                    />
                  </div>
                </template>
              </section>

              <!-- C. Endereço e Localização -->
              <section class="form-section">
                <h3>Endereço e Localização</h3>

                <div class="field">
                  <label for="cep">CEP</label>
                  <input id="cep" v-model="form.cep" placeholder="CEP..." maxlength="9" />
                  <button
                    type="button"
                    class="btn-search"
                    :disabled="buscandoCEP || form.cep.replace(/\D/g, '').length !== 8"
                    @click="buscarCEP"
                  >
                    {{ buscandoCEP ? 'Buscando…' : 'Buscar' }}
                  </button>
                </div>

                <div class="field">
                  <label for="email">E-mail</label>
                  <input id="email" v-model="form.email" type="email" placeholder="E-mail..." />
                </div>

                <div class="field-row">
                  <div class="field flex-2">
                    <label for="logradouro">Endereço</label>
                    <input id="logradouro" v-model="form.logradouro" placeholder="Logradouro" />
                  </div>
                  <div class="field flex-1">
                    <label for="numero">Número</label>
                    <input id="numero" v-model="form.numero" placeholder="Número" />
                  </div>
                </div>

                <div class="field-row">
                  <div class="field flex-1">
                    <label for="complemento">Complemento</label>
                    <input id="complemento" v-model="form.complemento" placeholder="Complemento" />
                  </div>
                  <div class="field flex-1">
                    <label for="bairro">Bairro</label>
                    <input id="bairro" v-model="form.bairro" placeholder="Bairro" />
                  </div>
                </div>

                <div class="field-row">
                  <div class="field half">
                    <label for="uf">UF</label>
                    <select id="uf" v-model="form.uf">
                      <option value="" disabled>UF</option>
                      <option value="AC">AC</option>
                      <option value="AL">AL</option>
                      <option value="AP">AP</option>
                      <option value="AM">AM</option>
                      <option value="BA">BA</option>
                      <option value="CE">CE</option>
                      <option value="DF">DF</option>
                      <option value="ES">ES</option>
                      <option value="GO">GO</option>
                      <option value="MA">MA</option>
                      <option value="MT">MT</option>
                      <option value="MS">MS</option>
                      <option value="MG">MG</option>
                      <option value="PA">PA</option>
                      <option value="PB">PB</option>
                      <option value="PR">PR</option>
                      <option value="PE">PE</option>
                      <option value="PI">PI</option>
                      <option value="RJ">RJ</option>
                      <option value="RN">RN</option>
                      <option value="RS">RS</option>
                      <option value="RO">RO</option>
                      <option value="RR">RR</option>
                      <option value="SC">SC</option>
                      <option value="SP">SP</option>
                      <option value="SE">SE</option>
                      <option value="TO">TO</option>
                    </select>
                  </div>
                  <div class="field half">
                    <label for="cidade">Cidade</label>
                    <input id="cidade" v-model="form.cidade" placeholder="Cidade" />
                  </div>
                </div>
              </section>

              <!-- D. Contatos Telefônicos -->
              <section class="form-section">
                <h3>Contatos Telefônicos</h3>

                <div v-for="(tel, idx) in form.telefones" :key="idx" class="phone-row">
                  <div class="phone-fields">
                    <select v-model="tel.tipo">
                      <option value="" disabled>Tipo</option>
                      <option value="Celular">Celular</option>
                      <option value="Comercial">Comercial</option>
                      <option value="Residencial">Residencial</option>
                      <option value="WhatsApp">WhatsApp</option>
                    </select>
                    <input v-model="tel.numero" placeholder="Telefone" />
                  </div>
                  <button
                    v-if="form.telefones.length > 1"
                    class="btn-remove-phone"
                    title="Remover"
                    @click="removerTelefone(idx)"
                  >
                    &times;
                  </button>
                </div>

                <button type="button" class="btn-add-phone" @click="adicionarTelefone">
                  + Adicionar Telefone
                </button>

                <div class="field">
                  <label for="observacoes">Observações</label>
                  <textarea
                    id="observacoes"
                    v-model="form.observacoes"
                    placeholder="Obs"
                    rows="3"
                  ></textarea>
                </div>
              </section>

              <p v-if="erroSalvar" class="error-msg">{{ erroSalvar }}</p>
            </fieldset>
          </div>

          <footer class="modal-footer">
            <button type="button" class="btn btn-cancel" :disabled="salvando" @click="close">
              {{ props.readonly ? 'Fechar' : 'Cancelar' }}
            </button>
            <button
              v-if="!props.readonly"
              type="button"
              class="btn btn-accent"
              :disabled="salvando"
              @click="submit"
            >
              {{ salvando ? 'Salvando…' : editando ? 'Alterar' : 'Inserir' }}
            </button>
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 2000;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 2rem 1rem;
  overflow-y: auto;
}

.modal-card {
  background: var(--card-bg);
  border-radius: 14px;
  width: 100%;
  max-width: 600px;
  margin: auto;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.15);
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.modal-header h2 {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-primary);
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: var(--text-secondary);
  cursor: pointer;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  transition: background 0.15s;
}

.modal-close:hover {
  background: var(--border-subtle);
  color: var(--text-primary);
}

.modal-body {
  padding: 1.25rem 1.5rem;
  overflow-y: auto;
  flex: 1;
}

.form-section {
  margin-bottom: 1.5rem;
}

.form-section h3 {
  font-size: 0.85rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--text-secondary);
  margin-bottom: 1rem;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid var(--border-light);
}

.field {
  margin-bottom: 0.875rem;
}

.field label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 0.25rem;
}

.field input,
.field select,
.field textarea {
  width: 100%;
  padding: 0.55rem 0.7rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.9rem;
  color: var(--text-primary);
  background: var(--card-bg);
  outline: none;
  transition: border-color 0.15s;
}

.field input:focus,
.field select:focus,
.field textarea:focus {
  border-color: var(--primary-light);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.15);
}

.field textarea {
  resize: vertical;
  font-family: inherit;
}

.field-row {
  display: flex;
  gap: 0.75rem;
}

.field-row.three .field {
  flex: 1;
}

.field-row .half {
  flex: 1;
}

.field-row .flex-2 {
  flex: 2;
}

.field-row .flex-1 {
  flex: 1;
}

.btn-search {
  margin-top: 0.35rem;
  padding: 0.4rem 1rem;
  background: var(--primary-light);
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 0.8rem;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s;
}

.btn-search:hover {
  background: var(--primary-hover);
}

.btn-search:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.cnpj-error {
  color: #dc2626;
  font-size: 0.8rem;
  margin-top: 0.25rem;
}

.phone-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.phone-fields {
  display: flex;
  gap: 0.5rem;
  flex: 1;
}

.phone-fields select,
.phone-fields input {
  flex: 1;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 0.9rem;
  color: var(--text-primary);
  background: var(--card-bg);
  outline: none;
  transition: border-color 0.15s;
}

.phone-fields select:focus,
.phone-fields input:focus {
  border-color: var(--primary-light);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.15);
}

.btn-remove-phone {
  background: none;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.15rem;
  color: #9ca3af;
  cursor: pointer;
  flex-shrink: 0;
  transition:
    background 0.15s,
    color 0.15s;
}

.btn-remove-phone:hover {
  background: #fef2f2;
  color: #dc2626;
  border-color: #fecaca;
}

.btn-add-phone {
  margin-bottom: 1rem;
  padding: 0.4rem 1rem;
  background: none;
  border: 1px dashed var(--border-light);
  border-radius: 6px;
  font-size: 0.85rem;
  color: var(--primary-light);
  cursor: pointer;
  transition:
    background 0.15s,
    border-color 0.15s;
  width: 100%;
}

.btn-add-phone:hover {
  background: var(--primary-soft);
  border-color: var(--primary-light);
}

.loading-msg {
  text-align: center;
  color: var(--text-secondary);
  padding: 2rem 0;
}

.error-msg {
  color: #e74c3c;
  font-size: 0.875rem;
  text-align: center;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--border-light);
  flex-shrink: 0;
}

.btn {
  padding: 0.55rem 1.25rem;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition: background 0.15s;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-primary {
  background: var(--primary);
  color: #fff;
}

.btn-primary:hover:not(:disabled) {
  background: var(--primary-hover);
}

.btn-accent {
  background: var(--accent);
  color: #fff;
}

.btn-accent:hover:not(:disabled) {
  background: var(--accent-hover);
}

.btn-cancel {
  background: var(--border-subtle);
  color: var(--text-secondary);
}

.btn-cancel:hover:not(:disabled) {
  background: var(--border-light);
}

/* Transition */
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-active .modal-card,
.modal-leave-active .modal-card {
  transition: transform 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-from .modal-card,
.modal-leave-to .modal-card {
  transform: translateY(-20px);
}

@media (max-width: 639px) {
  .modal-overlay {
    padding: 0;
    align-items: flex-end;
  }

  .modal-card {
    max-height: 95vh;
    border-radius: 14px 14px 0 0;
  }

  .modal-header {
    padding: 1rem;
  }

  .modal-body {
    padding: 1rem;
  }

  .modal-footer {
    padding: 0.75rem 1rem;
  }

  .field-row {
    flex-direction: column;
    gap: 0;
  }

  .phone-row {
    flex-direction: column;
    align-items: stretch;
  }

  .phone-fields {
    flex-direction: column;
  }
}

@media (min-width: 640px) and (max-width: 1023px) {
  .field-row {
    gap: 0.5rem;
  }

  .modal-overlay {
    padding: 1.5rem 0.75rem;
  }
}
</style>
