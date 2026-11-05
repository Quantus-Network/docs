import React, {type ReactNode} from 'react';
import Head from '@docusaurus/Head';
import SearchPage from '@theme-original/SearchPage';

export default function SearchPageWrapper(): ReactNode {
  return (
    <>
      <Head>
        {/* name="robots" is what crawlers and the sitemap plugin read.
            The search theme only sets property="robots", which neither honors. */}
        <meta name="robots" content="noindex, follow" />
      </Head>
      <SearchPage />
    </>
  );
}
