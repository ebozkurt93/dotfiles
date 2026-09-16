local home = os.getenv("HOME")
local ghPrsBinary = home .. "/bin/github-prs"
local stateSwitcherBinary = home .. "/bin/state-switcher"

local menu = hs.menubar.new()
local refresh

local function checkEnabled(callback)
  hs.task.new(stateSwitcherBinary, function(exitCode)
    callback(exitCode == 0)
  end, { "is-state-enabled", "instabee" }):start()
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

local ghUsername = os.getenv("GH_USERNAME") or ""

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

local function prColor(pr)
  local authorLogin = pr.author and pr.author.login
  if authorLogin == "app/dependabot" then
    return { list = "X11", name = "dimgray" }
  end
  if authorLogin == ghUsername then
    return { list = "X11", name = "teal" }
  end

  local myLast = lastActivityBy(pr, function(author) return author and author.login == ghUsername end)
  local othersLast = othersLastActivity(pr)
  if myLast and othersLast and othersLast > myLast then
    return { list = "X11", name = "mediumpurple" }
  end
  return nil
end

local function prMenuItem(pr)
  local name = (pr.headRepository and pr.headRepository.name or "?") .. "#" .. tostring(pr.number)
  local flags = {}
  if pr.isDraft then table.insert(flags, "Draft") end
  if pr.reviewDecision == "APPROVED" then table.insert(flags, "Approved")
  elseif pr.reviewDecision == "REVIEW_REQUIRED" then table.insert(flags, "Review required")
  elseif pr.reviewDecision == "CHANGES_REQUESTED" then table.insert(flags, "Changes requested")
  end
  if pr.mergeable ~= "MERGEABLE" then table.insert(flags, "Not mergeable") end
  local checks = checksLabel(pr.statusCheckRollup)
  if checks ~= "" then table.insert(flags, checks) end

  local titleText = string.format(
    "%s  %s  👤 %s  💬 %d  📜+%d-%d%s",
    name,
    pr.title,
    pr.author and pr.author.login or "?",
    pr.comments and #pr.comments or 0,
    pr.additions or 0,
    pr.deletions or 0,
    #flags > 0 and ("  [" .. table.concat(flags, ", ") .. "]") or ""
  )

  local color = prColor(pr)
  local title = color and hs.styledtext.new(titleText, { color = color }) or titleText

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
  hs.task.new(ghPrsBinary, function()
    refresh()
  end, { "refetch" }):start()
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
  checkEnabled(function(isEnabled)
    if not isEnabled then
      menu:removeFromMenuBar()
      return
    end

    menu:returnToMenuBar()
    hs.task.new(ghPrsBinary, function(exitCode, stdOut)
      if exitCode ~= 0 then
        menu:setTitle("PRs ?")
        return
      end
      local prs = hs.json.decode(stdOut) or {}
      renderPRs(prs)
    end, { "json" }):start()
  end)
end

local timer = hs.timer.doEvery(300, refresh):start()
refresh()

return {
  timer = timer,
  menubar = menu,
  refresh = refresh,
}
