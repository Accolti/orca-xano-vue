// Coleta automática de taxas de cartão (cron a cada ~15 dias).
//
// Fluxo: lista os provedores no Xano -> roda o adapter de cada um -> envia as
// taxas coletadas de volta (substitui apenas as de origem "scrape").
//
// Uso local:  XANO_BASE_URL=... COLETA_SECRET=... node scripts/coleta-taxas/index.mjs
import { listarProvedores, importarTaxas } from './lib/xano.mjs'
import { coletar } from './adapters/index.mjs'

function canalDoProvedor(provedor) {
  return provedor?.canal_default || 'cartao_link'
}

async function registrarFalha(provedor, canal, mensagem) {
  try {
    await importarTaxas({
      provedor_id: provedor.id,
      canal,
      taxas: [],
      sucesso: false,
      mensagem: String(mensagem || 'erro').slice(0, 500),
    })
  } catch (err) {
    console.error(`  (falha ao registrar o erro no Xano: ${err.message})`)
  }
}

async function main() {
  if (!process.env.COLETA_SECRET) {
    console.error('COLETA_SECRET não definido. Abortando.')
    process.exit(1)
  }

  const provedores = await listarProvedores()
  console.log(`Provedores para coletar: ${provedores.length}`)

  let falhas = 0

  for (const provedor of provedores) {
    const canal = canalDoProvedor(provedor)
    try {
      const taxas = await coletar(provedor)
      if (!taxas || taxas.length === 0) {
        console.log(`- ${provedor.nome} (${canal}): sem taxas/fonte — ignorado`)
        await registrarFalha(provedor, canal, 'Sem fonte/taxas configuradas')
        continue
      }
      const r = await importarTaxas({
        provedor_id: provedor.id,
        canal,
        taxas,
        sucesso: true,
        mensagem: 'ok',
      })
      console.log(
        `- ${provedor.nome} (${canal}): ${r?.inseridas ?? '?'} inseridas, ${r?.removidas ?? '?'} removidas`,
      )
    } catch (err) {
      falhas += 1
      console.error(`- ${provedor.nome} (${canal}): ERRO — ${err.message}`)
      await registrarFalha(provedor, canal, err.message)
    }
  }

  if (falhas > 0) {
    console.error(`Concluído com ${falhas} falha(s).`)
    process.exitCode = 1
  } else {
    console.log('Concluído sem falhas.')
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
