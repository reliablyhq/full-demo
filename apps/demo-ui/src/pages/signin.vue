<template>
    <section class="signin decoration-ribbon decoration-ribbon--yellow">
      <div class="container">
        <div class="card card--signin">
            <div class="card--signin__form light-blue">
                <img src="/many.svg">
                <p>
                    <button @click="login()" class="button button-cra">Sign in with Google</button>
                </p>
            </div>
            <div class="card--signin__glamour">
                <img class="logo" src="/logo-white.svg">
            </div>
        </div>
      </div>
    </section>
</template>

<style lang="scss" scoped>
.signin {
    display: flex;
    flex-direction: column;
    justify-content: center;
    min-height: 100vh;
    background-color: var(--grey-100);
}

.signin .container {
    flex-direction: row;
}

.card--signin {
    flex-direction: row;
    flex-grow: 1;
    height: 40em;
    background-color: var(--blue-800);
    color: var(--text-color-dark);
    h1, h2, h3, h4, h5, h6 {
        color: var(--heading-color-dark);
    }

    box-shadow: 0 14px 28px rgba(0,0,0,0.25), 
			0 10px 10px rgba(0,0,0,0.22);

  .card--signin__form {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    padding: 0 70px;
    order: 0;
    flex-grow: 1;
  }
  
  .card--signin__glamour {
    display: flex;  
    flex-direction: column;
    justify-content: center;
    align-items: center;
    padding: 0 70px;
    min-width: 70rem;
  }

  .card--signin__glamour .logo {
    width: 482;
    height: 101;
  }
}
</style>
<script setup lang="ts">
    import { useRouter } from 'vue-router'
    import { useUserStore } from '~/stores/user'
    
    const router = useRouter()
    const user = useUserStore()
    const login = () => {
        user.login()
        if (user.connected) {
            router.push("/")
        }
    }
</script>

<route lang="yaml">
meta:
  layout: full
</route>