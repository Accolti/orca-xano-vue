// Indica se o usuário tem o serviço de COMISSÕES habilitado, resolvendo pela
// empresa efetiva (topo da cadeia). Hoje: plano "plus" habilita. Estender aqui
// quando houver novos planos (ex.: "pro") ou uma tabela Plano com features.
function f_tem_comissoes {
  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    function.run f_perfil_efetivo {
      input = {user_id: $input.user_id}
    } as $perf
  
    var $tem {
      value = false
    }
  
    conditional {
      if ($perf.plano == "plus") {
        var.update $tem {
          value = true
        }
      }
    }
  }

  response = $tem
  tags = ["comissao", "plano", "f3"]
  guid = "f-tem-comissoes-plano-0001"
}