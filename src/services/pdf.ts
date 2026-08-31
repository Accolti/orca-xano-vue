import pdfMake from 'pdfmake/build/pdfmake'
import * as pdfFonts from 'pdfmake/build/vfs_fonts'
import type { TDocumentDefinitions } from 'pdfmake/interfaces'
import type { User } from '@/stores/auth'
import type { Cliente } from '@/types/cliente'
import { calcularCondicoesPagamento as calcularCondicoesUnificado } from '@/utils/condicoesPagamento'
import { montarLinhasGarantia } from '@/utils/garantia'
import { useCatalogoStore } from '@/stores/catalogo'
import logoOrca from '@/assets/logo.png?inline'
;(pdfMake as any).vfs = (pdfFonts as any).vfs

interface PdfOrcamentoInput {
  header: any
  itens: any[]
  cliente?: Cliente | null
  user?: User | null
  faturar?: boolean
  condicoesPagamento?: string
}

export const PRAZOS_ORCAMENTO = {
  entrega: '10 a 15 dias úteis',
  frete: 'Gratuito para Sorocaba e região',
}

// Garantia vinda da tabela Material (meses), agrupada por material e deduplicada.
// Vazia quando o catálogo não está carregado ou nenhum item tem material com garantia.
function linhasGarantia(itens: any[]): string[] {
  const catalogo = useCatalogoStore()
  return montarLinhasGarantia(itens, catalogo.allProdutos, catalogo.allMaterials)
}

export function formatarMoeda(valor: number): string {
  return `R$ ${(Number(valor) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

// Composição do produto composto PLAYKAP (a partir do detalhes_calculo gravado no item).
// Ex.: "578 placas + 102 rampas (51 M / 51 F) + 4 cantoneiras"
export function composicaoPlaykap(item: any): string {
  const p = item?.detalhes_calculo?.playkap
  if (!p) return ''
  const partes: string[] = []
  if (p.placas) partes.push(`${p.placas} placas`)
  if (p.rampas_total)
    partes.push(`${p.rampas_total} rampas (${p.rampas_macho} M / ${p.rampas_femea} F)`)
  if (p.cantoneiras) partes.push(`${p.cantoneiras} cantoneiras`)
  return partes.join(' + ')
}

// Composição de venda por ML (detalhes_calculo.ml) — rolos/metros/orientação.
// Ex.: "3 rolo(s) — 2,5 m fracionado — <orientação>"; com rolos, o total entra na frente:
// "32,5 m — 3 rolo(s) — 2,5 m fracionado — <orientação>". Sem rolos, só o fracionado.
export function composicaoML(item: any): string {
  const m = item?.detalhes_calculo?.ml
  if (!m) return ''
  const partes: string[] = []
  const total = Number(m.totalMetrosLineares) || 0
  const rolos = Number(m.rolosFechados) || 0
  const frac = Number(m.metrosFracionados) || 0
  if (rolos > 0 && total > 0) partes.push(`${total} m`)
  if (rolos > 0) partes.push(`${rolos} rolo(s)`)
  if (frac > 0) partes.push(`${frac} m fracionado`)
  if (m.orientacaoIdeal) partes.push(m.orientacaoIdeal)
  return partes.join(' — ')
}

// Composição combinada: PLAYKAP ou ML (a que existir no detalhes_calculo do item)
export function composicaoItem(item: any): string {
  return composicaoPlaykap(item) || composicaoML(item)
}

export function formatarDataHora(ts: number | string | undefined): string {
  if (!ts) return ''
  const d = new Date(ts)
  if (isNaN(d.getTime())) return ''
  const data = d.toLocaleDateString('pt-BR')
  const hora = d.toLocaleTimeString('pt-BR', { hour12: false })
  return `${data} às ${hora}`
}

// Data/hora atual (geração do PDF), pt-BR
function formatarDataHoraAgora(): string {
  const d = new Date()
  const data = d.toLocaleDateString('pt-BR')
  const hora = d.toLocaleTimeString('pt-BR', { hour12: false })
  return `${data} às ${hora}`
}

// Data de validade da proposta (pt-BR, dd/mm/aaaa) — header.validade ou hoje + DiasVencimentoOrcamento
function formatarValidade(header: any, user?: User | null): string {
  const val = header?.validade
  if (val) {
    const d = new Date(val)
    if (!isNaN(d.getTime())) return d.toLocaleDateString('pt-BR')
  }
  const dias = Number(user?.DiasVencimentoOrcamento) || 10
  const v = new Date(Date.now() + dias * 86400000)
  return v.toLocaleDateString('pt-BR')
}

function pad2(n: number): string {
  return String(n).padStart(2, '0')
}

// Data/hora atual no formato do nome de arquivo: 10-08-2026 14-08-48
function nomeDataHora(): string {
  const d = new Date()
  return `${pad2(d.getDate())}-${pad2(d.getMonth() + 1)}-${d.getFullYear()} ${pad2(d.getHours())}-${pad2(d.getMinutes())}-${pad2(d.getSeconds())}`
}

// Remove acentos, espaços e caracteres inválidos para nome de arquivo
function sanitizarNome(str: string): string {
  return (str || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '')
}

// Nome do arquivo: ORC123_Contato-NomeFantasia_10-08-2026 14-08-48_.pdf
export function nomeArquivoOrcamento(header: any, cliente?: Cliente | null): string {
  const codOrca = header?.cod_orca || 'ORC'
  const contato = sanitizarNome(cliente?.contato || '')
  const nomeCliente = sanitizarNome(
    cliente?.nome_fantasia || cliente?.razao_social || cliente?.nome_cpf || '',
  )
  const quem = [contato, nomeCliente].filter(Boolean).join('-')
  const dataHora = nomeDataHora()
  const base = [codOrca, quem, dataHora].filter(Boolean).join('_')
  return `${base}_.pdf`
}

// Condições de pagamento (Pix 2x + Boleto parcelado + Cartão com gross-up).
// Delega ao módulo unificado; mantém a assinatura antiga retornando o texto final.
export function calcularCondicoesPagamento(
  valorVenda: number,
  valorCusto: number,
  faturar = false,
  tabelaTaxasCartao?: any[],
  repassarTaxasCartao = true,
  descontoPixPercentual = 0,
): string {
  return calcularCondicoesUnificado({
    valorVenda,
    valorCusto,
    faturar,
    tabelaTaxasCartao: tabelaTaxasCartao as any,
    repassarTaxasCartao,
    descontoPixPercentual,
  }).texto
}

// Condições salvas no orçamento ou calculadas (fallback).
// Precedência: override (editado) → salvo na ORCA → calculado. Nunca sobrescreve conteúdo salvo.
function obterCondicoes(header: any, faturar = false, override?: string): string {
  if (override && String(override).trim()) return String(override).trim()
  const salvo = header?.condicoes_pagamento
  if (salvo && String(salvo).trim()) return String(salvo).trim()
  const totalGeral = Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0
  return calcularCondicoesPagamento(totalGeral, Number(header?.cst_tot) || 0, faturar)
}

// Linha de frete: valor ou "Grátis" (sem a sigla B2C)
function linhaFrete(freteB2C: number): string {
  return Number(freteB2C) > 0 ? `Frete: ${formatarMoeda(freteB2C)}` : 'Frete: Grátis'
}

// Preço cheio (bruto) unitário do item, antes do desconto.
// Fonte pronta: item.vlr_vnd_unit_bruto (salvo pelo backend no recalcular). Fallback para
// registros antigos sem o campo: custo_entrada × (1 + markup_alvo/100).
function brutoUnitarioItem(item: any, header: any): number {
  const brutoSalvo = Number(item.vlr_vnd_unit_bruto)
  if (brutoSalvo > 0) return brutoSalvo
  const custoEntrada = Number(item.vlr_cst_entrada_unit) || Number(item.vlr_cst_unit) || 0
  const markupAlvo = Number(header?.markup_alvo) || Number(header?.margem) || 0
  return custoEntrada * (1 + markupAlvo / 100)
}

// Subtotal = Σ do preço cheio (bruto) × qtd por item
function subtotalItensBruto(itens: any[], header: any): number {
  return (itens || []).reduce((acc, item) => {
    const qtd = Number(item.qtd) || 1
    return acc + brutoUnitarioItem(item, header) * qtd
  }, 0)
}

// Total geral derivado: subtotal (bruto) − desconto + frete + mão de obra
function totalGeralDerivado(itens: any[], header: any): number {
  const subtotal = subtotalItensBruto(itens, header)
  const desconto = Number(header?.desconto) || 0
  const freteB2C = Number(header?.frtB2C) || 0
  const maoDeObra = Number(header?.mao_de_obra) || 0
  return subtotal - desconto + freteB2C + maoDeObra
}

// Condição de pagamento com o método em negrito: "• *Pix* (2x de R$ ...): ..."
function formatarCondicaoWhatsApp(linha: string): string {
  const l = linha.trim()
  const m = l.match(/^(Pix|Boleto|Faturamos)\b/i)
  if (m && m[1]) {
    return `• *${m[1]}*${l.slice(m[1].length)}`
  }
  return `• ${l}`
}

// Converte um valor possivelmente com $/moeda/sujeira para número limpo (preserva decimais)
function valorNumericoLimpo(valor: any): number {
  if (valor == null) return 0
  let str = String(valor).replace(/[R$]/gi, '').trim()
  if (str.includes(',') && !str.includes('.')) {
    str = str.replace(',', '.')
  }
  const n = Number(str)
  return isNaN(n) ? 0 : n
}

// Medidas do item: "(2,50 x 1,20 m)" ou "Tamanho Padrão" quando zeradas (sem $)
function formatarMedidas(item: any): string {
  const larg = valorNumericoLimpo(item.larg)
  const comp = valorNumericoLimpo(item.comp)
  if (larg <= 0 && comp <= 0) return 'Tamanho Padrão'
  const fmt = (v: number) =>
    v.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  return `(${fmt(larg)} x ${fmt(comp)} m)`
}

// Observações organizadas em tópicos numerados
function organizarObservacoes(texto: string): string[] {
  return (texto || '')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .map((l, i) => `${i + 1}. ${l}`)
}

export function obterWhatsapp(user?: User | null): string {
  const telefones = (user as any)?._telefones ?? []
  const whats = telefones.find(
    (t: any) => String(t.tipo_telefone || '').toLowerCase() === 'whatsapp',
  )
  return whats?.telefone || ''
}

// Telefone do cliente com tipo_telefone_id == 1 (Celular/Comercial/WhatsApp)
export function obterWhatsappCliente(cliente?: Cliente | null): string {
  const telefones = cliente?._telefone_cliente_of_cliente ?? []
  const tel = telefones.find((t) => Number(t.tipo_telefone_id) === 1)
  return tel?.telefone || ''
}

// Monta o texto da mensagem de WhatsApp (sem o link)
export function montarTextoWhatsApp({
  header,
  itens,
  cliente,
  faturar,
  condicoesPagamento,
}: PdfOrcamentoInput): string {
  const codOrca = header?.cod_orca || 'ORC'
  const contato = cliente?.contato || cliente?.nome_fantasia || cliente?.razao_social || ''

  const subtotal = subtotalItensBruto(itens, header)
  const desconto = Number(header?.desconto) || 0
  const maoDeObra = Number(header?.mao_de_obra) || 0
  const freteB2C = Number(header?.frtB2C) || 0
  const totalGeral = totalGeralDerivado(itens, header)
  const observacao = header?.observacao || ''

  const condicoes = obterCondicoes(header, faturar, condicoesPagamento)

  const linhasItens = (itens || []).map((item, i) => {
    const temDescricaoCapital = Boolean((item.Descricao || '').trim())
    const descricao = (item.Descricao || item.descricao || '').trim()
    const comp = composicaoItem(item)
    const nome = comp ? `${descricao} — ${comp}` : descricao
    const medidas = formatarMedidas(item)
    const qtd = Number(item.qtd) || 1
    const unit = brutoUnitarioItem(item, header)
    // Observação do vendedor (ex.: "porta da frete") entra como linha extra,
    // igual ao PDF. Só quando a Descricao concatenada existe (senão é o fallback).
    const obsItem = temDescricaoCapital ? (item.descricao || '').trim() : ''
    const obsLinha = obsItem ? `\n${obsItem}` : ''
    return `📌 *Item ${i + 1}: ${nome}* ${medidas}${obsLinha}\n• Qtd: ${qtd} | Unitário: ${formatarMoeda(unit)} | Total: ${formatarMoeda(unit * qtd)}`
  })

  const linhas: string[] = []
  linhas.push(`📋 Olá ${contato}! Segue o orçamento ${codOrca}:`)
  linhas.push('')
  linhas.push('*Itens e Valores*')
  linhas.push('')
  linhasItens.forEach((linha) => {
    linhas.push(linha)
    linhas.push('')
  })
  linhas.push('💳 *Totais*')
  linhas.push('')
  linhas.push(`Subtotal: ${formatarMoeda(subtotal)}`)
  if (desconto) linhas.push(`Desconto: ${formatarMoeda(desconto)}`)
  linhas.push(linhaFrete(freteB2C))
  if (maoDeObra) linhas.push(`Mão de Obra: ${formatarMoeda(maoDeObra)}`)
  linhas.push(`*Total Geral: ${formatarMoeda(totalGeral)}*`)
  linhas.push('')
  linhas.push('📝 *Condições de Pagamento*')
  linhas.push(...condicoes.split('\n').filter(Boolean).map(formatarCondicaoWhatsApp))
  const garantias = linhasGarantia(itens)
  if (garantias.length) {
    linhas.push('')
    linhas.push('🛡️ *Garantia*')
    linhas.push(...garantias)
  }
  if (observacao) {
    linhas.push('')
    linhas.push('📎 *Observações*')
    linhas.push(observacao.trim())
  }
  return linhas.join('\n')
}

// Detecta dispositivo móvel (Web Share API faz sentido só no celular;
// no desktop o navigator.share abre a caixa de compartilhamento do SO, sem WhatsApp)
function ehDispositivoMovel(): boolean {
  if (typeof navigator === 'undefined') return false
  const ua = navigator.userAgent || ''
  if (/Android|iPhone|iPad|iPod|Mobile/i.test(ua)) return true
  if (navigator.maxTouchPoints && navigator.maxTouchPoints > 1) return true
  return false
}

// Salva o PDF com o usuário escolhendo o destino:
// 1º Desktop (Chrome/Edge): diálogo nativo "Salvar como" (showSaveFilePicker) — o usuário
//    navega até a pasta que quiser (ex.: G:\orcamentos\) e grava lá.
// 2º Mobile: Web Share API com o arquivo — o SO oferece salvar em Arquivos/Drive/enviar.
// 3º Fallback (Firefox/Safari desktop, mobile sem share): download padrão do navegador.
async function salvarPdf(doc: TDocumentDefinitions, nomeArquivo: string): Promise<void> {
  const picker = (window as any).showSaveFilePicker
  if (typeof picker === 'function' && !ehDispositivoMovel()) {
    try {
      const handle = await picker({
        suggestedName: nomeArquivo,
        types: [{ description: 'PDF', accept: { 'application/pdf': ['.pdf'] } }],
      })
      const blob = await pdfMake.createPdf(doc).getBlob()
      const writable = await handle.createWritable()
      await writable.write(blob)
      await writable.close()
      return
    } catch {
      // Cancelado pelo usuário → não faz nada
      return
    }
  }

  if (ehDispositivoMovel() && navigator.canShare?.({ files: [] })) {
    try {
      const blob = await pdfMake.createPdf(doc).getBlob()
      const file = new File([blob], nomeArquivo, { type: 'application/pdf' })
      await navigator.share({ files: [file] })
      return
    } catch {
      // Cancelado ou não suportado → cai no download padrão
    }
  }

  pdfMake.createPdf(doc).download(nomeArquivo)
}

// Envia a mensagem para o WhatsApp preservando emojis:
// 1º Web Share API (SÓ celular — texto nativo, mais automático) → 'shared';
// 2º copia para o clipboard e abre o wa.me sem texto (desktop e fallback) → 'copied';
// 3º fallback: wa.me?text= com o texto na URL → 'failed'.
export async function copiarEabrirWhatsApp(
  telefone: string,
  mensagem: string,
): Promise<'shared' | 'copied' | 'failed'> {
  const apenasDigitos = String(telefone || '').replace(/\D/g, '')
  if (!apenasDigitos) return 'failed'
  const numero = apenasDigitos.startsWith('55') ? apenasDigitos : `55${apenasDigitos}`

  const texto = String(mensagem || '').normalize('NFC')

  // Web Share API — somente mobile: texto entra nativo (sem URL), preserva emojis
  if (ehDispositivoMovel() && typeof navigator.share === 'function') {
    try {
      await navigator.share({ text: texto })
      return 'shared'
    } catch {
      // Cancelado ou falha: segue para copiar+colar
    }
  }

  const copiado = await copiarParaClipboard(texto)

  const url = copiado
    ? `https://wa.me/${numero}`
    : `https://wa.me/${numero}?text=${encodeURIComponent(texto)}`
  window.open(url, '_blank')
  return copiado ? 'copied' : 'failed'
}

// Copia texto para a área de transferência (Clipboard API com fallback execCommand)
async function copiarParaClipboard(texto: string): Promise<boolean> {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(texto)
      return true
    }
  } catch {
    /* tenta fallback abaixo */
  }
  try {
    const ta = document.createElement('textarea')
    ta.value = texto
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    const ok = document.execCommand('copy')
    document.body.removeChild(ta)
    return ok
  } catch {
    return false
  }
}

// Endereço da empresa (rodapé do PDF) no padrão:
// "Alameda dos Cravos, nº 48 - Jd. Simus - Sorocaba/SP - CEP: 18055-135"
function formatarEnderecoEmpresa(user?: User | null): string {
  const e = (user as any)?._endereco_user
  if (!e) return ''

  const logradouro = [e.endereco, e.numero ? `nº ${e.numero}` : '', e.complemento]
    .filter(Boolean)
    .join(', ')

  const cidadeEstado = [e.cidade, e.estado].filter(Boolean).join('/')

  const partes = [logradouro, e.bairro, cidadeEstado, e.cep ? `CEP: ${e.cep}` : ''].filter(Boolean)
  return partes.join(' - ')
}

export async function gerarPdfOrcamento({
  header,
  itens,
  cliente,
  user,
  faturar,
  condicoesPagamento,
}: PdfOrcamentoInput) {
  const codOrca = header?.cod_orca || 'ORC'
  const nomeEmpresa = user?.fantasia || user?.razao || user?.name || ''
  const cnpjEmpresa = user?.cnpj || ''
  const whatsapp = obterWhatsapp(user)
  const enderecoEmpresa = formatarEnderecoEmpresa(user)

  const nomeCliente =
    cliente?.nome_fantasia || cliente?.razao_social || cliente?.nome_cpf || cliente?.contato || ''
  const contatoCliente = cliente?.contato || ''
  const docCliente = cliente?.cnpj || cliente?.cpf || ''

  // Localização: usa o endereço comercial/preferencial do cliente (Endereco_Cliente)
  const enderecos = (header?._cliente?._enderecos as any[]) ?? []
  const end = enderecos.find((e) => e?.Tipo === 'Comercial') || enderecos[0]
  const localizacao = end?.cidade && end?.estado ? `${end.cidade} / ${end.estado}` : ''

  const subtotal = subtotalItensBruto(itens, header)
  const desconto = Number(header?.desconto) || 0
  const maoDeObra = Number(header?.mao_de_obra) || 0
  const totalGeral = totalGeralDerivado(itens, header)
  const freteB2C = Number(header?.frtB2C) || 0
  const observacao = header?.observacao || ''

  const condicoes = obterCondicoes(header, faturar, condicoesPagamento)

  // Cabeçalho duplo: esquerda = logo + emissora; direita = card ORÇAMENTO DE VENDA
  const cabecalho = {
    table: {
      widths: ['*', 190],
      body: [
        [
          {
            stack: [
              {
                image: logoOrca,
                width: 150,
                alignment: 'left',
                margin: [0, 0, 0, 8] as any,
              },
              {
                text: [
                  { text: 'Empresa Emissora: ', bold: true },
                  { text: nomeEmpresa },
                  { text: ` (CNPJ: ${cnpjEmpresa})` },
                  ...(whatsapp ? [{ text: ` | WhatsApp: ${whatsapp}` }] : []),
                ],
                fontSize: 9,
                margin: [0, 4, 0, 0] as any,
              },
            ],
            alignment: 'left',
            margin: [0, 6, 8, 6] as any,
          },
          {
            stack: [
              { text: 'ORÇAMENTO DE VENDA Nº', style: 'headerCardTitle' },
              { text: codOrca, style: 'headerCardNum' },
              { text: `Data de Emissão: ${formatarDataHoraAgora()}`, style: 'headerCardLine' },
              {
                text: `Validade da Proposta: ${formatarValidade(header, user)}`,
                style: 'headerCardLine',
              },
            ],
            fillColor: '#1f4e79',
            color: '#ffffff',
            margin: [12, 14, 12, 14] as any,
          },
        ],
      ],
    },
    layout: 'noBorders',
    margin: [0, 0, 0, 14] as any,
  } as any

  // Dados do cliente (quadro cinza claro)
  const dadosCliente = {
    table: {
      widths: ['*'],
      body: [
        [
          {
            stack: [
              {
                text: `Cliente/Razão Social: ${nomeCliente}${docCliente ? ` | CNPJ/CPF: ${docCliente}` : ''}`,
                style: 'cliente',
              },
              ...(contatoCliente
                ? [{ text: `A/C (Contato): ${contatoCliente}`, style: 'cliente' }]
                : []),
              ...(localizacao
                ? [{ text: `Localização do Cliente: ${localizacao}`, style: 'cliente' }]
                : []),
            ],
            fillColor: '#f3f3f3',
            margin: [10, 8, 10, 8] as any,
          },
        ],
      ],
    },
    layout: 'noBorders',
    margin: [0, 0, 0, 14] as any,
  } as any

  // Tabela de itens zebrada
  const th: any = {
    bold: true,
    color: '#ffffff',
    fontSize: 9,
    fillColor: '#1f4e79',
    margin: [4, 6, 4, 6],
  }
  const td: any = { fontSize: 9, margin: [4, 5, 4, 5] }
  const bodyItens: any[] = [
    [
      { text: '#', ...th },
      { text: 'Descrição do Item', ...th },
      { text: 'Medidas', ...th },
      { text: 'Qtd', ...th },
      { text: 'Valor Unitário', ...th, alignment: 'right' },
      { text: 'Valor Total', ...th, alignment: 'right' },
    ],
  ]
  ;(itens || []).forEach((item, i) => {
    const descricao = item.Descricao || item.descricao || ''
    const obsItem = item.descricao || ''
    const comp = composicaoItem(item)
    const qtd = Number(item.qtd) || 1
    const unit = brutoUnitarioItem(item, header)
    const zebra = i % 2 === 1 ? '#f7f9fb' : '#ffffff'
    const linhasDesc: any[] = [{ text: descricao, ...td, fillColor: zebra }]
    if (comp) {
      linhasDesc.push({
        text: comp,
        fontSize: 8,
        color: '#1f4e79',
        fillColor: zebra,
        margin: [4, 0, 4, 2] as any,
      })
    }
    if (obsItem) {
      linhasDesc.push({
        text: obsItem,
        fontSize: 8,
        italics: true,
        color: '#555555',
        fillColor: zebra,
        margin: [4, 0, 4, 5] as any,
      })
    }
    bodyItens.push([
      { text: String(i + 1), ...td, fillColor: zebra },
      {
        stack: linhasDesc,
        fillColor: zebra,
        margin: [4, 5, 4, 5] as any,
      },
      { text: formatarMedidas(item), ...td, fillColor: zebra },
      { text: String(qtd), ...td, fillColor: zebra, alignment: 'center' },
      { text: formatarMoeda(unit), ...td, fillColor: zebra, alignment: 'right' },
      { text: formatarMoeda(unit * qtd), ...td, fillColor: zebra, alignment: 'right' },
    ])
  })

  const tabelaItens = {
    table: {
      headerRows: 1,
      widths: [18, '*', 78, 32, 72, 72],
      body: bodyItens,
    },
    margin: [0, 0, 0, 12] as any,
  } as any

  // Resumo financeiro (alinhado à direita)
  const resumoRows: any[] = [
    [
      { text: 'Subtotal dos Itens', style: 'resumoLabel' },
      { text: formatarMoeda(subtotal), style: 'resumoVal' },
    ],
  ]
  if (desconto) {
    resumoRows.push([
      { text: 'Desconto', style: 'resumoLabel' },
      { text: formatarMoeda(desconto), style: 'resumoVal' },
    ])
  }
  resumoRows.push([
    { text: 'Frete', style: 'resumoLabel' },
    { text: linhaFrete(freteB2C).replace('Frete: ', ''), style: 'resumoVal' },
  ])
  if (maoDeObra) {
    resumoRows.push([
      { text: 'Mão de Obra / Serviços', style: 'resumoLabel' },
      { text: formatarMoeda(maoDeObra), style: 'resumoVal' },
    ])
  }
  resumoRows.push([
    { text: 'TOTAL GERAL', style: 'resumoTotal' },
    { text: formatarMoeda(totalGeral), style: 'resumoTotal' },
  ])

  const resumoFinanceiro = {
    table: {
      widths: ['*', 120],
      body: resumoRows,
    },
    layout: 'noBorders',
    alignment: 'right',
    margin: [0, 0, 0, 16] as any,
  } as any

  // Condições comerciais em 2 colunas com espaço garantido entre elas
  const colCondicoes = {
    width: '*',
    stack: [
      { text: 'Condições de Pagamento', style: 'section' },
      ...condicoes
        .split('\n')
        .filter(Boolean)
        .map((l) => ({ text: `• ${l.trim()}`, style: 'item' })),
    ],
  }

  const colPrazos = {
    width: '*',
    stack: [
      { text: 'Prazos e Entregas', style: 'section' },
      { text: `• Prazo de Entrega: ${PRAZOS_ORCAMENTO.entrega}`, style: 'item' },
      { text: `• ${linhaFrete(freteB2C)}`, style: 'item' },
    ],
  }

  const condicoesComerciais = {
    columns: [colCondicoes, colPrazos],
    columnGap: 24,
    margin: [0, 0, 0, 8] as any,
  } as any

  // Garantia por material (agrupada/deduplicada) — bloco só quando há linhas
  const garantias = linhasGarantia(itens)
  const blocoGarantia = garantias.length
    ? {
        stack: [
          { text: 'Garantia', style: 'section' },
          ...garantias.map((l) => ({ text: `• ${l}`, style: 'item' })),
        ],
        margin: [0, 0, 0, 8] as any,
      }
    : null

  const observacoes = organizarObservacoes(observacao)

  const doc: TDocumentDefinitions = {
    content: [
      cabecalho,
      dadosCliente,
      { text: 'Itens e Valores', style: 'section' },
      tabelaItens,
      resumoFinanceiro,
      condicoesComerciais,
      ...(blocoGarantia ? [blocoGarantia] : []),
      ...(observacoes.length
        ? [
            { text: 'Observações e Notas Técnicas', style: 'section' },
            ...observacoes.map((l) => ({ text: l, style: 'itemObs' })),
          ]
        : []),
    ],
    footer: (currentPage, pageCount) => {
      const contatoRodape = [
        nomeEmpresa,
        cnpjEmpresa ? `CNPJ: ${cnpjEmpresa}` : '',
        whatsapp ? `WhatsApp: ${whatsapp}` : '',
      ]
        .filter(Boolean)
        .join(' | ')
      return {
        stack: [
          ...(contatoRodape ? [{ text: contatoRodape, style: 'footer' }] : []),
          ...(enderecoEmpresa ? [{ text: enderecoEmpresa, style: 'footer' }] : []),
          { text: `Página ${currentPage} de ${pageCount}`, style: 'footer' },
        ],
        alignment: 'center',
        margin: [40, 12, 40, 8],
      }
    },
    styles: {
      headerCardTitle: { fontSize: 11, bold: true, color: '#ffffff', alignment: 'center' },
      headerCardNum: {
        fontSize: 18,
        bold: true,
        color: '#ffffff',
        alignment: 'center',
        margin: [0, 6, 0, 6],
      },
      headerCardLine: { fontSize: 9, color: '#e5e7eb', margin: [0, 2, 0, 2] },
      cliente: { fontSize: 10, margin: [0, 1, 0, 1] },
      section: { fontSize: 13, bold: true, margin: [0, 12, 0, 6], color: '#1f4e79' },
      item: { fontSize: 10, margin: [0, 2, 0, 2] },
      itemObs: { fontSize: 9, margin: [0, 2, 0, 6], color: '#444444' },
      resumoLabel: { fontSize: 10, margin: [0, 2, 0, 2] },
      resumoVal: { fontSize: 10, margin: [0, 2, 0, 2], alignment: 'right' },
      resumoTotal: { fontSize: 14, bold: true, color: '#1f4e79', margin: [0, 6, 0, 2] },
      footer: { fontSize: 8, color: '#666666', alignment: 'center', margin: [0, 1, 0, 1] },
    },
    defaultStyle: { fontSize: 10 },
    pageMargins: [40, 40, 40, 60],
  }

  await salvarPdf(doc, nomeArquivoOrcamento(header, cliente))
}

// ── PEDIDO DE VENDA ────────────────────────────────────────────────────────────
// Layout profissional A4 retrato: cabeçalho (logo + dados), CLIENTE + INFORMAÇÕES
// GERAIS em duas colunas, Condições e Entrega, tabela de itens (Código | Descrição |
// Qtde | Preço unit | Subtotal) com linha de DESCONTO e FRETE e TOTAL em destaque,
// e rodapé "Obrigado por fazer negócio conosco!".

interface PdfPedidoVendaInput {
  header: any
  itens: any[]
  cliente?: Cliente | null
  user?: User | null
  condicoesPagamento?: string
}

export function nomeArquivoPedidoVenda(header: any, cliente?: Cliente | null): string {
  const codOrca = header?.cod_orca || 'PDV'
  const contato = sanitizarNome(cliente?.contato || '')
  const nomeCliente = sanitizarNome(
    cliente?.nome_fantasia || cliente?.razao_social || cliente?.nome_cpf || '',
  )
  const quem = [contato, nomeCliente].filter(Boolean).join('-')
  const dataHora = nomeDataHora()
  const base = [codOrca, quem, dataHora].filter(Boolean).join('_')
  return `PDV_${base}_.pdf`
}

// Endereço do cliente em uma linha: "Av. Nações Unidas, 18801 - São Paulo/SP - CEP: 04757-025"
function enderecoClienteLinha(cliente?: Cliente | null): {
  cidade: string
  uf: string
  cep: string
  endereco: string
} {
  const end = cliente?._enderecos?.find((e) => e?.Tipo === 'Comercial') || cliente?._enderecos?.[0]
  const logradouro = [end?.endereco, end?.numero ? `nº ${end.numero}` : '', end?.complemento]
    .filter(Boolean)
    .join(', ')
  return {
    cidade: end?.cidade || '',
    uf: end?.estado || '',
    cep: end?.cep || '',
    endereco: logradouro,
  }
}

export async function gerarPdfPedidoVenda({
  header,
  itens,
  cliente,
  user,
  condicoesPagamento,
}: PdfPedidoVendaInput) {
  const codOrca = header?.cod_orca || 'PDV'
  const nomeEmpresa = user?.fantasia || user?.razao || user?.name || ''
  const cnpjEmpresa = user?.cnpj || ''
  const ieEmpresa = user?.ie || ''
  const vendedor = user?.name || ''

  const nomeCliente =
    cliente?.nome_fantasia || cliente?.razao_social || cliente?.nome_cpf || cliente?.contato || ''
  const docCliente = cliente?.cnpj || cliente?.cpf || ''
  const endCliente = enderecoClienteLinha(cliente)
  const telefoneCliente = obterWhatsappCliente(cliente)
  const contatoCliente = cliente?.contato || ''
  const ieCliente = cliente?.inscricao_estadual || ''
  const emailCliente = cliente?.['e-mail'] || ''

  const condicoes = condicoesPagamento?.trim() || header?.condicoes_pagamento || ''
  const desconto = Number(header?.desconto) || 0
  const freteB2C = Number(header?.frtB2C) || 0
  const totalGeral = Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || 0

  // Cabeçalho: esquerda = logo + identificação; direita = bloco de dados (Data, Pedido nº, Vendedor, Compra Nº)
  const cabecalho = {
    columns: [
      {
        width: '*',
        stack: [
          { image: logoOrca, width: 150, margin: [0, 0, 0, 6] },
          { text: 'Comércio e Representação', fontSize: 10, bold: true, color: '#1f2937' },
          { text: 'DISTRIBUIDOR AUTORIZADO', fontSize: 8, color: '#6b7280', margin: [0, 2, 0, 8] },
          {
            text: `Nome: ${nomeEmpresa} CNPJ ${cnpjEmpresa}${ieEmpresa ? ` IE: ${ieEmpresa}` : ''}`,
            fontSize: 8,
            color: '#4b5563',
          },
        ],
      },
      {
        width: 230,
        table: {
          widths: [85, '*'],
          body: [
            [
              { text: 'Data:', bold: true, fontSize: 8 },
              { text: formatarDataHoraAgora(), fontSize: 8 },
            ],
            [
              { text: 'Pedido nº:', bold: true, fontSize: 8 },
              { text: codOrca, fontSize: 8 },
            ],
            [
              { text: 'Vendedor:', bold: true, fontSize: 8 },
              { text: vendedor, fontSize: 8 },
            ],
            [
              { text: 'Compra Nº:', bold: true, fontSize: 8 },
              { text: '', fontSize: 8 },
            ],
          ],
        },
        layout: {
          hLineWidth: () => 0,
          vLineWidth: () => 0,
          paddingLeft: () => 6,
          paddingRight: () => 6,
          paddingTop: () => 4,
          paddingBottom: () => 4,
        },
        margin: [12, 0, 0, 0],
      },
    ],
    columnGap: 10,
    margin: [0, 0, 0, 12],
  } as any

  // Bloco CLIENTE + INFORMAÇÕES GERAIS em duas colunas
  const clienteGerais = {
    table: {
      widths: ['*', '*'],
      body: [
        [
          {
            stack: [
              { text: 'CLIENTE', bold: true, fontSize: 10, color: '#1f2937', margin: [0, 0, 0, 4] },
              { text: `Nome: ${nomeCliente}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `CNPJ: ${docCliente}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `Cidade: ${endCliente.cidade}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `Endereço: ${endCliente.endereco}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `Telefone: ${telefoneCliente}`, fontSize: 9, margin: [0, 1, 0, 1] },
            ],
          },
          {
            stack: [
              {
                text: 'INFORMAÇÕES GERAIS',
                bold: true,
                fontSize: 10,
                color: '#1f2937',
                margin: [0, 0, 0, 4],
              },
              { text: `Contato: ${contatoCliente}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `I.E.: ${ieCliente}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `UF: ${endCliente.uf}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `CEP: ${endCliente.cep}`, fontSize: 9, margin: [0, 1, 0, 1] },
              { text: `E-mail: ${emailCliente}`, fontSize: 9, margin: [0, 1, 0, 1] },
            ],
          },
        ],
      ],
    },
    layout: {
      hLineColor: () => '#d1d5db',
      hLineWidth: () => 0.5,
      vLineColor: () => '#d1d5db',
      vLineWidth: () => 0.5,
      paddingLeft: () => 8,
      paddingRight: () => 8,
      paddingTop: () => 6,
      paddingBottom: () => 6,
    },
    margin: [0, 0, 0, 12],
  } as any

  // Condições e Entrega
  const garantiasPdV = linhasGarantia(itens)
  const condicoesEntrega = {
    table: {
      widths: [120, '*'],
      body: [
        [
          { text: 'Condição de pagamento:', bold: true, fontSize: 9 },
          { text: condicoes, fontSize: 9 },
        ],
        ...(garantiasPdV.length
          ? [
              [
                { text: 'Garantia:', bold: true, fontSize: 9 },
                { text: garantiasPdV.join('\n'), fontSize: 9 },
              ] as any,
            ]
          : []),
        [
          { text: 'Transportadora:', bold: true, fontSize: 9 },
          { text: '', fontSize: 9 },
        ],
        [
          { text: 'Previsão de entrega:', bold: true, fontSize: 9 },
          { text: 'em 5 dias', fontSize: 9 },
        ],
        [
          { text: 'Observações:', bold: true, fontSize: 9 },
          {
            text: freteB2C > 0 ? `frete R$ ${formatarMoeda(freteB2C)} incluído acima` : '',
            fontSize: 9,
          },
        ],
      ],
    },
    layout: {
      hLineColor: () => '#d1d5db',
      hLineWidth: () => 0.5,
      vLineColor: () => '#d1d5db',
      vLineWidth: () => 0.5,
      paddingLeft: () => 8,
      paddingRight: () => 8,
      paddingTop: () => 5,
      paddingBottom: () => 5,
    },
    margin: [0, 0, 0, 12],
  } as any

  // Tabela de itens (5 colunas) + DESCONTO + FRETE + TOTAL
  const th: any = {
    bold: true,
    color: '#1f2937',
    fontSize: 9,
    fillColor: '#f3f4f6',
    margin: [4, 5, 4, 5],
  }
  const td: any = { fontSize: 9, margin: [4, 5, 4, 5] }
  const body: any[] = [
    [
      { text: 'Código', ...th },
      { text: 'Descrição', ...th },
      { text: 'Medidas', ...th },
      { text: 'Qtde.', ...th, alignment: 'center' },
      { text: 'Preço unit', ...th, alignment: 'right' },
      { text: 'Subtotal', ...th, alignment: 'right' },
    ],
  ]

  let subtotalItens = 0
  ;(itens || []).forEach((item) => {
    const qtd = Number(item.qtd) || 1
    const precoUnit = Number(item.vlr_vnd_unit) || 0
    const subtotal = precoUnit * qtd
    subtotalItens += subtotal
    body.push([
      { text: String(item.produto_id ?? ''), ...td },
      {
        text: [item.Descricao || item.descricao || '', composicaoItem(item)]
          .filter(Boolean)
          .join('  ·  '),
        ...td,
      },
      { text: formatarMedidas(item), ...td },
      { text: String(qtd), ...td, alignment: 'center' },
      { text: formatarMoeda(precoUnit), ...td, alignment: 'right' },
      { text: formatarMoeda(subtotal), ...td, alignment: 'right' },
    ])
  })

  if (desconto > 0) {
    body.push([
      { text: '', ...td },
      { text: 'DESCONTO', ...td },
      { text: '', ...td },
      { text: '1', ...td, alignment: 'center' },
      { text: `-${formatarMoeda(desconto)}`, ...td, alignment: 'right' },
      { text: `-${formatarMoeda(desconto)}`, ...td, alignment: 'right' },
    ])
  }
  if (freteB2C > 0) {
    body.push([
      { text: '', ...td },
      { text: 'FRETE', ...td },
      { text: '', ...td },
      { text: '1', ...td, alignment: 'center' },
      { text: formatarMoeda(freteB2C), ...td, alignment: 'right' },
      { text: formatarMoeda(freteB2C), ...td, alignment: 'right' },
    ])
  }
  body.push([
    { text: 'TOTAL', ...td, bold: true, fontSize: 11, fillColor: '#eef2ff' },
    { text: '', ...td, fillColor: '#eef2ff' },
    { text: '', ...td, fillColor: '#eef2ff' },
    { text: '', ...td, fillColor: '#eef2ff' },
    { text: '', ...td, fillColor: '#eef2ff' },
    {
      text: formatarMoeda(totalGeral),
      ...td,
      bold: true,
      fontSize: 11,
      alignment: 'right',
      fillColor: '#eef2ff',
    },
  ])

  const tabelaItens = {
    table: {
      headerRows: 1,
      widths: [40, '*', 72, 35, 62, 62],
      body,
    },
    layout: {
      hLineColor: () => '#d1d5db',
      hLineWidth: () => 0.5,
      vLineColor: () => '#d1d5db',
      vLineWidth: () => 0.5,
    },
    margin: [0, 0, 0, 16],
  } as any

  const doc: TDocumentDefinitions = {
    pageSize: 'A4',
    pageOrientation: 'portrait',
    content: [
      cabecalho,
      clienteGerais,
      condicoesEntrega,
      tabelaItens,
      {
        text: 'Obrigado por fazer negócio conosco!',
        alignment: 'center',
        fontSize: 11,
        italics: true,
        color: '#1f2937',
      },
    ],
    styles: {},
    defaultStyle: { fontSize: 10 },
    pageMargins: [40, 40, 40, 40],
  }

  await salvarPdf(doc, nomeArquivoPedidoVenda(header, cliente))
}
