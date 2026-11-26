crew_host_mode = false;
crew_state_kind = 3;
crew_order_kind = 4;
crew_state_base_size = packet_length + 12;
crew_order_size = packet_length + 5;
crew_max_rooms = 24;
crew_epoch = current_time;
crew_snapshot_number = 0;
crew_order_number = 0;

clear_crew_test = function() {
    shared_crew = noone;
    shared_cells = [];
    shared_origin_x = 0;
    shared_origin_y = 0;
    crew_rooms = [];
    crew_token = 0;
    crew_here = 0;
    crew_destination = 0;
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

    clear_crew_test();
    shared_crew = _crew;
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
    crew_epoch += 1;
    crew_token = crew_epoch;
};

crew_room_index = function(_cell) {
    for (var _index = 0; _index < array_length(shared_cells); _index += 1) {
        if (shared_cells[_index] == _cell) return _index + 1;
    }
    return 0;
};

send_crew_state = function() {
    if (crew_token != 0 && (!combat_ready() || !instance_exists(shared_crew)
            || !shared_crew.allied || crew_is_dead(shared_crew))) {
        clear_crew_test();
    }

    crew_rooms = [];
    for (var _index = 0; _index < array_length(shared_cells); _index += 1) {
        var _cell = shared_cells[_index];
        if (!instance_exists(_cell)) {
            clear_crew_test();
            break;
        }
        array_push(crew_rooms, [round(_cell.x - shared_origin_x), round(_cell.y - shared_origin_y)]);
    }

    crew_here = 0;
    crew_destination = 0;
    crew_arrived = false;
    if (crew_token != 0) {
        crew_destination = crew_room_index(shared_crew.currentCellID);
        crew_arrived = crew_has_reached_destination(shared_crew);
        crew_here = crew_arrived
            ? crew_destination : crew_room_index(shared_crew.collidingCellID);
    }

    crew_snapshot_number += 1;
    write_probe_header(crew_state_kind, crew_snapshot_number);
    buffer_write(outbound, buffer_u32, crew_token);
    buffer_write(outbound, buffer_u32, crew_ack);
    buffer_write(outbound, buffer_u8, (crew_accepted ? 1 : 0) + (crew_arrived ? 2 : 0));
    buffer_write(outbound, buffer_u8, crew_here);
    buffer_write(outbound, buffer_u8, crew_destination);
    buffer_write(outbound, buffer_u8, array_length(crew_rooms));
    for (var _index = 0; _index < array_length(crew_rooms); _index += 1) {
        var _position = crew_rooms[_index];
        buffer_write(outbound, buffer_s16, _position[0]);
        buffer_write(outbound, buffer_s16, _position[1]);
    }
    steam_net_packet_send(peer_id, outbound, buffer_tell(outbound));
};

read_crew_state = function(_snapshot, _size) {
    if (crew_host_mode || _snapshot <= crew_received_snapshot || _size < crew_state_base_size) return;

    var _token = buffer_read(inbound, buffer_u32);
    var _ack = buffer_read(inbound, buffer_u32);
    var _flags = buffer_read(inbound, buffer_u8);
    var _here = buffer_read(inbound, buffer_u8);
    var _destination = buffer_read(inbound, buffer_u8);
    var _count = buffer_read(inbound, buffer_u8);
    if (_count > crew_max_rooms || _size != crew_state_base_size + _count * 4
            || _here > _count || _destination > _count || (_token == 0) != (_count == 0)) return;

    if (_token != crew_token) {
        crew_pending = 0;
        crew_choice = 1;
        crew_notice = "";
    }
    crew_received_snapshot = _snapshot;
    crew_token = _token;
    crew_here = _here;
    crew_destination = _destination;
    crew_arrived = (_flags & 2) != 0;
    crew_rooms = [];
    for (var _index = 0; _index < _count; _index += 1) {
        var _x = buffer_read(inbound, buffer_s16);
        var _y = buffer_read(inbound, buffer_s16);
        array_push(crew_rooms, [_x, _y]);
    }
    if (crew_pending != 0 && _ack == crew_pending) {
        crew_pending = 0;
        crew_notice = (_flags & 1) != 0 ? "Order accepted." : "Host rejected the move.";
    }
};

read_crew_order = function(_order) {
    if (!crew_host_mode || crew_token == 0 || _order <= crew_ack) return;

    var _token = buffer_read(inbound, buffer_u32);
    var _slot = buffer_read(inbound, buffer_u8);
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

    if (_crew.currentCellID != _cell) crew_move_set_target(_crew, _cell);
    crew_accepted = _crew.currentCellID == _cell;
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

    if (crew_token == 0 || !window_has_focus()) return;
    var _count = array_length(crew_rooms);
    if (keyboard_check_pressed(vk_left)) crew_choice = max(1, crew_choice - 1);
    if (keyboard_check_pressed(vk_right)) crew_choice = min(_count, crew_choice + 1);
    if (keyboard_check_pressed(vk_enter) && crew_pending == 0) {
        crew_order_number += 1;
        crew_pending = crew_order_number;
        crew_order_room = crew_choice;
        crew_next_update = 0;
        crew_notice = "Waiting for host...";
    }
    if (crew_pending != 0 && current_time >= crew_next_update) {
        write_probe_header(crew_order_kind, crew_pending);
        buffer_write(outbound, buffer_u32, crew_token);
        buffer_write(outbound, buffer_u8, crew_order_room);
        steam_net_packet_send(peer_id, outbound, crew_order_size);
        crew_next_update = current_time + 250;
    }
};
