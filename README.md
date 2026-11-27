# Void War co-op mod

Two Windows Steam players can control one shared crew member aboard the host's ship. Both players connect from the title screen, and the host runs the encounter.

For project status, architecture, and verification history, see the [development handoff](docs/DEVELOPMENT.md).

## Build

Use Windows Steam build `26906873`. Run these commands from the repository in PowerShell.

```powershell
.\scripts\Setup-Assets.ps1
.\scripts\New-Build.ps1
```

Run setup once per checkout. It verifies and caches the vanilla `data.win` in `assets\data.win`. It also downloads the pinned Windows UndertaleModCli release and verifies its SHA-256 before extracting it into `assets\undertalemodcli\0.9.2.0`. Both paths are Git-ignored. Setup needs internet access for the first CLI download. Later builds use the cached files offline and write `build\data.win`. Both PCs should use the same source revision and compare the printed build hashes. [Official CLI release](https://github.com/UnderminersTeam/UndertaleModTool/releases/tag/0.9.2.0)

Setup discovers Void War from Steam. Use `-GameDirectory` to point setup at the installed game folder manually, or `-SteamDirectory` to specify the Steam client folder. If the installed data has been replaced, use Steam's **Verify integrity of game files** before the first setup and check for the pinned vanilla SHA-256 `ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B`. If you already have the pinned vanilla file, place it at `assets\data.win` and run setup to verify it. To build directly from a vanilla installation, pass `-GameDirectory` to the build script. To use a manually installed CLI, pass `-UndertaleModCli` with the executable path.

### Clean generated files

Use [Clear-TemporaryFiles.ps1](scripts/Clear-TemporaryFiles.ps1) to clear `temp/` and remove logs and other temporary files from `build/`. The script preserves `build\data.win`.

```powershell
.\scripts\Clear-TemporaryFiles.ps1 -WhatIf
.\scripts\Clear-TemporaryFiles.ps1
```

The first command previews the cleanup. The regular build replaces `build\data.win` after compilation succeeds, so routine builds can run with the previous output in place.

## Install and restore

Close Void War and run the [playtest launcher](scripts/Start-VoidWar.ps1) from the repository.

```powershell
.\scripts\Start-VoidWar.ps1
```

The launcher finds Steam and Void War, stages `build\data.win` beside the game as `void-war-playtest.win` so the runner can load the bundled fonts, and starts it through Steam. Steam's normal **Play** button uses the installed `data.win`. Use `-GameFile` for a different `.win`, `-GameDirectory` or `-SteamDirectory` for custom installations, and `-WhatIf` to preview the launch.

## Remote playtest

Use two Windows PCs on separate internet connections, signed into separate Steam accounts with access to the full game.

1. At the title screen, press **F8** on both PCs. Exchange the 17-digit Steam IDs displayed in the panel.
2. On both PCs, press **F9** to open the in-game field. Type the other player's ID or press **Ctrl+V** to paste it, then click **Connect** or press **Enter**. Confirm within 30 seconds of each other. To close the field, click **Cancel** or press **F9** again. Both panels should show **Connected through Steam**, an increasing reply count, and an RTT in milliseconds.
3. Press **F10** on one PC. It should show **Disconnected locally.** The other PC should show **Peer stopped replying.** within 10 seconds of its last reply. Repeat the connection, then close Void War on one PC and check the survivor times out again.
4. For a one-sided test, leave one panel idle and start the probe on the other PC. The active side should time out without receiving a reply. With a third consenting tester, attempt a probe against a player who selected someone else and verify that the third tester receives no replies.
5. To check protocol mismatch, build a test copy from a scratch checkout with `probe_version` changed in `src/Create.gml`. Connect it to the standard probe. Neither side should report a successful connection. At least one panel should report **Peer has a different build or probe version.** Launch the standard co-op build on both PCs after the mismatch check.

Repeat these checks when validating a new protocol build. Record the status shown on each PC if a check fails.

## Shared crew playtest

1. Launch the [co-op build](#install-and-restore) on both PCs. Open the panel with **F8** and use **F7** to set the **Host** and **Guest** roles before connecting. Follow the ID entry steps in the [remote playtest](#remote-playtest) and wait for both reply counters to increase.
2. The guest stays on the title screen with the panel open. The host starts a run, enters combat, selects one living crew member on their own ship, and presses **F6**. Both panels should show the same numbered map of up to 24 rooms.
3. In the guest's numbered panel, use **Left/Right** to choose a room and **Enter** to give the order. The host's game should move the selected crew member. Verify both panels report the same destination and arrival. If combat is paused, unpause it on the host to see movement.
4. Redirect the same crew member with the host's normal controls, then send another guest order. If both issue an order, the last valid order processed on the host should determine the destination. Check both panels agree where the crew member arrives.
5. Press **F10** on the guest. Verify the host can still move the crew normally after the session ends.

## Guest ship playtest

1. Follow the first two steps of the [shared crew playtest](#shared-crew-playtest) to connect and share one crew member in a starter encounter.
2. On the guest, press **F5**. The guest ship view should show the host ship's room layout and the shared crew's in-game sprite. On the host, send the crew in opposite directions and then let it stop. The guest should see walking, turns, and the idle sprite, with smooth position changes between updates. Click the crew where it is drawn while moving to verify selection. Pause the host and check that the guest animation stops after the next update.
3. Left-click empty space to clear the crew selection, then right-click a tile. This should send no order. Left-click the crew, then right-click a tile in a multi-tile room. Check that the host moves the crew member to that exact vacant tile and the guest shows the same tile and **Arrived**. Right-click a second vacant tile in the same room and check that the crew moves again.
4. Put another allied crew member on a reachable tile and let them arrive. With the host's mouse idle and their crew selection cleared, select the shared crew on the guest and right-click that occupied tile. The shared crew should reserve the exact clicked tile, the occupant should move to a free tile, and the guest should show the clicked tile and **Order accepted**. Redirect the crew with the host's normal controls, then issue another guest order. Confirm that the last valid order processed on the host determines the destination.
5. Press **F5** on the guest to return to the numbered panel and check that the connection survives. Reopen the ship view and press **F10** there. The guest should return to the title screen and the host should retain normal movement controls.

If the ship view fails at a step, record the starter ship, which room was clicked, and what the host and guest displayed. Follow the numbered-panel test to check whether peer connectivity and the host movement path still work.

## Empire cruiser guest view playtest

The native starter view uses the bundled hull, border, and room sprites for **Triumph of Heaven**.

1. Follow the first two steps of the [shared crew playtest](#shared-crew-playtest) on **Triumph of Heaven**. Confirm the host can select and move crew normally before sharing with **F6**.
2. On the guest, press **F5** to enter the layout view and **F4** to switch to the native starter view. Check that the hull, border, and rooms line up with the host and that the crew appears at the host's tile.
3. Run the [guest ship playtest](#guest-ship-playtest) movement checks in the native view. Include vacant tiles in different room shapes.
4. Move the host's shared crew into another room and press **F6** again. The native starter view should still line up once the new layout arrives. Press **F4** to switch back and verify that the layout view still accepts an order.
5. Run the [guest ship playtest](#guest-ship-playtest) exit checks. Press **F4** after reopening the ship view so **F10** is tested from the native view.

If you try another ship, **F4** should report that the native view is unavailable and leave the layout view usable. Report whether the native view opened, how the crew and rooms lined up, and any wrong tile or fallback.

## Native crew input experiment

This is a one-PC diagnostic. Select one crew member at a time in a normal starter encounter. Use a run you are comfortable testing in.

Run the [build command](#build) with `-NativeInput` to generate the diagnostic in `build\data.win`, then launch with runner logging enabled. Run the default build again when returning to co-op. [GameMaker command-line parameters](https://manual.gamemaker.io/lts/en/Settings/Command_Line_Parameters.htm)

```powershell
.\scripts\Start-VoidWar.ps1 -LogOutput
$log = '.\build\void-war-playtest.log'
```

Check the game log for `[Native crew input] ready` after launch. Each accepted click should produce one order line with the selected crew member and destination room. The crew should move as in normal play.

| Click | Expected order line |
| --- | --- |
| Right-click another reachable room with precision mode off | `room` and `slot=0` |
| Right-click a vacant tile with precision mode on | `precision` and the clicked slot |
| Right-click a tile occupied by another allied crew member with precision mode on | `occupied` and the clicked slot. The game applies its normal fallback. |
| With precision mode off, right-click the selected crew member's current room while its mannable console slot is vacant and the crew member is on another slot | `console` and the console slot |
| Right-click with no selection or observe idle combat without giving orders | No order lines |

Close the game and filter the log with `Select-String -LiteralPath $log -SimpleMatch '[Native crew input]'`. Report the matching order lines and whether each move behaved as expected.
