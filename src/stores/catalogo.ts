import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { xano } from '@/services/xano'
import type { Material, Linha, Tipo, Nivel, Borda, ProdutoCatalogo } from '@/types/orcamento'

const CACHE_MATERIAIS_KEY = 'orca_catalogo_materiais_cache'
const CACHE_PRODUTOS_KEY = 'orca_catalogo_produtos_cache'

interface CatalogoMateriaisCache {
  versao: number
  material: Material[]
  linha: Linha[]
  tipo: Tipo[]
  nivel: Nivel[]
  borda: Borda[]
}

interface CatalogoProdutosCache {
  versao: number
  produtos: ProdutoCatalogo[]
}

export const useCatalogoStore = defineStore('catalogo', () => {
  const allMaterials = ref<Material[]>([])
  const allLinhas = ref<Linha[]>([])
  const allTipos = ref<Tipo[]>([])
  const allNiveis = ref<Nivel[]>([])
  const allBordas = ref<Borda[]>([])
  const allProdutos = ref<ProdutoCatalogo[]>([])

  const loading = ref(false)
  const loaded = ref(false)

  const versaoMateriais = ref<number | null>(null)
  const versaoProdutos = ref<number | null>(null)

  const selectedMaterialId = ref<number | null>(null)

  const versaoLabel = computed(() => {
    const m = versaoMateriais.value ?? '?'
    const p = versaoProdutos.value ?? '?'
    return `M${m}P${p}`
  })

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

  function lerCache(key: string): { versao: number } | null {
    try {
      const raw = localStorage.getItem(key)
      if (!raw) return null
      return JSON.parse(raw) as { versao: number }
    } catch {
      localStorage.removeItem(key)
      return null
    }
  }

  function lerCacheMateriais(): CatalogoMateriaisCache | null {
    return lerCache(CACHE_MATERIAIS_KEY) as CatalogoMateriaisCache | null
  }

  function lerCacheProdutos(): CatalogoProdutosCache | null {
    return lerCache(CACHE_PRODUTOS_KEY) as CatalogoProdutosCache | null
  }

  function salvarCacheMateriais(versao: number) {
    try {
      const cache: CatalogoMateriaisCache = {
        versao,
        material: allMaterials.value,
        linha: allLinhas.value,
        tipo: allTipos.value,
        nivel: allNiveis.value,
        borda: allBordas.value,
      }
      localStorage.setItem(CACHE_MATERIAIS_KEY, JSON.stringify(cache))
    } catch {
      /* localStorage cheio ou desabilitado — ignorar */
    }
  }

  function salvarCacheProdutos(versao: number) {
    try {
      const cache: CatalogoProdutosCache = {
        versao,
        produtos: allProdutos.value,
      }
      localStorage.setItem(CACHE_PRODUTOS_KEY, JSON.stringify(cache))
    } catch {
      /* localStorage cheio ou desabilitado — ignorar */
    }
  }

  function resetarSessao() {
    loaded.value = false
    selectedMaterialId.value = null
  }

  async function carregarConfiguracoes() {
    const configResp = await xano.get('/api:-qqRIakp/configuracoes')
    const configBody = configResp.getBody() as any
    const cfg = configBody?.['configuracoes-mae']?.[0] ?? {}
    versaoMateriais.value = (cfg.versao_materiais as number) ?? null
    versaoProdutos.value = (cfg.versao_produtos as number) ?? null
  }

  async function fetchCatalogo() {
    if (loaded.value) return

    loading.value = true
    try {
      await carregarConfiguracoes()
      const versaoM = versaoMateriais.value ?? 0
      const versaoP = versaoProdutos.value ?? 0

      const cachedM = lerCacheMateriais()
      if (cachedM && cachedM.versao === versaoM) {
        allMaterials.value = cachedM.material
        allLinhas.value = cachedM.linha
        allTipos.value = cachedM.tipo
        allNiveis.value = cachedM.nivel
        allBordas.value = cachedM.borda
      } else {
        const response = await xano.get('/api:-qqRIakp/produtos_para_selecao')
        const body = response.getBody() as any
        const data = body?.lista_para_selecao ?? body

        const materialRaw = data?.Material
        const materialList = Array.isArray(materialRaw)
          ? materialRaw
          : (materialRaw?.material ?? [])
        allMaterials.value = materialList as Material[]
        allLinhas.value = (data?.Linha ?? []) as Linha[]
        allTipos.value = (data?.Tipo ?? []) as Tipo[]
        allNiveis.value = (data?.Nivel ?? []) as Nivel[]
        allBordas.value = (data?.Borda ?? []) as Borda[]

        salvarCacheMateriais(versaoM)
      }

      const cachedP = lerCacheProdutos()
      if (cachedP && cachedP.versao === versaoP) {
        allProdutos.value = cachedP.produtos ?? []
      } else {
        const produtosResp = await xano.get('/api:-qqRIakp/produtos_all', {
          produto_id: 0,
          material_id: 0,
          linha_id: 0,
          tipo_id: 0,
          nivel_id: 0,
          detalhe_id: 0,
        })
        allProdutos.value = (produtosResp.getBody() as ProdutoCatalogo[]) ?? []

        salvarCacheProdutos(versaoP)
      }

      loaded.value = true
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
    allProdutos,
    loading,
    loaded,
    versaoMateriais,
    versaoProdutos,
    versaoLabel,
    selectedMaterialId,
    materiais,
    linhasFiltradas,
    tiposFiltrados,
    niveisFiltrados,
    bordasFiltradas,
    carregarConfiguracoes,
    fetchCatalogo,
    resetarSessao,
  }
})
