<script setup lang="ts">
import { ref, computed } from 'vue'
import type { SimulacaoItem } from '@/types/orcamento'

const props = defineProps<{
  modelValue: boolean
  simulacao: SimulacaoItem[]
  custoTotal: number
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  select: [item: SimulacaoItem]
}>()

const itemSelecionado = ref<SimulacaoItem | null>(null)

function formatarMoeda(valor: number): string {
  return `R$ ${valor.toFixed(2).replace('.', ',')}`
}

function close() {
  emit('update:modelValue', false)
}

function selecionar(item: SimulacaoItem) {
  itemSelecionado.value = item
  emit('select', item)
}

function calcularOpcoesPagamento(valorVenda: number, valorCusto: number, bfaturar: boolean): string {
  const entradaPrazo = 5
  const intervaloParcelas = 30

  const primeiraParcelaPix = valorVenda / 2
  const segundaParcelaPix = valorVenda / 2
  const pixString = `Pix (2x) R$ ${primeiraParcelaPix.toFixed(2)} 1ª. em ${entradaPrazo}dd do pedido e 2ª em ${entradaPrazo + intervaloParcelas}dd`

  const metadeCusto = valorCusto / 2
  const numeroParcelas = Math.floor(valorVenda / metadeCusto) || 1
  const valorParcelas = valorVenda / numeroParcelas

  let prazos = `1ª. em ${entradaPrazo}dd do pedido e demais em `
  for (let i = 1; i < numeroParcelas; i++) {
    const prazoAtual = entradaPrazo + i * intervaloParcelas
    prazos += `${prazoAtual}dd`
    if (i < numeroParcelas - 1) prazos += '/'
  }

  const boletoString = `boleto (${numeroParcelas}x) R$ ${valorParcelas.toFixed(2)} ${prazos}`

  let faturadoString = ''
  if (bfaturar) {
    const numeroParcelasFaturamento = Math.floor(valorVenda / valorCusto) || 1
    const valorParcelasFaturamento = valorVenda / numeroParcelasFaturamento

    let prazosFaturamento = 'em '
    for (let i = 0; i < numeroParcelasFaturamento; i++) {
      const prazoFaturamento = 20 + i * 30
      prazosFaturamento += `${prazoFaturamento}dd`
      if (i < numeroParcelasFaturamento - 1) prazosFaturamento += ', '
    }

    faturadoString = `\nFaturado: (${numeroParcelasFaturamento}x) R$ ${valorParcelasFaturamento.toFixed(2)} ${prazosFaturamento}`
  }

  return `${pixString}\n${boletoString}${faturadoString}`
}

const opcoesPagamento = computed(() => {
  const item = itemSelecionado.value
  if (!item) return ''
  return calcularOpcoesPagamento(
    item.Valor_Venda_Total_B2B,
    item.Valor_Custo_Total,
    false,
  )
})
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue" class="modal-overlay" @click="close">
        <div class="modal-card" @click.stop>
          <header class="modal-header">
            <h2>Simulação</h2>
            <button class="modal-close" @click="close">✕</button>
          </header>

          <div class="modal-body">
            <div class="sim-header">
              <strong>Simulação (M V L)</strong>
              <span v-if="simulacao[0]" class="sim-custo">C {{ simulacao[0].Valor_Custo_Total.toFixed(2) }}</span>
            </div>

            <button
              v-for="item in simulacao"
              :key="item.margem"
              class="sim-row"
              @click="selecionar(item)"
            >
              <span class="sim-margem">{{ item.margem }}</span>
              <span class="sim-venda">{{ formatarMoeda(item.Valor_Venda_Total_FRT_B2B) }}</span>
              <span class="sim-lucro">{{ formatarMoeda(item.Valor_Lucro_Total) }}</span>
            </button>
          </div>

          <footer class="modal-footer">
            <p class="footer-text">Condições de Pgto. (Clique em uma opção acima)</p>
            <pre v-if="opcoesPagamento" class="pagamento-text">{{ opcoesPagamento }}</pre>
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
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.modal-card {
  background: #fff;
  border-radius: 12px;
  width: 100%;
  max-width: 520px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.2);
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  flex-shrink: 0;
}

.modal-header h2 {
  font-size: 1.15rem;
  font-weight: 700;
  color: #1f2937;
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: #6b7280;
  cursor: pointer;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}

.modal-close:hover {
  background: #f3f4f6;
  color: #1f2937;
}

.modal-body {
  padding: 1.25rem 1.5rem;
  overflow-y: auto;
  flex: 1;
}

.sim-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  font-size: 0.9rem;
}

.sim-custo {
  color: var(--secondary, #6b7280);
  font-weight: 600;
}

.sim-row {
  display: flex;
  align-items: center;
  width: 100%;
  padding: 0.75rem 1rem;
  margin-bottom: 0.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #fff;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
  text-align: left;
  gap: 0.75rem;
}

.sim-row:hover {
  background: #f9fafb;
  border-color: var(--primary-light, #3b82f6);
}

.sim-margem {
  font-weight: 700;
  font-size: 1rem;
  min-width: 2.5rem;
  color: #1f2937;
}

.sim-venda {
  flex: 1;
  text-align: center;
  font-weight: 700;
  font-size: 0.95rem;
  color: #1f2937;
}

.sim-lucro {
  text-align: right;
  font-size: 0.9rem;
  color: #6b7280;
  min-width: 5rem;
}

.modal-footer {
  padding: 1rem 1.5rem;
  border-top: 1px solid #e5e7eb;
  flex-shrink: 0;
}

.footer-text {
  font-size: 0.85rem;
  color: var(--secondary, #6b7280);
  margin-bottom: 0.5rem;
}

.pagamento-text {
  font-size: 0.8rem;
  color: #374151;
  background: #f9fafb;
  padding: 0.75rem;
  border-radius: 6px;
  white-space: pre-wrap;
  font-family: inherit;
  margin: 0;
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
</style>
