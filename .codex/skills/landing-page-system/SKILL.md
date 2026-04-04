---
name: landing-page-system
description: >
  Maintain Kauch's landing page artifact pipeline. Use when working on the
  landing page, screenshot generation, baked device frames, marketing scenario
  seeds, screenshot manifests, or landing-page content that should stay synced
  to real app UI.
---

# Landing Page System

Use this skill when the task touches Kauch's marketing site or the pipeline that feeds it.

## Scope

This skill covers:

- iOS marketing scenarios
- deterministic screenshot seeds
- simulator capture
- baked framed exports
- screenshot manifest generation
- typed web content that consumes those artifacts

## First Read

Start with:

- [landing-page-system.md](/Users/juan/Developer/kauch/docs/landing-page-system.md)
- [landing-page-pipeline.md](/Users/juan/Developer/kauch/docs/landing-page-pipeline.md)

Use the first doc for strategy and content direction.
Use the second doc for the validated implementation workflow.

## System Rules

- Real app UI is the source of truth.
- Raw simulator captures come before framed exports.
- Frames are baked by the repo pipeline, not composed manually.
- The web app should consume the generated manifest rather than hardcoded filenames.
- Screenshot seeds must be deterministic and believable.
- Do not invent product UI in the web layer that the app cannot render.

## Main Files

### iOS

- [KauchApp.swift](/Users/juan/Developer/kauch/apps/ios/Kauch/App/KauchApp.swift)
- [AppLaunchConfiguration.swift](/Users/juan/Developer/kauch/apps/ios/Kauch/Shared/Screenshots/AppLaunchConfiguration.swift)
- [MarketingBootstrap.swift](/Users/juan/Developer/kauch/apps/ios/Kauch/Shared/Screenshots/MarketingBootstrap.swift)
- [MarketingRootView.swift](/Users/juan/Developer/kauch/apps/ios/Kauch/Shared/Screenshots/MarketingRootView.swift)
- [KauchUITestsLaunchTests.swift](/Users/juan/Developer/kauch/apps/ios/KauchUITests/KauchUITestsLaunchTests.swift)

### pipeline

- [capture-screenshots.mjs](/Users/juan/Developer/kauch/scripts/marketing/capture-screenshots.mjs)
- [frame-lib.mjs](/Users/juan/Developer/kauch/scripts/marketing/frame-lib.mjs)
- [scenarios.mjs](/Users/juan/Developer/kauch/scripts/marketing/scenarios.mjs)

### web

- [manifest.json](/Users/juan/Developer/kauch/apps/web/public/screenshots/manifest.json)
- [screens.ts](/Users/juan/Developer/kauch/apps/web/content/screens.ts)

## Default Workflow

1. If the task changes what is shown on the site, decide whether that change belongs in app UI, screenshot seed data, framing, manifest metadata, or web content.
2. If a marketed screen changes materially, regenerate screenshots rather than hand-waving that the site is still current.
3. Validate in this order:
   `npm run gate`
   `node --test scripts/marketing/frame-lib.test.mjs`
   `xcodebuild test -only-testing:KauchUITests/KauchUITestsLaunchTests ... | xcbeautify`
   `node scripts/marketing/capture-screenshots.mjs`
4. Visually inspect at least one framed export when the framing or seed data changes.

## Failure Debugging

If a screenshot shows the simulator home screen, assume the app crashed after launch.

Check:

```bash
xcrun simctl spawn booted log show \
  --style compact \
  --last 5m \
  --predicate 'process == "Kauch"'
```

Common cause:

- scenario seed references an exercise name that does not exist in the built-in catalogue

## Content Guidance

When editing landing-page content:

- keep the homepage curated and short
- prefer product workflows over marketing abstractions
- grow through typed `features`, `screens`, `releases`, `faqs`, and `articles`
- keep the product tone calm, serious, and native-first

## Do Not

- Do not compose screenshots dynamically in the site as the primary delivery path.
- Do not use AI-generated images as substitutes for product screenshots.
- Do not hardcode screenshot filenames in multiple places.
- Do not let scenario IDs drift between iOS, pipeline scripts, and the manifest.
