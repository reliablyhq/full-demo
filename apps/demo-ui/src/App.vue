
<script setup lang="ts">
    import { useHead } from '@vueuse/head'
    useHead({
      title: 'Reliably',
      meta: [
        { name: 'description', content: 'Showcases' },
      ],
    })
    </script>

<template>
   <router-view />
</template>
