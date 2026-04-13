import React, {type ReactNode} from 'react';
import Layout from '@theme-original/DocItem/Layout';
import type LayoutType from '@theme/DocItem/Layout';
import CopyMarkdownButton from '@site/src/components/CopyMarkdownButton';

type Props = React.ComponentProps<typeof LayoutType>;

export default function LayoutWrapper(props: Props): ReactNode {
  return (
    <>
      <CopyMarkdownButton />
      <Layout {...props} />
    </>
  );
}
