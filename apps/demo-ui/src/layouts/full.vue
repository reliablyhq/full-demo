<template>
    <main class="layout">
        <router-view />
    </main>
</template>

<style lang="scss">
body {
  margin:0;
  padding:0;
}

.layout {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}
</style>
