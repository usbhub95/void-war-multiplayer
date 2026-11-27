crew_host_mode = false;
crew_state_kind = 3;
crew_order_kind = 4;
crew_layout_kind = 5;
crew_layout_ack_kind = 6;
crew_state_base_size = packet_length + 27;
crew_order_size = packet_length + 6;
crew_max_rooms = 24;
crew_epoch = current_time;
crew_snapshot_number = 0;
crew_order_number = 0;

clear_crew_test = function() {
    guest_selected = false;
    shared_crew = noone;
    shared_hull = noone;
    crew_layout_confirmed = false;
    crew_layout_epoch = 0;
    crew_view_epoch = 0;
    shared_cells = [];
    shared_origin_x = 0;
    shared_origin_y = 0;
    crew_rooms = [];
    guest_native_sprites = [];
    crew_token = 0;
    crew_here = 0;
    crew_destination = 0;
    crew_target_tile = 0;
    crew_arrived = false;
    crew_choice = 1;
    crew_ack = 0;
    crew_accepted = false;
    crew_pending = 0;
    crew_received_snapshot = -1;
    crew_next_update = 0;
    crew_notice = "";
};
clear_crew_test();

combat_ready = function() {
    return room != rmMainMenu && instance_exists(oUICursor)
        && hull_is_alive(1) && hull_is_alive(0);
};

arm_crew_test = function() {
    if (!combat_ready() || ds_list_size(oUICursor.currSelected) != 1) {
        crew_notice = "Select one crew member during a fight, then press F6.";
        return;
    }

    var _crew = ds_list_find_value(oUICursor.currSelected, 0);
    if (!instance_exists(_crew) || !objIA(_crew.object_index, oCrew) || !_crew.allied || !crew_belongs_to_player(_crew)
            || !_crew.occupancyInitialized || crew_is_dead(_crew)
            || !instance_exists(_crew.currentCellID) || !_crew.currentCellID.allied) {
        crew_notice = "Select a living member of your crew on your ship.";
        return;
    }

    capture_crew_layout(_crew);
};

capture_crew_layout = function(_crew) {
    clear_crew_test();
    shared_crew = _crew;
    shared_hull = get_hull(1);
    var _initial_cell = _crew.currentCellID;
    var _cells = [_initial_cell];
    var _limit = crew_max_rooms;
    with (oCell) {
        if (array_length(_cells) < _limit && id != _initial_cell && allied
                && objects_on_same_hull(id, _crew)) {
            array_push(_cells, id);
        }
    }
    shared_cells = _cells;
    shared_origin_x = _initial_cell.x;
    shared_origin_y = _initial_cell.y;
    for (var _i = 0; _i < array_length(_cells); _i += 1) {
        var _cell = _cells[_i];
        var _tiles = [];
        var _count = cell_get_slot_count(_cell);
        for (var _tile = 1; _tile <= _count; _tile += 1) {
            array_push(_tiles, [round(cell_get_slot_x(_cell, _tile) - shared_origin_x),
                round(cell_get_slot_y(_cell, _tile) - shared_origin_y)]);
        }
        array_push(crew_rooms, [round(_cell.x - shared_origin_x), round(_cell.y - shared_origin_y),
            round(_cell.sprite_width), round(_cell.sprite_height), _tiles]);
    }
    crew_epoch += 1;
    crew_token = crew_epoch;
};

crew_room_index = function(_cell) {
    for (var _index = 0; _index < array_length(shared_cells); _index += 1) {
        if (shared_cells[_index] == _cell) return _index + 1;
    }
    return 0;
};

retire_crew_layout = function() {
    clear_crew_test();
    crew_epoch += 1;
};

refresh_crew_layout = function() {
    if (crew_token == 0) return;
    if (!combat_ready() || !instance_exists(shared_crew) || !shared_crew.allied
            || crew_is_dead(shared_crew) || get_hull(1) != shared_hull
            || !instance_exists(shared_crew.currentCellID)
            || !shared_crew.currentCellID.allied) {
        retire_crew_layout();
        return;
    }

    for (var _i = 0; _i < array_length(shared_cells); _i += 1) {
        if (!instance_exists(shared_cells[_i])) {
            capture_crew_layout(shared_crew);
            return;
        }
    }

    if (!objects_on_same_hull(shared_crew.currentCellID, shared_cells[0])) {
        retire_crew_layout();
        return;
    }
    shared_origin_x = shared_cells[0].x;
    shared_origin_y = shared_cells[0].y;
    for (var _i = 0; _i < array_length(shared_cells); _i += 1) {
        var _cell = shared_cells[_i];
        var _layout = crew_rooms[_i];
        if (round(_cell.x - shared_origin_x) != _layout[0] || round(_cell.y - shared_origin_y) != _layout[1]
                || round(_cell.sprite_width) != _layout[2] || round(_cell.sprite_height) != _layout[3]) {
            capture_crew_layout(shared_crew);
            return;
        }
    }
};

send_crew_layout = function() {
    write_probe_header(crew_layout_kind, crew_token);
    buffer_write(outbound, buffer_u8, array_length(crew_rooms));
    for (var _i = 0; _i < array_length(crew_rooms); _i += 1) {
        var _layout = crew_rooms[_i];
        buffer_write(outbound, buffer_s16, _layout[0]);
        buffer_write(outbound, buffer_s16, _layout[1]);
        buffer_write(outbound, buffer_u16, _layout[2]);
        buffer_write(outbound, buffer_u16, _layout[3]);
        var _tiles = _layout[4];
        buffer_write(outbound, buffer_u8, array_length(_tiles));
        for (var _j = 0; _j < array_length(_tiles); _j += 1) {
            var _tile = _tiles[_j];
            buffer_write(outbound, buffer_s16, _tile[0]);
            buffer_write(outbound, buffer_s16, _tile[1]);
        }
    }
    write_guest_layout_assets();
    steam_net_packet_send(peer_id, outbound, buffer_tell(outbound));
};

begin_guest_epoch = function(_epoch) {
    if (_epoch == crew_view_epoch) return;
    crew_view_epoch = _epoch;
    crew_layout_epoch = 0;
    crew_token = 0;
    crew_rooms = [];
    guest_native_sprites = [];
    guest_selected = false;
    crew_pending = 0;
    crew_choice = 1;
    crew_notice = "";
};

read_crew_layout = function(_epoch, _size) {
    if (crew_host_mode || _epoch <= 0 || _epoch < crew_view_epoch || _size < packet_length + 1) return;
    if (_epoch == crew_layout_epoch) {
        send_probe(crew_layout_ack_kind, _epoch);
        return;
    }

    var _count = buffer_read(inbound, buffer_u8);
    if (_count < 1 || _count > crew_max_rooms) return;
    var _rooms = [];
    for (var _i = 0; _i < _count; _i += 1) {
        if (buffer_tell(inbound) + 9 > _size) return;
        var _x = buffer_read(inbound, buffer_s16);
        var _y = buffer_read(inbound, buffer_s16);
        var _w = buffer_read(inbound, buffer_u16);
        var _h = buffer_read(inbound, buffer_u16);
        var _tile_count = buffer_read(inbound, buffer_u8);
        if (_w == 0 || _w > 512 || _h == 0 || _h > 512 || _tile_count > 4
                || buffer_tell(inbound) + _tile_count * 4 > _size) return;
        var _tiles = [];
        repeat (_tile_count) {
            var _tx = buffer_read(inbound, buffer_s16);
            var _ty = buffer_read(inbound, buffer_s16);
            array_push(_tiles, [_tx, _ty]);
        }
        array_push(_rooms, [_x, _y, _w, _h, _tiles]);
    }

    if (buffer_tell(inbound) + 10 > _size) return;
    var _hx = buffer_read(inbound, buffer_s16);
    var _hy = buffer_read(inbound, buffer_s16);
    var _xs = buffer_read(inbound, buffer_s16) / 100;
    var _ys = buffer_read(inbound, buffer_s16) / 100;
    var _hull = read_view_sprite(_size);
    if (is_undefined(_hull)) return;
    var _portrait = read_view_sprite(_size);
    if (is_undefined(_portrait) || buffer_tell(inbound) != _size) return;

    begin_guest_epoch(_epoch);
    crew_layout_epoch = _epoch;
    crew_rooms = _rooms;
    guest_hull = _hull;
    guest_portrait = _portrait;
    guest_hull_pose = [_hx, _hy, clamp(_xs, -4, 4), clamp(_ys, -4, 4)];
    guest_native_sprites = match_native_guest_rooms(_rooms, _hull, _xs, _ys);
    send_probe(crew_layout_ack_kind, _epoch);
};

write_crew_pose = function() {
    var _x = 0;
    var _y = 0;
    var _sprite = -1;
    var _frame = 0;
    var _fps = 0;
    var _facing = 1;
    var _tint = c_white;

    if (crew_token != 0) {
        var _crew = shared_crew;
        _x = variable_instance_exists(_crew, "spriteX") ? _crew.spriteX : _crew.x;
        _y = variable_instance_exists(_crew, "spriteY") ? _crew.spriteY : _crew.y;
        _x -= shared_origin_x;
        _y -= shared_origin_y;
        if (sprite_exists(_crew.sprite_index)) {
            _sprite = _crew.sprite_index;
            _frame = _crew.image_index;
            if (!global.gamePaused) {
                _fps = sprite_get_speed(_crew.sprite_index) * _crew.image_speed;
                if (sprite_get_speed_type(_crew.sprite_index) == spritespeed_framespergameframe) {
                    _fps *= game_get_speed(gamespeed_fps);
                }
            }
        }
        if (variable_instance_exists(_crew, "xScale")) _facing = _crew.xScale;
        if (variable_instance_exists(_crew, "colorBlend")) _tint = _crew.colorBlend;
    }

    buffer_write(outbound, buffer_s16, round(_x));
    buffer_write(outbound, buffer_s16, round(_y));
    buffer_write(outbound, buffer_u16, clamp(round(_frame * 16), 0, 65535));
    buffer_write(outbound, buffer_s16, clamp(round(_fps * 16), -32768, 32767));
    buffer_write(outbound, buffer_s16, round(clamp(_facing, -4, 4) * 100));
    buffer_write(outbound, buffer_u32, _tint & 0xffffff);
    write_view_sprite(_sprite);
};

send_crew_state = function() {
    refresh_crew_layout();
    if (crew_token != 0 && !crew_layout_confirmed) send_crew_layout();
    crew_here = 0;
    crew_destination = 0;
    crew_target_tile = 0;
    crew_arrived = false;
    if (crew_token != 0) {
        crew_destination = crew_room_index(shared_crew.currentCellID);
        if (crew_destination > 0) crew_target_tile = shared_crew.currentCellSlot;
        crew_arrived = crew_has_reached_destination(shared_crew);
        crew_here = crew_arrived
            ? crew_destination : crew_room_index(shared_crew.collidingCellID);
    }

    crew_snapshot_number += 1;
    write_probe_header(crew_state_kind, crew_snapshot_number);
    buffer_write(outbound, buffer_u32, crew_epoch);
    buffer_write(outbound, buffer_u32, crew_ack);
    var _flags = (crew_accepted ? 1 : 0) + (crew_arrived ? 2 : 0) + (crew_token != 0 ? 4 : 0);
    buffer_write(outbound, buffer_u8, _flags);
    buffer_write(outbound, buffer_u8, crew_here);
    buffer_write(outbound, buffer_u8, crew_destination);
    buffer_write(outbound, buffer_u8, crew_target_tile);
    write_crew_pose();
    steam_net_packet_send(peer_id, outbound, buffer_tell(outbound));
};

read_crew_state = function(_snapshot, _size) {
    if (crew_host_mode || _snapshot <= crew_received_snapshot) return;
    var _epoch = buffer_read(inbound, buffer_u32);
    if (_epoch < crew_view_epoch) return;
    var _ack = buffer_read(inbound, buffer_u32);
    var _flags = buffer_read(inbound, buffer_u8);
    var _here = buffer_read(inbound, buffer_u8);
    var _destination = buffer_read(inbound, buffer_u8);
    var _tile = buffer_read(inbound, buffer_u8);
    var _x = buffer_read(inbound, buffer_s16);
    var _y = buffer_read(inbound, buffer_s16);

    var _frame = buffer_read(inbound, buffer_u16) / 16;
    var _fps = buffer_read(inbound, buffer_s16) / 16;
    var _facing = clamp(buffer_read(inbound, buffer_s16) / 100, -4, 4);
    var _tint = buffer_read(inbound, buffer_u32) & 0xffffff;
    var _sprite = read_view_sprite(_size);
    if (is_undefined(_sprite) || buffer_tell(inbound) != _size) return;

    begin_guest_epoch(_epoch);
    crew_received_snapshot = _snapshot;
    if ((_flags & 4) == 0 || crew_layout_epoch != _epoch || _epoch == 0) return;
    var _count = array_length(crew_rooms);
    if (_here > _count || _destination > _count || _tile > 4
            || (_destination == 0 && _tile != 0)) return;
    if (_destination > 0) {
        var _room = crew_rooms[_destination - 1];
        if (_tile > array_length(_room[4])) return;
    }

    var _first = crew_token == 0;
    crew_token = _epoch;
    crew_here = _here;
    crew_destination = _destination;
    crew_target_tile = _tile;
    crew_arrived = (_flags & 2) != 0;
    apply_guest_crew_pose(_x, _y, _sprite, _frame, _fps, _facing, _tint, current_time, _first);
    if (crew_pending != 0 && _ack == crew_pending) {
        crew_pending = 0;
        crew_notice = (_flags & 1) != 0 ? "Order accepted." : "Host rejected the move.";
    }
};


move_guest_crew_to_occupied_tile = function(_crew, _cell, _tile) {
    var _occupant = cell_get_crew_at_slot(_cell, _tile, _crew.allied);
    if (!instance_exists(_occupant) || _occupant.allied != _crew.allied
            || _occupant.currentCellID != _cell || _occupant.currentCellSlot != _tile
            || crew_is_dead(_occupant) || (!_occupant.enableFriendlyCrewAI && !crew_has_reached_destination(_occupant))
            || _occupant.moveSpeed <= 0 || crew_check_keyword(_occupant, oKWStunned)
            || crew_check_keyword(_occupant, oKWSessile) || crew_check_keyword(_occupant, oKWImmobilized)) return;

    var _origin = _crew.currentCellID;
    var _origin_tile = _crew.currentCellSlot;
    if (!instance_exists(_origin) || _origin_tile < 1 || _origin_tile > cell_get_slot_count(_origin)
            || cell_get_crew_at_slot(_origin, _origin_tile, _crew.allied) != _crew) return;

    // Reserve the requested tile before finding a new destination for its occupant.
    cell_clear_slot(_occupant);
    cell_clear_slot(_crew);
    if (slot_reserve(_crew, _tile, _cell)) {
        crew_move_set_target_nearest_free_cell_destination(_occupant);
        if (_occupant.currentCellSlot > 0) return;
        cell_clear_slot(_crew);
    }
    slot_reserve(_occupant, _tile, _cell);
    slot_reserve(_crew, _origin_tile, _origin);
};

read_crew_order = function(_order) {
    if (!crew_host_mode || crew_token == 0 || _order <= crew_ack) return;

    var _token = buffer_read(inbound, buffer_u32);
    var _slot = buffer_read(inbound, buffer_u8);
    var _tile = buffer_read(inbound, buffer_u8);
    if (_token != crew_token) return;
    crew_ack = _order;
    crew_accepted = false;
    crew_next_update = 0;
    if (_slot < 1 || _slot > array_length(shared_cells) || !combat_ready()) return;

    var _crew = shared_crew;
    var _cell = shared_cells[_slot - 1];
    if (!instance_exists(_crew) || !instance_exists(_cell) || !_crew.allied || !_cell.allied
            || !crew_belongs_to_player(_crew) || crew_is_dead(_crew)
            || !_crew.occupancyInitialized || _crew.state == 22 || _crew.state == 28
            || _crew.isImmobilized || _crew.inTorpedo
            || crew_check_keyword(_crew, oKWImmobilized) || crew_check_keyword(_crew, oKWSessile)
            || !objects_on_same_hull(_crew, _cell) || !crew_checkDestinationIsReachable(_crew, _cell)) return;

    if (_tile == 0) {
        if (_crew.currentCellID != _cell) crew_choose_move_slot(_crew, _cell, 1, 0);
        crew_accepted = _crew.currentCellID == _cell;
        return;
    }
    if (_tile > cell_get_slot_count(_cell)) return;
    if (_crew.currentCellID == _cell && _crew.currentCellSlot == _tile) {
        crew_accepted = true;
        return;
    }
    if (slot_is_vacant(_cell, _tile, _crew.allied)) {
        crew_move_set_target_slot(_crew, _cell, _tile, 1);
    } else {
        move_guest_crew_to_occupied_tile(_crew, _cell, _tile);
    }
    crew_accepted = _crew.currentCellID == _cell && _crew.currentCellSlot == _tile;
};

queue_crew_order = function(_room, _tile) {
    crew_order_number += 1;
    crew_pending = crew_order_number;
    crew_order_room = _room;
    crew_order_tile = _tile;
    crew_next_update = 0;
    crew_notice = "Waiting for host...";
};

update_crew_test = function() {
    if (crew_host_mode) {
        if (window_has_focus() && keyboard_check_pressed(vk_f6)) {
            arm_crew_test();
            crew_next_update = 0;
        }
        if (current_time >= crew_next_update) {
            send_crew_state();
            crew_next_update = current_time + 250;
        }
        return;
    }

    if (crew_token == 0) return;
    if (window_has_focus()) {
        if (room == guest_view_room) {
            var _left_pressed = mouse_check_button_pressed(mb_left);
            var _right_pressed = mouse_check_button_pressed(mb_right);
            if (_left_pressed || _right_pressed) {
                read_guest_click(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _left_pressed, _right_pressed);
            }
        } else if (panel_open) {
            var _count = array_length(crew_rooms);
            if (keyboard_check_pressed(vk_left)) crew_choice = max(1, crew_choice - 1);
            if (keyboard_check_pressed(vk_right)) crew_choice = min(_count, crew_choice + 1);
            if (keyboard_check_pressed(vk_enter) && crew_pending == 0) queue_crew_order(crew_choice, 0);
        }
    }
    if (crew_pending != 0 && current_time >= crew_next_update) {
        write_probe_header(crew_order_kind, crew_pending);
        buffer_write(outbound, buffer_u32, crew_token);
        buffer_write(outbound, buffer_u8, crew_order_room);
        buffer_write(outbound, buffer_u8, crew_order_tile);
        steam_net_packet_send(peer_id, outbound, crew_order_size);
        crew_next_update = current_time + 250;
    }
};
