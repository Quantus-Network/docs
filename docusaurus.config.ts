import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Quantus',
  tagline: 'Quantum-Secure Encrypted Money',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://docs.quantus.com',
  baseUrl: '/',

  organizationName: 'Quantus-Network',
  projectName: 'docs',

  onBrokenLinks: 'throw',

  markdown: {
    mermaid: true,
  },

  themes: ['@docusaurus/theme-mermaid'],

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: '/',
          editUrl: 'https://github.com/Quantus-Network/docs/tree/main/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    mermaid: {
      theme: { light: 'default', dark: 'dark' },
    },
    navbar: {
      logo: {
        src: 'img/logo.svg',
        alt: 'Quantus logomark',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://quantus.com',
          label: 'Website',
          position: 'right',
        },
        {
          href: 'https://github.com/Quantus-Network',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            { label: 'Architecture', to: '/architecture' },
            { label: 'Mining Guide', to: '/guides/mining' },
            { label: 'Repository Map', to: '/reference/repositories' },
          ],
        },
        {
          title: 'Community',
          items: [
            { label: 'Telegram', href: 'https://t.me/quantusnetwork' },
            { label: 'X / Twitter', href: 'https://x.com/QuantusNetwork' },
          ],
        },
        {
          title: 'Resources',
          items: [
            { label: 'GitHub', href: 'https://github.com/Quantus-Network' },
            { label: 'Messari Report', href: 'https://messari.io/report/quantus-network-quantum-defense' },
            { label: 'Whitepaper', href: 'https://github.com/Quantus-Network/whitepaper' },
          ],
        },
      ],
      copyright: `Copyright ${new Date().getFullYear()} Quantus`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['rust', 'bash', 'toml'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
