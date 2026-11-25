if (keyboard_check_pressed(vk_f8) && dialog_id == -1) {
    panel_open = !panel_open;
    if (!panel_open && peer_id != 0) stop_probe("Disconnected locally.");
}
if (!panel_open) exit;

if (keyboard_check_pressed(vk_f9) && dialog_id == -1 && peer_id == 0) {
    if (steam_initialised() && steam_is_user_logged_on()) {
        dialog_id = get_string_async("Enter your peer's 17-digit Steam ID", peer_text);
    } else {
        probe_status = "Launch through Steam and sign in.";
    }
}

if (keyboard_check_pressed(vk_f10) && peer_id != 0) {
    stop_probe("Disconnected locally.");
}
if (peer_id == 0) exit;

if (!steam_initialised() || !steam_is_user_logged_on()) {
    stop_probe("Steam went offline.");
    exit;
}

var _remaining = 16;
while (peer_id != 0 && _remaining > 0 && steam_net_packet_receive()) {
    read_probe();
    _remaining -= 1;
}
if (peer_id == 0) exit;

if (current_time >= deadline) {
    if (reply_count > 0) {
        stop_probe("Peer stopped replying.");
    } else {
        stop_probe("No reply. Check both Steam IDs and retry.");
    }
    exit;
}

if (current_time >= next_ping_at) {
    sequence = (sequence + 1) mod 4294967296;
    ping_sent_at = current_time;
    pending_sequence = sequence;
    next_ping_at = current_time + 2000;

    // An outgoing packet also accepts Steam's session for this specific peer.
    if (!send_probe(ping_packet, sequence) && reply_count == 0) {
        probe_status = "Steam send failed. Retrying...";
    }
}
