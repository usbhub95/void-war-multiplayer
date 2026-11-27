# Void War co-op connection probe

This Windows Steam mod tests whether two copies of Void War can exchange messages using the game's bundled Steam P2P extension. Both players connect from the title screen. The experimental crew test keeps that connection open while the host starts a fight.

For project status, architecture, and verification history, see the [development handoff](DEVELOPMENT.md).

## Build

Use an unmodified `data.win` from Windows Steam build `26906873` and [UndertaleModTool CLI 0.9.2.0 for Windows](https://github.com/UnderminersTeam/UndertaleModTool/releases/tag/0.9.2.0). In Steam, select **Void War → Manage → Browse local files** to find the game folder. If it already contains a patched `data.win`, use your vanilla backup as the input. Run this from the repository in PowerShell with your two paths.

```powershell
.\New-ProbeData.ps1 -GameData 'C:\Backups\Void War\data.win' `
    -UndertaleModCli 'C:\Tools\UTMT\UndertaleModCli.exe'
```

Both files are built together in `build\playtest`.

| File | Use |
| --- | --- |
| `void-war-native-guest-scene.win` | Co-op on both PCs, including the Empire cruiser guest view |
| `void-war-native-input.win` | One-PC native crew order diagnostic |

The script checks the vanilla input's SHA-256 and prints the hash of each output. On both PCs, use the same source revision and CLI version and compare the co-op hashes. Rerunning the command reuses identical files. Use `-OutputDirectory` to place both builds in a different folder. To build just one, use `-Target NativeGuestScene` or `-Target NativeInput`, with `-Output` for a custom filename.

## Install and restore

Close Void War, then copy `build\playtest\void-war-native-guest-scene.win` into the game folder with its name intact. Launch through Steam with `-game` pointing to that file. Adjust the Steam and game paths for your installation.

```powershell
$game = 'D:\SteamLibrary\steamapps\common\Void War'
$coop = Join-Path $game 'void-war-native-guest-scene.win'
& 'C:\Program Files (x86)\Steam\steam.exe' -applaunch 2853590 -game "$coop"
```

Steam's normal **Play** button loads the installed `data.win`. Check it with `Get-FileHash -LiteralPath (Join-Path $game 'data.win') -Algorithm SHA256`. The vanilla SHA-256 for build `26906873` is `ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B`. To restore that build after a manual replacement, close Void War and copy your verified vanilla backup over the installed `data.win`.

## Remote playtest

Use two Windows PCs on separate internet connections, signed into separate Steam accounts with access to the full game.

1. At the title screen, press **F8** on both PCs. Exchange the 17-digit Steam IDs displayed in the panel.
2. On both PCs, press **F9** to open the in-game field. Type the other player's ID or press **Ctrl+V** to paste it, then click **Connect** or press **Enter**. Confirm within 30 seconds of each other. To close the field, click **Cancel** or press **F9** again. Both panels should show **Connected through Steam**, an increasing reply count, and an RTT in milliseconds.
3. Press **F10** on one PC. It should show **Disconnected locally.** The other PC should show **Peer stopped replying.** within 10 seconds of its last reply. Repeat the connection, then close Void War on one PC and check the survivor times out again.
4. For a one-sided test, leave one panel idle and start the probe on the other PC. The active side should time out without receiving a reply. With a third consenting tester, attempt a probe against a player who selected someone else and verify that the third tester receives no replies.
5. To check protocol mismatch, build a test copy from a scratch checkout with `probe_version` changed in `probe/Create.gml`. Connect it to the standard probe. Neither side should report a successful connection. At least one panel should report **Peer has a different build or probe version.** Restore both PCs to the standard probe before retesting.

Record the result on both PCs and the status shown if either fails. The original connection milestone passed over Steam on two PCs. Repeat these checks when validating a new protocol build. Steam's bundled P2P API is [deprecated by Valve](https://partner.steamgames.com/doc/api/ISteamNetworking).

## Shared crew playtest

1. Launch the [co-op build](#install-and-restore) on both PCs. Open the panel with **F8** and use **F7** to set one player to **Host** and the other to **Guest** before entering peer IDs. Wait for both reply counters to increase.
2. The guest stays on the title screen with the panel open. The host starts a run, enters combat, selects one living crew member on their own ship, and presses **F6**. Both panels should show the same numbered room map.
3. On the guest PC, use **Left/Right** to choose a room and **Enter** to give the order. The host's game should move the selected crew member. Verify both panels report the same destination and arrival. If combat is paused, unpause it on the host to see movement.
4. Redirect the same crew member with the host's normal controls, then send another guest order. If both issue an order, the last valid order processed on the host should determine the destination. Check both panels agree where the crew member arrives.
5. Press **F10** on the guest. Verify the host can still move the crew normally after the session ends.

The guest uses the panel for this milestone. The numbered map shows up to 24 rooms from the host's ship. The host validates reachability at the time of the order. This build uses probe protocol 5, so both PCs need the same revision. The numbered map is still available for the keyboard playtest above.

## Guest ship playtest

1. Use the shared crew steps to connect both PCs and share one crew member in an encounter on a starter ship.
2. On the guest, press **F5**. The guest ship view should show the host ship's room layout and the shared crew's in-game sprite. On the host, send the crew in opposite directions and then let it stop. The guest should see walking, turns, and the idle sprite, with smooth position changes between updates. Click the crew where it is drawn while moving to verify selection. Pause the host and check that the guest animation stops after the next update.
3. Left-click empty space to clear the crew selection, then right-click a tile. This should send no order. Left-click the crew, then right-click a tile in a multi-tile room. Check that the host moves the crew member to that exact vacant tile and the guest shows the same tile and **Arrived**. Right-click a second vacant tile in the same room and check that the crew moves again.
4. Right-click an occupied tile and compare the result with a native precision-mode click on the host. The guest should highlight the tile the host actually chose. Redirect the crew with the host's normal controls, then issue another guest order. Confirm that the last valid order processed on the host determines the destination.
5. Press **F5** on the guest to return to the numbered panel and check that the connection survives. Reopen the ship view and press **F10** there. The guest should return to the title screen and the host should retain normal movement controls.

If the ship view fails at a step, record the starter ship, which room was clicked, and what the host and guest displayed. Follow the numbered-panel test to check whether peer connectivity and the host movement path still work.

## Empire cruiser guest view playtest

Use `void-war-native-guest-scene.win` from the [default build](#build) and follow the [launch steps](#install-and-restore) on both PCs. This view uses native hull, border, and room sprites for the starter ship **Triumph of Heaven**.

1. Follow the first two steps of the [shared crew playtest](#shared-crew-playtest) on **Triumph of Heaven**. Confirm the host can select and move crew normally before sharing with **F6**.
2. On the guest, press **F5** to enter the layout view and **F4** to switch to the native starter view. Check that the hull, border, and rooms line up with the host and that the crew appears at the host's tile.
3. Select the crew on the guest and right-click vacant tiles in different room shapes. Include a second tile in the same room. Compare where the crew arrives on both PCs. Have the host redirect one order and check that the last order processed by the host wins.
4. Move the host's shared crew into another room and press **F6** again. The native starter view should still line up once the new layout arrives. Press **F4** to switch back and verify that the layout view still accepts an order.
5. Press **F5** to return to the panel. Reopen the view, press **F4**, then press **F10**. The guest should return to the title screen and the host should retain normal crew controls.

If you try another ship, **F4** should report that the native view is unavailable and leave the layout view usable. Report whether the native view opened, how the crew and rooms lined up, and any wrong tile or fallback.

## Native crew input experiment

This one-PC test uses an optional diagnostic build. Select one crew member at a time in a normal starter encounter. Use a run you are comfortable testing in.

With the game closed, copy `build\playtest\void-war-native-input.win` beside the installed `data.win` with its name intact, then launch it through Steam. Adjust the paths for your installation. The sidecar needs to be in the game directory so the runner can load its bundled fonts. [GameMaker command-line parameters](https://manual.gamemaker.io/lts/en/Settings/Command_Line_Parameters.htm)

```powershell
$diagnostic = 'D:\SteamLibrary\steamapps\common\Void War\void-war-native-input.win'
$log = Join-Path (Get-Location) 'build\native-input-playtest.log'
& 'C:\Program Files (x86)\Steam\steam.exe' -applaunch 2853590 -game "$diagnostic" -output "$log"
```

Check the game log for `[Native crew input] ready` after launch. Each accepted click should produce one order line with the selected crew member and destination room. The crew should move as in normal play.

| Click | Expected order line |
| --- | --- |
| Right-click another reachable room with precision mode off | `room` and `slot=0` |
| Right-click a vacant tile with precision mode on | `precision` and the clicked slot |
| Right-click a tile occupied by another allied crew member with precision mode on | `occupied` and the clicked slot. The game applies its normal fallback. |
| With precision mode off, right-click the selected crew member's current room while its mannable console slot is vacant and the crew member is on another slot | `console` and the console slot |
| Right-click with no selection or observe idle combat without giving orders | No order lines |

Close the game and filter the log with `Select-String -LiteralPath $log -SimpleMatch '[Native crew input]'`. Report the matching order lines and whether each move behaved as expected. A normal Steam launch uses the installed `data.win`.
