# Firefox Developer Edition Setup

## First-time setup

```bash
bash ~/dotfiles/firefox/setup.sh
```

Requires terminal to have **App Management + Full Disk Access** in System Settings → Privacy & Security (needed to write into the Firefox app bundle).

Restart Firefox after running — the extension installs automatically via enterprise policy.

## Updating the extension

After changing `extension/background.js`:

```bash
bash ~/dotfiles/firefox/setup.sh --reload
```

Click **Add** in the Firefox dialog that opens. No restart needed.

## Adding a new bridge command

1. Add a `case "yourCommand":` block to `extension/background.js`
2. Run `setup.sh --reload` and click Add in Firefox
3. Call it from Hammerspoon: `helpers.sendBridgeCommand({ type = "yourCommand" })`

## After a Firefox update

Firefox updates wipe `policies.json` from the app bundle. Re-run the full setup:

```bash
bash ~/dotfiles/firefox/setup.sh
```

## How it works

```
Hammerspoon (Lua)
  → sendBridgeCommand() writes JSON to /tmp, runs bridge_send.py
    → bridge_send.py sends to Unix socket (~/.cache/firefox-bridge/socket)
      → firefox_bridge.py (native host, spawned by Firefox)
        → forwards to extension via native messaging (stdout)
          → background.js handles command via browser.* APIs
```

For commands that return data (`getUrl`, `getTabs`), the response travels back
through the same chain and is returned to Lua as a JSON string.

