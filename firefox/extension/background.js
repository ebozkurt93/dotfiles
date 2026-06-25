let port;

function connect() {
  port = browser.runtime.connectNative("firefox_bridge");
  port.onMessage.addListener(handleCommand);
  port.onDisconnect.addListener(() => setTimeout(connect, 5000));
}

async function handleCommand(msg) {
  try {
    switch (msg.type) {
      case "exec": {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        if (tab) await browser.tabs.executeScript(tab.id, { code: msg.js });
        break;
      }
      case "execMatch": {
        const tabs = await browser.tabs.query({});
        const regex = new RegExp(msg.pattern);
        const tab = tabs.find(t => regex.test(t.url));
        if (tab) await browser.tabs.executeScript(tab.id, { code: msg.js });
        break;
      }
      case "getUrl": {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        port.postMessage({ type: "urlResponse", url: tab ? tab.url : "" });
        break;
      }
      case "getTabs": {
        const windows = await browser.windows.getAll({ populate: true });
        const tabs = [];
        windows.forEach((win, wi) => {
          (win.tabs || []).forEach((tab, ti) => {
            tabs.push({ title: tab.title || "", url: tab.url || "", windowIndex: wi + 1, tabIndex: ti + 1, tabId: tab.id, windowId: win.id });
          });
        });
        port.postMessage({ type: "tabsResponse", tabs });
        break;
      }
      case "switch": {
        await browser.tabs.update(msg.tabId, { active: true });
        await browser.windows.update(msg.windowId, { focused: true });
        break;
      }
      case "duplicateTab": {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        if (tab) await browser.tabs.duplicate(tab.id);
        break;
      }
      case "toggleMute": {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        if (tab) await browser.tabs.update(tab.id, { muted: !tab.mutedInfo.muted });
        break;
      }
      case "togglePin": {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        if (tab) await browser.tabs.update(tab.id, { pinned: !tab.pinned });
        break;
      }
      case "newTabRight": {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        if (tab) await browser.tabs.create({ index: tab.index + 1, windowId: tab.windowId });
        break;
      }
      case "moveTabToWindow": {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        if (tab) await browser.windows.create({ tabId: tab.id });
        break;
      }
    }
  } catch (e) {
    console.error("firefox-bridge:", e);
  }
}

connect();
