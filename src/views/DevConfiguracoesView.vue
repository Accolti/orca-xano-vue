<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { xano } from '@/services/xano'
import { useCatalogoStore } from '@/stores/catalogo'
import DevNav from '@/components/DevNav.vue'

interface ConfiguracaoDev {
  id: number
  versao_materiais?: number | null
  versao_produtos?: number | null
  versao_taxas_banco?: number | null
  created_at?: string
}

const catalogo = useCatalogoStore()

const configuracoes = ref<ConfiguracaoDev[]>([])
const loading = ref(false)
const salvando = ref<{ id: number; campo: string } | null>(null)
const erroMsg = ref('')
const sucessoMsg = ref('')

async function carregar() {
  loading.value = true
  erroMsg.value = ''
  try {
    const resp = await xano.get('/api:-qqRIakp/configuracoes_dev')
    configuracoes.value = (resp.getBody() as ConfiguracaoDev[]) ?? []
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao listar configurações'
  } finally {
    loading.value = false
  }
}

async function incrementar(
  cfg: ConfiguracaoDev,
  campo: 'versao_materiais' | 'versao_produtos' | 'versao_taxas_banco',
  delta: number,
) {
  if (!cfg.id) return
  salvando.value = { id: cfg.id, campo }
  erroMsg.value = ''
  sucessoMsg.value = ''
  try {
    await xano.post('/api:-qqRIakp/configuracoes_versao', {
      configuracoes_id: cfg.id,
      campo,
      delta,
    })
    // Invalida o cache correspondente para o app rebaixar na próxima carga
    const cacheKey =
      campo === 'versao_materiais'
        ? 'orca_catalogo_materiais_cache'
        : campo === 'versao_produtos'
          ? 'orca_catalogo_produtos_cache'
          : 'orca_taxas_banco_cache'
    localStorage.removeItem(cacheKey)
    await catalogo.carregarConfiguracoes()
    await carregar()
    sucessoMsg.value =
      campo === 'versao_materiais'
        ? `Versão de materiais atualizada (+${delta}).`
        : campo === 'versao_produtos'
          ? `Versão de produtos atualizada (+${delta}).`
          : `Versão de taxas bancárias atualizada (+${delta}).`
  } catch (err: any) {
    erroMsg.value = err?.getResponse?.()?.getBody?.()?.message || 'Erro ao atualizar versão'
  } finally {
    salvando.value = null
  }
}

onMounted(async () => {
  await carregar()
  await catalogo.carregarConfiguracoes()
})
</script>

<template>
  <div class="dev-page">
    <DevNav />
    <section class="card header-card">
      <div class="header-top">
        <h2>Dev — Configurações</h2>
        <div class="header-actions">
          <button class="btn btn-outline btn-sm" @click="carregar">Recarregar</button>
        </div>
      </div>
      <p class="field-hint">
        As versões controlam o cache do catálogo no navegador. Ao alterar materiais/produtos
        (tabelas Material, Produto, Variacao, etc.) ou as taxas de banco (Taxa_Banco), acrescente a
        versão correspondente para forçar o app a rebaixar os dados na próxima carga. Valor atual do
        app:
        <strong
          >M{{ catalogo.versaoMateriais ?? '?' }}P{{ catalogo.versaoProdutos ?? '?' }}T{{
            catalogo.versaoTaxasBanco ?? '?'
          }}</strong
        >.
      </p>
    </section>

    <p v-if="erroMsg" class="error-msg">{{ erroMsg }}</p>
    <p v-if="sucessoMsg" class="success-msg">{{ sucessoMsg }}</p>

    <section v-if="loading" class="card loading-card"><p>Carregando...</p></section>

    <section v-else-if="configuracoes.length" class="card tabela-card">
      <div class="tabela-orcamentos-wrap">
        <table class="tabela-orcamentos">
          <thead>
            <tr>
              <th>ID</th>
              <th>Versão Materiais</th>
              <th>Versão Produtos</th>
              <th>Versão Taxas Bancárias</th>
              <th>Criado em</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="cfg in configuracoes" :key="cfg.id">
              <td class="cell-cod">{{ cfg.id }}</td>
              <td>
                <div class="versao-cell">
                  <span class="versao-valor">{{ cfg.versao_materiais ?? 0 }}</span>
                  <div class="versao-botoes">
                    <button
                      class="btn btn-outline btn-xs"
                      :disabled="salvando !== null"
                      @click="incrementar(cfg, 'versao_materiais', 1)"
                    >
                      +1
                    </button>
                    <button
                      class="btn btn-outline btn-xs"
                      :disabled="salvando !== null"
                      @click="incrementar(cfg, 'versao_materiais', 5)"
                    >
                      +5
                    </button>
                  </div>
                </div>
              </td>
              <td>
                <div class="versao-cell">
                  <span class="versao-valor">{{ cfg.versao_produtos ?? 0 }}</span>
                  <div class="versao-botoes">
                    <button
                      class="btn btn-outline btn-xs"
                      :disabled="salvando !== null"
                      @click="incrementar(cfg, 'versao_produtos', 1)"
                    >
                      +1
                    </button>
                    <button
                      class="btn btn-outline btn-xs"
                      :disabled="salvando !== null"
                      @click="incrementar(cfg, 'versao_produtos', 5)"
                    >
                      +5
                    </button>
                  </div>
                </div>
              </td>
              <td>
                <div class="versao-cell">
                  <span class="versao-valor">{{ cfg.versao_taxas_banco ?? 0 }}</span>
                  <div class="versao-botoes">
                    <button
                      class="btn btn-outline btn-xs"
                      :disabled="salvando !== null"
                      @click="incrementar(cfg, 'versao_taxas_banco', 1)"
                    >
                      +1
                    </button>
                    <button
                      class="btn btn-outline btn-xs"
                      :disabled="salvando !== null"
                      @click="incrementar(cfg, 'versao_taxas_banco', 5)"
                    >
                      +5
                    </button>
                  </div>
                </div>
              </td>
              <td>{{ cfg.created_at ? new Date(cfg.created_at).toLocaleString() : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section v-else class="card loading-card">
      <p>Nenhuma configuração encontrada. Crie um registro em Configuracoes no dashboard.</p>
    </section>
  </div>
</template>

<style scoped>
.dev-page {
  max-width: 1100px;
  margin: 0 auto;
  padding: 0 1rem;
}
.header-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: wrap;
}
.header-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}
.field-hint {
  font-size: 0.85rem;
  color: var(--text-secondary);
  margin-top: 0.75rem;
}
.error-msg {
  color: var(--danger, #dc2626);
  margin: 0.75rem 0;
}
.success-msg {
  color: var(--success, #16a34a);
  margin: 0.75rem 0;
}
.loading-card {
  padding: 1.5rem;
  text-align: center;
  color: var(--text-secondary);
}
.tabela-card {
  margin-top: 1rem;
  overflow-x: auto;
}
.versao-cell {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}
.versao-valor {
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  min-width: 24px;
}
.versao-botoes {
  display: flex;
  gap: 0.35rem;
}
</style>
