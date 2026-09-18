function f_produtos_selecao {
  input {
  }

  stack {
    function.run f_material_todos as $Material1
    db.query Linha {
      return = {type: "list"}
      addon = [
        {
          name  : "Material"
          output: ["nome"]
          input : {Material_id: $output.material_id}
          as    : "_material"
        }
      ]
    } as $Linha1
  
    db.query Tipo {
      return = {type: "list"}
      addon = [
        {
          name  : "Material"
          output: ["nome"]
          input : {Material_id: $output.material_id}
          as    : "_material"
        }
      ]
    } as $Tipo1
  
    db.query Nivel {
      return = {type: "list"}
      addon = [
        {
          name  : "Material"
          output: ["nome"]
          input : {Material_id: $output.material_id}
          as    : "_material"
        }
        {
          name  : "Linha"
          output: ["nome"]
          input : {Linha_id: $output.linha_id}
          as    : "_linha"
        }
        {
          name  : "Tipo"
          output: ["nome"]
          input : {Tipo_id: $output.tipo_id}
          as    : "_tipo"
        }
      ]
    } as $Nivel1
  
    db.query Borda {
      where = $db.Borda.ativo == true
      return = {type: "list"}
      addon = [
        {
          name  : "Material"
          output: ["nome"]
          input : {Material_id: $output.material_id}
          as    : "_material"
        }
      ]
    } as $Borda1
  }

  response = {
    Material : $Material1
    Linha    : $Linha1
    Tipo     : $Tipo1
    Nivel    : $Nivel1
    Borda    : $Borda1
    !Variacao: $Variacao1
  }

  guid = "mAlgGIpKYm8HB3NfJ2kQwR7kq3w"
}