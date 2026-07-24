<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>()

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

interface MenuItem {
  icon: string
  label: string
  path?: string
  disabled?: boolean
}

const menuItems: MenuItem[] = [
  { icon: '\u{1F3E0}', label: 'Home', path: '/' },
  { icon: '\u{1F464}', label: 'Clientes', path: '/clientes' },
  { icon: '\u{1F4C4}', label: 'Orçamentos', path: '/orcamentos' },
  { icon: '\u{1F6D2}', label: 'Pedidos', disabled: true },
  { icon: '\u{1F4CB}', label: 'Controle de Pedidos', disabled: true },
  { icon: '\u{1F4B3}', label: 'Boletos', disabled: true },
  { icon: '\u{1F4CA}', label: 'Relatórios', disabled: true },
  { icon: '\u{1F4D1}', label: 'Dados Gerais', disabled: true },
]

function isActive(item: MenuItem) {
  return !!item.path && route.path === item.path
}

function close() {
  emit('update:modelValue', false)
}

function handleLogout() {
  authStore.logout()
  router.push('/login')
  close()
}
</script>

<template>
  <Teleport to="body">
    <Transition name="drawer">
      <div v-if="modelValue" class="drawer-overlay" @click="close">
        <aside class="drawer" @click.stop>
          <header class="drawer-header">
            <div class="drawer-brand">
              <svg
                class="brand-icon"
                viewBox="0 0 24 24"
                fill="none"
                stroke="#3b82f6"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <rect x="2" y="8" width="8" height="12" rx="1" />
                <rect x="14" y="4" width="8" height="16" rx="1" />
              </svg>
              <span class="brand-name">Orca Systems</span>
            </div>
            <button class="close-btn" @click="close" aria-label="Fechar menu">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <circle cx="12" cy="12" r="10" />
                <line x1="8" y1="8" x2="16" y2="16" />
                <line x1="16" y1="8" x2="8" y2="16" />
              </svg>
            </button>
          </header>

          <div class="drawer-divider" />

          <nav class="drawer-nav">
            <RouterLink
              v-for="item in menuItems"
              :key="item.label"
              :to="item.path ?? ''"
              :class="{
                active: isActive(item),
                disabled: item.disabled,
              }"
              @click="item.disabled ? undefined : close()"
            >
              <span class="nav-icon">{{ item.icon }}</span>
              <span class="nav-label">{{ item.label }}</span>
            </RouterLink>
          </nav>

          <div class="drawer-footer">
            <div class="drawer-divider" />
            <button class="footer-btn" @click="handleLogout">
              <span class="user-avatar">
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <circle cx="12" cy="8" r="4" />
                  <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" />
                </svg>
              </span>
              <span class="footer-text">
                <span class="footer-title">Sair do Aplicativo</span>
                <span class="footer-subtitle">Administrador</span>
              </span>
            </button>
          </div>
        </aside>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.drawer-overlay {
  position: fixed;
  inset: 0;
  z-index: 1000;
  background: rgba(0, 0, 0, 0.45);
}

.drawer {
  width: 280px;
  height: 100%;
  background: #2d3036;
  display: flex;
  flex-direction: column;
  box-shadow: 2px 0 12px rgba(0, 0, 0, 0.3);
}

.drawer-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1rem;
}

.drawer-brand {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}

.brand-icon {
  width: 28px;
  height: 28px;
}

.brand-name {
  color: #fff;
  font-weight: 700;
  font-size: 1.1rem;
}

.close-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: #9ca3af;
  padding: 2px;
  width: 30px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  transition:
    background 0.2s,
    color 0.2s;
}

.close-btn:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
}

.close-btn svg {
  width: 20px;
  height: 20px;
}

.drawer-divider {
  height: 1px;
  background: rgba(255, 255, 255, 0.1);
  margin: 0 1rem;
}

.drawer-nav {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 0.75rem 0;
  overflow-y: auto;
}

.drawer-nav a {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.7rem 1rem;
  color: #e5e7eb;
  text-decoration: none;
  font-size: 0.95rem;
  font-weight: 500;
  transition: background 0.15s;
}

.drawer-nav a:hover:not(.disabled) {
  background: rgba(255, 255, 255, 0.06);
}

.drawer-nav a.active {
  background: #2563eb;
  color: #fff;
}

.drawer-nav a.disabled {
  opacity: 0.4;
  cursor: default;
}

.nav-icon {
  font-size: 1.15rem;
  width: 24px;
  text-align: center;
  flex-shrink: 0;
}

.drawer-footer {
  padding: 0.75rem 0;
}

.footer-btn {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.7rem 1rem;
  background: none;
  border: none;
  cursor: pointer;
  width: 100%;
  text-align: left;
  color: #e5e7eb;
  transition: background 0.15s;
}

.footer-btn:hover {
  background: rgba(255, 255, 255, 0.06);
}

.user-avatar {
  width: 36px;
  height: 36px;
  border-radius: 999px;
  background: #3b82f6;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.user-avatar svg {
  width: 18px;
  height: 18px;
  color: #fff;
}

.footer-text {
  display: flex;
  flex-direction: column;
}

.footer-title {
  font-weight: 600;
  font-size: 0.9rem;
}

.footer-subtitle {
  font-size: 0.78rem;
  color: #9ca3af;
}

/* Transition */
.drawer-enter-active,
.drawer-leave-active {
  transition: opacity 0.25s ease;
}

.drawer-enter-active .drawer,
.drawer-leave-active .drawer {
  transition: transform 0.25s ease;
}

.drawer-enter-from,
.drawer-leave-to {
  opacity: 0;
}

.drawer-enter-from .drawer,
.drawer-leave-to .drawer {
  transform: translateX(-100%);
}
</style>
