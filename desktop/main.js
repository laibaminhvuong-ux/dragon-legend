// Dragon Legend as a desktop app: runs the bundled game (site/) in Electron, on the dedicated GPU,
// at full speed even when another window is in front. Installer + self-update come in M6.
const { app, BrowserWindow, Menu, net, protocol, shell } = require("electron");
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
  win.once("ready-to-show", () => { win.maximize(); win.show(); });
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
