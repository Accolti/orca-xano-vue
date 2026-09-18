// Cadastro de Material (dev tool, auth User).
// Cria (sem id) ou edita (com id) um material com os campos da tabela Material.
query material_cadastrar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int material_id? {
      table = "Material"
    }
  
    text nome? filters=trim
  
    // prioridade para ordenação
    decimal Ordenacao?
  
    int material_pai_id? {
      table = "Material"
    }
  
    bool ativo?=true
    text descricao? filters=trim
  
    // Tempo de garantia em meses
    int garantia?
  
    text ncm? filters=trim
  
    // Imposto
    decimal imp?
  
    decimal ipi?
    decimal peso?
    int regra_fiscal_id?=1 {
      table = "Regra_Fiscal"
    }
  
    bool st?
  
    // % de MVA da Kapazi/SEFAZ (ex: 40.0 para 40%).
    decimal mva_padrao?
  
    // % da alíquota interna ICMS do destino de referência (ex: 18.0 para 18%).
    decimal aliq_st_interna?
  
    bool nac?
    text Observacao? filters=trim
  
    // se é importado ou não
    bool importado?
  
    int organizacao_id? {
      table = "Organizacao"
    }
  }

  stack {
    var $salvo {
      value = null
    }
  
    conditional {
      if ($input.material_id != null) {
        db.edit Material {
          field_name = "id"
          field_value = $input.material_id
          enforce_hidden_fields = false
          data = {
            nome           : $input.nome
            Ordenacao      : $input.Ordenacao
            material_id    : $input.material_pai_id
            ativo          : $input.ativo
            descricao      : $input.descricao
            garantia       : $input.garantia
            ncm            : $input.ncm
            imp            : $input.imp
            ipi            : $input.ipi
            peso           : $input.peso
            regra_fiscal_id: $input.regra_fiscal_id
            st             : $input.st
            mva_padrao     : $input.mva_padrao
            aliq_st_interna: $input.aliq_st_interna
            nac            : $input.nac
            Observacao     : $input.Observacao
            importado      : $input.importado
            organizacao_id : $input.organizacao_id
            updated_at     : now
          }
        } as $salvo
      }
    
      else {
        db.add Material {
          enforce_hidden_fields = false
          data = {
            nome           : $input.nome
            Ordenacao      : $input.Ordenacao
            material_id    : $input.material_pai_id
            ativo          : $input.ativo
            descricao      : $input.descricao
            garantia       : $input.garantia
            ncm            : $input.ncm
            imp            : $input.imp
            ipi            : $input.ipi
            peso           : $input.peso
            regra_fiscal_id: $input.regra_fiscal_id
            st             : $input.st
            mva_padrao     : $input.mva_padrao
            aliq_st_interna: $input.aliq_st_interna
            nac            : $input.nac
            Observacao     : $input.Observacao
            importado      : $input.importado
            organizacao_id : $input.organizacao_id
            created_at     : "now"
          }
        } as $salvo
      }
    }
  }

  response = {material_id: $salvo.id, material: $salvo}
  guid = "OrcaKap-material-cadastrar-dev"
}