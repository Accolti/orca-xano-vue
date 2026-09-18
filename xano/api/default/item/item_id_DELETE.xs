// Delete item record.
query "item/{item_id}" verb=DELETE {
  api_group = "Default"

  input {
    int item_id? filters=min:1
  }

  stack {
    db.get item {
      field_name = "id"
      field_value = $input.item_id
    } as $item_1
  
    db.transaction {
      stack {
        db.del item {
          field_name = "id"
          field_value = $input.item_id
        }
      
        function.run Orcamento_Detalhes_Function {
          input = {
            orca_codigo: ""
            newMargem  : ""
            orca_id    : $item_1.orca_id
          }
        } as $func_1
      
        db.add_or_edit Orca {
          field_name = "id"
          field_value = $item_1.orca_id
          enforce_hidden_fields = false
          data = {
            margem         : $func_1.margem_tot
            cst_tot        : $func_1.tot_cst_total
            luc_tot        : $func_1.tot_lucro
            vnd_tot        : $func_1.tot_vnd_total
            vnd_B2B_tot    : $func_1.tot_vnd_total_b2b
            vnd_B2B_B2C_tot: $func_1.tot_vnd_total_b2b_b2c
            desconto       : $func_1.desconto
          }
        } as $Orca_1
      }
    }
  }

  response = $[""]
  guid = "H6XkTSUOTnz83VSFBhfiGcoNnTU"
}