/// DeltaSponge Tool - Draw GUI (the menu)

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
ds_s = min(_gw / 640, _gh / 480);
ds_ox = (_gw - 640 * ds_s) / 2;
ds_oy = (_gh - 480 * ds_s) / 2;
ds_mx = (device_mouse_x_to_gui(0) - ds_ox) / ds_s;
ds_my = (device_mouse_y_to_gui(0) - ds_oy) / ds_s;
ds_click = mouse_check_button_pressed(mb_left);
ds_wheel = mouse_wheel_down() - mouse_wheel_up();

if (ds_has_font) draw_set_font(ds_font);
ds_ts = 14 / max(1, string_height("M"));

// ---------------- Menu closed: small HUD ----------------
if (!ds_open) {
    var _tags = "";
    if (ds_god) _tags += " GOD";
    if (ds_ohk) _tags += " 1-HIT";
    if (ds_onehp) _tags += " 1HP";
    if (ds_mercy) _tags += " SPARE";
    if (ds_tp) _tags += " TP";
    if (ds_hud && _tags != "") ds_text_sh(6, 10, "DS:" + _tags, c_yellow, fa_left, 0.75, 0);
    if (ds_status_t > 0) ds_text_sh(6, 26, ds_status, c_white, fa_left, 0.75, 620);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_alpha(1);
    exit;
}

// ---------------- Background ----------------
if (ds_is_paused && sprite_exists(ds_bg)) draw_sprite_stretched(ds_bg, 0, 0, 0, _gw, _gh);
draw_set_alpha(0.6);
draw_set_color(c_black);
draw_rectangle(0, 0, _gw, _gh, false);
draw_set_alpha(1);

// ---------------- Frame + title ----------------
ds_frame(16, 12, 624, 468, c_black, c_white);
ds_text(28, 30, "DELTASPONGE TOOL", c_yellow, fa_left, 1.4, 300);
if (ds_button(592, 18, 24, 24, "X", false)) ds_close_menu();

// ---------------- Tabs ----------------
for (var _t = 0; _t < 5; _t++) {
    if (ds_button(24 + _t * 119, 50, 115, 26, ds_tabs[_t], ds_tab == _t)) {
        ds_tab = _t;
        ds_enc_scroll = 0;
        ds_item_scroll = 0;
    }
}

// ---------------- Content ----------------
try {
    if (ds_tab == 0) ds_draw_combats();
    else if (ds_tab == 1) ds_draw_team();
    else if (ds_tab == 2) ds_draw_items();
    else if (ds_tab == 3) ds_draw_cheats();
    else ds_draw_options();
} catch (_e) {
    ds_text(320, 250, "Not available right now", c_gray, fa_center, 0.9, 580);
}

// ---------------- Status message + credit ----------------
if (ds_status_t > 0) ds_text(320, 440, ds_status, c_yellow, fa_center, 0.9, 400);
ds_text(26, 456, "by yutsu", c_gray, fa_left, 0.75, 0);

// ---------------- Cursor ----------------
var _cx = device_mouse_x_to_gui(0);
var _cy = device_mouse_y_to_gui(0);
var _cs = 14 * ds_s;
draw_set_color(c_black);
draw_triangle(_cx - 2, _cy - 3, _cx - 2, _cy + _cs + 3, _cx + _cs * 0.75 + 3, _cy + _cs * 0.72, false);
draw_set_color(c_white);
draw_triangle(_cx, _cy, _cx, _cy + _cs, _cx + _cs * 0.7, _cy + _cs * 0.7, false);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_set_alpha(1);
