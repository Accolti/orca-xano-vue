// Coleta automática de taxas de cartão (cron a cada ~15 dias).
//
// Fluxo: lista os provedores no Xano -> roda o adapter de cada um (que devolve as
// taxas por canal) -> envia de volta (substitui apenas as de origem "scrape").
//
// Uso local:
//   XANO_BASE_URL=... COLETA_SECRET=... node scripts/coleta-taxas/index.mjs
//   DRY_RUN=1 ... node scripts/coleta-taxas/index.mjs   (coleta e imprime, sem gravar)
import { listarProvedores, importarTaxas } from './lib/xano.mjs'
import { coletar } from './adapters/index.mjs'

const DRY_RUN =
  process.env.DRY_RUN === '1' ||
  process.env.DRY_RUN === 'true' ||
  process.argv.includes('--dry-run')

// Normaliza o retorno do adapter para [{ canal, taxas }].
function normalizarResultado(bruto, canalPadrao) {
  if (!bruto) return []
  if (Array.isArray(bruto)) {
    if (bruto.length && typeof bruto[0] === 'object' && 'canal' in bruto[0]) {
      return bruto.map((r) => ({ canal: r.canal || canalPadrao, taxas: r.taxas || [] }))
    }
    return [{ canal: canalPadrao, taxas: bruto }]
  }
  return Object.entries(bruto).map(([canal, taxas]) => ({
    canal: canal || canalPadrao,
    taxas: taxas || [],
  }))
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

  if (DRY_RUN) console.log('*** DRY_RUN ativo — nada será gravado no Xano ***')

  const provedores = await listarProvedores()
  console.log(`Provedores para coletar: ${provedores.length}`)

  let falhas = 0

  for (const provedor of provedores) {
    const canalPadrao = provedor?.canal_default || 'cartao_link'
    try {
      const bruto = await coletar(provedor)
      const porCanal = normalizarResultado(bruto, canalPadrao).filter(
        (r) => r.taxas && r.taxas.length,
      )

      if (!porCanal.length) {
        console.log(`- ${provedor.nome}: sem taxas/fonte — ignorado`)
        if (!DRY_RUN) await registrarFalha(provedor, canalPadrao, 'Sem fonte/taxas configuradas')
        continue
      }

      for (const { canal, taxas } of porCanal) {
        if (DRY_RUN) {
          console.log(`- ${provedor.nome} (${canal}) [DRY_RUN]: ${taxas.length} taxas`)
          for (const t of taxas) console.log(`    ${t.parcelas}x -> ${t.cc_taxa}%`)
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
      }
    } catch (err) {
      falhas += 1
      console.error(`- ${provedor.nome}: ERRO — ${err.message}`)
      if (!DRY_RUN) await registrarFalha(provedor, canalPadrao, err.message)
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
