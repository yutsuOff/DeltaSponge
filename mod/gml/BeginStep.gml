/// DeltaSponge Tool - Begin Step (applies cheats)
/// Runs before bullets / attacks so cheats always win.

if (ds_is_paused) exit;

try {
    var _fight = ds_in_battle();

    if (ds_god || ds_onehp) {
        for (var _i = 0; _i < 3; _i++) {
            var _c = global.char[_i];
            if (_c > 0) {
                if (ds_god && global.hp[_c] < global.maxhp[_c]) global.hp[_c] = global.maxhp[_c];
                if (ds_onehp && _fight && global.hp[_c] > 1) global.hp[_c] = 1;
            }
        }
        // global.inv = soul invincibility frames: scr_damage only hurts while it is < 0
        if (ds_god && _fight && global.inv < 2) global.inv = 2;
    }

    if (_fight) {
        for (var _m = 0; _m < 3; _m++) {
            if (global.monster[_m]) {
                if (ds_ohk && global.monsterhp[_m] > 1) global.monsterhp[_m] = 1;
                if (ds_mercy && global.mercymod[_m] < 100) global.mercymod[_m] = 100;
            }
        }
        if (ds_tp) global.tension = global.maxtension;
    }
} catch (_e) {
    // Some globals don't exist yet (title screen, etc.)
}
