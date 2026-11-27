guest_native_requested = false;

// Match the host's share-relative room order to the local starter room.
match_native_guest_rooms = function(_rooms, _hull, _xs, _ys) {
    var _count = array_length(_rooms);
    if (_count != array_length(guest_native_cells) || !sprite_exists(_hull)
            || sprite_get_name(_hull) != guest_native_hull_name || _xs != -1 || _ys != 1) return [];

    var _min_x = _rooms[0][0];
    var _min_y = _rooms[0][1];
    for (var _i = 1; _i < _count; _i += 1) {
        _min_x = min(_min_x, _rooms[_i][0]);
        _min_y = min(_min_y, _rooms[_i][1]);
    }

    var _matched = array_create(_count, -1);
    var _used = array_create(_count, false);
    for (var _i = 0; _i < _count; _i += 1) {
        var _room = _rooms[_i];
        var _local = -1;
        for (var _j = 0; _j < _count; _j += 1) {
            var _cell = guest_native_cells[_j];
            if (_cell[0] == _room[0] - _min_x && _cell[1] == _room[1] - _min_y) {
                _local = _j;
                break;
            }
        }
        if (_local < 0 || _used[_local]) return [];
        var _sprite = guest_native_cells[_local][2];
        if (_room[2] != sprite_get_width(_sprite) || _room[3] != sprite_get_height(_sprite)) return [];

        // The pinned cell initializer numbers the 36-pixel grid left to right, top to bottom.
        var _columns = _room[2] div 36;
        var _tiles = _room[4];
        if (array_length(_tiles) != _columns * (_room[3] div 36)) return [];
        for (var _j = 0; _j < array_length(_tiles); _j += 1) {
            if (_tiles[_j][0] != _room[0] + 18 + (_j mod _columns) * 36
                    || _tiles[_j][1] != _room[1] + 18 + (_j div _columns) * 36) return [];
        }
        _matched[_i] = _sprite;
        _used[_local] = true;
    }
    return _matched;
};
