query Ret_TabeFilhas verb=GET {
  api_group = "Default"

  input {
    int id_organizacao?
    int id_material?
  }

  stack {
    function.run Ret_TabMaeEFilhas {
      input = {
        id_material   : $input.id_material
        id_organizacao: $input.id_organizacao
      }
    } as $func_1
  }

  response = {func_1: $func_1}
  guid = "5ZJyX8mYuRayRPacyb6j0u66VIA"
}