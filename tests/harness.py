"""Offline test harness: drives the LootCheck addon inside a real Lua 5.1 VM
(OBS Studio's LuaJIT lua51.dll) with a thin WoW API stub layer, using the
player's real TMBExport / Gargul saved variables as fixtures."""
import ctypes
import io
import os
import sys

import glob

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")

# Everything below can be pointed elsewhere with an environment variable, so
# the suites run on any machine without editing this file.
ADDON = os.environ.get("LOOTCHECK_ADDON") or os.path.dirname(HERE)

WOW_ROOTS = [
    os.environ.get("LOOTCHECK_WOW"),
    r"C:\Program Files (x86)\World of Warcraft",
    r"C:\Program Files\World of Warcraft",
    r"D:\World of Warcraft",
    r"F:\Program Files (x86)\World of Warcraft",
    "/Applications/World of Warcraft",
]


def find_saved_variables():
    """Locate real Gargul / TMBExport saved variables to use as fixtures.

    The suites run against real data on purpose, so the assertions face the
    shapes the addon actually meets in game. Set LOOTCHECK_SV to your own
    WTF/Account/<account>/SavedVariables folder, or LOOTCHECK_WOW to your
    WoW install, and this will find it.
    """
    explicit = os.environ.get("LOOTCHECK_SV")
    if explicit:
        return explicit

    found = []
    for root in WOW_ROOTS:
        if not root or not os.path.isdir(root):
            continue
        pattern = os.path.join(root, "*", "WTF", "Account", "*", "SavedVariables")
        for candidate in glob.glob(pattern):
            fixtures = [os.path.join(candidate, name)
                        for name in ("Gargul.lua", "TMBExport.lua")]
            if not all(os.path.isfile(f) for f in fixtures):
                continue
            # An account that has barely played has almost no data to assert
            # against, so prefer the Anniversary client and the fullest file.
            anniversary = 0 if "_anniversary_" in candidate else 1
            size = sum(os.path.getsize(f) for f in fixtures)
            found.append((anniversary, -size, candidate))

    return sorted(found)[0][2] if found else None


SV = find_saved_variables()

# Lua 5.1 / LuaJIT runtimes that ship inside other software
CANDIDATES = [
    os.environ.get("LOOTCHECK_LUA_DLL"),
    r"C:\Program Files\obs-studio\bin\64bit\lua51.dll",
    os.path.join(HOME, r"AppData\Roaming\Path of Building Community\lua51.dll"),
    r"C:\Program Files\Blackmagic Design\DaVinci Resolve\lua5.1.dll",
]
CANDIDATES = [path for path in CANDIDATES if path]

lib = None
for path in CANDIDATES:
    try:
        lib = ctypes.CDLL(path)
        print("Loaded Lua runtime:", path, flush=True)
        break
    except OSError as exc:
        print("Could not load", path, "->", exc, flush=True)
if lib is None:
    sys.exit("no Lua runtime available")

lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
lib.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
lib.luaL_loadbuffer.restype = ctypes.c_int
lib.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lib.lua_pcall.restype = ctypes.c_int
lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_pushstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lib.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]

L = lib.luaL_newstate()
lib.luaL_openlibs(L)


def run(path, *args):
    sys.stdout.flush()
    with open(path, "rb") as fh:
        src = fh.read()
    chunk_name = ("@" + os.path.basename(path)).encode()
    status = lib.luaL_loadbuffer(L, src, len(src), chunk_name)
    if status == 0:
        for arg in args:
            lib.lua_pushstring(L, arg.encode())
        status = lib.lua_pcall(L, len(args), 0, 0)
    if status != 0:
        msg = lib.lua_tolstring(L, -1, None) or b"?"
        print("\nLUA ERROR (%s): %s" % (path, msg.decode("utf-8", "replace")), flush=True)
        lib.lua_settop(L, 0)
        sys.exit(1)
    lib.lua_settop(L, 0)


# The addon must never touch Blizzard's shared dropdown / popup systems: doing so
# taints the secure UI and the game menu's "Log Out" button stops working.
FORBIDDEN = ("UIDropDownMenu", "StaticPopupDialogs", "StaticPopup_Show")
offences = []
for name in sorted(os.listdir(ADDON)):
    if not name.endswith(".lua"):
        continue
    with io.open(os.path.join(ADDON, name), encoding="utf-8", errors="replace") as fh:
        for number, line in enumerate(fh, 1):
            code = line.split("--", 1)[0]
            for bad in FORBIDDEN:
                if bad in code:
                    offences.append("%s:%d uses %s" % (name, number, bad))
if offences:
    sys.exit("taint guard failed:\n  " + "\n  ".join(offences))
print("taint guard: no Blizzard dropdown/popup usage", flush=True)

run(os.path.join(HERE, "stubs.lua"), ADDON.replace("\\", "/"))
# Real libraries where they are pure Lua, a loopback stand-in for AceComm
run(os.path.join(ADDON, "Libs", "LibStub", "LibStub.lua"))
run(os.path.join(ADDON, "Libs", "LibDeflate", "LibDeflate.lua"))
run(os.path.join(ADDON, "Libs", "LibDeformat-3.0", "LibDeformat-3.0.lua"))
run(os.path.join(HERE, "fake_acecomm.lua"))
for name in ("Core.lua", "Data.lua", "Phases.lua", "TierTokens.lua", "Tooltip.lua", "Window.lua", "Drops.lua", "Graph.lua", "Wishlist.lua", "Awards.lua", "Imports.lua", "Comm.lua", "Help.lua", "Audit.lua", "Council.lua", "Config.lua"):
    run(os.path.join(ADDON, name), "LootCheck", "")
if not SV:
    sys.exit(
        "no SavedVariables folder found. Set LOOTCHECK_SV to your "
        "WTF/Account/<account>/SavedVariables folder (it needs Gargul.lua and "
        "TMBExport.lua), or LOOTCHECK_WOW to your WoW install."
    )
run(os.path.join(SV, "TMBExport.lua"))
run(os.path.join(SV, "Gargul.lua"))
run(os.path.join(HERE, "test.lua"))
run(os.path.join(HERE, "test_history.lua"))
run(os.path.join(HERE, "test_wishlist.lua"))
run(os.path.join(HERE, "test_imports.lua"))
run(os.path.join(HERE, "test_awards.lua"))
run(os.path.join(HERE, "test_config.lua"))
run(os.path.join(HERE, "test_help.lua"))
run(os.path.join(HERE, "test_audit.lua"))
run(os.path.join(HERE, "test_layout.lua"))
run(os.path.join(HERE, "test_comm.lua"))
run(os.path.join(HERE, "test_share.lua"))
run(os.path.join(HERE, "test_drops.lua"))
run(os.path.join(HERE, "test_council.lua"))
run(os.path.join(HERE, "test_phases.lua"))
run(os.path.join(HERE, "test_resize.lua"))
print("harness finished OK", flush=True)
