// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin')
const fs = require('fs')
const path = require('path')

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/f1_grid_watcher_web.ex',
    '../lib/f1_grid_watcher_web/**/*.*ex'
  ],
  theme: {
    extend: {
      container: {
        center: true,
        padding: {
          DEFAULT: '0.5rem',
          sm: '0.5rem',
          mm: '1rem',
          mt: '4rem',
          md: '5rem'
        }
      },
      colors: {
        // Existing palette (example)
        brand: { DEFAULT: '#E10600', dark: '#B10400', light: '#FF3B2E' },
        track: { DEFAULT: '#0A0A0B', pit: '#1A1B1E', line: '#2B2C30' },
        telemetry: {
          green: '#22C55E',
          purple: '#A855F7',
          yellow: '#F59E0B',
          red: '#EF4444',
          blue: '#3B82F6'
        },
        neutral: {
          50: '#FAFAFA',
          100: '#F4F4F5',
          200: '#E4E4E7',
          300: '#D4D4D8',
          400: '#A1A1AA',
          500: '#71717A',
          600: '#52525B',
          700: '#3F3F46',
          800: '#27272A',
          900: '#18181B'
        },

        // Added custom colors
        f1Lavender: '#FEF8FF', // very light lavender (backgrounds/cards)
        f1Pink: '#EFBBFF', // accent/pills
        f1Purple: '#B44AFF', // primary action/buttons
        f1Purple2: '#7E6287',
        f1Carbon: '#252127', // deep neutral (panels/text on light)
        f1Yellow: '#FFE74A' // highlight/warning/accent
      },
      fontFamily: {
        display: [
          'Eurostile Condensed',
          'Helvetica Neue Condensed',
          'DIN Condensed',
          'Agency FB',
          'system-ui',
          'sans-serif'
        ],
        ui: [
          'Inter',
          'SF Pro Text',
          'SF Pro Display',
          'Roboto',
          'DIN',
          'Helvetica Neue',
          'system-ui',
          'sans-serif'
        ]
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    function ({ addUtilities }) {
      addUtilities({
        '.font-tabular': { fontFeatureSettings: "'tnum' 1, 'lnum' 1" },
        '.font-normal-figures': { fontFeatureSettings: "'tnum' 0, 'lnum' 1" }
      })
    },

    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant('phx-click-loading', [
        '.phx-click-loading&',
        '.phx-click-loading &'
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-submit-loading', [
        '.phx-submit-loading&',
        '.phx-submit-loading &'
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-change-loading', [
        '.phx-change-loading&',
        '.phx-change-loading &'
      ])
    ),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function ({ matchComponents, theme }) {
      const iconsDir = path.join(__dirname, '../deps/heroicons/optimized')
      const values = {}
      const icons = [
        ['', '/24/outline'],
        ['-solid', '/24/solid'],
        ['-mini', '/20/solid'],
        ['-micro', '/16/solid']
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          const name = path.basename(file, '.svg') + suffix
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
        })
      })
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            const content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, '')
            let size = theme('spacing.6')
            if (name.endsWith('-mini')) {
              size = theme('spacing.5')
            } else if (name.endsWith('-micro')) {
              size = theme('spacing.4')
            }
            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              '-webkit-mask': `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              'mask-repeat': 'no-repeat',
              'background-color': 'currentColor',
              'vertical-align': 'middle',
              display: 'inline-block',
              width: size,
              height: size
            }
          }
        },
        { values }
      )
    })
  ]
}
