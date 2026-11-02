// Dragon Legend as a desktop app: runs the bundled game (site/) in Electron, on the dedicated GPU,
// at full speed even when another window is in front. Installed builds update themselves from
// GitHub releases (electron-updater reads the release's latest.yml).
const { app, BrowserWindow, Menu, dialog, net, protocol, shell } = require("electron");
const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");

app.commandLine.appendSwitch("force_high_performance_gpu");
app.commandLine.appendSwitch("ignore-gpu-blocklist");
app.commandLine.appendSwitch("enable-gpu-rasterization");
app.commandLine.appendSwitch("enable-zero-copy");
app.commandLine.appendSwitch("disable-background-timer-throttling");
app.commandLine.appendSwitch("disable-renderer-backgrounding");
app.commandLine.appendSwitch("disable-backgrounding-occluded-windows");

// served from app://game/ (not file://, where modules, fetch and storage misbehave)
protocol.registerSchemesAsPrivileged([{ scheme: "app", privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } }]);
const SITE = path.join(__dirname, "site");
const TITLE = "Dragon Legend";
const RELEASES = "https://github.com/laibaminhvuong-ux/dragon-legend/releases/latest";
let autoUpdater = null;
try { ({ autoUpdater } = require("electron-updater")); } catch { /* unpacked dev build: download page only */ }

/** Is version a newer than b? ("0.2.0" vs "0.1.0") */
function newer(a, b) {
  const pa = a.split(".").map(Number), pb = b.split(".").map(Number);
  for (let i = 0; i < 3; i++) if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) > (pb[i] || 0);
  return false;
}

/**
 * Update inside the game: ask, download (progress in the title bar and taskbar), install silently
 * and restart. Resolves once it knows whether there's an update; rejects if this build can't update
 * itself (portable zip, unpacked folder), so the caller falls back to the download page.
 */
function inAppUpdate(win) {
  return new Promise((resolve, reject) => {
    autoUpdater.autoDownload = false;
    autoUpdater.autoInstallOnAppQuit = false;
    let asked = false;
    autoUpdater.on("error", (e) => {
      if (!asked) return reject(e);
      win.setProgressBar(-1);
      win.setTitle(TITLE);
      dialog.showMessageBox(win, { type: "error", buttons: ["Open download page", "OK"], defaultId: 0, cancelId: 1, title: "Update failed",
        message: "The update couldn't be installed", detail: "You can download the new version from the download page instead. Your saves stay." })
        .then((r) => r.response === 0 && shell.openExternal(RELEASES));
    });
    autoUpdater.once("update-not-available", () => resolve());
    autoUpdater.once("update-available", async (info) => {
      asked = true;
      resolve();
      const { response } = await dialog.showMessageBox(win, {
        type: "question", buttons: ["Update now", "Later"], defaultId: 0, cancelId: 1, title: "Update available",
        message: `${TITLE} ${info.version} is out`,
        detail: `You have ${app.getVersion()}. Update now? The game downloads it, installs it and restarts by itself. Your saves stay.`,
      });
      if (response !== 0) return;
      autoUpdater.on("download-progress", (p) => {
        win.setProgressBar(p.percent / 100);
        win.setTitle(`${TITLE}: downloading update ${Math.round(p.percent)}%`);
      });
      autoUpdater.once("update-downloaded", () => {
        win.setProgressBar(-1);
        win.setTitle(`${TITLE}: installing update, restarting…`);
        setTimeout(() => autoUpdater.quitAndInstall(true, true), 800);
      });
      autoUpdater.downloadUpdate();
    });
    autoUpdater.checkForUpdates().catch(reject);
  });
}

/** On startup: update inside the game when this build can; otherwise offer the download page. */
async function checkForUpdate(win) {
  if (autoUpdater && app.isPackaged && process.platform !== "darwin") {
    try { await inAppUpdate(win); return; } catch { /* fall back to the download page */ }
  }
  try {
    const r = await net.fetch("https://api.github.com/repos/laibaminhvuong-ux/dragon-legend/releases/latest", { headers: { "User-Agent": "dragon-legend" } });
    if (!r.ok) return;
    const latest = String((await r.json()).tag_name || "").replace(/^v/, "");
    if (!/^\d+\.\d+/.test(latest) || !newer(latest, app.getVersion())) return;
    const { response } = await dialog.showMessageBox(win, {
      type: "info", buttons: ["Download", "Later"], defaultId: 0, cancelId: 1, title: "Update available",
      message: `${TITLE} ${latest} is out`, detail: `You have ${app.getVersion()}. Download the new version to get the latest features (your saves stay).`,
    });
    if (response === 0) shell.openExternal(RELEASES);
  } catch { /* offline: try again next launch */ }
}

app.whenReady().then(() => {
  protocol.handle("app", (req) => {
    let p = decodeURIComponent(new URL(req.url).pathname);
    if (p === "/" || p === "") p = "/index.html";
    const file = path.normalize(path.join(SITE, p));
    if (!file.startsWith(SITE + path.sep) || !fs.existsSync(file)) return new Response("Not found", { status: 404 });
    return net.fetch(pathToFileURL(file).toString());
  });
  Menu.setApplicationMenu(null);
  const win = new BrowserWindow({
    width: 1440, height: 900, minWidth: 900, minHeight: 600, show: false,
    backgroundColor: "#0b0d12", title: "Dragon Legend", icon: path.join(SITE, "icons", "icon-512.png"),
    webPreferences: { backgroundThrottling: false, contextIsolation: true, sandbox: true },
  });
  win.once("ready-to-show", () => {
    win.maximize();
    win.show();
    setTimeout(() => checkForUpdate(win), 4000);
  });
  win.loadURL("app://game/index.html");
  win.webContents.on("before-input-event", (e, input) => {
    if (input.type === "keyDown" && input.key === "F11") { win.setFullScreen(!win.isFullScreen()); e.preventDefault(); }
  });
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: "deny" };
  });
});
app.on("window-all-closed", () => app.quit());
