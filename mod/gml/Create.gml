/// DeltaSponge Tool v1.0 - Create
/// Cheat menu for DELTARUNE, toggled with the ` key (rebindable).

depth = -15000;
persistent = true;

ds_version = "1.0";

// --- Menu state ---
ds_open = false;
ds_tab = 0;
ds_tabs = ["BATTLES", "PARTY", "ITEMS", "CHEATS", "OPTIONS"];
ds_status = "";
ds_status_t = 0;

// --- Options (saved in deltasponge.ini) ---
ds_key = 192;              // ` key
ds_key_fallback = vk_f9;   // always works, even after rebinding
ds_pause = true;           // freeze the game while the menu is open
ds_hud = true;             // show active cheats when the menu is closed
ds_waitkey = false;

// --- Cheats ---
ds_god = false;
ds_ohk = false;
ds_onehp = false;
ds_mercy = false;
ds_tp = false;

// --- Battles ---
ds_enc = [];
ds_enc_scanned = false;
ds_enc_boss = true;
ds_enc_scroll = 0;
ds_enc_num = 1;
ds_pending = -1;
ds_pending_t = 0;
// Internal enemy object names treated as bosses / minibosses
ds_bosswords = ["boss", "lancer", "joker", "checkers_enemy", "susieenemy", "rudinnranger", "headhathy",
    "berdly", "queen", "spamton", "rouxls", "tasque_manager", "mauswheel", "sweet", "kk_enemy",
    "knight", "tenna", "elnina", "lanino", "shadowman",
    "justice", "titan", "jackenstein", "mizzle", "multiboss", "guei", "trashy_trio"];

// Boss music: enemy object -> song, taken from the game's own cutscenes / debug battle starter.
// All songs live in the shared DELTARUNE\mus folder, so they work in every chapter.
var _pairs = [
    "obj_joker", "joker.ogg",
    "obj_king_boss", "kingboss.ogg",
    "obj_checkers_enemy", "checkers.ogg",
    "obj_lancerboss2", "vs_susie.ogg",
    "obj_lancerboss3", "lancerfight.ogg",
    "obj_susieenemy", "lancerfight.ogg",
    "obj_berdlyb_enemy", "berdly_chase.ogg",
    "obj_berdlyb2_enemy", "berdly_chase.ogg",
    "obj_queen_enemy", "queen_boss.ogg",
    "obj_gigaqueen_enemy", "boxing_boss.ogg",
    "obj_spamton_enemy", "spamton_battle.ogg",
    "obj_spamton_neo_enemy", "spamton_neo_mix_ex_wip.ogg",
    "obj_sweet_enemy", "music_guys.ogg",
    "obj_rouxls_enemy", "rouxls_battle.ogg",
    "obj_rouxls_ch3_enemy", "rouxls_battle.ogg",
    "obj_knight_enemy", "knight.ogg",
    "obj_tenna_enemy", "tenna_battle.ogg",
    "obj_watercooler_enemy", "rudebuster_boss.ogg",
    "obj_hammer_of_justice_enemy", "ch4_extra_boss.ogg",
    "obj_sound_of_justice_enemy", "statue_chord_basic.ogg",
    "obj_jackenstein_enemy", "pumpkin_boss.ogg",
    "obj_titan_enemy", "titan_battle.ogg",
    "obj_titan_spawn_enemy", "titan_spawn.ogg"
];
ds_music = {};
for (var _p = 0; _p < array_length(_pairs); _p += 2) variable_struct_set(ds_music, _pairs[_p], _pairs[_p + 1]);

// --- Items ---
ds_isub = 0;
ds_isubs = ["ITEMS", "WEAPONS", "ARMOR"];
ds_items = [[], [], []];
ds_items_scanned = false;
ds_item_scroll = 0;

// --- Pause ---
ds_paused = [];
ds_is_paused = false;
ds_kris_seen = false;
ds_bg = -1;

// --- Mouse / scaling ---
ds_mx = 0;
ds_my = 0;
ds_click = false;
ds_wheel = 0;
ds_s = 1;
ds_ox = 0;
ds_oy = 0;
ds_ts = 1;

ds_charnames = ["NONE", "KRIS", "SUSIE", "RALSEI", "NOELLE"];
ds_orange = make_color_rgb(255, 160, 64);
ds_dark = make_color_rgb(40, 40, 40);
ds_selcol = make_color_rgb(80, 40, 0);

// =====================================================================
//  Helpers
// =====================================================================

ds_asset = function(_name) {
    if (asset_get_type(_name) == asset_unknown) return undefined;
    return asset_get_index(_name);
};

ds_g = function(_name, _def) {
    if (variable_global_exists(_name)) return variable_global_get(_name);
    return _def;
};

ds_msg = function(_txt) {
    ds_status = _txt;
    ds_status_t = 150;
};

ds_err = function(_e) {
    if (is_struct(_e) && variable_struct_exists(_e, "message")) return string(_e.message);
    return string(_e);
};

ds_in_battle = function() {
    return ds_g("fighting", 0) == 1;
};

ds_trim = function(_s) {
    while (string_length(_s) > 0 && string_char_at(_s, 1) == " ") _s = string_delete(_s, 1, 1);
    while (string_length(_s) > 0 && string_char_at(_s, string_length(_s)) == " ") _s = string_delete(_s, string_length(_s), 1);
    return _s;
};

ds_save = function() {
    try {
        ini_open("deltasponge.ini");
        ini_write_real("options", "key", ds_key);
        ini_write_real("options", "pause", ds_pause ? 1 : 0);
        ini_write_real("options", "hud", ds_hud ? 1 : 0);
        ini_close();
    } catch (_e) {
        try { ini_close(); } catch (_e2) {}
    }
};

ds_keyname = function(_k) {
    if (_k >= 48 && _k <= 57) return chr(_k);
    if (_k >= 65 && _k <= 90) return chr(_k);
    if (_k >= vk_f1 && _k <= vk_f1 + 11) return "F" + string(_k - vk_f1 + 1);
    if (_k >= vk_numpad0 && _k <= vk_numpad9) return "NUMPAD " + string(_k - vk_numpad0);
    switch (_k) {
        case 192: return "`";
        case 222: return "'";
        case vk_tab: return "TAB";
        case vk_insert: return "INSERT";
        case vk_delete: return "DELETE";
        case vk_home: return "HOME";
        case vk_end: return "END";
        case vk_pageup: return "PAGE UP";
        case vk_pagedown: return "PAGE DOWN";
        case vk_space: return "SPACE";
        case vk_backspace: return "BACKSPACE";
        case vk_enter: return "ENTER";
        case vk_shift: return "SHIFT";
        case vk_control: return "CTRL";
        case vk_alt: return "ALT";
        case 186: return ";";
        case 187: return "=";
        case 188: return ",";
        case 189: return "-";
        case 190: return ".";
        case 191: return "/";
        case 219: return "[";
        case 220: return "\\";
        case 221: return "]";
        case 223: return "!";
        case 226: return "<";
    }
    return "KEY " + string(_k);
};

// =====================================================================
//  Game pause (only deactivates what was active, restores exactly that)
// =====================================================================

ds_pause_start = function() {
    if (ds_is_paused) return;
    try {
        if (sprite_exists(ds_bg)) sprite_delete(ds_bg);
        ds_bg = -1;
        if (surface_exists(application_surface)) {
            ds_bg = sprite_create_from_surface(application_surface, 0, 0, surface_get_width(application_surface), surface_get_height(application_surface), false, false, 0, 0);
        }
    } catch (_e) {
        ds_bg = -1;
    }
    var _kris = ds_asset("obj_mainchara");
    ds_kris_seen = !is_undefined(_kris) && instance_exists(_kris);
    var _me = id;
    var _list = [];
    with (all) {
        if (id != _me) array_push(_list, id);
    }
    for (var _i = 0; _i < array_length(_list); _i++) instance_deactivate_object(_list[_i]);
    ds_paused = _list;
    ds_is_paused = true;
    audio_pause_all();
};

ds_pause_end = function() {
    if (!ds_is_paused) return;
    for (var _i = 0; _i < array_length(ds_paused); _i++) instance_activate_object(ds_paused[_i]);
    ds_paused = [];
    ds_is_paused = false;
    audio_resume_all();
};

ds_open_menu = function() {
    // Battle list is built outside of battles so nothing breaks mid-fight
    if (!ds_enc_scanned && !ds_in_battle()) ds_scan_encounters();
    if (!ds_items_scanned) ds_scan_items();
    ds_open = true;
    ds_waitkey = false;
    if (ds_pause) ds_pause_start();
};

ds_close_menu = function() {
    ds_open = false;
    ds_waitkey = false;
    ds_pause_end();
};

// =====================================================================
//  Battle discovery (reads the current chapter's scr_encountersetup)
// =====================================================================

ds_clean_name = function(_on) {
    var _s = string_lower(_on);
    _s = string_replace(_s, "obj_", "");
    _s = string_replace(_s, "_enemy", "");
    _s = string_replace(_s, "enemy", "");
    _s = string_replace_all(_s, "_", " ");
    return string_upper(ds_trim(_s));
};

ds_scan_encounters = function() {
    ds_enc = [];
    ds_enc_scanned = true;
    var _scr = ds_asset("scr_encountersetup");
    if (is_undefined(_scr)) return;

    // Back up the globals scr_encountersetup writes to
    var _names = ["monstertype", "monsterinstancetype", "monstermakex", "monstermakey", "heromakex", "heromakey", "battlemsg"];
    var _bak = {};
    for (var _k = 0; _k < array_length(_names); _k++) {
        var _src = ds_g(_names[_k], undefined);
        if (is_array(_src)) {
            var _cp = array_create(array_length(_src));
            array_copy(_cp, 0, _src, 0, array_length(_src));
            variable_struct_set(_bak, _names[_k], _cp);
        }
    }
    var _encno = ds_g("encounterno", 1);

    // Remember existing instances so anything spawned during the scan can be removed
    var _before = ds_map_create();
    with (all) ds_map_add(_before, string(id), 1);

    var _default = "";
    for (var _n = -1; _n <= 400; _n++) {
        var _en = (_n < 0) ? 99999 : _n;
        var _sig = "";
        var _label = "";
        var _song = "";
        var _boss = false;
        var _msg = "";
        var _ok = true;
        try {
            global.encounterno = _en;
            for (var _j = 0; _j < 3; _j++) {
                global.monstertype[_j] = 0;
                global.monsterinstancetype[_j] = -1;
            }
            global.battlemsg[0] = "";
            script_execute(_scr, _en);
            for (var _j2 = 0; _j2 < 3; _j2++) {
                if (global.monstertype[_j2] != 0) {
                    var _o = global.monsterinstancetype[_j2];
                    if (object_exists(_o)) {
                        var _on = object_get_name(_o);
                        _sig += _on + ";";
                        if (_label != "") _label += " + ";
                        _label += ds_clean_name(_on);
                        if (_song == "" && variable_struct_exists(ds_music, _on)) _song = variable_struct_get(ds_music, _on);
                        var _low = string_lower(_on);
                        for (var _w = 0; _w < array_length(ds_bosswords); _w++) {
                            if (string_pos(ds_bosswords[_w], _low) > 0) _boss = true;
                        }
                    }
                }
            }
            _msg = string(global.battlemsg[0]);
        } catch (_e) {
            _ok = false;
        }
        if (_ok) {
            if (_n < 0) {
                _default = _sig + "|" + _msg;
            } else if (_sig != "" && (_sig + "|" + _msg) != _default) {
                array_push(ds_enc, { eid: _n, name: _label, boss: _boss, song: _song });
            }
        }
    }

    // Restore
    for (var _k2 = 0; _k2 < array_length(_names); _k2++) {
        if (variable_struct_exists(_bak, _names[_k2])) variable_global_set(_names[_k2], variable_struct_get(_bak, _names[_k2]));
    }
    global.encounterno = _encno;
    with (all) {
        if (!ds_map_exists(_before, string(id))) instance_destroy(id, false);
    }
    ds_map_destroy(_before);

    if (array_length(ds_enc) > 0) ds_enc_num = ds_enc[0].eid;
};

ds_enc_name = function(_eid) {
    for (var _i = 0; _i < array_length(ds_enc); _i++) {
        if (ds_enc[_i].eid == _eid) return ds_enc[_i].name;
    }
    return "";
};

ds_start_battle = function(_n) {
    if (ds_in_battle()) { ds_msg("Already in a battle"); return; }
    var _scr = ds_asset("scr_battle");
    var _kris = ds_asset("obj_mainchara");
    if (is_undefined(_kris) || !instance_exists(_kris)) { ds_msg("Kris must be on the map"); return; }
    if (ds_g("darkzone", 1) == 0) { ds_msg("Dark World only"); return; }
    if (ds_g("interact", 0) != 0) { ds_msg("Not during a cutscene or menu"); return; }
    try {
        // flag[9] == 1: the game fades the area music and plays global.batmusic[0] when the battle starts
        global.flag[9] = 1;
        if (!is_undefined(_scr)) {
            // Chapter 2+: the game's own function
            script_execute(_scr, _n, 0, noone, noone, noone);
        } else {
            // Chapter 1: same sequence the game's cutscenes use
            var _back = ds_asset("obj_battleback");
            var _enc = ds_asset("obj_encounterbasic");
            if (is_undefined(_back) || is_undefined(_enc)) { ds_msg("Battle system not found"); return; }
            var _ic = ds_asset("instance_create"); // game's version (handles object depth)
            if (is_undefined(_ic)) instance_create_depth(0, 0, 0, _back); else script_execute(_ic, 0, 0, _back);
            global.encounterno = _n;
            global.specialbattle = 0;
            var _snd = ds_asset("snd_init");
            if (!is_undefined(_snd)) global.batmusic[0] = script_execute(_snd, "battle.ogg");
            if (is_undefined(_ic)) instance_create_depth(0, 0, 0, _enc); else script_execute(_ic, 0, 0, _enc);
        }
        // Swap in the boss's own song before the battle controller starts it
        ds_set_boss_music(ds_enc_song(_n));
    } catch (_e) {
        ds_msg("Error: " + ds_err(_e));
    }
};

ds_enc_song = function(_eid) {
    for (var _i = 0; _i < array_length(ds_enc); _i++) {
        if (ds_enc[_i].eid == _eid) return ds_enc[_i].song;
    }
    return "";
};

ds_set_boss_music = function(_song) {
    if (_song == "") return;
    var _init = ds_asset("snd_init");
    if (is_undefined(_init)) return;
    var _free = ds_asset("snd_free");
    if (!is_undefined(_free) && is_array(ds_g("batmusic", undefined))) {
        try { script_execute(_free, global.batmusic[0]); } catch (_e) {}
    }
    global.batmusic[0] = script_execute(_init, _song);
    // Tenna's fight layers a muted guitar track that his attacks fade in
    if (_song == "tenna_battle.ogg") {
        var _loop = ds_asset("mus_loop");
        var _vol = ds_asset("mus_volume");
        global.batmusic[2] = script_execute(_init, "tenna_battle_guitar.ogg");
        if (!is_undefined(_loop)) global.batmusic[3] = script_execute(_loop, global.batmusic[2]);
        if (!is_undefined(_vol) && !is_undefined(_loop)) script_execute(_vol, global.batmusic[3], 0, 0);
    }
};

// =====================================================================
//  Items / weapons / armor
// =====================================================================

ds_scan_items = function() {
    ds_items_scanned = true;
    ds_items = [[], [], []];
    var _scrn = ["scr_iteminfo", "scr_weaponinfo", "scr_armorinfo"];
    var _vars = ["itemnameb", "weaponnametemp", "armornametemp"];
    for (var _t = 0; _t < 3; _t++) {
        var _scr = ds_asset(_scrn[_t]);
        if (!is_undefined(_scr)) {
            var _list = [];
            for (var _n = 1; _n <= 150; _n++) {
                var _nm = "";
                try {
                    variable_instance_set(id, _vars[_t], "");
                    script_execute(_scr, _n);
                    _nm = ds_trim(string(variable_instance_get(id, _vars[_t])));
                } catch (_e) {
                    _nm = "";
                }
                if (_nm != "" && _nm != "---" && _nm != "0" && string_lower(_nm) != "undefined" && string_lower(_nm) != "null") {
                    array_push(_list, { iid: _n, name: _nm });
                }
            }
            ds_items[_t] = _list;
        }
    }
};

ds_item_name = function(_t, _iid) {
    var _l = ds_items[_t];
    for (var _i = 0; _i < array_length(_l); _i++) {
        if (_l[_i].iid == _iid) return _l[_i].name;
    }
    return "#" + string(_iid);
};

ds_inv_get = function(_t) {
    if (_t == 0) return ds_g("item", []);
    if (_t == 1) return ds_g("weapon", []);
    return ds_g("armor", []);
};

ds_inv_size = function(_t) {
    var _n = array_length(ds_inv_get(_t));
    if (_t == 0) return min(12, _n);
    return max(0, _n - 1);
};

ds_inv_set = function(_t, _i, _v) {
    if (_t == 0) global.item[_i] = _v;
    else if (_t == 1) global.weapon[_i] = _v;
    else global.armor[_i] = _v;
};

ds_give = function(_t, _iid, _name) {
    var _a = ds_inv_get(_t);
    var _n = ds_inv_size(_t);
    for (var _i = 0; _i < _n; _i++) {
        if (_a[_i] == 0) {
            ds_inv_set(_t, _i, _iid);
            ds_msg("+ " + _name);
            return;
        }
    }
    ds_msg("Inventory full");
};

ds_take = function(_t, _slot) {
    var _a = ds_inv_get(_t);
    var _n = ds_inv_size(_t);
    var _vals = [];
    for (var _i = 0; _i < _n; _i++) _vals[_i] = _a[_i];
    for (var _i2 = _slot; _i2 < _n - 1; _i2++) ds_inv_set(_t, _i2, _vals[_i2 + 1]);
    if (_n > 0) ds_inv_set(_t, _n - 1, 0);
};

ds_clear_inv = function(_t) {
    var _a = ds_inv_get(_t);
    var _n = ds_inv_size(_t);
    for (var _i = 0; _i < _n; _i++) {
        if (_a[_i] != 999) ds_inv_set(_t, _i, 0);
    }
};

// =====================================================================
//  Party
// =====================================================================

ds_set_char = function(_slot, _dir) {
    if (ds_in_battle()) { ds_msg("Change party outside of battle"); return; }
    var _maxc = (ds_g("chapter", 2) == 1) ? 3 : 4; // no Noelle in chapter 1
    var _cur = global.char[_slot];
    var _v = _cur;
    var _found = false;
    for (var _k = 0; _k < 6 && !_found; _k++) {
        _v = (_v + _dir + _maxc + 1) mod (_maxc + 1);
        var _ok = !(_slot == 0 && _v == 0);
        if (_ok && _v != 0) {
            for (var _j = 0; _j < 3; _j++) {
                if (_j != _slot && global.char[_j] == _v) _ok = false;
            }
        }
        if (_ok) _found = true;
    }
    if (!_found || _v == _cur) return;
    global.char[_slot] = _v;
    if (_v > 0) {
        if (global.maxhp[_v] <= 0) global.maxhp[_v] = 100;
        if (global.hp[_v] <= 0) global.hp[_v] = global.maxhp[_v];
    }
    // The game expects no gap in the party
    if (global.char[1] == 0 && global.char[2] != 0) {
        global.char[1] = global.char[2];
        global.char[2] = 0;
    }
};

ds_stat = function(_name, _slot, _cid, _d) {
    var _arr = variable_global_get(_name);
    var _old = _arr[_cid];
    var _v = max((_name == "maxhp") ? 1 : 0, _old + _d);
    var _fight = ds_in_battle();
    switch (_name) {
        case "maxhp":
            global.maxhp[_cid] = _v;
            if (global.hp[_cid] > _v) global.hp[_cid] = _v;
            break;
        case "at":
            global.at[_cid] = _v;
            if (_fight) global.battleat[_slot] += _v - _old;
            break;
        case "df":
            global.df[_cid] = _v;
            if (_fight) global.battledf[_slot] += _v - _old;
            break;
        case "mag":
            global.mag[_cid] = _v;
            if (_fight) global.battlemag[_slot] += _v - _old;
            break;
    }
};

ds_heal_all = function() {
    for (var _i = 0; _i < 3; _i++) {
        var _c = global.char[_i];
        if (_c > 0) global.hp[_c] = global.maxhp[_c];
    }
};

ds_toggle = function(_k) {
    switch (_k) {
        case 0: ds_god = !ds_god; if (ds_god) ds_onehp = false; break;
        case 1: ds_ohk = !ds_ohk; break;
        case 2: ds_onehp = !ds_onehp; if (ds_onehp) ds_god = false; break;
        case 3: ds_mercy = !ds_mercy; break;
        case 4: ds_tp = !ds_tp; break;
    }
};

// =====================================================================
//  Drawing (virtual 640x480 coordinates, scaled to the window)
// =====================================================================

ds_X = function(_x) { return ds_ox + _x * ds_s; };
ds_Y = function(_y) { return ds_oy + _y * ds_s; };

ds_rect = function(_x1, _y1, _x2, _y2, _col, _alpha) {
    draw_set_alpha(_alpha);
    draw_set_color(_col);
    draw_rectangle(ds_X(_x1), ds_Y(_y1), ds_X(_x2), ds_Y(_y2), false);
    draw_set_alpha(1);
};

ds_frame = function(_x1, _y1, _x2, _y2, _fill, _border) {
    ds_rect(_x1, _y1, _x2, _y2, _border, 1);
    ds_rect(_x1 + 2, _y1 + 2, _x2 - 2, _y2 - 2, _fill, 1);
};

ds_text = function(_x, _y, _str, _col, _ha, _sc, _maxw) {
    _str = string(_str);
    var _k = ds_ts * _sc;
    if (_maxw > 0) {
        var _w = string_width(_str) * _k;
        if (_w > _maxw) _k *= _maxw / _w;
    }
    draw_set_halign(_ha);
    draw_set_valign(fa_middle);
    draw_set_color(_col);
    draw_text_transformed(ds_X(_x), ds_Y(_y), _str, _k * ds_s, _k * ds_s, 0);
};

ds_text_sh = function(_x, _y, _str, _col, _ha, _sc, _maxw) {
    ds_text(_x + 1, _y + 1, _str, c_black, _ha, _sc, _maxw);
    ds_text(_x, _y, _str, _col, _ha, _sc, _maxw);
};

ds_hover = function(_x1, _y1, _x2, _y2) {
    return ds_mx >= _x1 && ds_mx <= _x2 && ds_my >= _y1 && ds_my <= _y2;
};

ds_button = function(_x, _y, _w, _h, _label, _active) {
    var _hv = ds_hover(_x, _y, _x + _w, _y + _h);
    var _col = _hv ? c_yellow : (_active ? ds_orange : c_white);
    ds_frame(_x, _y, _x + _w, _y + _h, _active ? ds_selcol : c_black, _col);
    ds_text(_x + _w / 2, _y + _h / 2, _label, _col, fa_center, 1, _w - 8);
    if (_hv && ds_click) {
        ds_click = false;
        return true;
    }
    return false;
};

// Label on the left, ON/OFF switch on the right
ds_switch_row = function(_y, _label, _on) {
    ds_frame(24, _y, 616, _y + 48, c_black, _on ? ds_orange : ds_dark);
    ds_text(40, _y + 24, _label, _on ? c_yellow : c_white, fa_left, 1.1, 420);
    return ds_button(500, _y + 9, 104, 30, _on ? "ON" : "OFF", _on);
};

// ---------------------------------------------------------------------
//  BATTLES tab
// ---------------------------------------------------------------------
ds_draw_combats = function() {
    if (ds_button(24, 84, 110, 24, "BOSSES", ds_enc_boss)) { ds_enc_boss = true; ds_enc_scroll = 0; }
    if (ds_button(140, 84, 110, 24, "ALL", !ds_enc_boss)) { ds_enc_boss = false; ds_enc_scroll = 0; }

    var _view = [];
    for (var _i = 0; _i < array_length(ds_enc); _i++) {
        if (!ds_enc_boss || ds_enc[_i].boss) array_push(_view, ds_enc[_i]);
    }

    var _rows = 12;
    var _rh = 21;
    var _ly = 116;
    var _maxs = max(0, array_length(_view) - _rows);
    if (ds_hover(24, _ly, 616, _ly + _rows * _rh)) ds_enc_scroll += ds_wheel * 2;
    ds_enc_scroll = clamp(ds_enc_scroll, 0, _maxs);

    ds_frame(24, _ly - 2, 616, _ly + _rows * _rh + 2, c_black, ds_dark);
    if (!ds_enc_scanned) ds_text(320, _ly + 126, "Reopen outside of battle", c_gray, fa_center, 0.9, 560);
    else if (array_length(_view) == 0) ds_text(320, _ly + 126, "None", c_gray, fa_center, 0.9, 560);
    for (var _r = 0; _r < _rows; _r++) {
        var _idx = ds_enc_scroll + _r;
        if (_idx >= array_length(_view)) break;
        var _e = _view[_idx];
        var _y = _ly + _r * _rh;
        var _sel = (_e.eid == ds_enc_num);
        var _hv = ds_hover(26, _y, 594, _y + _rh - 1);
        if (_sel) ds_rect(26, _y, 594, _y + _rh - 1, ds_selcol, 1);
        else if (_hv) ds_rect(26, _y, 594, _y + _rh - 1, ds_dark, 1);
        ds_text(34, _y + _rh / 2, "#" + string(_e.eid), c_gray, fa_left, 0.9, 0);
        ds_text(90, _y + _rh / 2, _e.name, (_sel || _hv) ? c_yellow : (_e.boss ? ds_orange : c_white), fa_left, 0.9, 420);
        if (_hv) ds_text(590, _y + _rh / 2, "FIGHT >", c_yellow, fa_right, 0.8, 0);
        if (_hv && ds_click) {
            // One click = fight right away
            ds_click = false;
            ds_enc_num = _e.eid;
            ds_request_battle(_e.eid);
        }
    }
    if (ds_button(597, _ly, 17, 22, "^", false)) ds_enc_scroll = max(0, ds_enc_scroll - _rows);
    if (ds_button(597, _ly + _rows * _rh - 22, 17, 22, "v", false)) ds_enc_scroll = min(_maxs, ds_enc_scroll + _rows);

    if (ds_button(24, 382, 44, 32, "-10", false)) ds_enc_num = max(0, ds_enc_num - 10);
    if (ds_button(72, 382, 44, 32, "-1", false)) ds_enc_num = max(0, ds_enc_num - 1);
    ds_frame(120, 382, 200, 414, c_black, ds_dark);
    ds_text(160, 398, "#" + string(ds_enc_num), c_yellow, fa_center, 1.1, 74);
    if (ds_button(204, 382, 44, 32, "+1", false)) ds_enc_num += 1;
    if (ds_button(252, 382, 44, 32, "+10", false)) ds_enc_num += 10;
    if (ds_button(310, 382, 306, 32, "FIGHT  " + ds_enc_name(ds_enc_num), true)) ds_request_battle(ds_enc_num);
};

// Checks right away (so the reason shows in the menu), then closes it and fights
ds_request_battle = function(_n) {
    if (ds_in_battle()) { ds_msg("Already in a battle"); return; }
    var _kris = ds_asset("obj_mainchara");
    if (is_undefined(_kris) || !ds_kris_on_map()) { ds_msg("Load a save first (Kris must be on the map)"); return; }
    if (ds_g("darkzone", 1) == 0) { ds_msg("Go to the Dark World first"); return; }
    if (ds_g("interact", 0) != 0) { ds_msg("Close the game's menu / wait for the cutscene to end"); return; }
    ds_pending = _n;
    ds_pending_t = 2;
    ds_close_menu();
};

// Kris may be deactivated while the game is paused by this menu
ds_kris_on_map = function() {
    var _kris = ds_asset("obj_mainchara");
    if (is_undefined(_kris)) return false;
    if (instance_exists(_kris)) return true;
    return ds_is_paused && ds_kris_seen;
};

// ---------------------------------------------------------------------
//  PARTY tab
// ---------------------------------------------------------------------
ds_draw_team = function() {
    var _stats = ["maxhp", "at", "df", "mag"];
    var _lbl = ["MAX HP", "ATK", "DEF", "MAG"];
    var _step = [10, 1, 1, 1];
    for (var _c = 0; _c < 3; _c++) {
        var _x = 24 + _c * 198;
        ds_frame(_x, 84, _x + 190, 322, c_black, ds_dark);
        var _cid = global.char[_c];
        if (ds_button(_x + 6, 92, 28, 26, "<", false)) ds_set_char(_c, -1);
        ds_text(_x + 95, 105, ds_charnames[clamp(_cid, 0, 4)], (_cid > 0) ? c_yellow : c_gray, fa_center, 1.1, 110);
        if (ds_button(_x + 156, 92, 28, 26, ">", false)) ds_set_char(_c, 1);
        _cid = global.char[_c];
        if (_cid > 0) {
            ds_text(_x + 95, 136, "HP " + string(global.hp[_cid]) + " / " + string(global.maxhp[_cid]), c_white, fa_center, 1, 176);
            for (var _k = 0; _k < 4; _k++) {
                var _yy = 154 + _k * 30;
                var _arr = ds_g(_stats[_k], undefined);
                var _val = (is_array(_arr) && _cid < array_length(_arr)) ? string(_arr[_cid]) : "?";
                ds_text(_x + 10, _yy + 12, _lbl[_k], c_white, fa_left, 0.85, 64);
                ds_text(_x + 112, _yy + 12, _val, c_yellow, fa_right, 0.9, 40);
                if (ds_button(_x + 118, _yy, 32, 24, "-", false)) ds_stat(_stats[_k], _c, _cid, -_step[_k]);
                if (ds_button(_x + 154, _yy, 32, 24, "+", false)) ds_stat(_stats[_k], _c, _cid, _step[_k]);
            }
            if (ds_button(_x + 6, 284, 178, 30, "HEAL", false)) global.hp[_cid] = global.maxhp[_cid];
        }
    }

    ds_frame(24, 332, 616, 418, c_black, ds_dark);
    ds_text(40, 354, "GOLD", c_white, fa_left, 1, 0);
    ds_text(170, 354, string(ds_g("gold", 0)), c_yellow, fa_right, 1, 90);
    if (ds_button(184, 340, 80, 28, "+100", false)) global.gold += 100;
    if (ds_button(270, 340, 80, 28, "+1000", false)) global.gold += 1000;
    if (ds_button(356, 340, 80, 28, "-100", false)) global.gold = max(0, global.gold - 100);

    ds_text(40, 392, "TP", c_white, fa_left, 1, 0);
    ds_text(170, 392, string(ds_g("tension", 0)) + "/" + string(ds_g("maxtension", 250)), c_yellow, fa_right, 1, 110);
    if (ds_button(184, 378, 166, 28, "MAX TP", false)) global.tension = global.maxtension;
    if (ds_button(442, 340, 166, 66, "HEAL ALL", false)) ds_heal_all();
};

// ---------------------------------------------------------------------
//  ITEMS tab
// ---------------------------------------------------------------------
ds_draw_items = function() {
    for (var _t = 0; _t < 3; _t++) {
        if (ds_button(24 + _t * 126, 84, 120, 24, ds_isubs[_t], ds_isub == _t)) { ds_isub = _t; ds_item_scroll = 0; }
    }

    var _list = ds_items[ds_isub];
    var _rows = 14;
    var _rh = 21;
    var _ly = 116;
    var _maxs = max(0, array_length(_list) - _rows);
    if (ds_hover(24, _ly, 404, _ly + _rows * _rh)) ds_item_scroll += ds_wheel * 2;
    ds_item_scroll = clamp(ds_item_scroll, 0, _maxs);

    // Everything available (click = add)
    ds_frame(24, _ly - 2, 404, _ly + _rows * _rh + 2, c_black, ds_dark);
    if (array_length(_list) == 0) ds_text(214, _ly + 146, "None", c_gray, fa_center, 0.9, 360);
    for (var _r = 0; _r < _rows; _r++) {
        var _idx = ds_item_scroll + _r;
        if (_idx >= array_length(_list)) break;
        var _it = _list[_idx];
        var _y = _ly + _r * _rh;
        var _hv = ds_hover(26, _y, 382, _y + _rh - 1);
        if (_hv) ds_rect(26, _y, 382, _y + _rh - 1, ds_dark, 1);
        ds_text(34, _y + _rh / 2, _hv ? "+" : "", c_lime, fa_left, 1, 0);
        ds_text(52, _y + _rh / 2, _it.name, _hv ? c_yellow : c_white, fa_left, 0.9, 320);
        if (_hv && ds_click) {
            ds_click = false;
            ds_give(ds_isub, _it.iid, _it.name);
        }
    }
    if (ds_button(385, _ly, 17, 22, "^", false)) ds_item_scroll = max(0, ds_item_scroll - _rows);
    if (ds_button(385, _ly + _rows * _rh - 22, 17, 22, "v", false)) ds_item_scroll = min(_maxs, ds_item_scroll + _rows);

    // Current inventory (click = remove)
    ds_frame(412, _ly - 2, 616, 380, c_black, ds_dark);
    ds_text(514, _ly + 12, "INVENTORY", c_gray, fa_center, 0.9, 190);
    var _a = ds_inv_get(ds_isub);
    var _n = ds_inv_size(ds_isub);
    var _shown = 0;
    for (var _i = 0; _i < _n && _shown < 13; _i++) {
        var _v = _a[_i];
        if (_v != 0 && _v != 999) {
            var _iy = _ly + 28 + _shown * 17;
            var _ihv = ds_hover(416, _iy, 612, _iy + 16);
            if (_ihv) ds_rect(416, _iy, 612, _iy + 16, ds_dark, 1);
            ds_text(420, _iy + 8, _ihv ? "x" : "", c_red, fa_left, 0.8, 0);
            ds_text(434, _iy + 8, ds_item_name(ds_isub, _v), _ihv ? c_red : c_white, fa_left, 0.75, 174);
            if (_ihv && ds_click) {
                ds_click = false;
                ds_take(ds_isub, _i);
            }
            _shown += 1;
        }
    }
    if (ds_button(412, 386, 204, 28, "CLEAR", false)) ds_clear_inv(ds_isub);
};

// ---------------------------------------------------------------------
//  CHEATS tab
// ---------------------------------------------------------------------
ds_draw_cheats = function() {
    var _names = ["GOD MODE", "ONE-HIT KILL", "1 HP MODE", "AUTO SPARE", "INFINITE TP"];
    var _vals = [ds_god, ds_ohk, ds_onehp, ds_mercy, ds_tp];
    for (var _k = 0; _k < 5; _k++) {
        if (ds_switch_row(88 + _k * 58, _names[_k], _vals[_k])) ds_toggle(_k);
    }
};

// ---------------------------------------------------------------------
//  OPTIONS tab
// ---------------------------------------------------------------------
ds_draw_options = function() {
    ds_frame(24, 88, 616, 136, c_black, ds_waitkey ? c_yellow : ds_dark);
    ds_text(40, 112, "MENU KEY", c_white, fa_left, 1.1, 0);
    ds_text(300, 112, ds_waitkey ? "PRESS A KEY..." : ds_keyname(ds_key), ds_waitkey ? c_yellow : ds_orange, fa_center, 1.1, 180);
    if (ds_button(500, 97, 104, 30, "CHANGE", ds_waitkey)) ds_waitkey = true;

    if (ds_switch_row(146, "PAUSE GAME", ds_pause)) {
        ds_pause = !ds_pause;
        if (ds_pause) ds_pause_start(); else ds_pause_end();
        ds_save();
    }
    if (ds_switch_row(204, "SHOW ACTIVE CHEATS", ds_hud)) { ds_hud = !ds_hud; ds_save(); }

    if (ds_button(24, 266, 292, 32, "RELOAD LISTS", false)) {
        if (ds_in_battle()) {
            ds_msg("Not during a battle");
        } else {
            var _was = ds_is_paused;
            ds_pause_end();
            ds_scan_encounters();
            ds_scan_items();
            if (_was) ds_pause_start();
            ds_msg("Reloaded");
        }
    }
    if (ds_button(324, 266, 292, 32, "RESET CHEATS", false)) {
        ds_god = false; ds_ohk = false; ds_onehp = false; ds_mercy = false; ds_tp = false;
    }
};

// --- Use the game's font if present ---
ds_font = ds_asset("fnt_main");
ds_has_font = !is_undefined(ds_font);

// --- Load options ---
try {
    ini_open("deltasponge.ini");
    ds_key = ini_read_real("options", "key", ds_key);
    ds_pause = ini_read_real("options", "pause", 1) >= 1;
    ds_hud = ini_read_real("options", "hud", 1) >= 1;
    ini_close();
} catch (_e) {
    try { ini_close(); } catch (_e2) {}
}
