import type { NotaFiscalItem } from '@/types/notaFiscal'

// Parsing de XML de NF-e (NFe) no navegador. Remove os namespaces e usa DOMParser
// + getElementsByTagName. Extrai os campos essenciais + itens + XML cru.

export interface NotaFiscalParsed {
  chave: string
  numero: string
  serie: string
  data_emissao: string // yyyy-mm-dd
  tp_nf: number
  natureza_operacao: string
  emitente_cnpj: string
  emitente_nome: string
  emitente_ie: string
  destinatario_cnpj: string
  destinatario_nome: string
  valor_total: number
  valor_produtos: number
  valor_frete: number
  valor_ipi: number
  valor_icms: number
  itens: NotaFiscalItem[]
  xml: string
}

function textOf(parent: Element | undefined, tag: string): string {
  const el = parent?.getElementsByTagName(tag)?.[0]
  return el?.textContent?.trim() ?? ''
}

function toNum(s: string): number {
  const n = parseFloat(s)
  return Number.isFinite(n) ? n : 0
}

export function parseNfeXml(xmlText: string): NotaFiscalParsed {
  const limpo = xmlText.replace(/\sxmlns(:[a-zA-Z0-9]+)?="[^"]*"/g, '')
  const doc = new DOMParser().parseFromString(limpo, 'text/xml')

  if (doc.getElementsByTagName('parsererror').length > 0) {
    throw new Error('Arquivo XML inválido.')
  }

  const infNFe = doc.getElementsByTagName('infNFe')[0]
  if (!infNFe) throw new Error('Não é um XML de NF-e (infNFe não encontrado).')

  const chave = (infNFe.getAttribute('Id') || '').replace(/^NFe/i, '')
  if (!chave) throw new Error('Chave de acesso da NF-e não encontrada.')

  const ide = infNFe.getElementsByTagName('ide')[0]
  const emit = infNFe.getElementsByTagName('emit')[0]
  const dest = infNFe.getElementsByTagName('dest')[0]
  const icmsTot = infNFe.getElementsByTagName('ICMSTot')[0]

  const dhEmi = textOf(ide, 'dhEmi') || textOf(ide, 'dEmi')

  const itens: NotaFiscalItem[] = []
  const dets = infNFe.getElementsByTagName('det')
  for (const det of Array.from(dets)) {
    const prod = det.getElementsByTagName('prod')[0]
    if (!prod) continue
    itens.push({
      codigo: textOf(prod, 'cProd'),
      descricao: textOf(prod, 'xProd'),
      ncm: textOf(prod, 'NCM'),
      cfop: textOf(prod, 'CFOP'),
      qtd: toNum(textOf(prod, 'qCom')),
      valor_unit: toNum(textOf(prod, 'vUnCom')),
      valor_total: toNum(textOf(prod, 'vProd')),
    })
  }

  return {
    chave,
    numero: textOf(ide, 'nNF'),
    serie: textOf(ide, 'serie'),
    data_emissao: dhEmi ? dhEmi.slice(0, 10) : '',
    tp_nf: toNum(textOf(ide, 'tpNF')),
    natureza_operacao: textOf(ide, 'natOp'),
    emitente_cnpj: textOf(emit, 'CNPJ') || textOf(emit, 'CPF'),
    emitente_nome: textOf(emit, 'xNome'),
    emitente_ie: textOf(emit, 'IE'),
    destinatario_cnpj: textOf(dest, 'CNPJ') || textOf(dest, 'CPF'),
    destinatario_nome: textOf(dest, 'xNome'),
    valor_total: toNum(textOf(icmsTot, 'vNF')),
    valor_produtos: toNum(textOf(icmsTot, 'vProd')),
    valor_frete: toNum(textOf(icmsTot, 'vFrete')),
    valor_ipi: toNum(textOf(icmsTot, 'vIPI')),
    valor_icms: toNum(textOf(icmsTot, 'vICMS')),
    itens,
    xml: xmlText,
  }
}
