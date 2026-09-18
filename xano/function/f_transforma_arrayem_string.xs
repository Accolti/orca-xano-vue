// REBIND-CHAIN: importar junto com os callers para re-resolver function.run
function f_transformaArrayemString {
  input {
    text[] Array? filters=trim
  }

  stack {
    api.lambda {
      code = """
        function transformarArrayEmString(arr) {
          return arr.filter(Boolean).join(' ');
        }
        
        const arr = $input.Array;
        return transformarArrayEmString(arr);
        """
      timeout = 10
    } as $descricao
  }

  response = $descricao
  guid = "26lmfYKNueIsKde5s1PPb4BUliM"
}