// banco provedor de taxas 
table Provedor {
  auth = false

  schema {
    int id
  
    // Nome do banco provedor
    text nome? filters=trim
  
    // URL pública das taxas (para coleta automática futura)
    text url_taxas? filters=trim
  
    // Como obter as taxas: manual | api | scrape
    text metodo?=manual filters=trim
  
    // Canal padrão do provedor: cartao_link | cartao_celular | cartao_pos (null = todos)
    text canal_default? filters=trim
  
    // Mapeamento para coleta (seletores/regex) — json
    json seletor?
  
    // Última coleta automática
    timestamp ultima_coleta?
  
    bool ativo?=true
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  tags = ["novo-sis"]
  guid = "bpE8t68AW4RHXUFLofvXEX_Bpjc"
}