<script setup lang="ts">
interface DevLink {
  label: string
  path: string
  icon: string
}

const links: DevLink[] = [
  { label: 'Produtos', path: '/dev/produtos', icon: '\u{1F4E6}' },
  { label: 'Materiais', path: '/dev/materiais', icon: '\u{1F333}' },
  { label: 'Fatores', path: '/dev/fatores', icon: '\u{2702}\u{FE0F}' },
  { label: 'Configurações', path: '/dev/configuracoes', icon: '\u{2699}\u{FE0F}' },
]
</script>

<template>
  <nav class="dev-nav">
    <RouterLink
      v-for="l in links"
      :key="l.path"
      :to="l.path"
      class="dev-nav-item"
      active-class="dev-nav-item-active"
    >
      <span class="dev-nav-icon">{{ l.icon }}</span>
      <span>{{ l.label }}</span>
    </RouterLink>
  </nav>
</template>

<style scoped>
.dev-nav {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-bottom: 1rem;
  padding: 0.5rem;
  background: var(--card-bg, #fff);
  border: 1px solid var(--border-light, #e5e7eb);
  border-radius: 10px;
}

.dev-nav-item {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.9rem;
  border-radius: 8px;
  text-decoration: none;
  color: var(--text-secondary, #4b5563);
  font-size: 0.85rem;
  font-weight: 600;
  border: 1px solid transparent;
  transition:
    background 0.15s,
    color 0.15s,
    border-color 0.15s;
}

.dev-nav-item:hover {
  background: var(--bg-subtle, #f3f4f6);
  color: var(--text-primary, #1f2937);
}

.dev-nav-item-active {
  background: var(--primary, #3366cc);
  color: #fff;
  border-color: var(--primary, #3366cc);
}

.dev-nav-icon {
  font-size: 1rem;
  line-height: 1;
}
</style>
