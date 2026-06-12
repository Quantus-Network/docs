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
  const [markdownCopied, setMarkdownCopied] = useState(false);
  const [skillCopied, setSkillCopied] = useState(false);
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

  const handleCopyMarkdown = useCallback(async () => {
    const markdown = extractMarkdownFromArticle();
    if (!markdown) return;

    await copyTextToClipboard(markdown);
    setMarkdownCopied(true);
    setTimeout(() => setMarkdownCopied(false), 2000);
  }, []);

  const handleCopySkill = useCallback(async () => {
    try {
      const res = await fetch(skillUrl);
      if (!res.ok) {
        console.error(`Failed to fetch skill: ${res.status}`);
        return;
      }
      const text = await res.text();
      await copyTextToClipboard(text);
      setSkillCopied(true);
      setTimeout(() => setSkillCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy skill', err);
    }
  }, [skillUrl]);

  if (!container) return null;

  return createPortal(
    <div className={`${styles.toolbar} docActionToolbar`} data-doc-action-buttons-content>
      {isMiningPage && (
        <button
          type="button"
          className={`${styles.button} ${styles.buttonPrimary} copySkillBtn`}
          onClick={handleCopySkill}
          title="Copy Claude mining skill to clipboard"
          aria-label="Copy Claude mining skill to clipboard">
          {skillCopied ? 'Copied!' : 'Copy Mining Skill'}
        </button>
      )}
      <button
        type="button"
        className={`${styles.button} ${styles.buttonDefault} copyMarkdownBtn`}
        onClick={handleCopyMarkdown}
        title="Copy page content as Markdown"
        aria-label="Copy page content as Markdown">
        {markdownCopied ? 'Copied!' : 'Copy as Markdown'}
      </button>
    </div>,
    container,
  );
}
