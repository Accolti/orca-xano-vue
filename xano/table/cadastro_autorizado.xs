// Allowlist de cadastros (cadastro por convite). O dono insere nesta tabela os
// e-mails autorizados a criar conta via auth/signup. Substitui o cadastro aberto;
// quando o fluxo híbrido (conta pendente → aprovação) existir, esta regra evolui.
table Cadastro_Autorizado {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    email email?
  
    // Observação opcional (ex.: nome do piloto / quem convidou)
    text obs? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email", op: "asc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "cadastro-autorizado-0001"
}