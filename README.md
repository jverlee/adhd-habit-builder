# ADHD Habit Builder

A SwiftUI app for iPad.

## Preview on your Mac

You need **Xcode** installed (free from the Mac App Store — search "Xcode").

1. Open `ADHDHabitBuilder.xcodeproj` in Xcode (double-click it in Finder).
2. In the toolbar at the top, pick an iPad destination from the run-target dropdown (e.g. **iPad Pro 13-inch (M4)**). If no iPad simulator is listed, choose **Product → Destination → Manage Run Destinations…** to download one.
3. Press **⌘R** (or the ▶ Play button) to build and run. The iPad Simulator will launch and show "Hello, ADHD!".

### Live preview (faster iteration)

Open `ADHDHabitBuilder/ContentView.swift`. The right-side Canvas shows a live preview of the view — click **Resume** (or press **⌥⌘P**) to render it. Edits update the preview instantly.

## Project layout

- `ADHDHabitBuilder/ADHDHabitBuilderApp.swift` — app entry point
- `ADHDHabitBuilder/ContentView.swift` — the main view (currently the placeholder text)
- `ADHDHabitBuilder/Assets.xcassets` — app icon, accent color
- `ADHDHabitBuilder.xcodeproj` — Xcode project
