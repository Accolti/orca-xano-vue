<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import SidebarNav from '@/components/SidebarNav.vue'
import GlobalHeader from '@/components/GlobalHeader.vue'
import TaxasAtualizadasBanner from '@/components/TaxasAtualizadasBanner.vue'

const authStore = useAuthStore()

const sidebarOpen = ref(false)
</script>

<template>
  <GlobalHeader v-if="authStore.isAuthenticated" @toggle-sidebar="sidebarOpen = true" />

  <TaxasAtualizadasBanner v-if="authStore.isAuthenticated" />

  <SidebarNav v-model="sidebarOpen" />

  <main class="app-content">
    <RouterView />
  </main>
</template>

<style scoped>
.app-content {
  padding-top: 0.5rem;
}
</style>
