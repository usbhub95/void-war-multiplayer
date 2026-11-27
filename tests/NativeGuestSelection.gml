function vw_guest_selection_create() {
    currSelected = ds_list_create();
    cursorDebugMode = "";
    selection_epoch = 0;
    selection_layout = [0, 0, 0];
    pending_right_click = undefined;
    vw_guest_cancel_drag();

    selection_crew = instance_create_depth(0, 0, 0, oVoidWarGuestSelectionCrew);
    selection_crew.allied = true;
    selection_crew.enableFriendlyCrewAI = false;
    selection_crew.unitSelected = false;
    selection_crew.selectionCol = instance_create_depth(0, 0, 0, oVoidWarGuestSelectionMask);

    // Defer orders until End Step, after the probe has read packets and selection is current.
    original_guest_click = selection_probe.read_guest_click;
    selection_probe.read_guest_click = function(_gx, _gy, _left, _right) {
        if (_right) pending_right_click = [_gx, _gy];
    };
    show_debug_message("[Native guest selection] enabled in guest room");
}

function vw_guest_cancel_drag() {
    startX = -1;
    startY = -1;
    endX = -1;
    endY = -1;
}

function vw_guest_selection_update() {
    var _right = pending_right_click;
    pending_right_click = undefined;
    if (!instance_exists(selection_probe)) return;

    if (selection_epoch != selection_probe.crew_token) {
        selection_epoch = selection_probe.crew_token;
        vw_native_guest_clear();
        selection_probe.guest_selected = false;
        vw_guest_cancel_drag();
    }
    if (selection_epoch == 0 || selection_probe.peer_id == 0 || !window_has_focus()) {
        vw_guest_cancel_drag();
        return;
    }

    selection_probe.layout_guest_view();
    var _layout = selection_probe.guest_layout;
    if (_layout[0] != selection_layout[0] || _layout[1] != selection_layout[1]
            || _layout[2] != selection_layout[2]) {
        vw_guest_cancel_drag();
        selection_layout = _layout;
    }

    // Use the same GUI position and scale as the drawn crew, regardless of room camera.
    var _position = selection_probe.guest_crew_screen_xy(current_time);
    var _size = 30 * _layout[2];
    selection_crew.x = _position[0];
    selection_crew.y = _position[1];
    var _mask = selection_crew.selectionCol;
    _mask.x = _position[0] - _size / 2;
    _mask.y = _position[1] - _size / 2;
    _mask.image_xscale = _size;
    _mask.image_yscale = _size;
    x = clamp(device_mouse_x_to_gui(0), 0, display_get_gui_width());
    y = clamp(device_mouse_y_to_gui(0), 0, display_get_gui_height());

    if (mouse_check_button_pressed(mb_left) || startX != -1) {
        vw_native_guest_select();
        if (!mouse_check_button(mb_left)) vw_guest_cancel_drag();
    }
    selection_probe.guest_selected = selection_crew.unitSelected;
    if (!is_undefined(_right)) {
        original_guest_click(_right[0], _right[1], false, true);
    }
}

function vw_guest_selection_draw() {
    if (startX == -1) return;
    var _color = draw_get_color();
    var _alpha = draw_get_alpha();
    draw_set_color(c_lime);
    draw_set_alpha(1);
    draw_rectangle(min(startX, x), min(startY, y), max(startX, x), max(startY, y), true);
    draw_set_color(_color);
    draw_set_alpha(_alpha);
}

function vw_guest_selection_cleanup() {
    if (instance_exists(selection_probe)) {
        selection_probe.read_guest_click = original_guest_click;
        selection_probe.guest_selected = false;
    }
    ds_list_destroy(currSelected);
}
