# Xano SDK — Extração de Erros

## Problema

`@xano/js-sdk` retorna a mensagem genérica `"There was an error with your request"` em vez do `message` real do backend.

## Causa

A SDK encapsula o erro em `XanoRequestError`. O `err.message` é fixo. O body real está em `err.getResponse().getBody()`.

## Solução (padrão para qualquer catch)

```typescript
catch (err: any) {
  const body = err?.getResponse?.()?.getBody?.()
  const mensagem = body?.message || err?.message || 'Erro inesperado'
  const payload = body?.payload
  erro.value = payload ? `${mensagem} (${payload})` : mensagem
}
```

## Alternativa com `XanoRequestError`

```typescript
import { XanoRequestError } from '@xano/js-sdk'

catch (err) {
  if (err instanceof XanoRequestError) {
    const body = err.getResponse().getBody()
    // body = { code, message, payload }
    console.log(body.message, body.payload)
  }
}
```

## Aplica-se a

- `xano.get()`, `xano.post()`, `xano.put()`, `xano.patch()`, `xano.delete()`
- Qualquer endpoint Xano que retorne 4xx/5xx com `{ message, payload }`
