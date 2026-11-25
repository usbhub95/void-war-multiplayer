panel_open = false;
dialog_id = -1;
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
