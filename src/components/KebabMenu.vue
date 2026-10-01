<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'

const open = ref(false)

function toggle() {
  open.value = !open.value
}

function close() {
  open.value = false
}

function onDocClick(e: MouseEvent) {
  const target = e.target as HTMLElement
  if (!target.closest('.kebab-wrap')) close()
}

onMounted(() => document.addEventListener('click', onDocClick))
onBeforeUnmount(() => document.removeEventListener('click', onDocClick))
</script>

<template>
  <div class="kebab-wrap">
    <button
      class="kebab-btn"
      type="button"
      title="Mais ações"
      aria-label="Mais ações"
      @click.stop="toggle"
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <circle cx="12" cy="5" r="1.7" />
        <circle cx="12" cy="12" r="1.7" />
        <circle cx="12" cy="19" r="1.7" />
      </svg>
    </button>
    <div v-if="open" class="kebab-menu" @click="close">
      <slot />
    </div>
  </div>
</template>

<style scoped>
.kebab-wrap {
  position: relative;
  display: inline-flex;
}

.kebab-btn {
  width: 24px;
  height: 24px;
  flex-shrink: 0;
  border: none;
  border-radius: 50%;
  background: transparent;
  color: var(--secondary, var(--text-secondary));
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition:
    background 0.15s,
    color 0.15s;
}

.kebab-btn:hover {
  background: var(--border-subtle);
  color: var(--primary);
}

.kebab-menu {
  position: absolute;
  top: calc(100% + 2px);
  right: 0;
  z-index: 30;
  min-width: 190px;
  background: var(--card-bg, #fff);
  border: 1px solid var(--border-light, #e5e7eb);
  border-radius: 8px;
  box-shadow: var(--shadow-card);
  padding: 0.3rem;
  display: flex;
  flex-direction: column;
}

.kebab-menu :deep(.kebab-item) {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  width: 100%;
  padding: 0.45rem 0.6rem;
  border: none;
  background: none;
  cursor: pointer;
  text-align: left;
  font-size: 0.85rem;
  color: var(--text-primary);
  border-radius: 6px;
  white-space: nowrap;
}

.kebab-menu :deep(.kebab-item):hover {
  background: var(--border-subtle);
}

.kebab-menu :deep(.kebab-item.kebab-danger) {
  color: var(--danger, #dc2626);
}

.kebab-menu :deep(.kebab-item svg) {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
}
</style>
