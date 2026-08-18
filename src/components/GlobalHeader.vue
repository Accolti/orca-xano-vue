<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useCatalogoStore } from '@/stores/catalogo'

defineEmits<{ toggleSidebar: [] }>()

const authStore = useAuthStore()
const catalogoStore = useCatalogoStore()

const versaoMenuOpen = ref(false)

function toggleVersaoMenu() {
  versaoMenuOpen.value = !versaoMenuOpen.value
}

function fecharVersaoMenu() {
  versaoMenuOpen.value = false
}

function onDocClick(e: MouseEvent) {
  const target = e.target as HTMLElement
  if (!target.closest('.versao-wrap')) {
    fecharVersaoMenu()
  }
}

onMounted(() => {
  document.addEventListener('click', onDocClick)
  catalogoStore.carregarConfiguracoes().catch(() => {})
})

onBeforeUnmount(() => {
  document.removeEventListener('click', onDocClick)
})
</script>

<template>
  <header v-if="true" class="global-header">
    <div class="header-left">
      <button class="hamburger-btn" aria-label="Abrir menu" @click="$emit('toggleSidebar')">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
        >
          <line x1="3" y1="6" x2="21" y2="6" />
          <line x1="3" y1="12" x2="21" y2="12" />
          <line x1="3" y1="18" x2="21" y2="18" />
        </svg>
      </button>
      <div class="brand-wrap">
        <span class="brand">{{
          authStore.user?.fantasia || authStore.user?.name || 'Orca Systems'
        }}</span>
        <span v-if="authStore.user?.name" class="brand-sub">{{ authStore.user.name }}</span>
      </div>
      <div class="versao-wrap">
        <button
          class="versao-badge"
          :title="`Versões: Materiais ${catalogoStore.versaoMateriais ?? '?'} · Produtos ${catalogoStore.versaoProdutos ?? '?'}`"
          aria-label="Versões do catálogo"
          @click.stop="toggleVersaoMenu"
        >
          {{ catalogoStore.versaoLabel }}
        </button>
        <Transition name="pop">
          <div v-if="versaoMenuOpen" class="versao-popover" @click.stop>
            <div class="versao-popover-title">Versões do Catálogo</div>
            <div class="versao-row">
              <span>Versão Materiais</span>
              <strong>{{ catalogoStore.versaoMateriais ?? '—' }}</strong>
            </div>
            <div class="versao-row">
              <span>Versão Produtos</span>
              <strong>{{ catalogoStore.versaoProdutos ?? '—' }}</strong>
            </div>
          </div>
        </Transition>
      </div>
    </div>
    <div class="header-right">
      <button class="header-icon" title="Notificações" aria-label="Notificações">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
        >
          <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9" />
          <path d="M13.73 21a2 2 0 01-3.46 0" />
        </svg>
      </button>
      <button class="header-icon" title="Perfil" aria-label="Perfil">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
        >
          <circle cx="12" cy="8" r="4" />
          <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" />
        </svg>
      </button>
    </div>
  </header>
</template>

<style scoped>
.global-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 56px;
  padding: 0 1rem;
  background: #1e1f24;
  color: #e5e7eb;
  position: sticky;
  top: 0;
  z-index: 90;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.hamburger-btn {
  background: none;
  border: none;
  color: #e5e7eb;
  cursor: pointer;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  transition: background 0.15s;
}

.hamburger-btn:hover {
  background: rgba(255, 255, 255, 0.1);
}

.hamburger-btn svg {
  width: 22px;
  height: 22px;
}

.brand-wrap {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
}

.versao-wrap {
  position: relative;
}

.versao-badge {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.12);
  color: #e5e7eb;
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  padding: 0.2rem 0.55rem;
  border-radius: 6px;
  cursor: pointer;
  font-family: inherit;
  transition:
    background 0.15s,
    border-color 0.15s;
}

.versao-badge:hover {
  background: rgba(255, 255, 255, 0.15);
  border-color: rgba(255, 255, 255, 0.25);
}

.versao-popover {
  position: absolute;
  top: calc(100% + 8px);
  left: 0;
  z-index: 95;
  background: #fff;
  color: #1f2937;
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.18);
  padding: 0.75rem;
  min-width: 200px;
  border: 1px solid #e5e7eb;
}

.versao-popover-title {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--secondary);
  margin-bottom: 0.5rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid #f3f4f6;
}

.versao-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  font-size: 0.85rem;
  padding: 0.25rem 0;
  color: #4b5563;
}

.versao-row strong {
  color: #1f2937;
  font-variant-numeric: tabular-nums;
}

.pop-enter-active,
.pop-leave-active {
  transition:
    opacity 0.15s ease,
    transform 0.15s ease;
}

.pop-enter-from,
.pop-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}

.brand {
  font-weight: 700;
  font-size: 1.05rem;
}

.brand-sub {
  font-size: 0.7rem;
  color: #9ca3af;
  font-weight: 400;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.header-icon {
  background: none;
  border: none;
  color: #9ca3af;
  cursor: pointer;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  transition:
    background 0.15s,
    color 0.15s;
}

.header-icon:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #e5e7eb;
}

.header-icon svg {
  width: 20px;
  height: 20px;
}
</style>
