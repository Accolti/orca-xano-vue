import { XanoClient } from '@xano/js-sdk'

const baseUrl = import.meta.env.DEV ? '/' : import.meta.env.VITE_XANO_BASE_URL

export const xano = new XanoClient({
  instanceBaseUrl: baseUrl,
})
