# Orca Systems — Exemplo de Precificação com Medida Exata e Frete B2B Kapazi

**Orçamento**: ORC12453 · **Cliente**: Patrícia de Paula Oliveira
**Produto**: Vinil Gold Vulcanizado Nível 1 — Borda Rebaixada (`produto_id 4`)

## 1. Dados do produto

| Item | Valor |
|---|---|
| Matéria-prima | R$ 392,00/m² |
| Borda | R$ 12,00/m² |
| Medida exata (fábrica) | Sim → acréscimo de **10%** |
| Área | 0,8 × 0,6 = **0,48 m²** |
| Margem (markup) | **100%** |
| IPI / IMP | 0% |
| DIFAL | 6% |
| Alíq. Inter / Interna | 12% / 18% |
| Regime | MEI (crédito ICMS 0) |

## 2. Regra de frete B2B da Kapazi

O frete B2B é calculado sobre a **soma dos custos de nota de TODOS os itens do orçamento**:

| Soma dos custos de nota | Frete B2B |
|---|---|
| ≥ R$ 1.000,00 | **R$ 0,00** (grátis) |
| ≥ R$ 300,00 | **10%** do total |
| < R$ 300,00 | **R$ 52,00** (mínimo) |

> O frete **não é por item** — é pela **compra inteira**. Por isso o valor do item **muda** quando entra ou sai outro item no orçamento.

## 3. Passo a passo do cálculo (por item)

**Passo 1 — Custo de fábrica com medida exata**
```
matéria-prima + borda = 392,00 + 12,00 = 404,00
acréscimo 10% = 404,00 × 1,10 = 444,40   ← por m²
```

**Passo 2 — Custo da Nota (× área)**
```
444,40 × 0,48 m² = 213,31   ← cst_nota_unit
```
(IPI 0 → não soma)

**Passo 3 — Custo Fiscal**
```
cst_nota   = 213,31
DIFAL 6%   = 213,31 × 0,06 = 12,80
cst_fiscal = 213,31 + 12,80 = 226,11   (crédito ICMS 0, ST 0)
```

**Passo 4 — Frete B2B (depende do orçamento inteiro)**

| Cenário | Soma custos nota | Faixa | Frete total |
|---|---|---|---|
| 1 item | 213,31 | < 300 | **R$ 52,00** |
| 2 itens | 426,62 | ≥ 300 → 10% | **R$ 42,66** |

**Passo 5 — Rateio do frete (proporcional ao custo de nota)**

Com 2 itens iguais:
```
participação de cada item = 213,31 / 426,62 = 50%
frete de cada item = 42,66 × 0,5 = 21,33
```

**Passo 6 — Custo de Entrada**
```
cst_fiscal   = 226,11
frete rateado = 21,33
cst_entrada  = 226,11 + 21,33 = 247,44
```

**Passo 7 — Venda (markup 100%)**
```
venda = 247,44 × 2 = 494,88
```

## 4. Por que os DOIS itens ficaram com 494,88?

1. **Mesmo produto + mesma medida exata** → mesmo `cst_nota` (213,31) e `cst_fiscal` (226,11).
2. O frete **total** mudou de **52,00 → 42,66** (a soma 426,62 passou para a faixa de 10%).
3. O frete foi **rateado igualmente** (21,33 para cada) → `cst_entrada` 247,44.
4. Markup 100% → **494,88** em cada.

## 5. Comparativo: COM vs SEM medida exata

Mesmo produto, mesma área (0,48 m²), 1 item (frete 52). Só muda o acréscimo de 10%.

| Passo | SEM medida exata (0%) | COM medida exata (10%) |
|---|---|---|
| Matéria-prima + borda | 404,00 | 404,00 |
| Acréscimo | 0,00 | +40,40 (10%) |
| **Custo fábrica/m²** | 404,00 | **444,40** |
| Cst Nota (×0,48) | 193,92 | **213,31** |
| DIFAL 6% | 11,64 | **12,80** |
| Cst Fiscal | 205,56 | **226,11** |
| Frete B2B (1 item) | 52,00 | 52,00 |
| Cst Entrada | 257,56 | **278,11** |
| **Venda (markup 100%)** | **515,12** | **556,22** |

> O acréscimo de 10% incide **no custo de fábrica** (matéria-prima + borda) **antes** do IPI, DIFAL e frete — por isso o efeito se propaga por todo o restante do cálculo (+40,40 no custo → +41,10 na venda, ≈ 8%).

## 6. E o 1º item que antes era 556,22?

**Com apenas 1 item**: soma 213,31 (< 300) → frete **52,00** inteiro → `cst_entrada` 278,11 → venda **556,22**.

**Ao adicionar o 2º item**, o frete **recalculou para menos** (faixa 10% = 42,66) e foi **rateado** → o 1º item **"caiu" de 556,22 para 494,88**.

> Não é erro: é o frete da Kapazi reagindo ao custo total do orçamento.

## 7. O que acontece ao excluir um item?

Ao **excluir o 2º item**, o recálculo faz o caminho inverso:
- Soma dos custos volta para **213,31** (< 300) → frete volta para **52,00**.
- O item restante recebe o frete inteiro: `226,11 + 52,00 = 278,11`.
- Venda: `278,11 × 2 = 556,22`.

**Resultado**: cabeçalho **e** item mostram **556,22** (sempre consistentes, graças ao `itemS` recalculado no endpoint de exclusão).

## 8. Totais finais (2 itens)

```
cst_tot = 247,44 + 247,44 = 494,88
vnd_tot = 494,88 + 494,88 = 989,76
luc_tot = 989,76 − 494,88 = 494,88
markup_efetivo = 100%
valor_difal_tot = 12,80 + 12,80 = 25,60
vlr_custo_fiscal_tot = 226,11 + 226,11 = 452,22
```
