# Orbit

A native macOS issue tracker for one person — a personal, local-first "Linear" for managing freelance work.

## Overview

Orbit organizes work in a simple hierarchy — **Workspace → Project → Issue** — with the status and priority model you'd expect from a modern tracker (Backlog / Todo / In Progress / Done / Cancelled, and None / Low / Medium / High / Urgent). It's built as a single-user tool: no accounts, no servers, no sync setup required — just open the app and start tracking.

## Features

- **Three-column layout** — a `NavigationSplitView` with sidebar, issue list, and detail pane, in the spirit of Linear and Mail.app
- **List and Kanban views** — switch between a sortable issue list and a drag-friendly Kanban board
- **Labels** — color-coded labels for categorizing issues
- **Filtering, sorting & search** — combine filters, sort issues, and search across your workspace
- **Saved views** — save a filter/sort combination for one-click access later
- **Command palette (⌘K)** — jump to any action or issue without leaving the keyboard
- **Keyboard shortcuts** — ⌘N to create an issue, ⌘F to search, and more
- **Comments & timeline** — discuss and track activity on an issue directly in its detail view
- **Paste-to-attach** — paste an image from the clipboard straight into an issue as an attachment

## Tech Stack

Orbit is 100% native Apple technology, with **zero third-party dependencies**:

- **SwiftUI** — the entire UI layer
- **SwiftData** — local persistence
- **AppKit** — interop where SwiftUI needs a hand (e.g. clipboard/pasteboard handling)
- **CloudKit** — designed to be sync-ready (see below), not yet enabled
- **Observation** — state management
- **Security** — system keychain/security APIs
- **UniformTypeIdentifiers** — typed handling of pasted/imported content
- **Inter** — bundled as the app's typeface

## Architecture Highlights

- **Local-first** — all data lives on-device via SwiftData; the app is fully functional offline
- **CloudKit-ready** — the persistence layer is structured so that Mac/iPhone/iPad sync can be switched on later without a redesign; CloudKit sync itself is not active yet
- **No third-party dependencies** — everything ships with the OS, keeping the app light, fast, and easy to audit
- **Clear module boundaries**:
  - `App/` — app entry point and commands (menu bar, keyboard shortcuts)
  - `Models/` — SwiftData models (Workspace, Project, Issue, Comment, Label, Attachment, SavedView)
  - `Persistence/` — SwiftData container setup and seed data
  - `Services/` — clipboard handling, pasted-image import, filtering logic, iCloud status
  - `Utilities/` — design tokens, the Nocturne component library, and theming
  - `ViewModels/` — filter state and selection state
  - `Views/` — organized by area: CommandPalette, Content, Detail, Labels, Sidebar

## Design — "Nocturne"

Orbit uses a custom dark theme called **Nocturne**, built on its own design tokens and a small library of reusable SwiftUI components (`Utilities/DesignTokens.swift`, `Utilities/NocturneComponents.swift`, `Utilities/Theme.swift`). The goal is a calm, focused, keyboard-driven workspace rather than a generic system look.

## Screenshots

<!-- screenshot -->

## Getting Started

1. Clone the repository
2. Open `Orbit.xcodeproj` in Xcode
3. Build and run (`⌘R`) — requires a recent version of macOS and Xcode

No additional setup, API keys, or accounts are needed.
