import devalue from '@nuxt/devalue'
import { ViteSSG } from 'vite-ssg'
import generatedRoutes from 'virtual:generated-pages'
import { setupLayouts } from 'virtual:generated-layouts'
import App from './App.vue'
import { pinia, useUserStore } from '~/stores'
import '~/scss/main.scss'

const routes = setupLayouts(generatedRoutes)

export const createApp = ViteSSG(
    App,
    {
        routes,
    },
    (ctx) => {
        Object.values(import.meta.globEager('./modules/*.ts')).map(i => i.install?.(ctx))
        
        const { app, router, initialState } = ctx
        app.use(pinia)

        if (import.meta.env.SSR) {
            initialState.pinia = pinia.state.value
        } else {
            pinia.state.value = initialState.pinia || {}
        }

        router.beforeEach((to, from, next) => {
            const user = useUserStore(pinia)
            if (to.name !== "signin" && !user.isLoggedIn) next({name: "signin"})
            else next()
        })
    },
    {
      transformState(state) {
        return import.meta.env.SSR ? devalue(state) : state
      },
    },
  )
