// Taxas de cartão efetivas do usuário logado. As taxas da EMPRESA (dono da conta)
// têm precedência; a tabela global (user_id = null) serve de fallback. Cada linha
// traz o canal (cartao_link | cartao_celular | cartao_pos | null = genérico) e a
// origem (manual | api | scrape). O front filtra por canal e resolve empresa→global.
query taxas_banco verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    function.run f_empresa_id {
      input = {user_id: $auth.id}
    } as $empresa_id
  
    db.query Taxa_Banco {
      join = {
        Provedor: {
          table: "Provedor"
          where: $db.Provedor.id == $db.Taxa_Banco.provedor_id
        }
      }
    
      where = $db.Taxa_Banco.ativo == true && ($db.Taxa_Banco.user_id == $empresa_id || $db.Taxa_Banco.user_id == null || $db.Taxa_Banco.user_id == 0)
      sort = {Taxa_Banco.parcelas: "asc"}
      eval = {provedor: $db.Provedor.nome}
      return = {type: "list"}
      output = ["id", "provedor_id", "parcelas", "cc_taxa", "provedor", "canal", "origem", "user_id"]
    } as $model
  }

  response = $model
  tags = ["novo-sis", "taxas"]
  guid = "3RAof8tAyzvGQCtazPvsephq3Cs"
}
