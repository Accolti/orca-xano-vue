// Add material record
query material verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Material"
    }
  }

  stack {
    db.add Material {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $material
  }

  response = $material
  guid = "Mr70qgF6nY6OUPFGi5F_HOT8bYA"
}