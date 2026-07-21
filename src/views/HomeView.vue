<template>
  <main class="home">
    <h1>Bem-vindo ao Orca Systems</h1>
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

.home h1 {
  font-size: 1.75rem;
  margin-bottom: 0.5rem;
}

.subtitle {
  color: var(--color-text);
  opacity: 0.65;
  font-size: 1.05rem;
}
</style>
