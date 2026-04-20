import React, {useState, useCallback, useEffect, type ReactNode} from 'react';
import {createPortal} from 'react-dom';
import {useLocation} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

const MINING_PATH = '/guides/mining';

export default function CopySkillButton(): ReactNode {
  const [copied, setCopied] = useState(false);
  const [container, setContainer] = useState<HTMLElement | null>(null);
  const location = useLocation();
  const skillUrl = useBaseUrl('/skills/mining-skill.md');

  const isMiningPage = location.pathname.replace(/\/$/, '') === MINING_PATH;

  useEffect(() => {
    if (!isMiningPage) return;
    const article = document.querySelector('article');
    if (article) {
      article.style.position = 'relative';
      setContainer(article);
    }
  }, [isMiningPage]);

  const handleCopy = useCallback(async () => {
    try {
      const res = await fetch(skillUrl);
      if (!res.ok) {
        console.error(`Failed to fetch skill: ${res.status}`);
        return;
      }
      const text = await res.text();
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy skill', err);
    }
  }, [skillUrl]);

  if (!isMiningPage || !container) return null;

  return createPortal(
    <button
      type="button"
      className={`${styles.copySkillButton} copySkillBtn`}
      onClick={handleCopy}
      title="Copy Claude mining skill to clipboard"
      aria-label="Copy Claude mining skill to clipboard">
      {copied ? 'Copied!' : 'Copy Mining Skill'}
    </button>,
    container,
  );
}
