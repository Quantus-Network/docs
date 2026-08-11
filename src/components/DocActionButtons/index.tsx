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
  const [copied, setCopied] = useState(false);
  const [container, setContainer] = useState<HTMLElement | null>(null);
  const location = useLocation();
  const skillUrl = useBaseUrl('/skills/mining-skill.md');

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
        const res = await fetch(skillUrl);
        if (res.ok) {
          const skill = await res.text();
          text = [
            '<!-- Quantus mining context: AI agent skill followed by the full guide. -->',
            '<!-- Agents: follow the skill; the guide below is the human-facing reference. -->',
            skill.trim(),
            '',
            '---',
            '',
            '# Reference: full mining guide (docs.quantus.com/guides/mining)',
            '',
            markdown,
          ].join('\n');
        }
      } catch (err) {
        console.error('Failed to fetch mining skill; copying page only', err);
      }
    }

    if (!text) return;
    await copyTextToClipboard(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }, [isMiningPage, skillUrl]);

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
        {copied ? 'Copied!' : label}
      </button>
    </div>,
    container,
  );
}
