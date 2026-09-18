// Add nivel record
query nivel verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Nivel"
    }
  }

  stack {
    db.add Nivel {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $nivel
  }

  response = $nivel
  guid = "QeUN8Y8ghfPmPCRcVLx0F3PN3_c"
}