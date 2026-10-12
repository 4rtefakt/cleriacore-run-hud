K17 = ";".join("%d:near=17;%d:atk" % (t, t + 1) for t in range(40, 140, 25))    # kill the nearest cast 17 (M_130, 74 HP)
LP = "[lua:4rtefakt.runhud] "
CASES = {
    # One kill with the Cheats' x10: 20 or 30 a hit (the game rounds at random), 90 in all; then a 22-damage hit taken.
    "kill_and_hit": dict(room="S_10/S_1002/S_1002",
        drive="8:opt=DamageDealt=10;" + K17 + ";150:hurt=60;170:lua=hud;171:shot;180:quit",
        expect=[LP + "Run HUD loaded", " kills 1 deaths 0 dealt 90 taken 22 hits 1 best 30 rooms 1 "], shots={"hud": 171}),
    # A death is counted and survives the Retry.
    "death": dict(room="S_10/S_1002/S_1002",
        drive="30:hp=0;200:ok;260:ok;400:lua=hud;420:quit",
        expect=["[death] HP 0", " kills 0 deaths 1 "]),
    # In a statue room the continue reloads the save's storage: the death is still counted.
    "death_reload": dict(room="S_10/S_1009/S_1009",
        drive="30:hp=0;200:ok;260:ok;400:lua=hud;420:quit",
        expect=["[death] HP 0", " kills 0 deaths 1 "]),
    # The numbers are kept with the save: a save and load brings them back; a room change restarts the room clock.
    "saved": dict(room="S_10/S_1002/S_1002",
        drive="8:opt=DamageDealt=10;" + K17 + ";150:lua=hud;160:saveload;200:lua=hud;210:exit=0;400:lua=hud;420:quit",
        expect=[" kills 1 ", " kills 1 deaths 0 dealt 90 taken 0 hits 0 best 30 rooms 1 ", ">> entering S_10", " kills 1 deaths 0 dealt 90 taken 0 hits 0 best 30 rooms 2 "]),
}
