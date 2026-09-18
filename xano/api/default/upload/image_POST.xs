query "upload/image" verb=POST {
  api_group = "Default"

  input {
    file content?
  }

  stack {
    storage.create_image {
      value = $input.content
      access = "public"
    } as $image
  }

  response = $image
  guid = "nfMOC46x-JII4wimleig9NmOc4Y"
}