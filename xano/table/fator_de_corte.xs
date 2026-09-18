table Fator_de_Corte {
  auth = false

  schema {
    int id
    text nome? filters=trim
    timestamp created_at?=now {
      visibility = "private"
    }
  
    decimal[] valor?
  
    // Largura Multiplo
    decimal larg_base?
  
    decimal comp_corte?
  
    // Tamanho tota em metro dos rolo
    decimal tam_total?
  
    // Como o corte é aplicado:
    // - lista: usa valor[] (múltiplos fixos, ex.: Vinil) — arredonda ao menor múltiplo >= dimensão
    //          e mantém a dimensão original se passar do maior valor da lista.
    // - passo: usa comp_corte como passo (ex.: 0.5) — arredonda SEMPRE para cima ao múltiplo
    //          (ex.: 1.23 → 1.50). Usado quando o fornecedor fraciona em medidas fixas.
    enum modo_corte?=lista {
      values = ["lista", "passo"]
    }
  
    text obs? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "klPt_SiTMgn-ie0X7RGuGDzo-_4"
}