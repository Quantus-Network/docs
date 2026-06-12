import React, {type ReactNode} from 'react';
import Layout from '@theme-original/DocItem/Layout';
import type LayoutType from '@theme/DocItem/Layout';
import DocActionButtons from '@site/src/components/DocActionButtons';

type Props = React.ComponentProps<typeof LayoutType>;

export default function LayoutWrapper(props: Props): ReactNode {
  return (
    <>
      <DocActionButtons />
      <Layout {...props} />
    </>
  );
}
