// Ajusta as dimensões comp/larg conforme o fator de corte.
// REBIND-CHAIN: importar junto com os callers para re-resolver function.run
// modo_corte = "lista" (padrão): usa fc[] (múltiplos fixos, ex.: Vinil) — arredonda ao
// menor múltiplo >= dimensão e mantém a dimensão original se passar do maior valor.
// modo_corte = "passo": usa passo (comp_corte, ex.: 0.5) — arredonda SEMPRE para cima
// ao múltiplo (ex.: 1.23 → 1.50). Usado quando o fornecedor fraciona em medidas fixas.
function f_retorna_fc {
  input {
    decimal comp?
    decimal larg?
    decimal[] fc?
    enum modo_corte?=lista {
      values = ["lista", "passo"]
    }
  
    decimal passo?
  }

  stack {
    api.lambda {
      code = """
        const comp = Number($input.comp) || 0;
        const larg = Number($input.larg) || 0;
        const FC = $input.fc || [];
        const modoCorte = $input.modo_corte || 'lista';
        const passo = Number($input.passo) || 0;
        
        // MODO PASSO: arredonda sempre para cima ao múltiplo do passo
        if (modoCorte === 'passo' && passo > 0) {
          const roundUp = (v) => (v > 0 ? Math.ceil(v / passo) * passo : 0);
          return { new_comp: roundUp(comp), new_larg: roundUp(larg) };
        }
        
        // MODO LISTA (comportamento original)
        if (!FC.length) {
          return { new_comp: comp, new_larg: larg };
        }
        
        const fc_max = FC[FC.length - 1];
        const larg_maior = FC.find(v => v >= larg) || 0;
        const comp_maior = FC.find(v => v >= comp) || 0;
        
        if (comp > fc_max && larg > fc_max) {
          return { new_comp: comp, new_larg: larg };
        }
        
        if (comp_maior && larg_maior) {
          return (comp_maior * larg > larg_maior * comp)
            ? { new_comp: comp, new_larg: larg_maior }
            : { new_comp: comp_maior, new_larg: larg };
        }
        
        return (comp_maior === 0)
          ? { new_comp: comp, new_larg: larg_maior }
          : { new_comp: comp_maior, new_larg: larg };
        """
      timeout = 10
    } as $newFC
  }

  response = $newFC
  guid = "L0c8hiR7qB9CxkhOLf1G6THw1yw"
}