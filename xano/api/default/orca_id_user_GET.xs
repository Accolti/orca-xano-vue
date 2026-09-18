// Query all Orca records
query orca_id_user verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int cliente_id? {
      table = "Cliente"
    }
  
    text cod_orca? filters=trim
  }

  stack {
    db.query Orca {
      join = {
        Cliente: {
          table: "Cliente"
          type : "left"
          where: $db.Orca.cliente_id ==? $db.Cliente.id
        }
      }
    
      where = $db.Orca.user_id ==? $auth.id && ($db.Cliente.id ==? $input.cliente_id || $db.orca.cod_orca includes? $input.cod_orca)
      sort = {orca.created_at: "desc"}
      eval = {
        nome_fantasia    : $db.Cliente.nome_fantasia
        razao_social     : $db.Cliente.razao_social
        contato          : $db.Cliente.contato
        cpf              : $db.Cliente.cpf
        cnpj             : $db.Cliente.cnpj
        iscricao_estadual: $db.Cliente.inscricao_estadual
        nome             : $db.Cliente.nome_fantasia
        doc              : $db.Cliente.cpf
        tipo_doc         : $db.Cliente.cpf
      }
    
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "cod_orca"
        "cliente_id"
        "frtB2B"
        "frtB2C"
        "validade"
        "user_id"
        "margem"
        "cst_tot"
        "luc_tot"
        "vnd_tot"
        "vnd_B2B_tot"
        "vnd_B2B_B2C_tot"
        "desconto"
        "eh_pedido"
        "nome_fantasia"
        "razao_social"
        "contato"
        "cpf"
        "cnpj"
        "iscricao_estadual"
        "nome"
        "doc"
        "tipo_doc"
      ]
    } as $orca
  
    db.get Contador {
      field_name = "user_id"
      field_value = $auth.id
    } as $Contador_1
  
    !debug.stop {
      value = $orca
    }
  
    foreach ($orca) {
      each as $item {
        var.update $item.created_at {
          value = $item.created_at
            |format_timestamp:"d/m/Y":"America/Sao_Paulo"
        }
      
        var.update $item.validade {
          value = $item.validade
            |format_timestamp:"d/m/Y":"America/Sao_Paulo"
        }
      
        conditional {
          if ($item.eh_pedido) {
            var.update $item.cod_orca {
              value = $item.cod_orca
                |replace:$Contador_1.Inicial:"PED"
            }
          }
        }
      
        conditional {
          if ($item.cnpj|is_empty) {
            var.update $item.doc {
              value = $item.cpf
            }
          
            var.update $item.tipo_doc {
              value = "CPF"
            }
          
            conditional {
              if ($item.nome_fantasia|is_empty) {
                var.update $item.nome {
                  value = $item.contato
                }
              }
            
              else {
                var.update $item.nome {
                  value = $item.nome_fantasia
                }
              }
            }
          }
        
          else {
            var.update $item.doc {
              value = $item.cnpj
            }
          
            var.update $item.tipo_doc {
              value = "CNPJ"
            }
          
            conditional {
              if ($item.nome_fantasia|is_empty) {
                var.update $item.nome {
                  value = $item.razao_social
                }
              }
            }
          }
        }
      }
    }
  }

  response = $orca
  guid = "oh_dy-0BbEYWHBpfDO-hYuXpCA0"
}