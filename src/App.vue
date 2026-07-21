<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import SidebarNav from '@/components/SidebarNav.vue'

const authStore = useAuthStore()
const router = useRouter()

const sidebarOpen = ref(false)

onMounted(async () => {
  if (authStore.token) {
    try {
      await authStore.fetchMe()
    } catch {
      router.push('/login')
    }
  }
})
</script>

<template>
  <button
    v-if="authStore.isAuthenticated"
    class="menu-toggle"
    aria-label="Abrir menu"
    @click="sidebarOpen = true"
  >
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

  <SidebarNav v-model="sidebarOpen" />

  <RouterView />
</template>

<style scoped>
.menu-toggle {
  position: fixed;
  top: 1rem;
  left: 1rem;
  z-index: 100;
  background: #2d3036;
  border: none;
  border-radius: 8px;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: #e5e7eb;
  transition: background 0.2s;
}

.menu-toggle:hover {
  background: #3b4046;
}

.menu-toggle svg {
  width: 22px;
  height: 22px;
}
</style>
