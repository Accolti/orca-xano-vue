function AtualizaStatus_Pedido {
  input {
  }

  stack {
    db.query Orca {
      where = $db.Orca.eh_pedido > false
      return = {type: "list"}
    } as $Orca1
  
    foreach ($Orca1) {
      each as $item {
        db.edit Orca {
          field_name = "id"
          field_value = $item.id
          data = {
            status     : ""
            regime_id  : 1
            uf_origem  : "PR"
            uf_destino : "SP"
            markup_alvo: $item.margem
          }
        } as $Orca2
      }
    }
  }

  response = $Orca1
  guid = "AJ6z1f4z4lOJBYh5JeYq4wERcAI"
}