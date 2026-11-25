if (dialog_id == -1 || async_load[? "id"] != dialog_id) exit;
dialog_id = -1;
if (!async_load[? "status"]) exit;

var _text = string_trim(async_load[? "result"]);
if (string_length(_text) != 17 || string_digits(_text) != _text) {
    probe_status = "Enter the peer's 17-digit Steam ID.";
    exit;
}

// Build the ID as an int64 so distinct accounts survive conversion without rounding.
var _target = int64(0);
for (var _index = 1; _index <= 17; _index += 1) {
    var _digit = ord(string_char_at(_text, _index)) - ord("0");
    _target = _target * int64(10) + int64(_digit);
}
if ((_target >> 32) != 0x01100001 || _target == steam_get_user_steam_id()) {
    probe_status = "Enter another player's individual Steam ID.";
    exit;
}

peer_text = _text;
peer_id = _target;
round_trip_ms = -1;
reply_count = 0;
next_ping_at = current_time;
deadline = current_time + 30000;
probe_status = "Waiting for peer...";
