<template>
    <nav class="navigation">
        hello
    </nav>
    <main class="layout">
        <div class="dashboard">
            <div class="sidebar">
                <ul>
                    <li><router-link to="/apps/noteboard">Noteboard</router-link></li>
                </ul>
            </div>
            <div class="main">
                <router-view />
            </div>
        </div>
       
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

.dashboard {
    display: flex;
    background-color: var(--grey-100);
    min-height: 100vh;
}
.sidebar {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    min-width: 25rem;
    padding: 10px;
    background-color: var(--grey-200);
}

.main {
    display: flex;
    flex-grow: 1;
    height: 100%;
    width: 100%;
    padding: 10px;
}

.navigation {
    background-color: var(--grey-600);
    height: 5rem;
}
</style>
