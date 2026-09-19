# Dashboard Redesign Direction

**Status:** Design discussion in progress
**Date:** September 16, 2026
**Implementation:** Not started

This document records the agreed direction for improving the StatusXP dashboard. Each approved design decision will be added as a numbered step before implementation begins.

## Step 1: Platform-aware profile identity and quick switcher

The profile area in the dashboard header should communicate which connected gaming platform the user has chosen to present. The avatar treatment must have a functional meaning rather than serving as decoration.

### Avatar presentation

- Keep the avatar, username, and active platform together as the player's identity area.
- Surround the avatar with a thin platform-colored ring and a restrained matching halo.
- Use the following visual treatments:
  - **PlayStation:** neon blue/cyan.
  - **Xbox:** neon green.
  - **Steam:** cool steel blue or silver. A black glow should not be used because it would disappear against the dark header.
- Show a small platform symbol on or beside the avatar so the selected platform is not communicated by color alone.
- Display the selected platform beneath the username using the corresponding platform treatment.

### Avatar interaction

Tapping the avatar should open a small anchored platform switcher. This provides a fast alternative to changing the presented platform through Settings.

The switcher should:

- Label the choice clearly, such as **Present profile as**.
- Show the currently presented platform with a checkmark.
- Show only platforms the user has connected and can select.
- Include **Manage connected accounts** as a path to the full account settings.
- When only one platform is connected, show the current platform and offer links to connect the other supported platforms.

Example:

```text
Present profile as

✓ PlayStation
  Xbox
  Steam

Manage connected accounts
```

### Selection behavior

When the user selects another connected platform:

- Update the avatar ring, halo, platform symbol, and platform label immediately.
- Refresh any dashboard content that is specific to the presented platform.
- Keep the combined StatusXP total and cross-platform statistics visible.
- Save the preference so it persists across sessions and devices.
- Close the switcher and provide brief confirmation, such as **Profile changed to Xbox**.

### Settings relationship

The existing platform preference must remain available in Settings. The avatar interaction is the quick switcher; Settings remains the place for connecting, disconnecting, and fully managing platform accounts.

### Design intent

This turns the avatar ring into a recognizable StatusXP feature: it identifies the player's currently presented platform, provides immediate feedback when that identity changes, and gives users a convenient way to switch without navigating away from the dashboard.

### Acceptance criteria for future implementation

- The avatar treatment always agrees with the selected presented platform.
- Only connected platforms can be selected from the quick switcher.
- Switching platforms persists after the app is restarted.
- The same preference is reflected in Settings.
- The interaction remains understandable without relying on color alone.
- Switching the presented platform does not alter or hide the user's combined StatusXP score.

## Step 2: Replace the outlined Menu pill with quiet navigation

The large cyan-outlined **Menu** pill makes a routine navigation control compete with the player's identity and dashboard content. Its combination of a hamburger icon, text label, rounded border, and neon treatment contributes to the generic cyber-dashboard appearance.

### Header control

- Remove the outlined **Menu** pill, including its permanent border, background, and glow.
- Replace it with a familiar menu icon sized to a minimum 44 × 44 logical-pixel touch target.
- Do not show a visible container while the control is idle.
- Use the same icon family, size, and stroke weight as the adjacent background and sync controls.
- Display the utility icons in white or a muted neutral color.
- Use the active platform color only for a subtle pressed, focused, or selected state.
- Keep the player identity and platform switcher as the visual anchor on the left side of the header.

Proposed header structure:

```text
[Avatar]  Player name              [Background] [Sync] [Menu]
          Active platform
```

### Header actions

- Keep the existing background-customization action in the header. Its icon should clearly communicate choosing, uploading, repositioning, or removing a dashboard background.
- Replace the standalone Settings gear with a global **Sync** action.
- The Sync action should synchronize every relevant connected platform instead of requiring users to visit Settings or trigger separate routine syncs.
- While syncing, prevent duplicate requests and show a clear progress state.
- Report the result by platform when necessary, preserving successful platform results if another platform fails.
- Routine app tasks should be available where users need them; Settings should be reserved for configuration and account management.

### Settings placement

- Remove the separate Settings icon from the main header.
- Place Settings at the bottom of the navigation opened by the menu icon.
- The header should contain three utility actions on the right: background customization, global sync, and navigation.

### Navigation behavior

- The menu icon should open the app's navigation panel or sheet.
- Use the familiar menu symbol rather than inventing an unfamiliar branded symbol.
- Express StatusXP's personality inside the opened navigation through meaningful account information, active-platform treatment, XP information, and purposeful destinations.
- Final contents and visual treatment of the opened navigation will be documented separately before implementation.

### Design intent

Routine controls should remain visually quiet so StatusXP's player identity, score, recommendations, and progress can carry the brand. Removing the decorative pill reduces the generated cyber-interface appearance and creates a clearer header hierarchy.

### Acceptance criteria for future implementation

- No outlined **Menu** pill remains in the dashboard header.
- The replacement menu control has a touch target of at least 44 × 44 logical pixels.
- Background, Sync, and Menu controls use consistent icon styling and alignment.
- The standalone Settings gear is removed from the header.
- Settings remains available at the bottom of the opened navigation.
- Global Sync handles all connected platforms and communicates partial failures without discarding successful results.
- The resting menu control has no neon border or glow.
- Pressed and focus states remain visible and accessible.
- The player identity remains the primary visual element in the header.

## Step 3: Replace the score circles with an interactive StatusXP logo

Replace the large standalone StatusXP score circle, the three static platform circles, and the detached average-per-game boxes with one interactive visualization based directly on the StatusXP logo.

The complete logo should remain visible on the dashboard. Its platform nodes should display live StatusXP contributions and act as controls for exploring each connected platform.

### Core presentation

- Preserve the recognizable geometry and connections of the StatusXP logo.
- Show the combined StatusXP total at the center of the visualization.
- Show PlayStation, Xbox, and Steam as connected platform nodes in their corresponding logo positions.
- Use the established platform colors:
  - **PlayStation:** neon blue/cyan.
  - **Xbox:** neon green.
  - **Steam:** cool steel blue, silver, or cool white against a dark node.
  - **StatusXP:** signature purple.
- Display each platform's StatusXP contribution inside or immediately beside its node.
- Make it clear that the platform contributions combine into the central StatusXP total.
- Use the logo's connecting lines or arrows as part of the brand rather than rearranging the visualization into a generic statistics grid.

Example data relationship:

```text
PlayStation StatusXP + Xbox StatusXP + Steam StatusXP = Total StatusXP
       62,239        +       165       +      2,225     =    64,629
```

### Interactions

- Make the center StatusXP value clickable.
- Tapping the center should open the combined score calculation, platform contributions, recent StatusXP gains, and other overall score details that are available.
- Make every connected platform node clickable.
- Tapping a platform should open a bottom sheet containing that platform's detailed statistics and a clear action to view its games.
- Keep the interactive logo visible after the detail sheet is dismissed.
- Highlight the selected node and its connection to the center with a restrained platform-colored response.

### Platform detail content

The platform sheets should use native platform measurements rather than forcing every platform into the same statistics.

**PlayStation**

- StatusXP contribution
- Total trophies
- Platinum, gold, silver, and bronze counts
- Games played
- Completion percentage
- View PlayStation games

**Xbox**

- StatusXP contribution
- Gamerscore
- Achievements earned
- Games played
- Completion percentage
- View Xbox games

**Steam**

- StatusXP contribution
- Achievements earned
- Perfect games when available
- Games played
- Completion percentage
- View Steam games

### Connected-account states

- Show live scores and full interaction for connected platforms.
- Provide a subtle, optional **Connect platform** state in unused logo positions when a supported platform is not connected.
- Do not imply that an unconnected platform contributes to the total.
- Ensure the visualization still looks intentional with one, two, or three connected platforms.

### Motion and accessibility

- The full logo should remain visible rather than requiring users to discover an expand interaction.
- A short one-time entrance animation may draw the connecting lines and fade in the nodes when the dashboard loads.
- Do not repeatedly animate the component or use excessive bounce effects.
- Respect reduced-motion settings.
- Give every node an accessible label that includes the platform name, StatusXP contribution, and action.
- Do not rely on platform color alone; retain platform names or recognizable symbols.

### Implementation direction

- Build the visualization directly in Flutter; do not create it as a Blender animation or other fixed rendered asset.
- Use responsive Flutter layout for the live score nodes and interaction targets.
- Use a `CustomPainter` for the logo connections where appropriate.
- Use standard Flutter widgets layered above the connections for readable text, semantic labels, and touch handling.
- Use the highest-quality StatusXP logo available as the geometry and proportion reference. SVG is preferred, but a large transparent PNG is sufficient as a reference.
- Keep live values as text rendered by Flutter so they remain dynamic, scalable, localizable, and accessible.

### Acceptance criteria for future implementation

- The visualization is immediately recognizable as an interactive version of the StatusXP logo.
- The combined total equals the displayed connected-platform contributions.
- Every connected platform node opens the correct platform details.
- The center opens a meaningful combined StatusXP breakdown.
- The component replaces the existing redundant score and platform-circle layouts.
- The layout works without clipping on supported phone widths and at increased text scale.
- One-, two-, and three-platform account states are visually complete.
- Reduced-motion and screen-reader users can access the same information and actions.

## Next steps

Continue the dashboard review and add each approved direction as the next numbered step. No implementation should begin until the design direction is ready for development.
