if (entry_open) {
    // Keep the draft in the probe across Windows focus changes.
    if (!window_has_focus()) exit;

    var _mouse_x = device_mouse_x_to_gui(0);
    var _mouse_y = device_mouse_y_to_gui(0);
    var _click = mouse_check_button_pressed(mb_left);
    var _on_buttons = _click && _mouse_y >= entry_button_top
        && _mouse_y < entry_button_top + entry_button_height;

    if (keyboard_check_pressed(vk_f9) || (_on_buttons && _mouse_x >= entry_cancel_left
            && _mouse_x < entry_cancel_left + entry_button_width)) {
        entry_open = false;
        exit;
    }

    if (keyboard_check(vk_control)) {
        if (keyboard_check_pressed(ord("V"))) {
            var _paste = string_trim(clipboard_get_text());
            if (string_length(_paste) == 17 && string_digits(_paste) == _paste) {
                entry_text = _paste;
                entry_error = "";
            } else {
                entry_error = "Clipboard must contain a 17-digit Steam ID.";
            }
        } else if (keyboard_check_pressed(ord("A"))) {
            entry_text = "";
            entry_error = "";
        }
    } else if (!keyboard_check(vk_alt)) {
        if (keyboard_check_pressed(vk_backspace)) {
            entry_text = string_copy(entry_text, 1, max(0, string_length(entry_text) - 1));
            entry_error = "";
        }
        for (var _digit = 0; _digit < 10 && string_length(entry_text) < 17; _digit += 1) {
            if (keyboard_check_pressed(ord("0") + _digit) || keyboard_check_pressed(vk_numpad0 + _digit)) {
                entry_text += string(_digit);
                entry_error = "";
            }
        }
    }

    if (keyboard_check_pressed(vk_enter) || (_on_buttons && _mouse_x >= entry_left
            && _mouse_x < entry_left + entry_button_width)) {
        enter_peer_id(entry_text);
    }
    exit;
}

if (keyboard_check_pressed(vk_f8)) {
    panel_open = !panel_open;
    if (!panel_open && peer_id != 0) stop_probe("Disconnected locally.");
}
if (!panel_open) exit;

if (window_has_focus() && keyboard_check_pressed(vk_f9) && peer_id == 0) {
    if (steam_initialised() && steam_is_user_logged_on()) {
        entry_text = peer_text;
        entry_error = "";
        entry_open = true;
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
