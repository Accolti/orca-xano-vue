// Versão filtrada do Ret_TabMaeEFilhas_2.
// Conta as opções (Linha, Tipo, Nivel, Borda, Variacao) disponíveis para um
// material CONSIDERANDO a seleção atual de linha/tipo. Quando linha_id ou
// tipo_id são informados, apenas os produtos que batem com a seleção entram
// na contagem — assim o frontend esconde dropdowns que não fazem sentido para
// a combinação atual (ex.: Fibra de Coco Liso não tem Nivel, mas Personalizado tem).
function Ret_Suc_Filtrado {
  input {
    int material_id?
    int linha_id?
    int tipo_id?
    int organizacao_id?
  }

  stack {
    db.query Produto {
      join = {
        Material: {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.Material.id ==? $db.Borda.material_id && $db.Borda.ativo == true
        }
        Detalhe : {
          table: "Detalhe"
          type : "left"
          where: $db.Produto.detalhe_id ==? $db.Detalhe.id
        }
        Variacao: {
          table: "Variacao"
          type : "left"
          where: $db.Detalhe.id ==? $db.Variacao.detalhe_id
        }
      }
    
      where = $db.Produto.material_id ==? $input.material_id && $db.Produto.linha_id ==? $input.linha_id && $db.Produto.tipo_id ==? $input.tipo_id && $db.Produto.ativo == true
      eval = {
        Linha   : $db.Linha.nome
        Tipo    : $db.Tipo.nome
        Nivel   : $db.Nivel.nome
        Borda   : $db.Borda.nome
        Variacao: $db.Variacao.id
      }
    
      return = {
        type : "aggregate"
        group: {Material_id: $db.Produto.material_id}
        eval : {
          Linha   : $db.Linha|count_distinct
          Tipo    : $db.Tipo|count_distinct
          Nivel   : $db.Nivel|count_distinct
          Borda   : $db.Borda|count_distinct
          Variacao: $db.Variacao|count_distinct
        }
      }
    
      output = ["Material_id", "Linha", "Tipo", "Nivel", "Borda", "Variacao"]
    } as $Material_1
  }

  response = {Material_1: $Material_1}
  guid = "vy1FnR9TlKZuUB-JWtegKg"
}