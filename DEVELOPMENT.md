# Development handoff

## Goal and scope

Build remote co-op for two players sharing control of one ship in Void War. The long-term requirement is for the guest to issue crew orders through the same native interaction used in single-player. The temporary guest panel tests host-side command handling and state sync before any work on native guest input or a replicated combat view.

The current target is the full Windows Steam game, build `26906873`, with a copy of the game on each PC. Steam networking was the first choice. Direct IP was the agreed fallback if Steam failed the remote connection test. That test passed, so the project uses Steam. Keep original game data, patched binaries, and extracted game assets out of Git. Build and install from each player's own copy using the [README](README.md#build).

## Architecture and game integration

- [New-ProbeData.ps1](New-ProbeData.ps1) pins the vanilla input by SHA-256, runs UndertaleModTool CLI 0.9.2.0, and publishes a new output without overwriting an existing file. [ApplyProbe.csx](probe/ApplyProbe.csx) compiles the GML, registers two Steam extension functions the compiler otherwise treats as variables, and installs a guarded creation hook in `rmMainMenu`. The persistent probe is intended to carry the connection through room changes without spawning a duplicate on return to the menu.
- [Create.gml](probe/Create.gml) and [Step.gml](probe/Step.gml) handle Steam IDs, the in-game editor, and the two-peer session. IDs are parsed digit by digit as 64-bit integers. The peer's Steam ID, packet bounds, magic, game build, and protocol version are checked. Ping/pong measures RTT and detects loss of replies. **F10** closes the local session. [Cleanup.gml](probe/Cleanup.gml) also frees the buffers when the probe is destroyed.
- [CrewTest.gml](probe/CrewTest.gml) extends the probe to protocol **2**. The 15-byte header still carries magic, build, protocol, packet kind, and sequence. The host sends crew snapshots every 250 ms. The guest retries one numbered order at a time until a snapshot acknowledges it. The host uses the sharing token to reject orders for an old selection and sequence numbers to avoid applying duplicates. Room numbers refer to cells in the host's map of up to 24 rooms. GameMaker instance IDs stay on the host.
- The native room-click path in `oCell` Step calls `crew_move_set_target` from `scrCrewMovement` for ordinary room movement. The host uses that function for guest orders after checking the live crew, hull, and destination. `currentCellID` is the reserved destination and can change before physical arrival. The snapshot uses `collidingCellID` while moving and `crew_has_reached_destination` to report arrival. The host runs the encounter. The last valid order processed by the host wins, whether it came from the host or the guest. The playtest confirmed this behavior and the user approved it. The guest stays at the title screen and sees a numbered map and the host's reported state.

References for build-specific work include the [Void War developer FAQ](https://steamcommunity.com/app/2853590/discussions/0/4695658570140629717/), [UndertaleModTool 0.9.2.0](https://github.com/UnderminersTeam/UndertaleModTool/releases/tag/0.9.2.0), [GameMaker instance persistence](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/Asset_Management/Instances/Instance_Variables/persistent.htm), and [Valve's legacy P2P API reference](https://partner.steamgames.com/doc/api/ISteamNetworking). Valve deprecates that API. It is the one available through Void War's bundled GameMaker extension and used in the successful connection playtest.

## Verification and current checkpoint

| Milestone | Evidence | Status |
| --- | --- | --- |
| Patch and launch | Vanilla UndertaleModTool round-trip was byte-identical. Earlier patch builds reproduced, the probe initialized at the title screen through Steam, and restoring the original was verified by SHA-256. | Verified on the pinned build. |
| Remote connection and ID editor | Two-PC testers confirmed connection, rising reply counts, guest disconnect followed by host timeout, version mismatch rejection, and that the replacement in-game ID field works as intended. | Complete. These results predate protocol 2. |
| Shared crew | Commit `eb8c0fc` implements the milestone. The rebuilt data reopened with a persistent probe and direct native movement, reachability, arrival, and Steam calls. A temporary Steam runner fixture passed synthetic snapshot, arrival, acknowledgement, stale and malformed packet, duplicate-order, and disconnect cleanup checks. A live two-PC playtest confirmed guest movement, the most recent processed order taking priority across host and guest, and normal host movement after guest disconnect. | Shared-control checkpoint passed. Exact room-map parity and arrival display were not separately reported. |

The current local `build/data.win` was rebuilt from the previous probe artifact and verified as `A2680D491F639F05BBF1924F75DC635C0ED5807E4ED3FA22919EC8A31EA4891C`. A fresh patch from vanilla input need not have that same artifact hash. Compare hashes for builds produced from the same revision, tool version, and vanilla input. The Steam install was last observed to contain the older probe, so use the saved vanilla backup as the patcher's input. The SHA-256 gate in the build script is the source of truth.

The runtime fixtures were temporary. For future changes, build from the pinned vanilla file, reopen the result in UndertaleModTool, and inspect actual compiled calls when changing bindings or hooks. Do a local Steam smoke test where practical. Record synthetic runner results separately from live game and remote playtest observations.

## Technical history and known issues

- `b3efb45` fixed the old native dialog crash. UndertaleModTool compiled `async_load[? "id"]` as array indexing and tried to convert `"id"` to an integer. Explicit map lookups worked in the runner. `5bb993f` then removed the native dialog because returning from Alt-Tab in fullscreen made it minimize whenever the player interacted with it. The in-game editor keeps its own draft across focus changes.
- `8b484ba` fixed a receive crash caused by `steam_net_packet_get_size` compiling as a variable read. `steam_net_close_p2p_session` had the same problem. Register both using their bundled extension declarations before compiling and verify direct calls. Both ran in Steam.
- With a mismatched version, the peer that detects the mismatch closes the session immediately. Two-PC testers saw a mismatch on one side and **No reply** on the other. This is a reporting asymmetry. An off-directory `-game` smoke-test file also failed because the runner could not find the game's bundled Chinese font. A temporary sidecar beside the installed data worked and allowed the installed file hash to remain intact.

## Resume here

The [shared crew playtest](README.md#shared-crew-playtest) confirmed the command path, conflict rule, and disconnect behavior. The next milestone to scope is native guest crew input. Agree on what combat state the guest needs to see and how native selected-crew and room-click input resolves to host-owned targets before implementation. Retain the current panel as a reproducible control for testing the transport and host command path.
