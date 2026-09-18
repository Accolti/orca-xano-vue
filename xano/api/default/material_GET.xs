// Query all material records
// 5. Retorna os materiais originais e o objeto montado no Lambda
query material verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    function.run f_material_todos as $func_1
  }

  response = $func_1
  guid = "u_dzdzS3ajaTCoVUseLUSQx9TXI"
}