<script setup lang="ts">
import { ref, watch } from 'vue'
import { useClienteStore } from '@/stores/cliente'
import type { Cliente } from '@/types/cliente'
import ClienteModal from '@/components/ClienteModal.vue'

const clienteStore = useClienteStore()

const termoBusca = ref('')
const modalOpen = ref(false)
const editandoId = ref<number | null>(null)
const erroExcluir = ref<string | null>(null)

let debounceTimer: ReturnType<typeof setTimeout>
watch(termoBusca, (val) => {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    clienteStore.buscarClientes(val || undefined)
  }, 350)
})

function abrirNovo() {
  editandoId.value = null
  modalOpen.value = true
}

function abrirEdicao(cliente: Cliente) {
  editandoId.value = cliente.id
  modalOpen.value = true
}

function aoSalvar() {
  editandoId.value = null
  termoBusca.value = ''
  clienteStore.buscarClientes()
}

async function excluirCliente(cliente: Cliente) {
  const nome = cliente.nome_fantasia || cliente.razao_social
  if (!confirm(`Deseja realmente excluir "${nome}"?`)) return

  try {
    erroExcluir.value = null
    const { xano } = await import('@/services/xano')
    await xano.delete(`/api:-qqRIakp/cliente/${cliente.id}`)
    await clienteStore.buscarClientes(termoBusca.value || undefined)
  } catch (err: any) {
    const body = err?.getResponse?.()?.getBody?.()
    const mensagem = body?.message || err?.message || 'Erro ao tentar excluir o cliente.'
    const payload = body?.payload
    erroExcluir.value = payload ? `${mensagem} (${payload})` : mensagem
  }
}

function limparBusca() {
  termoBusca.value = ''
  clienteStore.buscarClientes()
}

</script>

<template>
  <main class="container">
    <div class="topo">
      <h2>Clientes</h2>
      <button class="btn-novo" @click="abrirNovo">+ Novo Cliente</button>
    </div>

    <div class="barra-busca">
      <svg
        class="search-icon"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
      >
        <circle cx="11" cy="11" r="8" />
        <line x1="21" y1="21" x2="16.65" y2="16.65" />
      </svg>
      <input v-model="termoBusca" placeholder="Buscar por nome, CPF/CNPJ ou e-mail..." />
      <button v-if="termoBusca" class="btn-limpar" title="Limpar busca" @click="limparBusca">
        ✕
      </button>
    </div>

    <p v-if="clienteStore.loading" class="status"><span class="spinner" /> Buscando clientes...</p>

    <div v-else-if="clienteStore.error" class="erro-bloco">
      <p class="erro">{{ clienteStore.error }}</p>
      <button class="btn-retry" @click="clienteStore.buscarClientes(termoBusca || undefined)">
        Tentar novamente
      </button>
    </div>

    <div v-else-if="clienteStore.clientes.length === 0" class="vazio-bloco">
      <p class="status">
        {{
          termoBusca ? 'Nenhum cliente encontrado para esta busca.' : 'Digite um termo na busca acima para encontrar clientes.'
        }}
      </p>
    </div>

    <table v-else class="tabela-clientes">
      <thead>
        <tr>
          <th>ID</th>
          <th>Nome Fantasia / Razão Social</th>
          <th>CPF/CNPJ</th>
          <th>Contato</th>
          <th>E-mail</th>
          <th class="th-acoes">Ações</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="cliente in clienteStore.clientes" :key="cliente.id">
          <td>
            <strong>#{{ cliente.id }}</strong>
          </td>
          <td>
            <div class="nome-fantasia">
              {{ cliente.nome_fantasia || 'Sem Nome Fantasia' }}
            </div>
            <small class="razao-social">{{ cliente.razao_social }}</small>
          </td>
          <td>{{ cliente.cnpj || '-' }}</td>
          <td>{{ cliente.contato || '-' }}</td>
          <td>{{ cliente['e-mail'] || '-' }}</td>
          <td class="td-acoes">
            <button class="btn-icon" title="Editar" @click="abrirEdicao(cliente)">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <path d="M17 3l4 4L7 21H3v-4L17 3z" />
              </svg>
            </button>
            <button
              class="btn-icon btn-icon-danger"
              title="Excluir"
              @click="excluirCliente(cliente)"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <polyline points="3 6 5 6 21 6" />
                <path
                  d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"
                />
              </svg>
            </button>
          </td>
        </tr>
      </tbody>
    </table>

    <p v-if="erroExcluir" class="erro-excluir" @click="erroExcluir = null">{{ erroExcluir }}</p>

    <ClienteModal v-model="modalOpen" :cliente-id="editandoId" @saved="aoSalvar" />
  </main>
</template>

<style scoped>
.container {
  padding: 1rem;
  max-width: 1100px;
  margin: 0 auto;
}

.topo {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.topo h2 {
  font-size: 1.35rem;
}

.btn-novo {
  padding: 0.5rem 1rem;
  background: #2563eb;
  color: #fff;
  border: none;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
}

.btn-novo:hover {
  background: #1d4ed8;
}

.barra-busca {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: var(--color-background-soft, #f9fafb);
  border: 1px solid var(--color-border, #d1d5db);
  border-radius: 8px;
  padding: 0.5rem 0.75rem;
  margin-bottom: 1rem;
}

.search-icon {
  width: 18px;
  height: 18px;
  color: #9ca3af;
  flex-shrink: 0;
}

.barra-busca input {
  flex: 1;
  border: none;
  background: transparent;
  font-size: 0.9rem;
  color: var(--color-text, #1f2937);
  outline: none;
}

.btn-limpar {
  background: none;
  border: none;
  cursor: pointer;
  color: #9ca3af;
  font-size: 1rem;
  line-height: 1;
  padding: 0.1rem 0.3rem;
  border-radius: 4px;
}

.btn-limpar:hover {
  color: #6b7280;
  background: #f3f4f6;
}

.status {
  color: #6b7280;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid #d1d5db;
  border-top-color: #2563eb;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.erro {
  color: #ff4d4d;
}

.erro-bloco {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.75rem;
}

.btn-retry {
  padding: 0.4rem 0.9rem;
  background: #fee2e2;
  color: #b91c1c;
  border: 1px solid #fecaca;
  border-radius: 6px;
  font-size: 0.85rem;
  cursor: pointer;
  transition: background 0.15s;
}

.btn-retry:hover {
  background: #fecaca;
}

.vazio-bloco {
  padding: 2rem 0;
}

.tabela-clientes {
  width: 100%;
  border-collapse: collapse;
  font-family: sans-serif;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border-radius: 8px;
  overflow: hidden;
}

.tabela-clientes th,
.tabela-clientes td {
  padding: 12px 15px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.tabela-clientes th {
  background-color: #42b883;
  color: white;
  font-weight: 600;
}

.th-acoes {
  width: 100px;
  text-align: center;
}

.td-acoes {
  text-align: center;
  white-space: nowrap;
}

.tabela-clientes tr:hover {
  background-color: #f5f5f5;
}

.nome-fantasia {
  font-weight: bold;
  color: #2c3e50;
}

.razao-social {
  color: #7f8c8d;
  font-size: 0.85rem;
}

.btn-icon {
  background: none;
  border: none;
  cursor: pointer;
  width: 32px;
  height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  color: #6b7280;
  transition:
    background 0.15s,
    color 0.15s;
}

.btn-icon:hover {
  background: #f3f4f6;
  color: #2563eb;
}

.btn-icon-danger:hover {
  color: #dc2626;
}

.btn-icon svg {
  width: 17px;
  height: 17px;
}

.erro-excluir {
  margin-top: 1rem;
  padding: 0.75rem 1rem;
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 6px;
  color: #b91c1c;
  font-size: 0.875rem;
  cursor: pointer;
}
</style>
