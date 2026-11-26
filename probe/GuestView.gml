guest_view_room = rmVoidWarGuestView;
guest_selected = false;
guest_layout = [0, 0, 1];
guest_hull = -1;
guest_portrait = -1;
guest_crew_xy = [0, 0];
guest_hull_pose = [0, 0, 1, 1];

write_view_sprite = function(_sprite) {
    var _name = sprite_exists(_sprite) ? sprite_get_name(_sprite) : "";
    _name = string_copy(_name, 1, 64);
    buffer_write(outbound, buffer_u8, string_length(_name));
    for (var _i = 1; _i <= string_length(_name); _i += 1) {
        buffer_write(outbound, buffer_u8, ord(string_char_at(_name, _i)));
    }
};

read_view_sprite = function(_size) {
    if (buffer_tell(inbound) >= _size) return undefined;
    var _length = buffer_read(inbound, buffer_u8);
    if (_length > 64 || buffer_tell(inbound) + _length > _size) return undefined;
    var _name = "";
    for (var _i = 0; _i < _length; _i += 1) {
        var _char = buffer_read(inbound, buffer_u8);
        if (_char < 32 || _char > 126) return undefined;
        _name += chr(_char);
    }
    return _name != "" && asset_get_type(_name) == asset_sprite ? asset_get_index(_name) : -1;
};

write_guest_layout_assets = function() {
    var _hull = get_hull(1);
    if (instance_exists(_hull)) {
        buffer_write(outbound, buffer_s16, round(_hull.x - shared_origin_x));
        buffer_write(outbound, buffer_s16, round(_hull.y - shared_origin_y));
        buffer_write(outbound, buffer_s16, round(_hull.image_xscale * 100));
        buffer_write(outbound, buffer_s16, round(_hull.image_yscale * 100));
        write_view_sprite(_hull.sprite_index);
    } else {
        repeat (4) buffer_write(outbound, buffer_s16, 0);
        write_view_sprite(-1);
    }
    write_view_sprite(variable_instance_exists(shared_crew, "sprite_portrait") ? shared_crew.sprite_portrait : -1);
};

layout_guest_view = function() {
    var _min_x = crew_rooms[0][0];
    var _min_y = crew_rooms[0][1];
    var _max_x = _min_x;
    var _max_y = _min_y;
    for (var _i = 0; _i < array_length(crew_rooms); _i += 1) {
        var _cell = crew_rooms[_i];
        _min_x = min(_min_x, _cell[0]);
        _min_y = min(_min_y, _cell[1]);
        _max_x = max(_max_x, _cell[0] + _cell[2]);
        _max_y = max(_max_y, _cell[1] + _cell[3]);
    }
    var _width = max(1, display_get_gui_width() - 96);
    var _height = max(1, display_get_gui_height() - 176);
    var _scale = min(_width / max(1, _max_x - _min_x), _height / max(1, _max_y - _min_y), 2);
    guest_layout = [
        48 + (_width - (_max_x - _min_x) * _scale) / 2 - _min_x * _scale,
        100 + (_height - (_max_y - _min_y) * _scale) / 2 - _min_y * _scale,
        _scale
    ];
};

read_guest_click = function(_gx, _gy, _left_pressed, _right_pressed) {
    layout_guest_view();
    var _x = (_gx - guest_layout[0]) / guest_layout[2];
    var _y = (_gy - guest_layout[1]) / guest_layout[2];

    if (_left_pressed) {
        var _cx = guest_layout[0] + guest_crew_xy[0] * guest_layout[2];
        var _cy = guest_layout[1] + guest_crew_xy[1] * guest_layout[2];
        guest_selected = point_distance(_gx, _gy, _cx, _cy) <= 18;
    }
    if (!guest_selected || !_right_pressed) return;

    for (var _i = 0; _i < array_length(crew_rooms); _i += 1) {
        var _cell = crew_rooms[_i];
        // Half-open bounds give shared edges one owner.
        if (_x >= _cell[0] && _x < _cell[0] + _cell[2]
                && _y >= _cell[1] && _y < _cell[1] + _cell[3]) {
            var _tiles = _cell[4];
            var _nearest = 0;
            var _distance = 0;
            for (var _j = 0; _j < array_length(_tiles); _j += 1) {
                var _tile = _tiles[_j];
                var _d = point_distance(_x, _y, _tile[0], _tile[1]);
                if (_nearest == 0 || _d < _distance) {
                    _distance = _d;
                    _nearest = _j + 1;
                }
            }
            queue_crew_order(_i + 1, _nearest);
            return;
        }
    }
};

draw_guest_ship = function() {
    draw_set_color(make_color_rgb(14, 19, 25));
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    draw_set_color(c_white);
    draw_text(24, 20, "Shared ship   F5  Return to panel   F10  Disconnect");
    if (crew_token == 0) {
        draw_text(24, 48, "Waiting for the host to share crew.");
        return;
    }
    draw_text(24, 48, "Left-click crew to select   Right-click a tile to move"
        + "\n" + (crew_arrived ? "Arrived" : "Moving")
        + "   Room: " + string(crew_destination) + "   Tile: " + string(crew_target_tile) + "   " + crew_notice);

    layout_guest_view();
    var _x = guest_layout[0];
    var _y = guest_layout[1];
    var _s = guest_layout[2];
    if (sprite_exists(guest_hull)) {
        draw_sprite_ext(guest_hull, 0, _x + guest_hull_pose[0] * _s,
            _y + guest_hull_pose[1] * _s, _s * guest_hull_pose[2], _s * guest_hull_pose[3],
            0, c_white, 1);
    }
    for (var _i = 0; _i < array_length(crew_rooms); _i += 1) {
        var _cell = crew_rooms[_i];
        var _left = _x + _cell[0] * _s;
        var _top = _y + _cell[1] * _s;
        var _right = _left + _cell[2] * _s;
        var _bottom = _top + _cell[3] * _s;
        draw_set_alpha(sprite_exists(guest_hull) ? 0.40 : 1);
        draw_set_color(make_color_rgb(42, 60, 72));
        draw_rectangle(_left, _top, _right, _bottom, false);
        draw_set_alpha(1);
        draw_set_color(_i + 1 == crew_destination ? c_yellow : c_gray);
        draw_rectangle(_left, _top, _right, _bottom, true);
        var _tiles = _cell[4];
        for (var _j = 0; _j < array_length(_tiles); _j += 1) {
            var _tile = _tiles[_j];
            var _targeted = _i + 1 == crew_destination && _j + 1 == crew_target_tile;
            draw_set_color(_targeted ? c_yellow : c_silver);
            draw_circle(_x + _tile[0] * _s, _y + _tile[1] * _s, _targeted ? 7 : 3, true);
        }
    }
    var _cx = _x + guest_crew_xy[0] * _s;
    var _cy = _y + guest_crew_xy[1] * _s;
    draw_set_color(make_color_rgb(28, 38, 47));
    draw_circle(_cx, _cy, 16, false);
    if (sprite_exists(guest_portrait)) {
        draw_sprite_stretched(guest_portrait, 0, _cx - 13, _cy - 13, 26, 26);
    }
    draw_set_color(guest_selected ? c_lime : c_white);
    draw_circle(_cx, _cy, 16, true);
};
