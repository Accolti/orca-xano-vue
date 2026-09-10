<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { xano } from '@/services/xano'

const props = withDefaults(defineProps<{ apenasLimites?: boolean }>(), { apenasLimites: false })

const authStore = useAuthStore()
const router = useRouter()

const carregouFaixas = ref(false)
const faixasVazias = ref(false)
const membrosSemLimite = ref(false)
const temEquipe = ref(false)

// admin_geral é administrador do SISTEMA (não é empresa) — não mostra o banner.
const ehAdminEmpresa = computed(() => authStore.isAdmin && !authStore.isAdminGeral)

// Mostra para quem configura (empresa e Master) e também para o vendedor
// (informativo: sem limites de desconto ele não consegue aplicar desconto).
const elegivel = computed(
  () =>
    !!authStore.user &&
    (ehAdminEmpresa.value || authStore.isVendedorMaster || authStore.isVendedor),
)

const podeConfigurar = computed(() => ehAdminEmpresa.value || authStore.isVendedorMaster)

// Faixas só fazem sentido quando o usuário tem equipe (vendedores atrelados).
const semFaixas = computed(
  () =>
    !props.apenasLimites &&
    podeConfigurar.value &&
    temEquipe.value &&
    carregouFaixas.value &&
    faixasVazias.value,
)

function faltaLimite(u: { desconto_livre_perc?: number | null; desconto_max_perc?: number | null }) {
  const livre = Number(u?.desconto_livre_perc)
  const max = Number(u?.desconto_max_perc)
  const livreOk = u?.desconto_livre_perc != null && !Number.isNaN(livre) && livre > 0
  const maxOk = u?.desconto_max_perc != null && !Number.isNaN(max) && max > 0
  return !livreOk || !maxOk
}

const euSemLimite = computed(() => faltaLimite(authStore.user ?? {}))

// Empresa (admin): os limites que importam são os dos vendedores da equipe.
// Master: os dele + os da equipe dele.
const semLimites = computed(() => {
  if (!elegivel.value) return false
  if (authStore.isVendedor) return euSemLimite.value
  if (authStore.isVendedorMaster) return euSemLimite.value || membrosSemLimite.value
  return membrosSemLimite.value
})

const visivel = computed(() => semFaixas.value || semLimites.value)

async function carregar() {
  if (!elegivel.value) return
  const [faixas, equipe] = await Promise.allSettled([
    xano.get('/api:-qqRIakp/faixas_comissao'),
    xano.get('/api:-qqRIakp/equipe'),
  ])

  if (faixas.status === 'fulfilled') {
    const d = faixas.value.getBody() ?? {}
    faixasVazias.value = !((d?.faixas as unknown[])?.length)
  }
  carregouFaixas.value = true

  if (equipe.status === 'fulfilled') {
    const lista = ((equipe.value.getBody() as any[]) ?? []).filter((m) => m?.ativo !== false)
    temEquipe.value = lista.length > 0
    membrosSemLimite.value = lista.some((m) => faltaLimite(m))
  }
}

function irFaixas() {
  router.push('/faixas')
}

function irEquipe() {
  router.push('/equipe')
}

onMounted(carregar)
</script>

<template>
  <div v-if="visivel" class="ccb" role="alert">
    <div class="ccb-texto">
      <span v-if="semFaixas" class="ccb-linha">
        <strong>Comissões não configuradas</strong> — cadastre as faixas de comissão para o
        Master receber o repasse.
        <template v-if="authStore.isAdmin"> Sem isso a comissão cai no cálculo padrão.</template>
        <template v-else> Solicite ao administrador da sua empresa.</template>
      </span>
      <span v-if="semLimites" class="ccb-linha">
        <strong>Limites de desconto não definidos</strong> — sem cadastro, nenhum desconto pode
        ser aplicado.
        <template v-if="authStore.isAdmin">
          Defina o desconto livre/máximo de cada vendedor da equipe.
        </template>
        <template v-else> Solicite ao administrador da sua empresa.</template>
      </span>
    </div>
    <div v-if="authStore.isAdmin" class="ccb-acoes">
      <button v-if="semFaixas" type="button" class="btn btn-sm btn-accent" @click="irFaixas">
        Configurar comissões
      </button>
      <button v-if="semLimites" type="button" class="btn btn-sm btn-outline" @click="irEquipe">
        Definir limites da equipe
      </button>
    </div>
  </div>
</template>

<style scoped>
.ccb {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem 1rem;
  padding: 0.65rem 0.9rem;
  border-radius: 10px;
  border: 1px solid var(--warning, #f59e0b);
  background: var(--warning-soft, #fffbeb);
  margin-bottom: 1rem;
}

.ccb-texto {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  min-width: 0;
}

.ccb-linha {
  font-size: 0.85rem;
  color: var(--text-primary);
}

.ccb-acoes {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}
</style>
