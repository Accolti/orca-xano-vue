function f_get_CNPJ {
  input {
    text cnpj? filters=trim
  }

  stack {
    api.request {
      url = "https://api.cnpja.com/office/"|concat:$input.cnpj:""
      method = "GET"
      headers = []
        |push:"Accept: application/json"
        |push:("Authorization:"|concat:$env.cnpj_ja:" ")
    } as $CNPJ
  
    !debug.stop {
      value = $CNPJ
    }
  
    api.request {
      url = "https://api.cnpja.com/ccc"
      method = "GET"
      params = {}
        |set:"states":"SP"
        |set:"taxId":$input.cnpj
      headers = []
        |push:"Accept: application/json"
        |push:("Authorization:"|concat:$env.cnpj_ja:" ")
    } as $IE
  
    !debug.stop {
      value = $IE
    }
  
    api.lambda {
      code = """
        function limparCNPJ(cnpj) {
          if (!cnpj) return null;
        
          // garante que é string antes de aplicar replace
          return String(cnpj).replace(/[^0-9]/g, "");
        }
        
        //let teste = limparCNPJ($var.CNPJ);
        
        let cnpj_json = $var.CNPJ;
        let ie_json = $var.IE;
        
        
        
         try {
            const statusCNPJ = cnpj_json?.response?.status || null;
            const statusIE = ie_json?.response?.status || null;
        
            // Se status do CNPJ for diferente de 200 → retorna erro
            if (statusCNPJ !== 200) {
              return {
                statusCNPJ,
                errorCNPJ: {
                  code: cnpj_json?.response?.code || 400,
                  message: cnpj_json?.response?.message || "request validation failed",
                  constraints: cnpj_json?.response?.constraints || [
                    "taxId must be a string that obeys cnpj verification algorithm"
                  ]
                }
              };
            }
        
            // Se status da IE for diferente de 200 → retorna erro
            if (statusIE !== 200) {
              return {
                statusIE,
                errorIE: {
                  code: ie_json?.response?.code || 400,
                  message: ie_json?.response?.message || "request validation failed",
                  constraints: ie_json?.response?.constraints || [
                    "state registration invalid or not found"
                  ]
                }
              };
            }
        
            const cnpjData = cnpj_json?.response?.result;
            const ieData = ie_json?.response?.result;
        
            // Endereço estruturado
            const endereco = cnpjData.address
              ? {
                  rua: cnpjData.address.street || null,
                  numero: cnpjData.address.number || null,
                  complemento: cnpjData.address.details || null,
                  bairro: cnpjData.address.district || null,
                  cidade: cnpjData.address.city || null,
                  estado: cnpjData.address.state || null,
                  cep: cnpjData.address.zip || null,
                  pais: cnpjData.address.country?.name || null
                }
              : null;
        
            // Telefones estruturados
            const telefones = cnpjData.phones?.length
              ? cnpjData.phones.map(t => ({
                  tipo: t.type || null,
                  ddd: t.area || null,
                  numero: t.number || null
                }))
              : [];
        
            // Emails (todos)
            const emails = cnpjData.emails?.length
              ? cnpjData.emails.map(e => e.address)
              : [];
        
            // Pega inscrição estadual ativa (enabled = true)
            const inscricaoEstadualAtiva = ieData?.registrations?.find(r => r.enabled === true) || null;
        
            // Retorno final
            return {
              statusCNPJ,
              statusIE,
              cnpj: cnpjData.taxId || null,
              razaoSocial: cnpjData.company?.name || null,
              nomeFantasia: cnpjData.alias || null,
              enderecoCompleto: endereco,
              telefones: telefones,
              emails: emails,
              inscricaoEstadual: inscricaoEstadualAtiva,
              IE: inscricaoEstadualAtiva ? inscricaoEstadualAtiva.number : null,
              estadoOrigem: ieData?.originState || null
            };
        
          } catch (error) {
            console.error("Erro ao capturar dados importantes:", error.message);
            return null;
          }
        """
      timeout = 10
    } as $dados
  }

  response = $dados
  guid = "2SdA9JFaOgxzT17qkDezQRTH7H0"
}