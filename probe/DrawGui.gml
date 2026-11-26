if (room != rmMainMenu && peer_id == 0) exit;

var _old_color = draw_get_color();
var _old_alpha = draw_get_alpha();
var _old_font = draw_get_font();
var _old_halign = draw_get_halign();
var _old_valign = draw_get_valign();

draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
var _left = 16;
var _top = 16;
var _text = "F8  Steam co-op probe";
if (panel_open) {
    var _identity = "Steam offline";
    if (steam_initialised() && steam_is_user_logged_on()) {
        _identity = "Your Steam ID  " + string(steam_get_user_steam_id());
    }
    _text += "\n" + _identity;
}
if (panel_open && !entry_open) {
    _text += "\nF9  Enter peer ID     F10  Disconnect"
        + "\n" + probe_status;
    if (reply_count > 0) {
        _text += "\nReplies  " + string(reply_count)
            + "   RTT  " + string(round_trip_ms) + " ms";
    }
}

var _show_crew = panel_open && !entry_open && reply_count > 0 && peer_id != 0;
if (panel_open && !entry_open && room == rmMainMenu) {
    _text += "\n" + (crew_host_mode ? "Host" : "Guest");
    if (peer_id == 0) _text += "   F7  Switch role";
}
if (_show_crew) {
    if (crew_token == 0) _text += crew_host_mode ? "\nSelect one crew member in combat, then press F6." : "\nWaiting for the host to share crew.";
    if (crew_token != 0) {
        _text += "\n" + (crew_arrived ? "Arrived" : "Moving")
            + "   Current: " + string(crew_here) + "   Target: " + string(crew_destination);
        if (!crew_host_mode) {
            _text += "\nLeft/Right  Choose room   Enter  Move to " + string(crew_choice);
        }
    }
    if (crew_notice != "") _text += "\n" + crew_notice;
}

var _width = string_width(_text) + 24;
var _height = string_height(_text) + 20;
var _show_map = _show_crew && array_length(crew_rooms) > 0;
if (_show_map) {
    _width = max(_width, 294);
    _height += 132;
}
if (entry_open) {
    _width = max(_width, entry_left + entry_width + 12 - _left);
    _height = entry_button_top + entry_button_height + 60 - _top;
}
draw_set_alpha(0.90);
draw_set_color(make_color_rgb(16, 21, 24));
draw_rectangle(_left, _top, _left + _width, _top + _height, false);
draw_set_alpha(1);
draw_set_color(c_white);
draw_text(_left + 12, _top + 10, _text);

if (_show_map) {
    var _min_x = 0;
    var _max_x = 0;
    var _min_y = 0;
    var _max_y = 0;
    for (var _index = 0; _index < array_length(crew_rooms); _index += 1) {
        var _xy = crew_rooms[_index];
        _min_x = min(_min_x, _xy[0]);
        _max_x = max(_max_x, _xy[0]);
        _min_y = min(_min_y, _xy[1]);
        _max_y = max(_max_y, _xy[1]);
    }
    var _scale = min(248 / max(1, _max_x - _min_x), 104 / max(1, _max_y - _min_y));
    var _map_y = _top + string_height(_text) + 28;
    for (var _index = 0; _index < array_length(crew_rooms); _index += 1) {
        var _xy = crew_rooms[_index];
        var _room = _index + 1;
        var _cx = _left + 19 + round((_xy[0] - _min_x) * _scale);
        var _cy = _map_y + round((_xy[1] - _min_y) * _scale);
        draw_set_color(_room == crew_here ? make_color_rgb(53, 107, 75) : make_color_rgb(43, 52, 60));
        draw_rectangle(_cx - 9, _cy - 8, _cx + 9, _cy + 8, false);
        draw_set_color(_room == crew_choice && !crew_host_mode ? c_yellow : c_white);
        draw_text(_cx - 6, _cy - 7, string(_room));
    }
}

if (entry_open) {
    draw_text(entry_left, entry_top - 17, "Peer's 17-digit Steam ID");
    draw_set_color(make_color_rgb(5, 9, 12));
    draw_rectangle(entry_left, entry_top, entry_left + entry_width, entry_top + entry_height, false);
    draw_set_color(c_white);
    draw_rectangle(entry_left, entry_top, entry_left + entry_width, entry_top + entry_height, true);
    draw_text(entry_left + 6, entry_top + 4, entry_text + (window_has_focus() ? "|" : ""));

    draw_set_color(make_color_rgb(55, 67, 74));
    draw_rectangle(entry_left, entry_button_top, entry_left + entry_button_width,
        entry_button_top + entry_button_height, false);
    draw_rectangle(entry_cancel_left, entry_button_top, entry_cancel_left + entry_button_width,
        entry_button_top + entry_button_height, false);
    draw_set_color(c_white);
    draw_text(entry_left + 8, entry_button_top + 5, "Connect [Enter]");
    draw_text(entry_cancel_left + 8, entry_button_top + 5, "Cancel [F9]");
    draw_text(entry_left, entry_button_top + entry_button_height + 7, "Ctrl+V Paste    Ctrl+A Clear");
    if (entry_error != "") {
        draw_set_color(make_color_rgb(255, 183, 131));
        draw_text(entry_left, entry_button_top + entry_button_height + 25, entry_error);
    }
}

draw_set_color(_old_color);
draw_set_alpha(_old_alpha);
draw_set_font(_old_font);
draw_set_halign(_old_halign);
draw_set_valign(_old_valign);
