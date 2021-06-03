import { defineStore } from 'pinia'

export interface User {
    id: null
    name: null
}

export interface AuthState {
    user: null | User,
    connected: boolean
}

export const useUserStore = defineStore({
  id: 'user',
  state: (): AuthState => ({user: null, connected: false }),
  getters: {
    isLoggedIn: (state: AuthState): boolean => state.connected,
  },
  actions: {
    async login() {
        const url = 'https://rly001.free.beeceptor.com/api/v1/user'

        const auth: AuthState = await (await fetch(url)).json()
        this.user = auth.user
        this.connected = auth.connected
    },
  },
})
