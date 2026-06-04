# Contributing to BootBar

Thanks for your interest in improving BootBar.

## Setup

- Xcode 26+ with the Swift 6 toolchain
- Build the core package: `cd BootBarCore && swift build`
- Run tests: `cd BootBarCore && swift test`
- Open the app: `open BootBar.xcodeproj`

## Workflow

1. Fork and create a branch: `feat/<scope>-<description>` or `fix/<scope>-<description>`
2. Keep changes focused; add tests for new behavior in `BootBarCore/Tests`
3. Run `swift test` and make sure CI passes
4. Open a PR against `main` and fill in the template

## Guidelines

- Device logic belongs in the `BootBarCore` package with unit tests; the app target is views only
- Test parsers against real CLI output fixtures (watch for CRLF from `adb emu` console replies)
- Swift 6 strict concurrency; no new compiler warnings
- Commit format: `<type>(<scope>): <description>` (e.g. `fix(core): handle offline adb serials`)

## Reporting bugs

Use the bug report issue template and include your macOS version, Xcode version, and Android SDK location.
