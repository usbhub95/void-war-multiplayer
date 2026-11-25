panel_open = false;
entry_open = false;
entry_text = "";
entry_error = "";
entry_left = 28;
entry_top = 82;
entry_width = 284;
entry_height = 24;
entry_button_top = 114;
entry_button_width = 126;
entry_button_height = 26;
entry_cancel_left = entry_left + entry_button_width + 8;
peer_text = "";
peer_id = int64(0);
probe_status = "Idle";
round_trip_ms = -1;
reply_count = 0;

probe_magic = 0x31505756;
game_build = 26906873;
probe_version = 1;
packet_length = 15;
ping_packet = 1;
pong_packet = 2;
outbound = buffer_create(packet_length, buffer_fixed, 1);
inbound = buffer_create(packet_length, buffer_fixed, 1);
sequence = current_time;
pending_sequence = -1;
ping_sent_at = 0;
next_ping_at = 0;
deadline = 0;

enter_peer_id = function(_text) {
    if (string_length(_text) != 17 || string_digits(_text) != _text) {
        entry_error = "Enter the peer's 17-digit Steam ID.";
        return;
    }

    // Build the ID as an int64 so distinct accounts survive conversion without rounding.
    var _target = int64(0);
    for (var _index = 1; _index <= 17; _index += 1) {
        var _digit = ord(string_char_at(_text, _index)) - ord("0");
        _target = _target * int64(10) + int64(_digit);
    }
    if ((_target >> 32) != 0x01100001 || _target == steam_get_user_steam_id()) {
        entry_error = "Enter another player's individual Steam ID.";
        return;
    }

    peer_text = _text;
    peer_id = _target;
    round_trip_ms = -1;
    reply_count = 0;
    next_ping_at = current_time;
    deadline = current_time + 30000;
    probe_status = "Waiting for peer...";
    entry_open = false;
};

stop_probe = function(_reason) {
    if (peer_id != 0 && steam_initialised()) {
        steam_net_close_p2p_session(peer_id);
    }
    peer_id = int64(0);
    pending_sequence = -1;
    probe_status = _reason;
};

send_probe = function(_kind, _sequence) {
    buffer_seek(outbound, buffer_seek_start, 0);
    buffer_write(outbound, buffer_u32, probe_magic);
    buffer_write(outbound, buffer_u32, game_build);
    buffer_write(outbound, buffer_u16, probe_version);
    buffer_write(outbound, buffer_u8, _kind);
    buffer_write(outbound, buffer_u32, _sequence);
    return steam_net_packet_send(peer_id, outbound, packet_length);
};

read_probe = function() {
    if (steam_net_packet_get_sender_id() != peer_id) return;
    if (steam_net_packet_get_size() != packet_length) return;
    if (!steam_net_packet_get_data(inbound)) return;

    buffer_seek(inbound, buffer_seek_start, 0);
    if (buffer_read(inbound, buffer_u32) != probe_magic) return;

    var _build = buffer_read(inbound, buffer_u32);
    var _version = buffer_read(inbound, buffer_u16);
    if (_build != game_build || _version != probe_version) {
        stop_probe("Peer has a different build or probe version.");
        return;
    }

    var _kind = buffer_read(inbound, buffer_u8);
    var _sequence = buffer_read(inbound, buffer_u32);
    if (_kind == ping_packet) {
        send_probe(pong_packet, _sequence);
    } else if (_kind == pong_packet && _sequence == pending_sequence) {
        round_trip_ms = current_time - ping_sent_at;
        pending_sequence = -1;
        reply_count += 1;
        deadline = current_time + 10000;
        probe_status = "Connected through Steam";
    }
};

show_debug_message("[Void War probe] Ready at the title screen.");
