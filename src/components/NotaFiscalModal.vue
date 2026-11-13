<script setup lang="ts">
import { computed } from 'vue'
import type { NotaFiscal } from '@/types/notaFiscal'

const props = defineProps<{
  modelValue: boolean
  nota: NotaFiscal | null
}>()

const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>()

function close() {
  emit('update:modelValue', false)
}

function moeda(v: number | null | undefined): string {
  return `R$ ${(Number(v) || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`
}

function dataBR(v: string | null | undefined): string {
  if (!v) return ''
  const [y, m, d] = String(v).slice(0, 10).split('-')
  if (!y || !m || !d) return String(v)
  return `${d}/${m}/${y}`
}

const itens = computed(() => props.nota?.itens ?? [])

function baixarXml() {
  if (!props.nota?.xml) return
  const blob = new Blob([props.nota.xml], { type: 'application/xml' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `NF-${props.nota.chave || props.nota.numero || 'nota'}.xml`
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue && nota" class="nf-overlay" @click="close">
        <div class="nf-card" @click.stop>
          <header class="nf-header">
            <h2>Nota Fiscal {{ nota.numero ? `Nº ${nota.numero}` : '' }}</h2>
            <button class="nf-close" @click="close" aria-label="Fechar">&times;</button>
          </header>

          <div class="nf-body">
            <section class="nf-section">
              <div class="nf-grid">
                <div class="nf-field">
                  <label>Chave de acesso</label>
                  <span class="mono">{{ nota.chave || '—' }}</span>
                </div>
                <div class="nf-field">
                  <label>Nº / Série</label>
                  <span>{{ nota.numero || '—' }}{{ nota.serie ? ` / ${nota.serie}` : '' }}</span>
                </div>
                <div class="nf-field">
                  <label>Emissão</label>
                  <span>{{ dataBR(nota.data_emissao) || '—' }}</span>
                </div>
                <div class="nf-field">
                  <label>Tipo</label>
                  <span>{{ nota.tp_nf === 1 ? 'Saída' : 'Entrada' }}</span>
                </div>
              </div>
              <p v-if="nota.natureza_operacao" class="nf-natop">
                <strong>Natureza da operação:</strong> {{ nota.natureza_operacao }}
              </p>
            </section>

            <section class="nf-section">
              <h3>Partes</h3>
              <div class="nf-duo">
                <div class="nf-bloco">
                  <strong>Emitente</strong>
                  <span>{{ nota.emitente_nome || '—' }}</span>
                  <span>CNPJ/CPF: {{ nota.emitente_cnpj || '—' }}</span>
                  <span v-if="nota.emitente_ie">IE: {{ nota.emitente_ie }}</span>
                </div>
                <div class="nf-bloco">
                  <strong>Destinatário</strong>
                  <span>{{ nota.destinatario_nome || '—' }}</span>
                  <span>CNPJ/CPF: {{ nota.destinatario_cnpj || '—' }}</span>
                </div>
              </div>
            </section>

            <section class="nf-section">
              <h3>Itens ({{ itens.length }})</h3>
              <div class="nf-itens">
                <table>
                  <thead>
                    <tr>
                      <th>Cód.</th>
                      <th>Descrição</th>
                      <th>NCM</th>
                      <th class="ta-r">Qtd</th>
                      <th class="ta-r">V. Unit</th>
                      <th class="ta-r">V. Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(it, i) in itens" :key="i">
                      <td class="mono">{{ it.codigo }}</td>
                      <td>{{ it.descricao }}</td>
                      <td class="mono">{{ it.ncm }}</td>
                      <td class="ta-r">{{ it.qtd }}</td>
                      <td class="ta-r">{{ moeda(it.valor_unit) }}</td>
                      <td class="ta-r">{{ moeda(it.valor_total) }}</td>
                    </tr>
                    <tr v-if="!itens.length">
                      <td colspan="6" class="empty">Sem itens no XML</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="nf-section">
              <h3>Totais</h3>
              <div class="nf-totais">
                <div><label>Produtos</label><span>{{ moeda(nota.valor_produtos) }}</span></div>
                <div><label>Frete</label><span>{{ moeda(nota.valor_frete) }}</span></div>
                <div><label>IPI</label><span>{{ moeda(nota.valor_ipi) }}</span></div>
                <div><label>ICMS</label><span>{{ moeda(nota.valor_icms) }}</span></div>
                <div class="total"><label>Total da NF</label><span>{{ moeda(nota.valor_total) }}</span></div>
              </div>
            </section>
          </div>

          <footer class="nf-footer">
            <button v-if="nota.xml" type="button" class="btn btn-accent" @click="baixarXml">
              Baixar XML
            </button>
            <button type="button" class="btn btn-cancel" @click="close">Fechar</button>
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.nf-overlay {
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

.nf-card {
  background: var(--card-bg);
  border-radius: 14px;
  width: 100%;
  max-width: 680px;
  margin: auto;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.15);
}

.nf-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-light);
  flex-shrink: 0;
}

.nf-header h2 {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-primary);
}

.nf-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: var(--text-secondary);
  cursor: pointer;
  width: 32px;
  height: 32px;
  border-radius: 6px;
}

.nf-close:hover {
  background: var(--border-subtle);
  color: var(--text-primary);
}

.nf-body {
  padding: 1.25rem 1.5rem;
  overflow-y: auto;
  flex: 1;
}

.nf-section {
  margin-bottom: 1.5rem;
}

.nf-section h3 {
  font-size: 0.8rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--text-secondary);
  margin-bottom: 0.75rem;
}

.nf-grid {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1fr;
  gap: 0.75rem;
}

.nf-field {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.nf-field label {
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.nf-field span {
  font-size: 0.9rem;
  color: var(--text-primary);
  word-break: break-word;
}

.mono {
  font-family: monospace;
  font-size: 0.82rem !important;
}

.nf-natop {
  margin-top: 0.75rem;
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.nf-duo {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.nf-bloco {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  font-size: 0.9rem;
  color: var(--text-primary);
  padding: 0.75rem;
  border: 1px solid var(--border-light);
  border-radius: 8px;
}

.nf-bloco strong {
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.nf-itens {
  overflow-x: auto;
  border: 1px solid var(--border-light);
  border-radius: 8px;
}

.nf-itens table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.82rem;
}

.nf-itens th,
.nf-itens td {
  padding: 0.5rem 0.6rem;
  text-align: left;
  border-bottom: 1px solid var(--border-light);
  color: var(--text-primary);
}

.nf-itens th {
  background: var(--border-subtle);
  font-size: 0.72rem;
  text-transform: uppercase;
  color: var(--text-secondary);
}

.nf-itens tr:last-child td {
  border-bottom: none;
}

.ta-r {
  text-align: right !important;
  white-space: nowrap;
}

.empty {
  text-align: center;
  color: var(--text-secondary);
  padding: 1rem;
}

.nf-totais {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  max-width: 320px;
  margin-left: auto;
}

.nf-totais > div {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  font-size: 0.9rem;
  color: var(--text-primary);
}

.nf-totais label {
  color: var(--text-secondary);
}

.nf-totais .total {
  font-weight: 700;
  border-top: 1px solid var(--border-light);
  padding-top: 0.4rem;
}

.nf-footer {
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
}

.btn-accent {
  background: var(--accent);
  color: #fff;
}

.btn-accent:hover {
  background: var(--accent-hover);
}

.btn-cancel {
  background: var(--border-subtle);
  color: var(--text-secondary);
}

.btn-cancel:hover {
  background: var(--border-light);
}

.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

@media (max-width: 639px) {
  .nf-grid {
    grid-template-columns: 1fr 1fr;
  }

  .nf-duo {
    grid-template-columns: 1fr;
  }
}
</style>
