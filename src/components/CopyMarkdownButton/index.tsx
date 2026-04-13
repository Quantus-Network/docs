import React, {useState, useCallback, useEffect, type ReactNode} from 'react';
import {createPortal} from 'react-dom';
import styles from './styles.module.css';

/**
 * Converts the rendered HTML content of a doc page's <article> element
 * into a simplified markdown-like plain text representation, then copies
 * it to the clipboard.
 */
function extractMarkdownFromArticle(): string {
  const article = document.querySelector('article');
  if (!article) {
    return '';
  }

  // Clone so we can manipulate without affecting the DOM
  const clone = article.cloneNode(true) as HTMLElement;

  // Remove breadcrumbs, version badges, TOC, and footer nav
  clone
    .querySelectorAll(
      'nav, .theme-doc-version-badge, .theme-doc-breadcrumbs, .theme-doc-footer, .theme-doc-toc-mobile',
    )
    .forEach((el) => el.remove());

  // Walk the DOM and build markdown text
  function walk(node: Node): string {
    if (node.nodeType === Node.TEXT_NODE) {
      return node.textContent ?? '';
    }

    if (node.nodeType !== Node.ELEMENT_NODE) {
      return '';
    }

    const el = node as HTMLElement;
    const tag = el.tagName.toLowerCase();

    // Skip the copy-markdown button itself
    if (el.classList.contains('copyMarkdownBtn')) {
      return '';
    }

    const childText = () =>
      Array.from(el.childNodes).map(walk).join('');

    // Headings
    if (/^h[1-6]$/.test(tag)) {
      const level = parseInt(tag[1], 10);
      const prefix = '#'.repeat(level);
      return `\n${prefix} ${childText().trim()}\n\n`;
    }

    // Paragraphs
    if (tag === 'p') {
      return `${childText().trim()}\n\n`;
    }

    // Line breaks
    if (tag === 'br') {
      return '\n';
    }

    // Bold
    if (tag === 'strong' || tag === 'b') {
      return `**${childText()}**`;
    }

    // Italic
    if (tag === 'em' || tag === 'i') {
      return `*${childText()}*`;
    }

    // Inline code
    if (tag === 'code' && el.parentElement?.tagName.toLowerCase() !== 'pre') {
      return `\`${el.textContent ?? ''}\``;
    }

    // Code blocks
    if (tag === 'pre') {
      const codeEl = el.querySelector('code');
      const lang = codeEl?.className
        ?.split(' ')
        .find((c) => c.startsWith('language-'))
        ?.replace('language-', '') ?? '';
      const code = codeEl?.textContent ?? el.textContent ?? '';
      return `\n\`\`\`${lang}\n${code.trim()}\n\`\`\`\n\n`;
    }

    // Links
    if (tag === 'a') {
      const href = el.getAttribute('href') ?? '';
      return `[${childText()}](${href})`;
    }

    // Images
    if (tag === 'img') {
      const src = el.getAttribute('src') ?? '';
      const alt = el.getAttribute('alt') ?? '';
      return `![${alt}](${src})`;
    }

    // Unordered lists
    if (tag === 'ul') {
      return (
        '\n' +
        Array.from(el.children)
          .map((li) => `- ${walk(li).trim()}`)
          .join('\n') +
        '\n\n'
      );
    }

    // Ordered lists
    if (tag === 'ol') {
      return (
        '\n' +
        Array.from(el.children)
          .map((li, i) => `${i + 1}. ${walk(li).trim()}`)
          .join('\n') +
        '\n\n'
      );
    }

    // Table
    if (tag === 'table') {
      const rows = Array.from(el.querySelectorAll('tr'));
      if (rows.length === 0) return childText();

      const result: string[] = [];
      rows.forEach((row, rowIdx) => {
        const cells = Array.from(row.querySelectorAll('th, td')).map(
          (cell) => (cell.textContent ?? '').trim(),
        );
        result.push(`| ${cells.join(' | ')} |`);
        if (rowIdx === 0) {
          result.push(`| ${cells.map(() => '---').join(' | ')} |`);
        }
      });
      return `\n${result.join('\n')}\n\n`;
    }

    // Blockquote
    if (tag === 'blockquote') {
      return (
        '\n' +
        childText()
          .trim()
          .split('\n')
          .map((line) => `> ${line}`)
          .join('\n') +
        '\n\n'
      );
    }

    // Horizontal rule
    if (tag === 'hr') {
      return '\n---\n\n';
    }

    // Default: just recurse
    return childText();
  }

  const raw = walk(clone);

  // Clean up excessive blank lines
  return raw.replace(/\n{3,}/g, '\n\n').trim();
}

export default function CopyMarkdownButton(): ReactNode {
  const [copied, setCopied] = useState(false);
  const [container, setContainer] = useState<HTMLElement | null>(null);

  useEffect(() => {
    const article = document.querySelector('article');
    if (article) {
      article.style.position = 'relative';
      setContainer(article);
    }
  }, []);

  const handleCopy = useCallback(async () => {
    const markdown = extractMarkdownFromArticle();
    if (!markdown) return;

    try {
      await navigator.clipboard.writeText(markdown);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback for older browsers / non-HTTPS contexts
      const textarea = document.createElement('textarea');
      textarea.value = markdown;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  }, []);

  if (!container) return null;

  return createPortal(
    <button
      type="button"
      className={`${styles.copyButton} copyMarkdownBtn`}
      onClick={handleCopy}
      title="Copy page content as Markdown"
      aria-label="Copy page content as Markdown">
      {copied ? 'Copied!' : 'Copy as Markdown'}
    </button>,
    container,
  );
}
