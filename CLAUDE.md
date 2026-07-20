# Quantus Docs

Technical documentation site for Quantus Network. Built with Docusaurus, deployed to docs.quantus.com.

## Build

This project uses **bun** (not npm). `bun.lock` is the source of truth.

```bash
bun install
bun start        # dev server at localhost:3000
bun run build    # production build
bun run serve    # serve production build locally
```

## Structure

```
docs/
  intro.md                     Landing page (slug: /)
  architecture.md              System architecture overview
  deep-dives/                  Per-subsystem technical docs (6 pages)
  guides/                      Mining app (GUI), mining + node setup (CLI)
  reference/                   Repo map, tokenomics, audits, roadmap, tools & community
src/
  components/DocActionButtons/     Copy-as-Markdown and mining-skill buttons
  theme/DocItem/Layout/            Swizzled layout wrapper for doc action buttons
  css/custom.css                   Dark-only brand theme (void/flare/Geist)
```

## Conventions

- No marketing fluff -- this is technical documentation for investors and engineers
- No emojis in content
- Keep pages under 1500 words; split or link to deeper resources if longer
- Use tables and bullet points over prose paragraphs
- Mermaid diagrams where they clarify architecture
- Source claims from the codebase, DeepWiki exports, or quantusContext.md -- do not hallucinate
- Mining guide follows the official wiki as source of truth: https://github.com/Quantus-Network/chain/wiki
- Do NOT publish internal AI audit findings (quantus-audit/ is internal only)
- Theme tokens follow the main website design system (void `#0e0e0e`, flare `#ff6b35`, content `#e8e6e0`, Geist + Geist Mono); dark mode only

## Key Links

- GitHub: https://github.com/Quantus-Network
- Website: https://quantus.com
- Whitepaper: https://quantus.com/whitepaper
- DeepWiki (per-repo): https://deepwiki.com/Quantus-Network/{repo-name}

## Content Status

Content was generated from DeepWiki exports and quantusContext.md. Needs:
- Engineer accuracy review (especially deep dives and mining guide)
- Copywriting sweep
