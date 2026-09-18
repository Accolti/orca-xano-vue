query Gerar_Texto_Orcamento_Whatsapp verb=GET {
  api_group = "Default"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    bool bfaturar?
  }

  stack {
    function.run Texto_Envio_WhatsApp {
      input = {orca_id: $input.orca_id, bfatura: $input.bfaturar}
    } as $textowhats
  }

  response = $textowhats
  tags = ["orcamento", "whatsapp"]
  guid = "TgU9nvU3AvmLBSfvFBNLoiTP6Z0"
}