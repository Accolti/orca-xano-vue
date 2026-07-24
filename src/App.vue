<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import SidebarNav from '@/components/SidebarNav.vue'
import GlobalHeader from '@/components/GlobalHeader.vue'

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
  <GlobalHeader v-if="authStore.isAuthenticated" @toggle-sidebar="sidebarOpen = true" />

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
