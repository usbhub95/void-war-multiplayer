# Void War co-op connection probe

This Windows Steam mod tests whether two copies of Void War can exchange messages using the game's bundled Steam P2P extension. Both players connect from the title screen. The experimental crew test keeps that connection open while the host starts a fight.

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

Record the result on both PCs and the status shown if either fails. Direct IP is the planned fallback if the Steam probe fails the remote test. Steam's bundled P2P API is [deprecated by Valve](https://partner.steamgames.com/doc/api/ISteamNetworking).

## Shared crew playtest

1. Install this build on both PCs. Open the panel with **F8** and use **F7** to set one player to **Host** and the other to **Guest** before entering peer IDs. Wait for both reply counters to increase.
2. The guest stays on the title screen with the panel open. The host starts a run, enters combat, selects one living crew member on their own ship, and presses **F6**. Both panels should show the same numbered room map.
3. On the guest PC, use **Left/Right** to choose a room and **Enter** to give the order. The host's game should move the selected crew member. Verify both panels report the same destination and arrival. If combat is paused, unpause it on the host to see movement.
4. Redirect the same crew member with the host's normal controls, then send another guest order. If both issue an order, the last valid order processed on the host should determine the destination. Check both panels agree where the crew member arrives.
5. Press **F10** on the guest. Verify the host can still move the crew normally after the session ends.

The guest uses the panel for this milestone. The numbered map shows up to 24 rooms from the host's ship. The host validates reachability at the time of the order. This build uses probe protocol 2, so both PCs need the same revision.
