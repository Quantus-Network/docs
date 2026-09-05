import {describe, expect, test} from 'bun:test';
import {existsSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root = resolve(import.meta.dir, '..');
const prompt = readFileSync(resolve(root, 'static/agent-setup/prompt.md'), 'utf8');
const guide = readFileSync(resolve(root, 'docs/guides/mining.md'), 'utf8');

describe('one-line mining agent setup', () => {
  test('places one copyable prompt before manual prerequisites', () => {
    const line = 'Fetch and follow https://docs.quantus.com/agent-setup/prompt.md to set up Quantus mining on this computer.';
    expect(guide).toContain('```text\n' + line + '\n```');
    expect(guide.indexOf(line)).toBeLessThan(guide.indexOf('## Before you start'));
  });

  test('all referenced setup assets exist in the published static tree', () => {
    const paths = [...prompt.matchAll(/https:\/\/docs\.quantus\.com\/(\S+)/g)]
      .map((match) => match[1])
      .filter((path) => !path.startsWith('guides/'));
    expect(paths.length).toBe(4);
    for (const path of paths) expect(existsSync(resolve(root, 'static', path))).toBe(true);
    for (const shell of ['sh', 'ps1']) {
      expect(existsSync(resolve(root, `static/scripts/quantus-mining.${shell}.sha256`))).toBe(true);
    }
  });

  test('keeps secrets, network and completion boundaries explicit', () => {
    expect(prompt).toContain('agent-captured terminal');
    expect(prompt).toContain('Never pipe');
    expect(prompt).toContain('nonzero hash rate');
    expect(prompt).toContain('restart-check');
    expect(prompt).toContain('not a mainnet setup');
    expect(prompt).toContain('Never add antivirus exclusions');
    expect(prompt).not.toContain('\u2014');
    expect(prompt).not.toContain('/releases/latest');
  });
});
