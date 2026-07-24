<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'

defineEmits<{ toggleSidebar: [] }>()

const authStore = useAuthStore()
</script>

<template>
  <header v-if="true" class="global-header">
    <div class="header-left">
      <button class="hamburger-btn" aria-label="Abrir menu" @click="$emit('toggleSidebar')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <line x1="3" y1="6" x2="21" y2="6" />
          <line x1="3" y1="12" x2="21" y2="12" />
          <line x1="3" y1="18" x2="21" y2="18" />
        </svg>
      </button>
      <div class="brand-wrap">
        <span class="brand">{{ authStore.user?.fantasia || authStore.user?.name || 'Orca Systems' }}</span>
        <span v-if="authStore.user?.name" class="brand-sub">{{ authStore.user.name }}</span>
      </div>
    </div>
    <div class="header-right">
      <button class="header-icon" title="Notificações" aria-label="Notificações">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9" />
          <path d="M13.73 21a2 2 0 01-3.46 0" />
        </svg>
      </button>
      <button class="header-icon" title="Perfil" aria-label="Perfil">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
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
  background: #2d3036;
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
  transition: background 0.15s, color 0.15s;
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
