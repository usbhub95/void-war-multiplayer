# Void War co-op connection probe

This Windows Steam mod tests whether two copies of Void War can exchange messages using the game's bundled Steam P2P extension. Both players connect from the title screen. The experimental crew test keeps that connection open while the host starts a fight.

For project status, architecture, and verification history, see the [development handoff](DEVELOPMENT.md).

## Build

Use the full Windows Steam build `26906873` and [UndertaleModTool CLI 0.9.2.0 for Windows](https://github.com/UnderminersTeam/UndertaleModTool/releases/tag/0.9.2.0). In Steam, select **Void War → Manage → Browse local files** to find your original `data.win`. Extract the CLI zip, then run this from the repository in PowerShell with your two paths.

```powershell
.\New-ProbeData.ps1 -GameData 'D:\SteamLibrary\steamapps\common\Void War\data.win' `
    -UndertaleModCli 'C:\Tools\UTMT\UndertaleModCli.exe'
```

The script checks the original SHA-256 and writes `build\data.win`. Use the same source revision and CLI version on both PCs and compare the printed output hashes. To build again, choose a fresh filename with `-Output`.

## Install and restore

1. Close Void War. Back up the original `data.win` outside the Steam install folder.
2. Copy your locally built `build\data.win` over `data.win` in the Void War folder, then launch from Steam.
3. To uninstall, exit the game and copy the original `data.win` back. Check that its SHA-256 is `ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B`. If Steam has updated the game since the test, use Steam's **Verify integrity of game files** to restore the current build.

## Remote playtest

Use two Windows PCs on separate internet connections, signed into separate Steam accounts with access to the full game.

1. At the title screen, press **F8** on both PCs. Exchange the 17-digit Steam IDs displayed in the panel.
2. On both PCs, press **F9** to open the in-game field. Type the other player's ID or press **Ctrl+V** to paste it, then click **Connect** or press **Enter**. Confirm within 30 seconds of each other. To close the field, click **Cancel** or press **F9** again. Both panels should show **Connected through Steam**, an increasing reply count, and an RTT in milliseconds.
3. Press **F10** on one PC. It should show **Disconnected locally.** The other PC should show **Peer stopped replying.** within 10 seconds of its last reply. Repeat the connection, then close Void War on one PC and check the survivor times out again.
4. For a one-sided test, leave one panel idle and start the probe on the other PC. The active side should time out without receiving a reply. With a third consenting tester, attempt a probe against a player who selected someone else and verify that the third tester receives no replies.
5. To check protocol mismatch, build a test copy from a scratch checkout with `probe_version` changed in `probe/Create.gml`. Connect it to the standard probe. Neither side should report a successful connection. At least one panel should report **Peer has a different build or probe version.** Restore both PCs to the standard probe before retesting.

Record the result on both PCs and the status shown if either fails. The original connection milestone passed over Steam on two PCs. Repeat these checks when validating a new protocol build. Steam's bundled P2P API is [deprecated by Valve](https://partner.steamgames.com/doc/api/ISteamNetworking).

## Shared crew playtest

1. Install this build on both PCs. Open the panel with **F8** and use **F7** to set one player to **Host** and the other to **Guest** before entering peer IDs. Wait for both reply counters to increase.
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

## Native crew input experiment

This one-PC test uses an optional diagnostic build. Select one crew member at a time in a normal starter encounter. Use a run you are comfortable testing in.

To build the diagnostic from the vanilla file for build `26906873` or the pinned protocol 5 probe, run UndertaleModTool CLI 0.9.2.0 from the repository. The example uses the protocol 5 probe as input.

```powershell
& 'C:\Tools\UTMT\UndertaleModCli.exe' load .\build\data.win `
    --scripts .\experiments\NativeCrewInput.csx --output .\build\native-input.win
```

With the game closed, copy `build\native-input.win` beside the installed `data.win` as `void-war-native-input.win`, then launch it through Steam. Adjust the paths for your installation. The sidecar needs to be in the game directory so the runner can load its bundled fonts. [GameMaker command-line parameters](https://manual.gamemaker.io/lts/en/Settings/Command_Line_Parameters.htm)

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
