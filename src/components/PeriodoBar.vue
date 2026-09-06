<script setup lang="ts">
// Barra de período compartilhada (Dashboard / Controle Financeiro / Relatórios).
// Mês inicial + chips (Todos/Mensal/Trimestral/Semestral/Anual).
// Emite 'mudou' quando o usuário troca mês ou período — cada tela decide como reagir
// (recarregar API ou apenas recomputar filtros locais).

export type PeriodoOpcao = 'todos' | 'mensal' | 'trimestral' | 'semestral' | 'anual'

const props = defineProps<{
  periodo: PeriodoOpcao
  mesInicio: string
}>()

const emit = defineEmits<{
  'update:periodo': [value: PeriodoOpcao]
  'update:mesInicio': [value: string]
  mudou: []
}>()

const periodos: { id: PeriodoOpcao; label: string }[] = [
  { id: 'todos', label: 'Todos os períodos' },
  { id: 'mensal', label: 'Mensal' },
  { id: 'trimestral', label: 'Trimestral' },
  { id: 'semestral', label: 'Semestral' },
  { id: 'anual', label: 'Anual' },
]

function selecionar(p: PeriodoOpcao) {
  if (p === props.periodo) return
  emit('update:periodo', p)
  emit('mudou')
}

function mudarMes(e: Event) {
  const valor = (e.target as HTMLInputElement).value
  emit('update:mesInicio', valor)
  emit('mudou')
}
</script>

<template>
  <div class="periodo-bar">
    <label class="periodo-label">
      Período a partir de
      <input
        :value="mesInicio"
        type="month"
        class="periodo-input"
        @change="mudarMes"
      />
    </label>
    <div class="periodo-chips">
      <button
        v-for="p in periodos"
        :key="p.id"
        class="aba"
        :class="{ active: periodo === p.id }"
        @click="selecionar(p.id)"
      >
        {{ p.label }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.periodo-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem 0.9rem;
  margin-bottom: 1.25rem;
}

.periodo-label {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.periodo-input {
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  background: var(--card-bg);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.85rem;
}

.periodo-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.aba {
  padding: 0.4rem 0.9rem;
  border-radius: 999px;
  border: 1px solid var(--border-light);
  background: var(--card-bg);
  font-size: 0.85rem;
  color: var(--text-secondary);
  cursor: pointer;
  font-family: inherit;
  transition: background 0.15s;
}

.aba:hover {
  background: var(--table-hover);
}

.aba.active {
  background: var(--primary);
  color: #fff;
  border-color: var(--primary);
}
</style>
