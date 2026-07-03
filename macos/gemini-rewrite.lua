-- Gemini Rewrite for macOS (Hammerspoon)
-- Select text anywhere, press Ctrl+Alt+Cmd+C, and the selection is
-- rewritten by the Gemini API and pasted back in place.
--
-- Config: ~/.hammerspoon/gemini-rewrite-config.json
--   { "apiKey": "...", "model": "gemini-3.1-flash-lite",
--     "hotkeyMods": ["ctrl","alt","cmd"], "hotkeyKey": "c" }

local M = {}

local CONFIG_PATH = os.getenv("HOME") .. "/.hammerspoon/gemini-rewrite-config.json"
local DEFAULT_MODEL = "gemini-3.1-flash-lite"
local HTTP_TIMEOUT = 15

local function readConfig()
  local cfg = hs.json.read(CONFIG_PATH) or {}
  cfg.model = (cfg.model and cfg.model ~= "") and cfg.model or DEFAULT_MODEL
  cfg.hotkeyMods = cfg.hotkeyMods or { "ctrl", "alt", "cmd" }
  cfg.hotkeyKey = cfg.hotkeyKey or "c"
  return cfg
end

local function notify(msg)
  hs.notify.new({ title = "Gemini Rewrite", informativeText = msg }):send()
end

-- Strip markdown code fences and one pair of wrapping quotes
local function sanitize(s)
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  local fenced = s:match("^```[%w]*\n(.-)\n?```$")
  if fenced then s = fenced:gsub("^%s+", ""):gsub("%s+$", "") end
  local first, last = s:sub(1, 1), s:sub(-1)
  if (first == '"' and last == '"') or (first == "'" and last == "'") then
    s = s:sub(2, -2):gsub("^%s+", ""):gsub("%s+$", "")
  end
  return s
end

local function callGemini(cfg, text, onDone, onError)
  local url = "https://generativelanguage.googleapis.com/v1beta/models/"
      .. cfg.model .. ":generateContent"
  local prompt = "Rewrite/paraphrase the following text. Preserve the original "
      .. "meaning, tone, and approximate length. Return ONLY the rewritten text "
      .. "with no extra commentary, no quotation marks wrapping it, and no "
      .. "markdown formatting:\n\n" .. text
  local body = hs.json.encode({
    contents = { { parts = { { text = prompt } } } },
    generationConfig = { thinkingConfig = { thinkingBudget = 0 } },
  })
  hs.http.asyncPost(url, body,
    { ["Content-Type"] = "application/json", ["x-goog-api-key"] = cfg.apiKey },
    function(status, respBody)
      if status == 200 then
        local ok, resp = pcall(hs.json.decode, respBody)
        local out = ok and resp and resp.candidates and resp.candidates[1]
            and resp.candidates[1].content and resp.candidates[1].content.parts
            and resp.candidates[1].content.parts[1]
            and resp.candidates[1].content.parts[1].text
        if out and out ~= "" then onDone(sanitize(out))
        else onError("Couldn't parse Gemini response.") end
      elseif status == 401 or status == 403 then
        onError("Invalid API key (HTTP " .. status .. ").")
      elseif status == 429 then
        onError("Rate limit hit (HTTP 429). Try again in a moment.")
      elseif status <= 0 then
        onError("Network error — check your internet connection.")
      else
        onError("Gemini API error (HTTP " .. status .. ").")
      end
    end)
end

local function rewriteSelection()
  local cfg = readConfig()
  if not cfg.apiKey or cfg.apiKey == "" or cfg.apiKey == "YOUR_API_KEY_HERE" then
    notify("Missing API key. Edit " .. CONFIG_PATH)
    return
  end

  local saved = hs.pasteboard.getContents()
  local beforeCount = hs.pasteboard.changeCount()
  hs.eventtap.keyStroke({ "cmd" }, "c")

  hs.timer.doAfter(0.3, function()
    if hs.pasteboard.changeCount() == beforeCount then
      notify("No text selected.")
      return
    end
    local text = hs.pasteboard.getContents()
    if not text or text:gsub("%s", "") == "" then
      hs.pasteboard.setContents(saved or "")
      notify("Clipboard doesn't contain text.")
      return
    end
    hs.alert.show("Rewriting…", 1)
    callGemini(cfg, text,
      function(rewritten)
        hs.pasteboard.setContents(rewritten)
        hs.eventtap.keyStroke({ "cmd" }, "v")
        hs.timer.doAfter(0.6, function()
          if saved then hs.pasteboard.setContents(saved) end
        end)
        hs.alert.show("Rewritten ✓", 1)
      end,
      function(err)
        if saved then hs.pasteboard.setContents(saved) end
        notify(err)
      end)
  end)
end

function M.start()
  local cfg = readConfig()
  M.hotkey = hs.hotkey.bind(cfg.hotkeyMods, cfg.hotkeyKey, rewriteSelection)
  print("Gemini Rewrite loaded: " .. table.concat(cfg.hotkeyMods, "+")
      .. "+" .. cfg.hotkeyKey)
end

return M
