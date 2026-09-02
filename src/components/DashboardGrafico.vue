<script setup lang="ts">
import { computed } from 'vue'

export interface SerieGrafico {
  nome: string
  cor: string
  valores: number[]
}

const props = defineProps<{
  rotulos: string[]
  series: SerieGrafico[]
}>()

const vazio = computed(() => {
  if (!props.rotulos.length) return true
  return props.series.every((s) => s.valores.every((v) => !v || Number.isNaN(v)))
})

const maxVal = computed(() => {
  let mx = 0
  for (const s of props.series) {
    for (const v of s.valores) {
      const n = Number(v) || 0
      if (n > mx) mx = n
    }
  }
  return mx || 1
})

function pct(valor: number): string {
  const n = Number(valor) || 0
  if (n <= 0) return '0%'
  return `${Math.max((n / maxVal.value) * 100, 1.5)}%`
}

function fmtVal(valor: number): string {
  return (Number(valor) || 0).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  })
}

function larguraMin(): string {
  return `${Math.max(props.rotulos.length * 54, 320)}px`
}
</script>

<template>
  <div v-if="vazio" class="dg-vazio">Sem dados no período.</div>
  <div v-else class="dg-scroll">
    <div class="dg-bars" :style="{ minWidth: larguraMin() }">
      <div v-for="(r, idx) in rotulos" :key="r + idx" class="dg-col">
        <div class="dg-plot">
          <div
            v-for="s in series"
            :key="s.nome"
            class="dg-bar"
            :style="{ height: pct(s.valores[idx] ?? 0), background: s.cor }"
            :title="`${s.nome}: ${fmtVal(s.valores[idx] ?? 0)} — ${r}`"
          />
        </div>
        <span class="dg-label">{{ r }}</span>
      </div>
    </div>
  </div>
  <div v-if="series.length > 1" class="dg-legend">
    <span v-for="s in series" :key="s.nome" class="dg-legend-item">
      <i class="dg-dot" :style="{ background: s.cor }" />{{ s.nome }}
    </span>
  </div>
</template>

<style scoped>
.dg-scroll {
  overflow-x: auto;
}

.dg-bars {
  display: flex;
  gap: 6px;
  height: 210px;
}

.dg-col {
  display: flex;
  flex-direction: column;
  width: 46px;
  flex-shrink: 0;
}

.dg-plot {
  flex: 1;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 3px;
  border-bottom: 1px solid var(--border-light);
}

.dg-bar {
  width: 14px;
  border-radius: 3px 3px 0 0;
  transition: height 0.2s ease;
}

.dg-label {
  text-align: center;
  font-size: 0.68rem;
  color: var(--text-secondary);
  padding-top: 5px;
  white-space: nowrap;
}

.dg-vazio {
  padding: 1.25rem;
  text-align: center;
  color: var(--text-secondary);
  font-size: 0.85rem;
}

.dg-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.9rem;
  margin-top: 0.6rem;
}

.dg-legend-item {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.dg-dot {
  width: 10px;
  height: 10px;
  border-radius: 3px;
  display: inline-block;
}
</style>
