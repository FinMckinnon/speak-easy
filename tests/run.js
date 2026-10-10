// Runs one Lua test file under Fengari (npm install fengari) against the addon folder given second.
// From the addon folder: node tests/run.js tests/core.lua .
const { lua, lauxlib, lualib, to_luastring } = require("fengari");
const fs = require("fs");
const addonDir = process.argv[3] || ".";
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_pushstring(L, to_luastring(addonDir)); lua.lua_setglobal(L, to_luastring("ADDON_DIR"));
lua.lua_pushstring(L, to_luastring(fs.readFileSync(addonDir + "/SpeakEasy.toc", "utf8"))); lua.lua_setglobal(L, to_luastring("TOC"));
// READ_FILE(path) returns a file's text, since Fengari has no io library.
lua.lua_pushcfunction(L, (S) => { lua.lua_pushstring(S, to_luastring(fs.readFileSync(lua.lua_tojsstring(S, 1), "utf8"))); return 1; });
lua.lua_setglobal(L, to_luastring("READ_FILE"));
// WRITE_FILE(path, text) writes a file, making its folder, for test snapshots.
lua.lua_pushcfunction(L, (S) => {
    const p = lua.lua_tojsstring(S, 1);
    fs.mkdirSync(require("path").dirname(p), { recursive: true });
    fs.writeFileSync(p, lua.lua_tojsstring(S, 2));
    return 0;
});
lua.lua_setglobal(L, to_luastring("WRITE_FILE"));
if (lauxlib.luaL_dofile(L, to_luastring(process.argv[2])) !== 0) {
    console.log("LUA ERROR:", lua.lua_tojsstring(L, -1));
    process.exit(1);
}
