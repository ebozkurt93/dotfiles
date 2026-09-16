local helpers = require("helpers")

local home = os.getenv("HOME")
local ghPrsBinary = home .. "/bin/github-prs"
local stateSwitcherBinary = home .. "/bin/state-switcher"

local menu = nil
local refresh

-- hs.task inherits Hammerspoon's own (launchd-minimal) PATH, which doesn't
-- include ~/.nix-profile/bin where gh/jq live, so those binaries would
-- otherwise fail to be found.
local taskPath = home .. "/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

-- The streaming callback drains the pipe incrementally to avoid a deadlock
-- on large output, but once one's registered, the completion callback's own
-- stdOut is no longer populated, so we accumulate manually. hs.task's docs
-- warn the streaming callback may fire once more (with task == nil) right
-- after termination, so defer finalizing by one tick to catch that chunk.
local function runWithPath(binary, args, callback)
  local outputChunks = {}
  local finished = false

  local function finish(exitCode, stdErr)
    if finished then return end
    finished = true
    local stdOut = table.concat(outputChunks)
    if exitCode ~= 0 then
      print(string.format("github_prs.lua: %s exited %s: %s", binary, tostring(exitCode), stdErr or ""))
    end
    callback(exitCode, stdOut, stdErr)
  end

  local task = hs.task.new(binary, function(exitCode, _, stdErr)
    hs.timer.doAfter(0.1, function() finish(exitCode, stdErr) end)
  end, function(_, stdOut)
    if stdOut and stdOut ~= "" then
      table.insert(outputChunks, stdOut)
    end
    return true
  end, args)
  task:setEnvironment({ PATH = taskPath, HOME = home })
  task:start()
end

local function checkEnabled(callback)
  runWithPath(stateSwitcherBinary, { "is-state-enabled", "instabee" }, function(exitCode)
    callback(exitCode == 0)
  end)
end

local function checksLabel(statusCheckRollup)
  if not statusCheckRollup or #statusCheckRollup == 0 then
    return ""
  end
  for _, check in ipairs(statusCheckRollup) do
    if check.conclusion == "FAILURE" or check.conclusion == "TIMED_OUT"
      or check.conclusion == "ACTION_REQUIRED" or check.conclusion == "CANCELLED" then
      return "Failing"
    end
  end
  for _, check in ipairs(statusCheckRollup) do
    if check.status ~= "COMPLETED" then
      return "Pending"
    end
  end
  return "Passing"
end

-- Hammerspoon.app is launched by launchd/Finder, not a login shell, so it
-- never sees GH_USERNAME (exported in .personal.zshrc) -- ask `gh` directly.
local ghUsername = ""
local ghBinary = home .. "/.nix-profile/bin/gh"
local function fetchGhUsername()
  runWithPath(ghBinary, { "config", "get", "-h", "github.com", "user" }, function(exitCode, stdOut)
    if exitCode == 0 then
      ghUsername = (stdOut or ""):gsub("%s+$", "")
    end
  end)
end
fetchGhUsername()

local function maxTimestamp(a, b)
  if not a then return b end
  if not b then return a end
  return a > b and a or b
end

local function lastActivityBy(pr, matchesAuthor)
  local last = nil
  for _, review in ipairs(pr.reviews or {}) do
    if matchesAuthor(review.author) then
      last = maxTimestamp(last, review.submittedAt)
    end
  end
  for _, comment in ipairs(pr.comments or {}) do
    if matchesAuthor(comment.author) then
      last = maxTimestamp(last, comment.createdAt)
    end
  end
  return last
end

local function othersLastActivity(pr)
  local last = nil
  for _, commit in ipairs(pr.commits or {}) do
    last = maxTimestamp(last, commit.committedDate)
  end
  for _, comment in ipairs(pr.comments or {}) do
    if not comment.author or comment.author.login ~= ghUsername then
      last = maxTimestamp(last, comment.createdAt)
    end
  end
  for _, review in ipairs(pr.reviews or {}) do
    if not review.author or review.author.login ~= ghUsername then
      last = maxTimestamp(last, review.submittedAt)
    end
  end
  return last
end

-- Named colors, since hs.styledtext doesn't resolve { list = "X11", name = ... }
-- the way BitBar's `color=name` did; every other widget in this config uses
-- explicit RGB tables, so match that.
local dimgray = { red = 0.412, green = 0.412, blue = 0.412 }
local teal = { red = 0, green = 0.502, blue = 0.502 }
local mediumpurple = { red = 0.576, green = 0.439, blue = 0.859 }

local function prColor(pr)
  local authorLogin = pr.author and pr.author.login
  if authorLogin == "app/dependabot" then
    return dimgray
  end
  if authorLogin == ghUsername then
    return teal
  end

  local myLast = lastActivityBy(pr, function(author) return author and author.login == ghUsername end)
  local othersLast = othersLastActivity(pr)
  if myLast and othersLast and othersLast > myLast then
    return mediumpurple
  end
  return nil
end

-- NSMenuItem's attributedTitle doesn't reliably honor NSParagraphStyle tab
-- stops in practice (columns drifted regardless of content length), so align
-- columns the guaranteed way instead: a monospace font with fixed-width,
-- space-padded fields.
local monoFont = { name = "JetBrainsMono-Regular", size = 12 }

local function charLen(text)
  return utf8 and utf8.len(text) or #text
end

local function truncate(text, maxLen)
  text = text or ""
  if charLen(text) > maxLen then
    local cutAt = utf8 and utf8.offset(text, maxLen) or maxLen
    return text:sub(1, cutAt - 1) .. "…"
  end
  return text
end

local function padRight(text, width)
  text = text or ""
  local len = charLen(text)
  if len >= width then
    return text
  end
  return text .. string.rep(" ", width - len)
end

local function prMenuItem(pr)
  local name = truncate((pr.headRepository and pr.headRepository.name or "?") .. "#" .. tostring(pr.number), 22)
  local draftText = pr.isDraft and "Draft" or ""
  local reviewText = ""
  if pr.reviewDecision == "APPROVED" then reviewText = "Approved"
  elseif pr.reviewDecision == "REVIEW_REQUIRED" then reviewText = "Review required"
  elseif pr.reviewDecision == "CHANGES_REQUESTED" then reviewText = "Changes requested"
  end
  local mergeableText = pr.mergeable ~= "MERGEABLE" and "Not mergeable" or ""
  local checks = checksLabel(pr.statusCheckRollup)
  local flags = {}
  for _, flag in ipairs({ draftText, reviewText, mergeableText, checks }) do
    if flag ~= "" then table.insert(flags, flag) end
  end
  local flagsText = truncate(table.concat(flags, ", "), 40)

  local titleText = table.concat({
    padRight(name, 24),
    padRight(truncate(pr.title, 45), 47),
    padRight("👤 " .. truncate(pr.author and pr.author.login or "?", 12), 18),
    padRight("💬 " .. tostring(pr.comments and #pr.comments or 0), 8),
    padRight(string.format("📜+%d-%d", pr.additions or 0, pr.deletions or 0), 14),
    flagsText,
  })

  local style = { font = monoFont }
  local color = prColor(pr)
  if color then style.color = color end
  local title = hs.styledtext.new(titleText, style)

  return {
    title = title,
    fn = function() hs.urlevent.openURL(pr.url) end,
  }
end

local function nonDependabotCount(prs)
  local count = 0
  for _, pr in ipairs(prs) do
    if not pr.author or pr.author.login ~= "app/dependabot" then
      count = count + 1
    end
  end
  return count
end

local function refetch()
  runWithPath(ghPrsBinary, { "refetch" }, function()
    refresh()
  end)
end

local function renderPRs(prs)
  menu:setTitle(string.format("PRs: %d (%d)", #prs, nonDependabotCount(prs)))

  local items = {}
  for _, pr in ipairs(prs) do
    table.insert(items, prMenuItem(pr))
  end
  table.insert(items, { title = "-" })
  table.insert(items, { title = "Refetch PRs", fn = refetch })
  table.insert(items, { title = "Refresh", fn = refresh })
  menu:setMenu(items)
end

refresh = function()
  if ghUsername == "" then
    fetchGhUsername()
  end
  checkEnabled(function(isEnabled)
    if not isEnabled then
      if menu then
        menu:delete()
        menu = nil
      end
      return
    end

    if not menu then
      menu = helpers.registerMenubar(hs.menubar.new(true, "eb-github-prs"))
    end
    runWithPath(ghPrsBinary, { "json" }, function(exitCode, stdOut)
      if not menu then return end
      if exitCode ~= 0 then
        menu:setTitle("PRs ?")
        return
      end
      local prs = hs.json.decode(stdOut) or {}
      renderPRs(prs)
    end)
  end)
end

helpers.onStateSwitcherChanged(refresh)

local timer = hs.timer.doEvery(300, refresh):start()
refresh()

return {
  timer = timer,
  refresh = refresh,
  refetch = refetch,
}
