/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#0d9488',
          light: '#14b8a6',
          dark: '#0f766e',
        },
        gray: {
          50: '#f9fafb',
          100: '#f3f4f6',
          200: '#e5e7eb',
          300: '#d1d5db',
          400: '#9ca3af',
          500: '#6b7280',
          600: '#4b5563',
          700: '#374151',
          800: '#1f2937',
          900: '#111827',
        },
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', '"Segoe UI"', '"Roboto"', 'sans-serif'],
        mono: ['"Monaco"', '"Menlo"', '"Ubuntu Mono"', 'monospace'],
      },
      boxShadow: {
        sm: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
        md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1)',
        lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1)',
        xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
      },
    },
  },
  plugins: [
    function ({ addComponents, theme }) {
      addComponents({
        '.btn': {
          '@apply': 'inline-flex items-center gap-2 px-6 py-3 rounded font-semibold text-base transition-all border-none cursor-pointer',
        },
        '.btn-primary': {
          '@apply': 'bg-primary text-white hover:bg-primary-light hover:shadow-lg hover:-translate-y-0.5',
        },
        '.btn-secondary': {
          '@apply': 'bg-gray-100 text-gray-900 border-2 border-gray-200 hover:bg-gray-50 hover:border-primary',
        },
        '.feature-card': {
          '@apply': 'bg-white border border-gray-200 rounded-xl p-8 transition-all hover:shadow-lg hover:-translate-y-1 hover:border-primary',
        },
        '.feature-icon': {
          '@apply': 'w-12 h-12 mb-4 inline-block',
          'display': 'flex',
          'align-items': 'center',
          'justify-content': 'center',
        },
      });
    },
  ],
};
