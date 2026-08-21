<script setup lang="ts">
import logoOrca from '@/assets/orca_system_1000x1000.png?inline'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
</script>

<template>
  <main class="home">
    <img :src="logoOrca" alt="Orca Systems" class="home-logo" />
    <h1>Bem-vindo, {{ authStore.user?.name_first || authStore.user?.name || 'Usuário' }}!</h1>
    <p class="subtitle">Selecione uma opção no menu lateral para começar.</p>
  </main>
</template>

<style scoped>
.home {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 50vh;
  text-align: center;
  padding: 2rem;
}

.home-logo {
  max-width: 260px;
  width: 100%;
  height: auto;
  object-fit: contain;
  margin-bottom: 1.25rem;
}

.home h1 {
  font-size: 1.6rem;
  margin-bottom: 0.5rem;
}

.subtitle {
  color: var(--text-secondary);
  font-size: 1.05rem;
}
</style>
