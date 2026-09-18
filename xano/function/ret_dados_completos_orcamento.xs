// Criar Json para gerar PDF 
function ret_Dados_Completos_Orcamento {
  input {
    text orca_codigo? filters=trim
    decimal new_margem?
  }

  stack {
    function.run Orcamento_Detalhes_Function {
      input = {
        orca_codigo: $input.orca_codigo
        newMargem  : $input.new_margem
      }
    } as $func_1
  }

  response = $func_1
  guid = "vS6VvIO0Efs48LmMlVANArxokds"
}