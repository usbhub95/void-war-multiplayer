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
    _text += "\n" + _identity
        + "\nF9  Enter peer ID     F10  Disconnect"
        + "\n" + probe_status;
    if (reply_count > 0) {
        _text += "\nReplies  " + string(reply_count)
            + "   RTT  " + string(round_trip_ms) + " ms";
    }
}

var _width = string_width(_text) + 24;
var _height = string_height(_text) + 20;
draw_set_alpha(0.90);
draw_set_color(make_color_rgb(16, 21, 24));
draw_rectangle(_left, _top, _left + _width, _top + _height, false);
draw_set_alpha(1);
draw_set_color(c_white);
draw_text(_left + 12, _top + 10, _text);

draw_set_color(_old_color);
draw_set_alpha(_old_alpha);
draw_set_font(_old_font);
draw_set_halign(_old_halign);
draw_set_valign(_old_valign);
