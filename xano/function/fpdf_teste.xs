function FpdfTeste {
  input {
  }

  stack {
    !db.get Teste {
      field_name = "id"
      field_value = 1
    } as $Teste1
  
    !var $html {
      value = $Teste1.html
    }
  
    !debug.stop {
      value = $html
    }
  
    api.lambda {
      code = """
        const pdf = await import("npm:html-pdf-node");
        
        // Cria o HTML
        let html = `
        <html>
        <head>
        <meta charset="UTF-8">
        <title>Lista de Contatos</title>
        <style>
        body { font-family: Arial, sans-serif; background-color: #f2f2f2; margin: 50px; }
        h1 { text-align: center; color: #333; }
        table { width: 50%; margin: 20px auto; border-collapse: collapse; background-color: #fff; box-shadow: 0px 2px 5px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #ccc; padding: 10px; text-align: left; }
        th { background-color: #007BFF; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        </style>
        </head>
        <body>
        <h1>Lista de Contatos</h1>
        <table>
        <tr><th>Nome</th><th>Telefone</th></tr>
        <tr><td>Maria Oliveira</td><td>(11) 98765-4321</td></tr>
        <tr><td>João Silva</td><td>(21) 99888-1122</td></tr>
        <tr><td>Ana Santos</td><td>(31) 97777-3344</td></tr>
        <tr><td>Pedro Costa</td><td>(41) 96666-7788</td></tr>
        <tr><td>Lucas Almeida</td><td>(51) 95555-9900</td></tr>
        </table>
        </body>
        </html>
        `;
        
        // Opções do PDF
        let options = { format: 'A4' };
        
        // Cria o PDF a partir do HTML
        let file = { content: html };
        let pdfBuffer = await pdf.generatePdf(file, options);
        
        // Retorna o PDF como arquivo
        return {
          path: 'lista_de_contatos.pdf',
          data: pdfBuffer
        };
        """
      timeout = 10
    } as $x1
  
    var.update $x1 {
      value = "data:application/pdf;base64,"|concat:$x1:""
    }
  
    storage.create_file_resource {
      filename = "pdf.pdf"
      filedata = $x1
    } as $file1
  
    // https://www.youtube.com/watch?v=H_c1mb7k0v0
    // veja esse video - precisa ter a versão paga do xano
    debug.stop {
      value = $x1
    }
  }

  response = $x1
  guid = "eOqmZF0WJVuEjHPQkPcJdFaIT6o"
}