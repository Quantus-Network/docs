# quantus-docs

Technical documentation for [Quantus Network](https://quantus.network). Built with [Docusaurus](https://docusaurus.io/).

Serves as investor-grade technical documentation covering architecture, cryptographic stack, consensus, ZK scaling, mining guides, and a full repository map.

## Setup

```bash
bun install
```

## Development

```bash
bun start
```

Starts a local dev server at `http://localhost:3000`. Changes are reflected live.

## Build

```bash
bun run build
```

Generates static output in `build/`. Verify with:

```bash
bun run serve
```

## Structure

```
docs/
  intro.md                  Landing page
  architecture.md           System architecture overview
  deep-dives/               Per-subsystem technical documentation
  guides/                   Mining quickstart, running a node
  reference/                Repo map, tokenomics, audits, roadmap
```
