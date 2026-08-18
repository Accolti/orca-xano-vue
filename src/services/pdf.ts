import pdfMake from 'pdfmake/build/pdfmake'
import * as pdfFonts from 'pdfmake/build/vfs_fonts'
import type { TDocumentDefinitions } from 'pdfmake/interfaces'
import type { User } from '@/stores/auth'
import type { Cliente } from '@/types/cliente'

;(pdfMake as any).vfs = (pdfFonts as any).vfs

interface PdfOrcamentoInput {
  header: any
  itens: any[]
  cliente?: Cliente | null
  user?: User | null
  faturar?: boolean
}

export const PRAZOS_ORCAMENTO = {
  entrega: '10 a 15 dias úteis',
  frete: 'Gratuito para Sorocaba e região',
  garantia: '1 ano de fábrica contra defeitos de fabricação',
}

const TEXTO_FATURAR = 'Faturamos com até 20 dias da entrega do produto'

export function formatarMoeda(valor: number): string {
  return `R$ ${(Number(valor) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
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

// Port do JS de condições de pagamento (Pix 2x fixas + Boleto parcelado).
export function calcularCondicoesPagamento(
  valorVenda: number,
  valorCusto: number,
  faturar = false,
) {
  const venda = Number(valorVenda) || 0
  const custo = Number(valorCusto) || 0
  const entradaPrazo = 5
  const intervaloParcelas = 30

  const primeiraParcelaPix = venda / 2
  const segundaParcelaPix = venda / 2
  const pixString = `Pix (2x de ${formatarMoeda(primeiraParcelaPix)}): 1ª parcela em ${entradaPrazo} dias do pedido; 2ª parcela em ${entradaPrazo + intervaloParcelas} dias.`

  const metadeCusto = custo / 2
  const numeroParcelas = Math.max(1, Math.floor(venda / metadeCusto))
  const valorParcelas = venda / numeroParcelas

  let prazos = `${entradaPrazo} dias do pedido`
  const prazosRestantes: string[] = []
  for (let i = 1; i < numeroParcelas; i++) {
    prazosRestantes.push(String(entradaPrazo + i * intervaloParcelas))
  }
  if (numeroParcelas > 1) {
    prazos += `; demais em ${prazosRestantes.join(' e ')} dias`
  }
  const boletoString = `Boleto (${numeroParcelas}x de ${formatarMoeda(valorParcelas)}): 1ª parcela em ${prazos}.`

  const linhas = [pixString, boletoString]
  if (faturar) {
    linhas.push(TEXTO_FATURAR)
  }
  return linhas.join('\n')
}

export function obterWhatsapp(user?: User | null): string {
  const telefones = (user as any)?._telefones ?? []
  const whats = telefones.find((t: any) => String(t.tipo_telefone || '').toLowerCase() === 'whatsapp')
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
}: PdfOrcamentoInput): string {
  const codOrca = header?.cod_orca || 'ORC'
  const contato = cliente?.contato || cliente?.nome_fantasia || cliente?.razao_social || ''

  const vendaBruta = (Number(header?.vnd_B2B_tot) || 0) + (Number(header?.desconto) || 0)
  const desconto = Number(header?.desconto) || 0
  const maoDeObra = Number(header?.mao_de_obra) || 0
  const freteB2C = Number(header?.frtB2C) || 0
  const totalGeral =
    Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || vendaBruta - desconto
  const observacao = header?.observacao || ''

  const condicoes = calcularCondicoesPagamento(totalGeral, Number(header?.cst_tot) || 0, faturar)

  const linhasItens = (itens || []).map((item, i) => {
    const descricao = item.Descricao || item.descricao || ''
    const largCm = (Number(item.larg) || 0) * 100
    const compCm = (Number(item.comp) || 0) * 100
    const dim = `(${largCm.toLocaleString('pt-BR', { minimumFractionDigits: 2 })} x ${compCm.toLocaleString('pt-BR', { minimumFractionDigits: 2 })} cm)`
    const qtd = Number(item.qtd) || 1
    const unit = Number(item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit) || 0
    return `Item ${i + 1}: ${descricao} ${dim} — Qtd: ${qtd} — Unitário: ${formatarMoeda(unit)} — Total: ${formatarMoeda(unit * qtd)}`
  })

  const linhas: string[] = []
  linhas.push(`Olá ${contato}! Segue o orçamento ${codOrca}:`)
  linhas.push('')
  linhas.push('*Itens e Valores*')
  linhas.push(...linhasItens)
  linhas.push('')
  linhas.push(`Subtotal: ${formatarMoeda(vendaBruta)}`)
  if (desconto) linhas.push(`Desconto: ${formatarMoeda(desconto)}`)
  if (freteB2C) linhas.push(`Frete B2C: ${formatarMoeda(freteB2C)}`)
  if (maoDeObra) linhas.push(`Mão de Obra: ${formatarMoeda(maoDeObra)}`)
  linhas.push(`*Total Geral: ${formatarMoeda(totalGeral)}*`)
  linhas.push('')
  linhas.push('*Condições de Pagamento*')
  linhas.push(...condicoes.split('\n'))
  if (observacao) {
    linhas.push('')
    linhas.push('*Observações*')
    linhas.push(observacao)
  }
  return linhas.join('\n')
}

// Gera o link wa.me a partir da mensagem (abre em nova aba)
export function abrirWhatsApp(telefone: string, mensagem: string) {
  const apenasDigitos = String(telefone || '').replace(/\D/g, '')
  if (!apenasDigitos) return false
  const numero = apenasDigitos.startsWith('55') ? apenasDigitos : `55${apenasDigitos}`
  const url = `https://wa.me/${numero}?text=${encodeURIComponent(mensagem)}`
  window.open(url, '_blank')
  return true
}

export function gerarPdfOrcamento({ header, itens, cliente, user, faturar }: PdfOrcamentoInput) {
  const codOrca = header?.cod_orca || 'ORC'
  const nomeEmpresa = user?.fantasia || user?.razao || user?.name || ''
  const cnpjEmpresa = user?.cnpj || ''
  const whatsapp = obterWhatsapp(user)

  const nomeCliente =
    cliente?.nome_fantasia || cliente?.razao_social || cliente?.nome_cpf || cliente?.contato || ''
  const contatoCliente = cliente?.contato || ''
  const docCliente = cliente?.cnpj || cliente?.cpf || ''

  // Localização: usa o endereço comercial/preferencial do cliente (Endereco_Cliente)
  const enderecos = (header?._cliente?._enderecos as any[]) ?? []
  const end = enderecos.find((e) => e?.Tipo === 'Comercial') || enderecos[0]
  const localizacao = end?.cidade && end?.estado ? `${end.cidade} / ${end.estado}` : ''

  const vendaBruta = (Number(header?.vnd_B2B_tot) || 0) + (Number(header?.desconto) || 0)
  const desconto = Number(header?.desconto) || 0
  const maoDeObra = Number(header?.mao_de_obra) || 0
  const totalGeral = Number(header?.vnd_B2B_B2C_tot) || Number(header?.vnd_tot) || vendaBruta - desconto
  const freteB2C = Number(header?.frtB2C) || 0
  const observacao = header?.observacao || ''

  const condicoes = calcularCondicoesPagamento(totalGeral, Number(header?.cst_tot) || 0, faturar)

  // Linha do item + descrição digitada abaixo (se houver)
  const itensTable = (itens || []).map((item, i) => {
    const descricao = item.Descricao || item.descricao || ''
    const largCm = (Number(item.larg) || 0) * 100
    const compCm = (Number(item.comp) || 0) * 100
    const dim = `(${largCm.toLocaleString('pt-BR', { minimumFractionDigits: 2 })} x ${compCm.toLocaleString('pt-BR', { minimumFractionDigits: 2 })} cm)`
    const qtd = Number(item.qtd) || 1
    const unit = Number(item.vlr_vnd_unit_b2b ?? item.vlr_vnd_unit) || 0
    const obsItem = item.descricao || ''
    const linha = `Item ${i + 1}: ${descricao} ${dim} — Qtd: ${qtd} — Unitário: ${formatarMoeda(unit)} — Total: ${formatarMoeda(unit * qtd)}`
    return obsItem
      ? [
          { text: linha, style: 'item' },
          { text: obsItem, style: 'itemObs' },
        ]
      : [{ text: linha, style: 'item' }]
  })

  const doc: TDocumentDefinitions = {
    content: [
      {
        table: {
          widths: ['*'],
          body: [
            [
              {
                stack: [
                  { text: nomeEmpresa || 'Orçamento de Venda', style: 'headerEmpresa' },
                  ...(cnpjEmpresa || whatsapp
                    ? [
                        {
                          text: [cnpjEmpresa ? `CNPJ: ${cnpjEmpresa}` : '', whatsapp ? `WhatsApp: ${whatsapp}` : '']
                            .filter(Boolean)
                            .join('   ·   '),
                          style: 'headerSub',
                        },
                      ]
                    : []),
                  { text: `Orçamento ${codOrca}`, style: 'headerOrc' },
                  { text: `Data/Hora: ${formatarDataHoraAgora()}`, style: 'headerSub' },
                ],
                alignment: 'center',
                fillColor: '#111111',
                color: '#ffffff',
                margin: [16, 18, 16, 18],
              },
            ],
          ],
        },
        layout: 'noBorders',
        margin: [0, 0, 0, 14],
      } as any,

      ...(contatoCliente ? [{ text: `Contato do Cliente: ${contatoCliente}`, style: 'info' }] : []),
      ...(nomeCliente ? [{ text: `Cliente: ${nomeCliente}`, style: 'info' }] : []),
      ...(localizacao ? [{ text: `Localização do Cliente: ${localizacao}`, style: 'info' }] : []),
      ...(docCliente ? [{ text: `Documento: ${docCliente}`, style: 'info' }] : []),
      { text: ' ', style: 'info' },

      { text: 'Itens e Valores', style: 'section' },
      ...itensTable.flat(),
      { text: ' ', style: 'info' },
      { text: `Subtotal: ${formatarMoeda(vendaBruta)}`, style: 'tot' },
      ...(desconto ? [{ text: `Desconto: ${formatarMoeda(desconto)}`, style: 'tot' }] : []),
      ...(freteB2C ? [{ text: `Frete B2C: ${formatarMoeda(freteB2C)}`, style: 'tot' }] : []),
      ...(maoDeObra ? [{ text: `Mão de Obra: ${formatarMoeda(maoDeObra)}`, style: 'tot' }] : []),
      { text: `Total Geral: ${formatarMoeda(totalGeral)}`, style: 'total' },
      { text: ' ', style: 'info' },

      { text: 'Condições de Pagamento', style: 'section' },
      ...condicoes.split('\n').map((linha) => ({ text: linha, style: 'item' })),
      { text: ' ', style: 'info' },

      { text: 'Prazos, Frete e Garantia', style: 'section' },
      { text: `Prazo de Entrega: ${PRAZOS_ORCAMENTO.entrega}`, style: 'item' },
      { text: `Frete: ${PRAZOS_ORCAMENTO.frete}`, style: 'item' },
      { text: `Garantia: ${PRAZOS_ORCAMENTO.garantia}`, style: 'item' },

      ...(observacao
        ? [
            { text: ' ', style: 'info' },
            { text: 'Observações', style: 'section' },
            { text: observacao, style: 'itemObs' },
          ]
        : []),
    ],
    styles: {
      headerEmpresa: { fontSize: 20, bold: true, alignment: 'center', color: '#ffffff', margin: [0, 0, 0, 6] },
      headerOrc: { fontSize: 13, bold: true, alignment: 'center', color: '#ffffff', margin: [0, 8, 0, 2] },
      headerSub: { fontSize: 10, alignment: 'center', color: '#e5e7eb', margin: [0, 2, 0, 2] },
      info: { fontSize: 10, margin: [0, 1, 0, 1] },
      section: { fontSize: 13, bold: true, margin: [0, 12, 0, 6], color: '#1f4e79' },
      item: { fontSize: 10, margin: [0, 2, 0, 2] },
      itemObs: { fontSize: 9, margin: [0, 0, 0, 6], color: '#555555', italics: true },
      tot: { fontSize: 11, margin: [0, 2, 0, 2] },
      total: { fontSize: 13, bold: true, margin: [0, 4, 0, 2], color: '#1f4e79' },
    },
    defaultStyle: { fontSize: 10 },
    pageMargins: [40, 40, 40, 60],
  }

  pdfMake.createPdf(doc).download(nomeArquivoOrcamento(header, cliente))
}
