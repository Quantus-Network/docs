import React, {useState, useCallback, useEffect, type ReactNode} from 'react';
import {createPortal} from 'react-dom';
import {useLocation} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';
import {extractMarkdownFromArticle} from '@site/src/utils/extractMarkdownFromArticle';
import styles from './styles.module.css';

const MINING_PATH = '/guides/mining';

async function copyTextToClipboard(text: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
  }
}

export default function DocActionButtons(): ReactNode {
  const [copyState, setCopyState] = useState<'idle' | 'copied' | 'failed'>('idle');
  const [container, setContainer] = useState<HTMLElement | null>(null);
  const location = useLocation();
  const skillUrl = useBaseUrl('/skills/mining-skill.md');
  const compatibilityUrl = useBaseUrl('/mining-compatibility.json');

  const isMiningPage =
    location.pathname.replace(/\/$/, '') === MINING_PATH;

  useEffect(() => {
    const article = document.querySelector('article');
    if (!article) return;

    article.style.position = 'relative';

    let mount = article.querySelector<HTMLElement>('[data-doc-action-buttons]');
    if (!mount) {
      mount = document.createElement('div');
      mount.setAttribute('data-doc-action-buttons', '');
      article.insertBefore(mount, article.firstChild);
    }

    setContainer(mount);
  }, [location.pathname]);

  const handleCopy = useCallback(async () => {
    const markdown = extractMarkdownFromArticle() ?? '';
    let text = markdown;

    if (isMiningPage) {
      try {
        const [skillResponse, compatibilityResponse] = await Promise.all([
          fetch(skillUrl),
          fetch(compatibilityUrl),
        ]);
        if (!skillResponse.ok) {
          throw new Error(`Skill fetch returned ${skillResponse.status}`);
        }
        if (!compatibilityResponse.ok) {
          throw new Error(
            `Compatibility fetch returned ${compatibilityResponse.status}`,
          );
        }
        const skill = await skillResponse.text();
        const compatibility = await compatibilityResponse.text();
        text = [
          '<!-- Quantus mining context: AI agent skill followed by the full guide. -->',
          '<!-- Agents: follow the skill; the guide below is the human-facing reference. -->',
          skill.trim(),
          '',
          '## Pinned compatibility manifest',
          '',
          '```json',
          compatibility.trim(),
          '```',
          '',
          '---',
          '',
          '# Reference: full mining guide (docs.quantus.com/guides/mining)',
          '',
          markdown,
        ].join('\n');
      } catch (err) {
        console.error('Copy Context failed: could not fetch mining skill', err);
        setCopyState('failed');
        setTimeout(() => setCopyState('idle'), 2000);
        return;
      }
    }

    if (!text) return;
    await copyTextToClipboard(text);
    setCopyState('copied');
    setTimeout(() => setCopyState('idle'), 2000);
  }, [compatibilityUrl, isMiningPage, skillUrl]);

  if (!container) return null;

  const label = isMiningPage ? 'Copy Context' : 'Copy as Markdown';
  const description = isMiningPage
    ? 'Copy the mining guide and AI agent skill as Markdown'
    : 'Copy page content as Markdown';

  return createPortal(
    <div className={`${styles.toolbar} docActionToolbar`} data-doc-action-buttons-content>
      <button
        type="button"
        className={`${styles.button} ${isMiningPage ? styles.buttonPrimary : styles.buttonDefault} copyContextBtn`}
        onClick={handleCopy}
        title={description}
        aria-label={description}>
        {copyState === 'copied' ? 'Copied!' : copyState === 'failed' ? 'Copy failed' : label}
      </button>
    </div>,
    container,
  );
}
