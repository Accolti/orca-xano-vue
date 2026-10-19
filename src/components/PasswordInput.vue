<script setup lang="ts">
import { ref, computed } from 'vue'

const props = withDefaults(
  defineProps<{
    modelValue: string
    id?: string
    placeholder?: string
    autocomplete?: string
    required?: boolean
    size?: 'default' | 'sm'
  }>(),
  { size: 'default' },
)

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const visivel = ref(false)

const value = computed({
  get: () => props.modelValue,
  set: (v: string) => emit('update:modelValue', v),
})
</script>

<template>
  <div class="pw" :class="`pw--${size}`">
    <input
      :id="id"
      v-model="value"
      :type="visivel ? 'text' : 'password'"
      :placeholder="placeholder"
      :autocomplete="autocomplete"
      :required="required"
    />
    <button
      type="button"
      class="pw-eye"
      :class="{ active: visivel }"
      :aria-label="visivel ? 'Ocultar senha' : 'Mostrar senha'"
      :title="visivel ? 'Ocultar senha' : 'Mostrar senha'"
      @click="visivel = !visivel"
    >
      <svg
        v-if="!visivel"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        width="16"
        height="16"
      >
        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
        <circle cx="12" cy="12" r="3" />
      </svg>
      <svg
        v-else
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        width="16"
        height="16"
      >
        <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" />
        <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" />
        <path d="M14.12 14.12a3 3 0 1 1-4.24-4.24" />
        <line x1="1" y1="1" x2="23" y2="23" />
      </svg>
    </button>
  </div>
</template>

<style scoped>
.pw {
  position: relative;
  width: 100%;
}

.pw input {
  width: 100%;
  padding: 0.6rem 0.75rem;
  padding-right: 2.4rem;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  font-size: 1rem;
  font-family: inherit;
  background: var(--input-bg);
  color: var(--text-primary);
  outline: none;
  transition: border-color 0.2s;
}

.pw input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.18);
}

.pw--sm input {
  padding: 0.5rem 0.6rem;
  padding-right: 2.2rem;
  border-radius: 8px;
  font-size: 0.9rem;
}

.pw-eye {
  position: absolute;
  top: 50%;
  right: 0.5rem;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: var(--text-secondary);
  cursor: pointer;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  border-radius: 6px;
  transition: color 0.15s;
}

.pw-eye:hover {
  color: var(--text-primary);
}

.pw-eye.active {
  color: var(--primary);
}
</style>
