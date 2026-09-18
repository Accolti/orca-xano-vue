function Cliente_Inserir {
  input {
    text nome_fantasia? filters=trim
    text razao_social? filters=trim
    text contato? filters=trim
    text cpf? filters=trim
    text cnpj? filters=trim
    text inscricao_estadual? filters=trim
    email email?
    bool contrinui_icms?
    bool isento?
    text observacao? filters=trim
    int user_id? {
      table = "User"
    }
  
    text logradouro? filters=trim
    text numero? filters=trim
    text complemento? filters=trim
    text bairro? filters=trim
    text cidade? filters=trim
    text uf? filters=trim
    text[:3] telefone? filters=trim
    text cep? filters=trim
  }

  stack {
    db.transaction {
      stack {
        db.add Cliente {
          enforce_hidden_fields = false
          data = {
            created_at         : "now"
            endereco_cliente_id: 0
            nome_fantasia      : $input.nome_fantasia
            razao_social       : $input.razao_social
            contato            : $input.contato
            cpf                : $input.cpf
            cnpj               : $input.cnpj
            inscricao_estadual : $input.inscricao_estadual
            "e-mail"           : $input.email
            contribui_icms     : $input.contrinui_icms
            isento             : $input.isento
            observacao         : $input.observacao
            user_id            : $input.user_id
          }
        } as $Cliente_1
      
        var $id_cliente {
          value = $Cliente_1.id
        }
      
        var $tipo_endereco {
          value = ""
        }
      
        conditional {
          if (($input.cnpj|is_null) == false) {
            var.update $tipo_endereco {
              value = "Comercial"
            }
          }
        
          else {
            conditional {
              if (($input.cpf|is_null) == false) {
                var.update $tipo_endereco {
                  value = "Residencial"
                }
              }
            }
          }
        }
      
        db.add Endereco_Cliente {
          enforce_hidden_fields = false
          data = {
            created_at : "now"
            cliente_id : $id_cliente
            Tipo       : $tipo_endereco
            endereco   : $input.logradouro
            numero     : $input.numero
            complemento: $input.complemento
            cep        : $input.cep
            bairro     : $input.bairro
            cidade     : $input.cidade
            estado     : $input.uf
          }
        } as $Endereco_Cliente_1
      
        db.edit Cliente {
          field_name = "id"
          field_value = $id_cliente
          enforce_hidden_fields = false
          data = {
            endereco_cliente_id: $Endereco_Cliente_1.id
            nome_fantasia      : $input.nome_fantasia
            razao_social       : $input.razao_social
            contato            : $input.contato
            cpf                : $input.cpf
            cnpj               : $input.cnpj
            inscricao_estadual : $input.inscricao_estadual
            isento             : $input.isento
            observacao         : $input.observacao
            user_id            : $input.user_id
          }
        } as $Cliente_3
      
        foreach ($input.telefone) {
          each as $item {
            db.add Telefone_Cliente {
              enforce_hidden_fields = false
              data = {
                created_at: "now"
                telefone  : $item
                cliente_id: $id_cliente
              }
            } as $Telefone_Cliente_1
          }
        }
      }
    }
  }

  response = $Cliente_1
  guid = "zHP4w2DmzfJ62FeREzbkhuUPbdI"
}