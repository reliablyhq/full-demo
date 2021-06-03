import path from 'path'
import { UserConfig } from 'vite'
import {} from 'vite-ssg'
import vue from '@vitejs/plugin-vue'
import Pages from 'vite-plugin-pages'
import Layouts from 'vite-plugin-vue-layouts';
import ViteComponents from 'vite-plugin-components'
import ViteIcons, { ViteIconsResolver } from 'vite-plugin-icons'

const config: UserConfig = {
  resolve: {
    alias: {
      '~/': `${path.resolve(__dirname, 'src')}/`,
    },
  },
  plugins: [
      vue({
        include: [/\.vue$/, /\.md$/],
      }),
      Pages({
        extensions: ['vue', 'md'],
      }),
      Layouts(),
      ViteComponents({
        // allow auto load markdown components under `./src/components/`
        extensions: ['vue', 'md'],
  
        // allow auto import and register components used in markdown
        customLoaderMatcher: id => id.endsWith('.md'),
  
        globalComponentsDeclaration: true,
  
        // auto import icons
        customComponentResolvers: [
          // https://github.com/antfu/vite-plugin-icons
          ViteIconsResolver({
            componentPrefix: '',
            // enabledCollections: ['carbon']
          }),
        ],
      }),
      ViteIcons(),
  ],
  optimizeDeps: {
    include: [
      'vue',
      'vue-router',
      '@vueuse/core',
    ],
  },
  ssgOptions: {
    script: 'async',
    formatting: 'prettify',
  },
}

export default config
