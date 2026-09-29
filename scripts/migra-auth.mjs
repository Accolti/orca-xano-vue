// Migração em lote: cria a identidade Supabase Auth (auth.users) para cada usuário
// da tabela `usuarios` que ainda não tem `auth_id`. NÃO envia e-mail (createUser com
// email_confirm), evitando o rate-limit de e-mails do Supabase. A senha é definida
// depois pelo próprio usuário via "Esqueci a senha" (resetPasswordForEmail).
//
// Idempotente: pula quem já tem auth_id; se o auth.user já existe (parcial anterior),
// apenas vincula.
//
// Uso:
//   SUPABASE_SERVICE_ROLE_KEY=<service_role> node scripts/migra-auth.mjs
//   DRY_RUN=1 SUPABASE_SERVICE_ROLE_KEY=... node scripts/migra-auth.mjs   # só lista
//
// Variáveis:
//   SUPABASE_URL              (default: https://dptyqjyueclscsryyrmv.supabase.co)
//   SUPABASE_SERVICE_ROLE_KEY (obrigatório)
//   DRY_RUN=1                 não grava nada, só lista quem seria migrado

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://dptyqjyueclscsryyrmv.supabase.co'
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY
const DRY_RUN = process.env.DRY_RUN === '1'

if (!SERVICE_ROLE) {
  console.error('Defina SUPABASE_SERVICE_ROLE_KEY')
  process.exit(1)
}

const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } })
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function main() {
  const { data: users, error } = await sb
    .from('usuarios')
    .select('id, name, email')
    .is('auth_id', null)
    .not('email', 'is', null)
    .order('id')

  if (error) {
    console.error('Erro ao listar usuarios:', error.message)
    process.exit(1)
  }

  const pendentes = (users || []).filter((u) => u.email && u.email.trim())
  console.log(`Usuários sem auth_id: ${pendentes.length}`)

  let criados = 0
  let linkados = 0

  for (const u of pendentes) {
    const email = u.email.trim()

    if (DRY_RUN) {
      console.log(`[DRY] migraria: ${email} (${u.name || u.id})`)
      continue
    }

    try {
      const { data, error: err } = await sb.auth.admin.createUser({
        email,
        email_confirm: true,
      })

      if (err) {
        if (/already been registered/i.test(err.message)) {
          const { data: list } = await sb.auth.admin.listUsers({ perPage: 1000 })
          const found = (list?.users || []).find(
            (x) => (x.email || '').toLowerCase() === email.toLowerCase(),
          )
          if (found) {
            const { error: upErr } = await sb
              .from('usuarios')
              .update({ auth_id: found.id })
              .eq('id', u.id)
            if (upErr) console.error(`falha ao linkar ${email}: ${upErr.message}`)
            else {
              console.log(`linkado ${email} -> ${found.id}`)
              linkados++
            }
          } else {
            console.error(`auth.user não encontrado para ${email}`)
          }
        } else {
          console.error(`erro ${email}: ${err.message}`)
        }
        continue
      }

      const authId = data?.user?.id
      if (authId) {
        const { error: upErr } = await sb
          .from('usuarios')
          .update({ auth_id: authId })
          .eq('id', u.id)
        if (upErr) console.error(`falha ao gravar auth_id de ${email}: ${upErr.message}`)
        else {
          console.log(`migrado ${email} -> ${authId}`)
          criados++
        }
      }

      await sleep(150)
    } catch (e) {
      console.error(`falha ${email}:`, e.message)
    }
  }

  console.log(`Concluído. Criados: ${criados} | vinculados: ${linkados}`)
}

main()
