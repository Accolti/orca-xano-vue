import { ref } from 'vue'
import { defineStore } from 'pinia'

export type Tema = 'light' | 'dark'

function temaInicial(): Tema {
  try {
    const salvo = localStorage.getItem('orca_theme')
    if (salvo === 'light' || salvo === 'dark') return salvo
  } catch {
    /* ignore */
  }
  return 'light'
}

// Estado de UI compartilhado (modal de perfil acessível do header e da sidebar + tema)
export const useUiStore = defineStore('ui', () => {
  const perfilOpen = ref(false)
  const tema = ref<Tema>(temaInicial())

  function aplicarTema(t: Tema) {
    tema.value = t
    document.documentElement.setAttribute('data-theme', t)
    try {
      localStorage.setItem('orca_theme', t)
    } catch {
      /* ignore */
    }
  }

  function alternarTema() {
    aplicarTema(tema.value === 'dark' ? 'light' : 'dark')
  }

  return {
    perfilOpen,
    tema,
    aplicarTema,
    alternarTema,
  }
})
