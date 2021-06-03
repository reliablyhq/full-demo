<template>
<div>hello</div>
</template>

<script setup lang="ts">
    import { computed } from 'vue'
    import { pinia } from '~/stores'
    import { useUserStore } from '~/stores/user'

    const userStore = useUserStore(pinia)
    const user = computed(() => userStore.user)
</script>
