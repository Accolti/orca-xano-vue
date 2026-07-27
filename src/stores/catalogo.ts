import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import type { Material, Linha, Tipo, Nivel, Borda } from '@/types/orcamento'

const CACHE_KEY = 'orca_catalogo_cache'

interface CatalogoCache {
  versao: number
  material: Material[]
  linha: Linha[]
  tipo: Tipo[]
  nivel: Nivel[]
  borda: Borda[]
}

export const useCatalogoStore = defineStore('catalogo', () => {
  const allMaterials = ref<Material[]>([])
  const allLinhas = ref<Linha[]>([])
  const allTipos = ref<Tipo[]>([])
  const allNiveis = ref<Nivel[]>([])
  const allBordas = ref<Borda[]>([])

  const loading = ref(false)
  const loaded = ref(false)

  const selectedMaterialId = ref<number | null>(null)

  const materiais = computed(() =>
    allMaterials.value
      .filter((m) => m.ativo)
      .sort((a, b) => a.Ordenacao - b.Ordenacao),
  )

  const linhasFiltradas = computed(() =>
    allLinhas.value.filter((l) => l.material_id === selectedMaterialId.value),
  )

  const tiposFiltrados = computed(() =>
    allTipos.value.filter((t) => t.material_id === selectedMaterialId.value),
  )

  const niveisFiltrados = computed(() =>
    allNiveis.value.filter((n) => n.material_id === selectedMaterialId.value),
  )

  const bordasFiltradas = computed(() =>
    allBordas.value.filter((b) => b.material_id === selectedMaterialId.value),
  )

  function lerCache(): CatalogoCache | null {
    try {
      const raw = localStorage.getItem(CACHE_KEY)
      if (!raw) return null
      return JSON.parse(raw) as CatalogoCache
    } catch {
      localStorage.removeItem(CACHE_KEY)
      return null
    }
  }

  function salvarCache(versao: number) {
    try {
      const cache: CatalogoCache = {
        versao,
        material: allMaterials.value,
        linha: allLinhas.value,
        tipo: allTipos.value,
        nivel: allNiveis.value,
        borda: allBordas.value,
      }
      localStorage.setItem(CACHE_KEY, JSON.stringify(cache))
    } catch {
      /* localStorage cheio ou desabilitado — ignorar */
    }
  }

  function resetarSessao() {
    loaded.value = false
    selectedMaterialId.value = null
  }

  async function fetchCatalogo() {
    if (loaded.value) return

    loading.value = true
    try {
      const configResp = await xano.get('/api:-qqRIakp/configuracoes')
      const configBody = configResp.getBody() as any
      const versao =
        (configBody?.['configuracoes-mae']?.[0]?.versao_materiais as number) ?? 0

      const cached = lerCache()
      if (cached && cached.versao === versao) {
        allMaterials.value = cached.material
        allLinhas.value = cached.linha
        allTipos.value = cached.tipo
        allNiveis.value = cached.nivel
        allBordas.value = cached.borda
        loaded.value = true
        return
      }

      const response = await xano.get('/api:-qqRIakp/produtos_para_selecao')
      const body = response.getBody() as any
      const data = body?.lista_para_selecao ?? body

      allMaterials.value = (data?.Material?.material ?? []) as Material[]
      allLinhas.value = (data?.Linha ?? []) as Linha[]
      allTipos.value = (data?.Tipo ?? []) as Tipo[]
      allNiveis.value = (data?.Nivel ?? []) as Nivel[]
      allBordas.value = (data?.Borda ?? []) as Borda[]

      loaded.value = true
      salvarCache(versao)
    } catch (err: any) {
      console.error('Erro ao carregar catálogo:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  return {
    allMaterials,
    allLinhas,
    allTipos,
    allNiveis,
    allBordas,
    loading,
    loaded,
    selectedMaterialId,
    materiais,
    linhasFiltradas,
    tiposFiltrados,
    niveisFiltrados,
    bordasFiltradas,
    fetchCatalogo,
    resetarSessao,
  }
})
