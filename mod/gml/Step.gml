/// DeltaSponge Tool - Step (keyboard + queued battles)

if (ds_status_t > 0) ds_status_t -= 1;

// Waiting for a new menu key (OPTIONS tab)
if (ds_waitkey) {
    if (keyboard_check_pressed(vk_escape)) {
        ds_waitkey = false;
    } else if (keyboard_check_pressed(vk_anykey)) {
        var _k = keyboard_lastkey;
        if (_k > 0 && _k != vk_escape) {
            ds_key = _k;
            ds_waitkey = false;
            ds_save();
        }
    }
    exit;
}

// Open / close the menu.
// Until rebound, the key under Esc works on both QWERTY (`, 192) and AZERTY (², 222).
var _toggle = keyboard_check_pressed(ds_key) || keyboard_check_pressed(ds_key_fallback);
if (ds_key == 192 && keyboard_check_pressed(222)) _toggle = true;

if (_toggle) {
    if (ds_open) ds_close_menu();
    else ds_open_menu();
} else if (ds_open && keyboard_check_pressed(vk_escape)) {
    ds_close_menu();
}

// Battle requested from the menu: starts a couple of frames after closing
if (ds_pending >= 0 && !ds_open) {
    if (ds_pending_t > 0) {
        ds_pending_t -= 1;
    } else {
        var _n = ds_pending;
        ds_pending = -1;
        ds_start_battle(_n);
    }
}
