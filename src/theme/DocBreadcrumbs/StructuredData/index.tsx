import React, {type ReactNode} from 'react';
import Head from '@docusaurus/Head';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {useBreadcrumbsStructuredData} from '@docusaurus/plugin-content-docs/client';
import {useHomePageRoute} from '@docusaurus/theme-common/internal';
import {applyTrailingSlash} from '@docusaurus/utils-common';
import type {Props} from '@theme/DocBreadcrumbs/StructuredData';

type Crumb = {
  '@type': 'ListItem';
  position: number;
  name: string;
  item?: string;
};

function asCrumbs(value: unknown): Crumb[] {
  const entries = Array.isArray(value) ? value : value ? [value] : [];
  return entries.filter((entry): entry is Crumb => {
    return Boolean(entry) && typeof entry === 'object' && 'name' in entry;
  });
}

function sameUrl(left: string, right: string): boolean {
  const strip = (url: string) => (url.length > 1 ? url.replace(/\/+$/, '') : url);
  return strip(left) === strip(right);
}

export default function DocBreadcrumbsStructuredData({
  breadcrumbs,
}: Props): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  const homePageRoute = useHomePageRoute();
  const structuredData = useBreadcrumbsStructuredData({breadcrumbs});
  const slashOptions = {
    trailingSlash: siteConfig.trailingSlash,
    baseUrl: siteConfig.baseUrl,
  };
  const homeUrl = `${siteConfig.url}${applyTrailingSlash('/', slashOptions)}`;

  const pages = asCrumbs(structuredData.itemListElement).map((crumb) => ({
    ...crumb,
    ...(typeof crumb.item === 'string'
      ? {item: applyTrailingSlash(crumb.item, slashOptions)}
      : {}),
  }));

  const homeAlreadyListed = pages.some(
    (crumb) => typeof crumb.item === 'string' && sameUrl(crumb.item, homeUrl),
  );

  const itemListElement = [
    ...(homePageRoute && !homeAlreadyListed
      ? [
          {
            '@type': 'ListItem' as const,
            position: 1,
            name: 'Quantus Docs',
            item: homeUrl,
          },
        ]
      : []),
    ...pages,
  ].map((crumb, index) => ({...crumb, position: index + 1}));

  return (
    <Head>
      <script type="application/ld+json">
        {JSON.stringify({...structuredData, itemListElement})}
      </script>
    </Head>
  );
}
