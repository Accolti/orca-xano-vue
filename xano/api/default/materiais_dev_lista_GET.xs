// Lista TODOS os materiais (ativos e inativos) com os campos da tabela Material —
// usada pela tela de cadastro de materiais (dev tool, auth User).
// Isolado do f_material_todos (que filtra ativo) para permitir reativar materiais.
query materiais_dev_lista verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Material {
      sort = {id: "asc"}
      eval = {material_pai_id: $db.Material.material_id}
      return = {type: "list"}
      output = [
        "id"
        "nome"
        "Ordenacao"
        "created_at"
        "ativo"
        "descricao"
        "garantia"
        "ncm"
        "imp"
        "ipi"
        "peso"
        "regra_fiscal_id"
        "st"
        "mva_padrao"
        "aliq_st_interna"
        "nac"
        "Observacao"
        "importado"
        "organizacao_id"
        "updated_at"
        "material_pai_id"
      ]
    } as $materiais
  }

  response = $materiais
  guid = "OrcaKap-materiais-dev-lista"
}