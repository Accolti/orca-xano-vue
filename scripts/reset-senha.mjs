// Define (ou redefine) a senha de um usuário do Supabase Auth por e-mail.
// A senha fica em auth.users (não na tabela `usuarios`).
//
// Uso:
//   SUPABASE_SERVICE_ROLE_KEY=<service_role> node scripts/reset-senha.mjs <email> <nova_senha>
//
// Variáveis:
//   SUPABASE_URL              (default: https://dptyqjyueclscsryyrmv.supabase.co)
//   SUPABASE_SERVICE_ROLE_KEY (obrigatório)

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://dptyqjyueclscsryyrmv.supabase.co'
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY

const email = process.argv[2]
const senha = process.argv[3]

if (!SERVICE_ROLE) {
  console.error('Defina SUPABASE_SERVICE_ROLE_KEY')
  process.exit(1)
}
if (!email || !senha) {
  console.error('Uso: node scripts/reset-senha.mjs <email> <nova_senha>')
  process.exit(1)
}

const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } })

const { data: list, error } = await sb.auth.admin.listUsers({ perPage: 1000 })
if (error) {
  console.error('Erro ao listar usuários:', error.message)
  process.exit(1)
}

const alvo = email.toLowerCase().trim()
const user = (list?.users || []).find((u) => (u.email || '').toLowerCase() === alvo)

if (!user) {
  console.error(`Usuário não encontrado no auth.users: ${email}`)
  process.exit(1)
}

const r = await sb.auth.admin.updateUserById(user.id, { password: senha })
if (r.error) {
  console.error(`Falha ao definir senha de ${user.email}: ${r.error.message}`)
  process.exit(1)
}

console.log(`Senha definida para ${user.email} (auth_id ${user.id})`)
