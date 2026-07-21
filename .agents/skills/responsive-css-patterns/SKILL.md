# Responsive CSS Patterns (Orca Xano Vue)

## Breakpoints

| Viewport | Breakpoint | Device |
|---|---|---|
| Mobile | `< 640px` | Smartphones |
| Tablet | `640px – 1023px` | Tablets em portrait/landscape |
| Desktop | `>= 1024px` | Notebooks/desktops |

Auth forms usam um breakpoint extra `480px` para empilhamento de campos.

## Padrões

### 1. Tabela → Card List em mobile

Em `< 640px` a tabela é escondida (`display: none`) e uma `.card-list` com `.cliente-card` aparece. Cada card tem header (nome + ID), info rows (label + valor), e botões de ação.

```css
.tabela-wrapper { display: block; overflow-x: auto; }
.card-list     { display: none; }

@media (max-width: 639px) {
  .tabela-wrapper { display: none; }
  .card-list      { display: flex; flex-direction: column; gap: 0.75rem; }
}
```

### 2. Field-rows empilháveis

Usar `flex-direction: column` em mobile. Os `.field` filhos naturalmente ocupam 100% da largura via `align-items: stretch`.

```css
.field-row { display: flex; gap: 0.75rem; }

@media (max-width: 639px) {
  .field-row { flex-direction: column; gap: 0; }
}
```

### 3. Modal bottom-sheet em mobile

Em `< 640px` o modal desliza de baixo, ocupa quase a tela toda:

```css
@media (max-width: 639px) {
  .modal-overlay {
    padding: 0;
    align-items: flex-end;
  }
  .modal-card {
    max-height: 95vh;
    border-radius: 12px 12px 0 0;
  }
  .modal-header,
  .modal-body,
  .modal-footer {
    padding: 1rem;
  }
}
```

### 4. Tabela com scroll horizontal (tablet)

Entre `640px` e `1023px` a tabela mantém o formato tabela mas com scroll horizontal:

```css
.tabela-wrapper { overflow-x: auto; }
.tabela-clientes { min-width: 640px; }
```

### 5. Global padding

```css
#app { padding: 1rem; }
@media (min-width: 768px) { #app { padding: 2rem; } }
```

Auth cards reduzem padding em mobile:

```css
@media (max-width: 480px) {
  .auth-card { padding: 1.5rem 1.25rem; }
}
```

### 6. Botão hamburger (menu toggle)

Tamanho `44px` em mobile (alvo de toque ≥ 44px), `40px` em desktop:

```css
.menu-toggle { width: 44px; height: 44px; }
@media (min-width: 768px) { .menu-toggle { width: 40px; height: 40px; } }
```

## Referência

- `src/views/ClientesView.vue` — tabela + card list
- `src/components/ClienteModal.vue` — field-rows + bottom-sheet
- `src/views/SignupView.vue` — field-row empilhado
- `src/App.vue` — menu-toggle responsivo
- `src/assets/main.css` — padding global
