// Calcular o prazo de entrega
function fcalcularPrazo {
  input {
    json itens?
  }

  stack {
    api.lambda {
      code = """
          const prazos = {
            "Acabado": { texto: "Prazo de entrega 7 a 10 dias úteis", max: 10 },
            "Personalizado Padrão": { texto: "Prazo de entrega 7 a 10 dias úteis", max: 10 },
            "Acabado Personalizado": { texto: "Prazo de entrega 7 a 10 dias úteis", max: 10 },
            "Personalizado": { texto: "Prazo de entrega 10 a 15 dias úteis", max: 15 },
          };
        
          const itens = $input.itens;
        
          // Pega todas as classificações
          const classificacoes = itens.map(item => 
            item?._produto?.[0]?._classificacao?.nome
          ).filter(Boolean);
        
          // Remove duplicadas
          const unicas = [...new Set(classificacoes)];
        
          // Identifica o maior prazo
          let maiorPrazo = 0;
          let textoFinal = "";
        
          unicas.forEach(nome => {
            const prazo = prazos[String(nome)];
            if (prazo && prazo.max > maiorPrazo) {
              maiorPrazo = prazo.max;
              textoFinal = prazo.texto;
            }
          });
        
          return textoFinal || "Prazo não definido";
        """
      timeout = 10
    } as $prazo
  }

  response = $prazo
  tags = ["orcamento"]
  guid = "-xBhDMMa3Jnsg16gfiDXpcmCvr4"
}