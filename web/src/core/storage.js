// localStorage with a memory fallback (private windows, node checks, blocked storage).
const memory = new Map();
let ls = null;
try {
  ls = globalThis.localStorage || null;
  if (ls) { ls.setItem("__t", "1"); ls.removeItem("__t"); }
} catch { ls = null; }

export const storage = {
  persistent: !!ls,
  get(key) {
    try { return ls ? ls.getItem(key) : memory.get(key) ?? null; } catch { return memory.get(key) ?? null; }
  },
  set(key, value) {
    memory.set(key, value);
    try { ls && ls.setItem(key, value); return true; } catch { return false; }
  },
  remove(key) {
    memory.delete(key);
    try { ls && ls.removeItem(key); } catch { /* ignore */ }
  },
};
