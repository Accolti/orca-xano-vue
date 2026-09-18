// novo-sis: retorna o ControlePedido (dados Kapazi/faturamento) de uma Orca convertida em pedido.
// Retorna null quando ainda não existe registro — o frontend cria no primeiro salvar.
query controle_pedido_por_orca verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.query ControlePedido {
      where = $db.ControlePedido.orca_id == $input.orca_id
      sort = {ControlePedido.id: "asc"}
      return = {type: "list"}
    } as $controleLista
  
    var $controle {
      value = $controleLista|first
    }
  }

  response = $controle
  tags = ["orcamento", "novo-sis", "pedido"]
  guid = "controle-pedido-por-orca-novo-sis-0001"
}