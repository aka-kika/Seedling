<div align="center">

<img src="Seedling/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" width="120" alt="Seedling"/>

# Seedling

**Plant a seed and watch it grow.**

*A tiny, calm macOS app for starting new projects —*
*made for late nights, brain resets, and fresh beginnings.* 🌙

<br>

[![Download Seedling 3.0](https://img.shields.io/badge/Download-Seedling%203.0-97CEC2?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/dot-RealityTest/Seedling/releases/latest/download/Seedling-3.0.dmg)

<sub>Notarized by Apple · macOS 26+ · drag to Applications and go</sub>

</div>

---

Some nights you don't want a dashboard. You just want to *start something*.

Seedling lives quietly in your menu bar. Summon it — a click, or `⌥⌘S` — and a small window fades into the center of your screen: just a seed in the dark, waiting for a name. Type one. Watch a little line-art seedling draw itself and bloom. Your new project is alive.

That's the whole thing. That's the point.

## The idea 🌱

Every project starts from the same handful of files — your rules and guidelines. `AGENTS.md`, `CLAUDE.md`, `README`, `TODO`, `SECURITY`… the DNA a project grows from.

In Seedling, those files are your **seeds**, kept in a folder you call your **Root**. Name a new project and Seedling plants a fresh copy of them into your **Garden** — and a new folder is born. Tend your seeds whenever you like; every future project grows from the latest version.

> 🌰 **Root** — where your seed files live
> 🌳 **Garden** — where new projects grow
> 🌿 **Plant** — name a project, and it sprouts, seeded and ready

It never overwrites anything. Re-plant into a patch that already exists and the old files stay untouched.

## A small ceremony

1. **A seed in the dark** — one quiet field: *name your project*
2. **It grows** — the line draws itself, then a single breath of light
3. **Enter the garden** — your new folder opens, and the window fades away

No menus to wade through. No settings page pretending to be a workflow. Just a moment.

## Get it

**The easy way** — [**download the latest `.dmg`**](https://github.com/dot-RealityTest/Seedling/releases/latest/download/Seedling-3.0.dmg), open it, and drag **Seedling** to **Applications**. It's signed and **notarized by Apple**, so it opens with no security warnings. (Or browse all [releases](https://github.com/dot-RealityTest/Seedling/releases).)

**From source** — it's a native macOS app (SwiftUI, built for macOS 26 with Liquid Glass):

```bash
open Seedling.xcodeproj   # then ⌘R in Xcode
```

Either way: look for the leaf 🌿 in your menu bar. On first run it asks *where are your seeds?* then *take me to your garden* — after that it's just `⌥⌘S`, a name, and grow.

> Requires **macOS 26 (Tahoe)** or later.

## Quiet by design

One pastel-sage accent, hairlines, Liquid Glass, no drop shadows — and a single belief: **starting a project should feel like a new beginning, not a chore.**

<details>
<summary>For the curious — the technical bits</summary>

<br>

A focused menu-bar app: no main window, no networking, ~16 small Swift files. Sandboxed with security-scoped bookmarks, a Carbon global hotkey, and a Finder *"Seed this folder"* service on the side. The growth is pure SwiftUI line-art (no image assets), and the whole flow lives in a centered, key-accepting `NSPanel`.

- 🛠 Full engineering tour → [HANDOFF.md](HANDOFF.md)
- 🗺 Plain-language map → [PROJECT_GUIDE.md](PROJECT_GUIDE.md)

</details>

---

<div align="center">
<sub>Made on a late night, for late nights. 🌙🌱</sub>
</div>
