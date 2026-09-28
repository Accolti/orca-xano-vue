/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_XANO_BASE_URL?: string
  readonly VITE_SUPABASE_URL?: string
  readonly VITE_SUPABASE_ANON_KEY?: string
  readonly VITE_BACKEND?: 'xano' | 'supabase'
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
