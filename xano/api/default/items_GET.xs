// Query all Items records
query items verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query "" {
      return = {type: "list"}
    } as $items
  }

  response = $items
  guid = "3h7AhKnD7DlCqkWzXM5hIS4X_H8"
}