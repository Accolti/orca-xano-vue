// Calcula a precificação de um orçamento 
// 
// Endpoint POST para simulação, criação e recálculo de orçamentos em tempo real no front-end. Recebe as dimensões do produto (largura, comprimento/área), adicionais (borda, variação), quantidade e markup, repassando os dados ao f_Orcamento_Orquestrador com o user_id autenticado.
// 
// regra: a entrada comprimento_ou_area é duplo ou seja pode receber o compromemnto ou a área . O o sistema reconhece  que é a área quando a largura for informaca com 0. Então se comprimento e largura forem >0 não tem area envolvida na entrada desta api
// 
// Retorno:
// Estrutura unificada com o detalhamento dos itens e os totais consolidados com impostos ({ itens: [...], totais: {...} }).
// 
// Uso do parâmetro orca_id:
// 
// Essa função está calculando um orçamento e temos o freteb2b  que vai seguir a regra segundo a função fCalculaFrete. Quando tem insidencia de frete,  ele  precisa ser rateado entre todos os itens. A orca_id é a chave que vai trazer a informação do somatório dos seus itens filhos.
// 
// orca_id > 0 (ex: 123): Recalcula ou atualiza um orçamento já existente.
// 
// orca_id = 0 (ou null): Cria um orçamento do zero ou gera uma simulação rápida.
query orcamento_calcular verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int produto_id? {
      table = "Produto"
    }
  
    int borda_id? {
      table = "Borda"
    }
  
    int variacao_id? {
      table = "Variacao"
    }
  
    decimal markup?
    decimal largura?
    decimal comprimento_ou_area?
    decimal quantidade?
    int orca_id? {
      table = "Orca"
    }
  
    // Item em edição (0/ausente = item novo) — excluído do somatório do frete
    int item_id? {
      table = "item"
    }
  
    // Vendedor marcou medida exata → aplica porcentagem_acrescimo do produto no custo
    bool com_medida_exata?
  
    // Produto composto (COMPOSTO): lados do perímetro com rampa e cantos
    bool rampa_larg1?
  
    bool rampa_comp1?
    bool rampa_larg2?
    bool rampa_comp2?
    int qtd_cantos?
  }

  stack {
    // Reforço: bloqueia quem foi desativado (o próprio ou um "pai") após o login
    function.run f_ativo_efetivo {
      input = {user_id: $auth.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    function.run f_Orcamento_Orquestrador {
      input = {
        produto_id         : $input.produto_id
        borda_id           : $input.borda_id
        variacao_id        : $input.variacao_id
        comprimento_ou_area: $input.comprimento_ou_area
        largura            : $input.largura
        quantidade         : $input.quantidade
        markup             : $input.markup
        user_id            : $auth.id
        orca_id            : $input.orca_id
        item_id            : $input.item_id
        com_medida_exata   : $input.com_medida_exata
        rampa_larg1        : $input.rampa_larg1
        rampa_comp1        : $input.rampa_comp1
        rampa_larg2        : $input.rampa_larg2
        rampa_comp2        : $input.rampa_comp2
        qtd_cantos         : $input.qtd_cantos
      }
    } as $func1
  }

  response = $func1
  guid = "-LESmOdWoPkROY8hxjDXZA"
}