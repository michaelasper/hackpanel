# HackPanel

HackPanel is a **macOS-native dashboard** for monitoring and diagnosing an **OpenClaw Gateway**.
It combines a SwiftUI app (`HackPanelApp`) with a reusable gateway client library (`HackPanelGateway`) and mock implementations for development (`HackPanelGatewayMocks`).

## Table of contents

- [What this repository contains](#what-this-repository-contains)
- [Features](#features)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Development workflow](#development-workflow)
- [Testing](#testing)
- [Makefile commands](#makefile-commands)
- [CI](#ci)
- [Documentation and assets](#documentation-and-assets)
- [Security](#security)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)

## What this repository contains

This repo is a Swift Package with three products:

- `HackPanelApp` (executable): the macOS app.
- `HackPanelGateway` (library): gateway protocol/client models and decoding logic.
- `HackPanelGatewayMocks` (library): deterministic mock client(s) for app development and previews.

## Features

Current implemented areas include:

- Gateway connection state and health handling.
- Decoding and modeling gateway status and node list payloads.
- SwiftUI dashboard/navigation surfaces.
- Settings validation and local defaults support.
- Diagnostics formatting and helper utilities.
- Extensive unit coverage for frame decoding, payload contracts, and app-level connection behavior.

## Project structure

```text
.
├── Sources/
│   ├── HackPanelApp/            # macOS app (SwiftUI UI, connection store, support utils)
│   ├── HackPanelGateway/        # Gateway client, frames/payloads, shared models
│   └── HackPanelGatewayMocks/   # Mock gateway client implementation
├── Tests/
│   ├── HackPanelAppTests/       # App-level unit tests
│   └── HackPanelGatewayTests/   # Gateway protocol/model decoding tests + fixtures
├── Scripts/                     # Dev/automation helpers
├── Docs/                        # Screenshots, PR review docs, media assets
├── Package.swift                # SwiftPM package definition
└── Makefile                     # Common development commands
```

## Requirements

- macOS 14+
- Xcode 15.4+ (recommended for Swift tools compatibility)
- Swift toolchain supporting `swift-tools-version: 5.10`

## Quick start

### 1) Clone and enter the repo

```bash
git clone <your-fork-or-repo-url>
cd hackpanel
```

### 2) Build the package

```bash
swift build
```

### 3) Run tests

```bash
swift test
```

### 4) Run the app in Xcode

- Open `Package.swift` in Xcode.
- Choose the `HackPanelApp` executable scheme.
- Build and run.

## Development workflow

Recommended local loop:

1. `make format-check` (or your formatter/lint flow if you use one locally)
2. `make build`
3. `make test`
4. `make sanity` (matches CI build+test sequence)

If you are changing gateway decoding/contracts, also run:

```bash
make test-gateway
```

If you are changing app connection/UI behavior, also run:

```bash
make test-app
```

## Testing

The repo has two test bundles:

- `HackPanelGatewayTests`
  - Validates JSON fixtures for frame contract and payload decoding.
- `HackPanelAppTests`
  - Validates app-focused behavior (settings validation, connection store behavior, diagnostics formatting, keychain/storage helpers).

You can run all tests with `swift test` or target specific suites with `swift test --filter <SuiteName>`.

## Makefile commands

A `Makefile` is included for common tasks and CI parity.

```bash
make help
```

Key targets:

- `make build` — Build package.
- `make test` — Run all tests.
- `make test-app` — Run app tests only.
- `make test-gateway` — Run gateway tests only.
- `make run` — Launch app via SwiftPM executable.
- `make sanity` — Run `Scripts/spm_sanity_check.sh` (used in CI).
- `make clean` — Clean SwiftPM build artifacts.

## CI

GitHub Actions CI is configured in:

- `.github/workflows/ci.yml`

CI currently executes the SwiftPM sanity check script to ensure build/test parity with local development.

## Documentation and assets

- `Docs/PR_REVIEW.md` — PR review guidance.
- `Docs/Screenshots/` — UI screenshots.
- `Docs/Snapshots/` — Snapshot comparison media.
- `Docs/copy-diagnostics.gif` — Diagnostics copy UX demo.

## Security

- Do **not** commit secrets, tokens, or private keys.
- Review `SECURITY.md` for reporting guidance.
- Keep local credentials in secure storage and gitignored files only.

## Contributing

See `CONTRIBUTING.md` for branch naming, PR expectations, and local workflow.

## Troubleshooting

### Xcode can’t resolve package state

```bash
make clean
swift package resolve
```

### A test depends on stale artifacts

```bash
make clean
make test
```

### Need CI-equivalent local validation

```bash
make sanity
```
