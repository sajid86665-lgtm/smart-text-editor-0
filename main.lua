require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.graphics.*"
import "android.graphics.drawable.*"
import "android.media.*"
import "android.speech.tts.TextToSpeech"
import "android.speech.RecognizerIntent"
import "android.text.*"
import "android.text.style.BackgroundColorSpan"
import "java.io.File"
import "java.io.FileWriter"
import "java.lang.String"
import "java.util.Locale"
import "java.util.ArrayList"
import "java.util.HashMap"
import "android.view.WindowManager"
import "android.net.Uri"
import "android.text.TextWatcher"
import "android.webkit.WebView"
import "android.webkit.WebChromeClient"
import "android.webkit.WebViewClient"
import "android.widget.PopupMenu"
import "java.net.URL"
import "java.net.HttpURLConnection"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "java.net.URLEncoder"
import "java.lang.Thread"

-- ============================================================
-- NOTIFICATION TEXT – now a short, simple message
-- ============================================================
local NOTIFICATION_TEXT = "Hello friends, as you know, a few months ago, we released a form 📝, through which you could join our team. However, we have closed that form and created a new one 📄. If any of you are interested in joining our demat ad team, you can fill out this form and join us 🤝. We will contact you through the WhatsApp number or username you provide, and you will be added to our team 📲. Thank you     https://form.svhrt.com/6a461cc8e59fb36ceca67aa2"
-- ============================================================

local APP_NAME = "Smart Text Editor"
local DEV_NAME = "Accessible Resource"
local APP_VER = "2.3.0 Focus Optimized"

activity.setTitle(APP_NAME)
activity.setTheme(android.R.style.Theme_DeviceDefault_NoActionBar)
activity.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

local handler = Handler(Looper.getMainLooper())
local tts_engine
local toneGen
local REQ_CODE_SPEECH = 100
local config = { lang="en", theme=1, sound=true }
local recentFiles = {}

pcall(function() toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 80) end)

local THEMES = {
  {name="Ocean Breeze", bg=0xFFF0F8FF, text=0xFF003366, card=0xFFE6F2FF, primary=0xFF0066CC},
  {name="Night Owl", bg=0xFF011627, text=0xFFD6DEEB, card=0xFF0B2942, primary=0xFF82AAFF},
  {name="Coffee Bean", bg=0xFFECE0D1, text=0xFF38220F, card=0xFFDBC1AC, primary=0xFF967259},
  {name="Mint Minimal", bg=0xFFF5FFFA, text=0xFF2F4F4F, card=0xFFE0FFFF, primary=0xFF20B2AA},
  {name="Cherry Blossom", bg=0xFFFFF0F5, text=0xFF800000, card=0xFFFFE4E1, primary=0xFFDB7093},
  {name="Steel Matrix", bg=0xFF2B2B2B, text=0xFFA9B7C6, card=0xFF3C3F41, primary=0xFFCC7832},
  {name="True Black", bg=0xFF000000, text=0xFFFFFFFF, card=0xFF121212, primary=0xFFFFFFFF},
  {name="Sunny Day", bg=0xFFFFFFE0, text=0xFF8B4513, card=0xFFFFFACD, primary=0xFFDAA520},
  {name="Lavender Dream", bg=0xFFF8F8FF, text=0xFF4B0082, card=0xFFE6E6FA, primary=0xFF8A2BE2},
  {name="Abyss Blue", bg=0xFF000080, text=0xFFE0FFFF, card=0xFF0000CD, primary=0xFF00BFFF}
}

local app_desc_text = "An advanced, highly portable text and code editor for developers and writers. Features granular editing, real-time text analysis, and integrated web previews tailored for optimal productivity."

local L = {
  en = {
    welcome_title = APP_NAME,
    welcome_desc = app_desc_text,
    btn_exit = "EXIT APPLICATION",
    btn_contact = "DEVELOPER SUPPORT", 
    btn_editor = "LAUNCH WORKSPACE",
    btn_recent = "RECENT FILES",       
    btn_settings = "SETTINGS",
    btn_about = "ABOUT",
    head_title = "DOCUMENT TITLE",
    hint_title = "Untitled_Project",
    head_content = "EDITOR CANVAS",
    hint_content = "Begin typing your text or code here...",
    btn_save = "SAVE FILE",
    saved = "File Saved Successfully: ",
    settings_title = "SYSTEM CONFIGURATION",
    lbl_theme = "INTERFACE THEME",
    lbl_lang = "SYSTEM LANGUAGE",
    btn_save_cfg = "APPLY AND RESTART",
    btn_cancel = "DISMISS",
    msg_theme_applied = "Configuration Loaded Successfully!",
    voice_prompt = "Speak now to input text",
    btn_full_text = "FULL TEXT"
  }
}
L.bn = L.en
setmetatable(L.bn, {__index = L.en})

local showHome, showSettings, showEditor, contactDev, showAbout, showRecentFiles
local active_editor_field = nil

function getStr(key) return L[config.lang][key] or L.en[key] end
function getTheme() return THEMES[config.theme] or THEMES[1] end
function runOnUiThread(func) handler.post(Runnable({ run = func })) end
function playClick() if config.sound and toneGen then pcall(function() toneGen.startTone(ToneGenerator.TONE_PROP_BEEP, 50) end) end end

function hideKeyboard(view)
  pcall(function()
    local imm = activity.getSystemService(Context.INPUT_METHOD_SERVICE)
    imm.hideSoftInputFromWindow(view.getWindowToken(), 0)
  end)
end

function escape_magic(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")) end

function loadRecentFiles()
  local path = activity.getExternalFilesDir(nil).toString() .. "/recent.cfg"
  local f = File(path)
  recentFiles = {}
  if f.exists() then 
     local content = io.open(path, "r"):read("*a")
     for line in content:gmatch("[^\r\n]+") do
        table.insert(recentFiles, line)
     end
  end
end

function addRecentFile(filePath)
  for i, v in ipairs(recentFiles) do
     if v == filePath then table.remove(recentFiles, i) break end
  end
  table.insert(recentFiles, 1, filePath)
  while #recentFiles > 10 do table.remove(recentFiles) end
  local path = activity.getExternalFilesDir(nil).toString() .. "/recent.cfg"
  local fw = FileWriter(File(path))
  for i, v in ipairs(recentFiles) do fw.write(v.."\n") end
  fw.close()
end

function loadConfig()
  local path = activity.getExternalFilesDir(nil).toString() .. "/settings_v2.cfg"
  local f = File(path)
  if f.exists() then 
     local content = io.open(path, "r"):read("*a")
     for line in content:gmatch("[^\r\n]+") do
        local k, v = line:match("(%w+)=(%w+)")
        if k == "lang" then config.lang = v 
        elseif k == "theme" then config.theme = tonumber(v)
        elseif k == "sound" then config.sound = (v == "true") end
     end
  end
  pcall(function()
     local loc = Locale(config.lang)
     Locale.setDefault(loc)
     local r = activity.getResources()
     local cfg = r.getConfiguration()
     cfg.locale = loc
     r.updateConfiguration(cfg, r.getDisplayMetrics())
  end)
end

function saveConfig()
  local path = activity.getExternalFilesDir(nil).toString() .. "/settings_v2.cfg"
  local data = "lang="..config.lang.."\ntheme="..config.theme.."\nsound="..tostring(config.sound)
  local f = FileWriter(File(path))
  f.write(data)
  f.close()
end

function speakSmart(text)
  if not tts_engine then return end
  local jText = String(text)
  if jText.matches(".*[\\u0980-\\u09FF].*") then
     tts_engine.setLanguage(Locale("bn"))
  else
     tts_engine.setLanguage(Locale("en"))
  end
  tts_engine.speak(text, TextToSpeech.QUEUE_FLUSH, nil)
end

function startVoiceInput(field)
  active_editor_field = field
  local intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
  intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
  intent.putExtra(RecognizerIntent.EXTRA_PROMPT, getStr("voice_prompt"))
  pcall(function() activity.startActivityForResult(intent, REQ_CODE_SPEECH) end)
end

function onActivityResult(requestCode, resultCode, data)
  if resultCode == activity.RESULT_OK and data then
    if requestCode == REQ_CODE_SPEECH then
      local result = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
      if result and result.size() > 0 then
         local text = result.get(0)
         if active_editor_field then
            local current = active_editor_field.getText()
            local pos = active_editor_field.getSelectionStart()
            if pos < 0 then pos = current.length() end
            current.insert(pos, " " .. text)
         end
      end
    end
  end
end

function runHTML(htmlContent)
  playClick()
  local thm = getTheme()
  local ids = {}
  local layout = {
    LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill", backgroundColor=0xFFFFFFFF,
    { LinearLayout, orientation="horizontal", backgroundColor=thm.primary, padding="10dp",
      { TextView, text="HTML PREVIEW", textColor=0xFFFFFFFF, textSize="16sp", layout_weight=1, typeface=Typeface.DEFAULT_BOLD },
      { Button, text="CLOSE PREVIEW", id="btn_close_web", backgroundColor=0xFFF44336, textColor=0xFFFFFFFF }
    },
    { WebView, id="webview", layout_width="fill", layout_height="fill" }
  }
  local d = Dialog(activity, android.R.style.Theme_DeviceDefault_NoActionBar_Fullscreen)
  d.setContentView(loadlayout(layout, ids))
  ids.webview.getSettings().setJavaScriptEnabled(true)
  ids.webview.setWebChromeClient(WebChromeClient())
  ids.webview.setWebViewClient(WebViewClient())
  ids.webview.loadDataWithBaseURL(nil, htmlContent, "text/html", "UTF-8", nil)
  ids.btn_close_web.setOnClickListener(View.OnClickListener{ onClick = function() d.dismiss() end })
  d.show()
end

function showTokenList(tokens, typeIdx, editTextRef, undoStack, redoStack, thm)
  local adapter = ArrayAdapter(activity, android.R.layout.simple_list_item_1, tokens)
  local lv = ListView(activity)
  lv.setBackgroundColor(thm.card)
  lv.setAdapter(adapter)
  local b = AlertDialog.Builder(activity)
  b.setTitle("MODIFY SELECTION")
  b.setView(lv)
  lv.setOnItemClickListener(AdapterView.OnItemClickListener{
     onItemClick = function(p,v,pos,id)
        local input = EditText(activity)
        input.setText(tokens[pos+1])
        input.setTextColor(thm.text)
        local editB = AlertDialog.Builder(activity)
        editB.setTitle("EDIT ELEMENT")
        editB.setView(input)
        editB.setPositiveButton("UPDATE", function()
            tokens[pos+1] = input.getText().toString()
            adapter.clear()
            for _, item in ipairs(tokens) do adapter.add(item) end
            adapter.notifyDataSetChanged()
         end)
        editB.show()
     end
  })
  b.setPositiveButton("APPLY CHANGES", function()
      local sep = ""
      if typeIdx==1 then sep=" " elseif typeIdx==2 then sep="\n" elseif typeIdx==3 then sep="\n\n" end
      local newText = table.concat(tokens, sep)
      if editTextRef.getText().toString() ~= newText then
           table.insert(undoStack, editTextRef.getText().toString())
           if #undoStack > 50 then table.remove(undoStack, 1) end
           for k in pairs(redoStack) do redoStack[k] = nil end
           editTextRef.setText(newText)
           Toast.makeText(activity, "TEXT UPDATED", 0).show()
      end
  end)
  b.setNegativeButton("BACK", nil)
  b.show()
end

showSettings = function()
  playClick()
  local thm = getTheme()
  local ids = {}
  local langCodes = {"en", "bn"}
  local themeList = {}
  for k,v in ipairs(THEMES) do table.insert(themeList, v.name) end
  local layout = {
    ScrollView, layout_width="fill", backgroundColor=thm.bg,
    { LinearLayout, orientation="vertical", padding="20dp",
      { TextView, text=getStr("settings_title"), textSize="22sp", textColor=thm.primary, typeface=Typeface.DEFAULT_BOLD, layout_marginBottom="20dp" },
      { TextView, text=getStr("lbl_theme"), textColor=thm.text, layout_marginBottom="5dp" },
      { Spinner, id="spin_theme", layout_width="fill", layout_marginBottom="20dp", backgroundColor=thm.card },
      { TextView, text=getStr("lbl_lang"), textColor=thm.text, layout_marginBottom="5dp" },
      { Spinner, id="spin_lang", layout_width="fill", layout_marginBottom="20dp", backgroundColor=thm.card },
      { CheckBox, id="chk_snd", text="SYSTEM SOUNDS", checked=config.sound, textColor=thm.text, layout_marginBottom="30dp" },
      { LinearLayout, orientation="horizontal",
        { Button, text=getStr("btn_save_cfg"), id="btn_save", layout_weight=1, backgroundColor=thm.primary, textColor=0xFFFFFFFF },
        { View, layout_width="10dp" },
        { Button, text=getStr("btn_cancel"), id="btn_cancel", layout_weight=1, backgroundColor=0xFF757575, textColor=0xFFFFFFFF }
      }
    }
  }
  local b = AlertDialog.Builder(activity)
  b.setView(loadlayout(layout, ids))
  local d = b.create()
  ids.spin_theme.setAdapter(ArrayAdapter(activity, android.R.layout.simple_list_item_1, themeList))
  ids.spin_theme.setSelection(config.theme - 1)
  ids.spin_lang.setAdapter(ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, {"English", "Bengali"}))
  for i,v in ipairs(langCodes) do if v == config.lang then ids.spin_lang.setSelection(i-1) end end
  ids.btn_save.setOnClickListener(View.OnClickListener{ onClick = function()
      config.theme = ids.spin_theme.getSelectedItemPosition() + 1
      config.lang = langCodes[ids.spin_lang.getSelectedItemPosition() + 1]
      config.sound = ids.chk_snd.isChecked()
      saveConfig()
      d.dismiss()
      Toast.makeText(activity, getStr("msg_theme_applied"), 0).show()
      showEditor()
   end })
  ids.btn_cancel.setOnClickListener(View.OnClickListener{ onClick = function() d.dismiss() end })
  d.show()
end

showAbout = function()
  playClick()
  local thm = getTheme()
  local ids = {}
  local layout = {
    ScrollView, layout_width="fill", backgroundColor=thm.bg,
    { LinearLayout, orientation="vertical", padding="20dp",
      { TextView, text=APP_NAME, textSize="22sp", typeface=Typeface.DEFAULT_BOLD, textColor=thm.primary, gravity="center", layout_marginBottom="5dp" },
      { TextView, text="VERSION: " .. APP_VER, textSize="14sp", textColor=thm.text, gravity="center", layout_marginBottom="20dp" },
      { TextView, text=getStr("welcome_desc"), textSize="14sp", textColor=thm.text, gravity="center", layout_marginBottom="30dp" },
      { Button, text="CONTACT DEVELOPER", onClick=function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/9118141191"))) end, backgroundColor=0xFF25D366, textColor=0xFFFFFFFF, layout_width="fill", layout_marginBottom="10dp" },
      { Button, text="SUBSCRIBE ON YOUTUBE", onClick=function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@blindtechhub-p2s?si=ojpWK5jj7tL_dXTK"))) end, backgroundColor=0xFFFF0000, textColor=0xFFFFFFFF, layout_width="fill", layout_marginBottom="10dp" },
      { Button, text="CLOSE WINDOW", id="btn_close_about", backgroundColor=0xFF757575, textColor=0xFFFFFFFF, layout_width="fill", layout_marginTop="10dp" }
    }
  }
  local b = AlertDialog.Builder(activity)
  b.setView(loadlayout(layout, ids))
  local d = b.create()
  ids.btn_close_about.setOnClickListener(View.OnClickListener{ onClick = function() d.dismiss() end })
  d.show()
end

contactDev = function()
  playClick()
  activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/9118141191")))
end

showRecentFiles = function()
  playClick()
  local thm = getTheme()
  if #recentFiles == 0 then
     Toast.makeText(activity, "NO RECENT FILES FOUND", 0).show()
     return
  end
  local displayNames = {}
  for i, path in ipairs(recentFiles) do
     local f = File(path)
     table.insert(displayNames, f.getName())
  end
  local adapter = ArrayAdapter(activity, android.R.layout.simple_list_item_1, displayNames)
  local lv = ListView(activity)
  lv.setBackgroundColor(thm.card)
  lv.setAdapter(adapter)
  local b = AlertDialog.Builder(activity)
  b.setTitle("RECENTLY EDITED FILES")
  b.setView(lv)
  local d = b.create()
  lv.setOnItemClickListener(AdapterView.OnItemClickListener{
     onItemClick = function(p,v,pos,id)
        d.dismiss()
        local filePath = recentFiles[pos+1]
        local f = File(filePath)
        if f.exists() then
           local content = io.open(filePath, "r"):read("*a")
           local title = f.getName():gsub("%.[^%.]+$", "")
           showEditor(title, content)
        else
           Toast.makeText(activity, "FILE NO LONGER EXISTS", 0).show()
        end
     end
  })
  d.show()
end

showEditor = function(initTitle, initContent)
  playClick()
  local thm = getTheme()
  local ids = {}
  local undoStack = {}
  local redoStack = {}
  local isSystemChange = false
  local isTokenMode = false

  local function applyFormatting(markerOpen, markerClose)
    local edit = ids.et_content
    local selStart = edit.getSelectionStart()
    local selEnd = edit.getSelectionEnd()
    local text = edit.getText().toString()
    if selStart == selEnd then
      local cursor = selStart
      local newText = text:sub(1, cursor) .. markerOpen .. markerClose .. text:sub(cursor+1)
      edit.setText(newText)
      edit.setSelection(cursor + #markerOpen, cursor + #markerOpen)
    else
      local selected = text:sub(selStart+1, selEnd)
      local newText = text:sub(1, selStart) .. markerOpen .. selected .. markerClose .. text:sub(selEnd+1)
      edit.setText(newText)
      edit.setSelection(selStart + #markerOpen, selEnd + #markerOpen)
    end
  end

  local function performSave()
      playClick()
      local title = ids.et_title.getText().toString()
      local text = ids.et_content.getText().toString()
      if #text == 0 then Toast.makeText(activity, "ERROR: CONTENT IS EMPTY", 0).show() return end
      if #title == 0 then title = "Untitled_Project" end
      title = title:gsub("[^%w%-_]", "")
      local dir = File(Environment.getExternalStorageDirectory(), "blind Tech hub/smart text editor")
      dir.mkdirs()
      local fmtAdapter = ids.spin_fmt.getAdapter()
      local ext = fmtAdapter.getItem(ids.spin_fmt.getSelectedItemPosition())
      local file = File(dir, title..ext)
      pcall(function()
         local fw = FileWriter(file)
         fw.write(text)
         fw.close()
         addRecentFile(file.getAbsolutePath())
         Toast.makeText(activity, getStr("saved") .. "\n" .. file.getPath(), 1).show()
         speakSmart("File saved successfully")
      end)
  end

  local function normalizeText()
    local text = ids.et_content.getText().toString()
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("\n\n\n+", "\n\n")
    text = text:gsub("([.!?]%s+)(%l)", function(p, c) return p .. c:upper() end)
    text = text:gsub("^(%l)", string.upper)
    ids.et_content.setText(text)
    Toast.makeText(activity, "Text normalized", 0).show()
  end

  local function removeContactInfo()
    local text = ids.et_content.getText().toString()
    local phones = {}
    local emails = {}
    for phone in text:gmatch("%+?%d[%d%-%s]+%d") do
      local cleaned = phone:gsub("[%s%-]", "")
      if cleaned:match("^%+?91%d%d%d%d%d%d%d%d%d%d$") or cleaned:match("^%d%d%d%d%d%d%d%d%d%d$") then
        table.insert(phones, phone)
      end
    end
    for email in text:gmatch("[%w%.%%%+%-]+@[%w%.%-]+%.%w+") do
      table.insert(emails, email)
    end
    if #phones == 0 and #emails == 0 then
      Toast.makeText(activity, "No phone numbers or emails found", 0).show()
      return
    end
    local items = {}
    for _, p in ipairs(phones) do table.insert(items, "📞 " .. p) end
    for _, e in ipairs(emails) do table.insert(items, "✉️ " .. e) end
    local adapter = ArrayAdapter(activity, android.R.layout.simple_list_item_1, items)
    local lv = ListView(activity)
    lv.setAdapter(adapter)
    lv.setBackgroundColor(thm.card)
    local b = AlertDialog.Builder(activity)
    b.setTitle("CONTACT INFORMATION FOUND")
    b.setView(lv)
    b.setPositiveButton("DELETE ALL", function()
      local newText = text
      for _, p in ipairs(phones) do
        newText = newText:gsub(p, "")
      end
      for _, e in ipairs(emails) do
        newText = newText:gsub(e, "")
      end
      newText = newText:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      ids.et_content.setText(newText)
      Toast.makeText(activity, "All contact info removed", 0).show()
    end)
    b.setNegativeButton("CANCEL", nil)
    b.show()
  end

  local function openExtraTools()
      playClick()
      local layout = {
        LinearLayout, orientation="vertical", padding="20dp", backgroundColor=thm.bg, gravity="center",
        { TextView, text="TOOLS", textSize="20sp", textColor=thm.primary, typeface=Typeface.DEFAULT_BOLD, gravity="center", layout_marginBottom="20dp" },
        { Button, text="FORMATTER", id="btn_format_tool", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFF9C27B0, textColor=0xFFFFFFFF, textSize="16sp" },
        { Button, text="ANALYSER", id="btn_analyser_tool", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFFFF9800, textColor=0xFFFFFFFF, textSize="16sp" },
        { Button, text="GLOBAL REPLACE", id="btn_global_replace", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFF3F51B5, textColor=0xFFFFFFFF, textSize="16sp" },
        { Button, text="TEXT FORMATTING", id="btn_formatting_tool", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFF607D8B, textColor=0xFFFFFFFF, textSize="16sp" },
        { Button, text="NORMALIZE TEXT", id="btn_normalize", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFF4CAF50, textColor=0xFFFFFFFF, textSize="16sp" },
        { Button, text="REMOVE NUMBERS & EMAILS", id="btn_remove_contacts", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFFE91E63, textColor=0xFFFFFFFF, textSize="16sp" },
        { Button, text="CLOSE", id="btn_close_tools", layout_width="fill", backgroundColor=0xFF757575, textColor=0xFFFFFFFF }
      }
      local b = AlertDialog.Builder(activity)
      local ids2 = {}
      b.setView(loadlayout(layout, ids2))
      local d = b.create()

      ids2.btn_format_tool.setOnClickListener(View.OnClickListener{ onClick = function()
            local fLayout = {
              ScrollView, layout_width="fill", backgroundColor=thm.bg,
              { LinearLayout, orientation="vertical", padding="15dp",
                { Button, text="FORMAT UPPERCASE", id="btn_up", layout_width="fill", layout_marginBottom="10dp", backgroundColor=thm.card, textColor=thm.text },
                { Button, text="FORMAT LOWERCASE", id="btn_low", layout_width="fill", layout_marginBottom="10dp", backgroundColor=thm.card, textColor=thm.text },
                { Button, text="FORMAT CAPITALIZE", id="btn_cap", layout_width="fill", layout_marginBottom="10dp", backgroundColor=thm.card, textColor=thm.text },
                { Button, text="CLOSE FORMATTER", id="btn_cls", layout_width="fill", layout_marginTop="10dp", backgroundColor=0xFFF44336, textColor=0xFFFFFFFF }
              }
            }
            local fb = AlertDialog.Builder(activity)
            local fIds = {}
            fb.setView(loadlayout(fLayout, fIds))
            local fd = fb.create()
            local function applyFormat(func)
               local old = ids.et_content.getText().toString()
               local newT = func(old)
               table.insert(undoStack, old)
               if #undoStack > 50 then table.remove(undoStack, 1) end
               for k in pairs(redoStack) do redoStack[k] = nil end
               ids.et_content.setText(newT)
               fd.dismiss()
            end
            fIds.btn_up.setOnClickListener(View.OnClickListener{ onClick = function() applyFormat(string.upper) end })
            fIds.btn_low.setOnClickListener(View.OnClickListener{ onClick = function() applyFormat(string.lower) end })
            fIds.btn_cap.setOnClickListener(View.OnClickListener{ onClick = function() applyFormat(function(str) return str:gsub("(%w)(%w*)", function(f, r) return f:upper()..r:lower() end) end) end })
            fIds.btn_cls.setOnClickListener(View.OnClickListener{ onClick = function() fd.dismiss() end })
            fd.show()
      end })

      ids2.btn_analyser_tool.setOnClickListener(View.OnClickListener{ onClick = function()
            local tLayout = {
              ScrollView, layout_width="fill", backgroundColor=thm.bg,
              { LinearLayout, orientation="vertical", padding="15dp",
                { TextView, id="tv_full_stats", text="LOADING STATS...", textSize="16sp", textColor=thm.text, layout_marginBottom="20dp" },
                { Button, text="CLOSE ANALYSER", id="btn_cls", layout_width="fill", layout_marginTop="10dp", backgroundColor=0xFFF44336, textColor=0xFFFFFFFF }
              }
            }
            local tb = AlertDialog.Builder(activity)
            local tIds = {}
            tb.setView(loadlayout(tLayout, tIds))
            local td = tb.create()
            local textToAnalyse = ids.et_content.getText().toString()
            local s = tostring(textToAnalyse)
            local chars = #s
            local _, words = s:gsub("%S+", "")
            local _, lines = s:gsub("\n", "")
            if chars > 0 then lines = lines + 1 else lines = 0 end
            local _, paras = s:gsub("\n\n+", "")
            if chars > 0 then paras = paras + 1 else paras = 0 end
            local _, symbols = s:gsub("[%p]", "")
            local _, headings = s:gsub("\n#", "")
            local _, html_headings = s:gsub("<h[1-6]", "")
            headings = headings + html_headings
            if s:match("^#") then headings = headings + 1 end
            tIds.tv_full_stats.setText(string.format("Chars: %d | Words: %d | Lines: %d | Paras: %d | Symbols: %d | Headings: %d", chars, words, lines, paras, symbols, headings))
            tIds.btn_cls.setOnClickListener(View.OnClickListener{ onClick = function() td.dismiss() end })
            td.show()
      end })

      ids2.btn_global_replace.setOnClickListener(View.OnClickListener{ onClick = function()
            local subLayout = {
              LinearLayout, orientation="vertical", padding="15dp", backgroundColor=thm.bg,
              { TextView, text="GLOBAL REPLACE", textSize="18sp", textColor=thm.primary, typeface=Typeface.DEFAULT_BOLD, gravity="center", layout_marginBottom="15dp" },
              { EditText, id="et_find_sub", hint="FIND STRING", backgroundColor=thm.card, textColor=thm.text, hintTextColor=0xFF999999, singleLine=true, layout_marginBottom="10dp" },
              { EditText, id="et_rep_sub", hint="REPLACE STRING", backgroundColor=thm.card, textColor=thm.text, hintTextColor=0xFF999999, singleLine=true, layout_marginBottom="15dp" },
              { Button, text="EXECUTE REPLACE", id="btn_exec_rep", backgroundColor=thm.primary, textColor=0xFFFFFFFF, layout_width="fill" }
            }
            local sb = AlertDialog.Builder(activity)
            local sIds = {}
            sb.setView(loadlayout(subLayout, sIds))
            local sd = sb.create()
            sIds.btn_exec_rep.setOnClickListener(View.OnClickListener{ onClick = function()
                  local find = sIds.et_find_sub.getText().toString()
                  local rep = sIds.et_rep_sub.getText().toString()
                  if #find > 0 then
                     local old = ids.et_content.getText().toString()
                     local newT = old:gsub(escape_magic(find), rep)
                     table.insert(undoStack, old)
                     if #undoStack > 50 then table.remove(undoStack, 1) end
                     for k in pairs(redoStack) do redoStack[k] = nil end
                     ids.et_content.setText(newT)
                     Toast.makeText(activity, "REPLACE COMPLETED", 0).show()
                     sd.dismiss()
                  else
                     Toast.makeText(activity, "Enter a string to find", 0).show()
                  end
            end })
            sd.show()
      end })

      ids2.btn_formatting_tool.setOnClickListener(View.OnClickListener{ onClick = function()
            local fLayout = {
              LinearLayout, orientation="vertical", padding="15dp", backgroundColor=thm.bg, gravity="center",
              { TextView, text="TEXT FORMATTING", textSize="18sp", textColor=thm.primary, typeface=Typeface.DEFAULT_BOLD, gravity="center", layout_marginBottom="15dp" },
              { Button, text="Bold", id="btn_bold", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFF607D8B, textColor=0xFFFFFFFF, textSize="16sp" },
              { Button, text="Italic", id="btn_italic", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFF607D8B, textColor=0xFFFFFFFF, textSize="16sp" },
              { Button, text="Underline", id="btn_underline", layout_width="fill", layout_marginBottom="10dp", backgroundColor=0xFF607D8B, textColor=0xFFFFFFFF, textSize="16sp" },
              { Button, text="CLOSE", id="btn_cls_fmt", layout_width="fill", backgroundColor=0xFF757575, textColor=0xFFFFFFFF }
            }
            local fb = AlertDialog.Builder(activity)
            local fIds = {}
            fb.setView(loadlayout(fLayout, fIds))
            local fd = fb.create()
            fIds.btn_bold.setOnClickListener(View.OnClickListener{ onClick = function() applyFormatting("**", "**"); fd.dismiss() end })
            fIds.btn_italic.setOnClickListener(View.OnClickListener{ onClick = function() applyFormatting("*", "*"); fd.dismiss() end })
            fIds.btn_underline.setOnClickListener(View.OnClickListener{ onClick = function() applyFormatting("__", "__"); fd.dismiss() end })
            fIds.btn_cls_fmt.setOnClickListener(View.OnClickListener{ onClick = function() fd.dismiss() end })
            fd.show()
      end })

      ids2.btn_normalize.setOnClickListener(View.OnClickListener{ onClick = function()
            normalizeText()
            d.dismiss()
      end })

      ids2.btn_remove_contacts.setOnClickListener(View.OnClickListener{ onClick = function()
            removeContactInfo()
            d.dismiss()
      end })

      ids2.btn_close_tools.setOnClickListener(View.OnClickListener{ onClick = function() d.dismiss() end })
      d.show()
  end

  -- Top bar: APP_NAME and MENU only
  local topBar = {
    LinearLayout, orientation="horizontal", layout_width="fill", backgroundColor=thm.primary, padding="10dp", gravity="center_vertical",
    { TextView, text=APP_NAME, textSize="18sp", textColor=0xFFFFFFFF, typeface=Typeface.DEFAULT_BOLD, layout_weight=1 },
    { Button, id="btn_menu", text="MENU", textSize="14sp", textColor=0xFFFFFFFF, backgroundColor=Color.TRANSPARENT, padding="5dp" }
  }

  -- Notification banner – now with a short, simple message
  local notificationBanner = {
    TextView, text=NOTIFICATION_TEXT, textSize="14sp", textColor=0xFFFFFFFF, backgroundColor=0xFFE91E63, padding="10dp", layout_width="fill", gravity="center"
  }

  local layout = {
    LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill", backgroundColor=thm.bg,
    topBar,
    notificationBanner,
    { ScrollView, layout_width="fill", layout_height="fill", fillViewport=true,
      { LinearLayout, orientation="vertical", layout_width="fill", layout_height="wrap_content", padding="15dp",
        { LinearLayout, orientation="horizontal", layout_marginBottom="10dp", layout_width="fill",
            { Button, text="UNDO ACTION", id="btn_undo", layout_weight=1, backgroundColor=0xFF607D8B, textColor=0xFFFFFFFF, layout_marginRight="2dp" },
            { Button, text="REDO ACTION", id="btn_redo", layout_weight=1, backgroundColor=0xFF607D8B, textColor=0xFFFFFFFF, layout_marginLeft="2dp" },
        },
        { TextView, text=getStr("head_title"), textSize="14sp", typeface=Typeface.DEFAULT_BOLD, textColor=thm.text },
        { EditText, id="et_title", hint=getStr("hint_title"), hintTextColor=0xFF999999, text=initTitle or "", singleLine=true, layout_marginBottom="10dp", backgroundColor=thm.card, textColor=thm.text, padding="10dp", layout_width="fill" },
        { TextView, text="FILE FORMAT", textSize="14sp", typeface=Typeface.DEFAULT_BOLD, textColor=thm.text, layout_marginBottom="5dp" },
        { Spinner, id="spin_fmt", layout_width="fill", layout_marginBottom="10dp", backgroundColor=thm.card },
        { Button, text="VOICE INPUT", onClick=function() startVoiceInput(ids.et_content) end, backgroundColor=thm.primary, textColor=0xFFFFFFFF, layout_width="fill", layout_marginBottom="10dp" },
        { TextView, text=getStr("head_content"), textSize="14sp", typeface=Typeface.DEFAULT_BOLD, textColor=thm.text, layout_marginBottom="5dp" },
        { EditText, id="et_content", focusable=true, focusableInTouchMode=true, hint=getStr("hint_content"), hintTextColor=0xFF999999, text=initContent or "", gravity="top", layout_width="fill", layout_height="wrap_content", minLines=12, backgroundColor=thm.card, textColor=thm.text, padding="10dp" },
        { Button, text=getStr("btn_full_text"), id="btn_full_text", layout_width="fill", layout_marginTop="5dp", layout_marginBottom="5dp", backgroundColor=0xFF4CAF50, textColor=0xFFFFFFFF },
        { Button, text="CHARACTER EDIT", id="btn_char", layout_width="fill", layout_marginBottom="5dp", backgroundColor=thm.card, textColor=thm.text },
        { Button, text="WORD EDIT", id="btn_word", layout_width="fill", layout_marginBottom="5dp", backgroundColor=thm.card, textColor=thm.text },
        { Button, text="LINE EDIT", id="btn_line", layout_width="fill", layout_marginBottom="5dp", backgroundColor=thm.card, textColor=thm.text },
        { Button, text="PARAGRAPH EDIT", id="btn_para", layout_width="fill", layout_marginBottom="5dp", backgroundColor=thm.card, textColor=thm.text },
        { Button, text="HIDE KEYBOARD", onClick=function() hideKeyboard(ids.et_content) end, layout_width="fill", layout_marginBottom="5dp", backgroundColor=0xFFB0BEC5, textColor=0xFFFFFFFF },
        { LinearLayout, id="ll_code_actions", orientation="horizontal", gravity="center_vertical", layout_marginTop="10dp", layout_width="fill",
          { Button, id="btn_run_html", text="RUN HTML", onClick=function() runHTML(ids.et_content.getText().toString()) end, backgroundColor=0xFF4CAF50, textColor=0xFFFFFFFF, layout_width="fill" }
        },
        { Button, text="OPEN TOOLS", id="btn_open_tool", layout_width="fill", layout_marginTop="10dp", backgroundColor=0xFF3F51B5, textColor=0xFFFFFFFF },
        { Button, text="SAVE DOCUMENT", id="btn_save_text", onClick=function() performSave() end, backgroundColor=thm.primary, textColor=0xFFFFFFFF, layout_marginTop="10dp", layout_width="fill" },
        { Button, text=getStr("btn_exit"), onClick=function() activity.finishAffinity() end, backgroundColor=0xFFF44336, textColor=0xFFFFFFFF, layout_marginTop="10dp", layout_width="fill" }
      }
    }
  }

  local view = loadlayout(layout, ids)
  active_editor_field = ids.et_content

  local fmtAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, {
    ".txt", ".docx", ".pdf", ".rtf", ".md", ".xml", ".csv", ".json", ".lua", ".html", ".css", ".js"
  })
  ids.spin_fmt.setAdapter(fmtAdapter)

  local function updateContextUI()
      local selected = ids.spin_fmt.getSelectedItemPosition()
      if selected == 9 then  -- .html
         ids.ll_code_actions.setVisibility(View.VISIBLE)
         ids.btn_run_html.setVisibility(View.VISIBLE)
      else
         ids.ll_code_actions.setVisibility(View.GONE)
         ids.btn_run_html.setVisibility(View.GONE)
      end
  end

  ids.spin_fmt.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{ onItemSelected = function() updateContextUI() end })
  updateContextUI()

  ids.btn_undo.setOnClickListener(View.OnClickListener{ onClick = function()
      if #undoStack > 0 then
        isSystemChange = true
        local lastState = table.remove(undoStack)
        table.insert(redoStack, ids.et_content.getText().toString())
        ids.et_content.setText(lastState)
        ids.et_content.setSelection(#lastState)
        isSystemChange = false
      end
  end })
  ids.btn_redo.setOnClickListener(View.OnClickListener{ onClick = function()
      if #redoStack > 0 then
        isSystemChange = true
        local nextState = table.remove(redoStack)
        table.insert(undoStack, ids.et_content.getText().toString())
        ids.et_content.setText(nextState)
        ids.et_content.setSelection(#nextState)
        isSystemChange = false
      end
  end })

  ids.btn_char.setOnClickListener(View.OnClickListener{ onClick = function()
      local text = ids.et_content.getText().toString()
      local tokens = {}
      for s in text:gmatch(".") do table.insert(tokens, s) end
      showTokenList(tokens, 0, ids.et_content, undoStack, redoStack, thm)
  end })
  ids.btn_word.setOnClickListener(View.OnClickListener{ onClick = function()
      local text = ids.et_content.getText().toString()
      local tokens = {}
      for s in text:gmatch("[^%s]+") do table.insert(tokens, s) end
      showTokenList(tokens, 1, ids.et_content, undoStack, redoStack, thm)
  end })
  ids.btn_line.setOnClickListener(View.OnClickListener{ onClick = function()
      local text = ids.et_content.getText().toString()
      local tokens = {}
      for s in text:gmatch("[^\n]+") do table.insert(tokens, s) end
      showTokenList(tokens, 2, ids.et_content, undoStack, redoStack, thm)
  end })
  ids.btn_para.setOnClickListener(View.OnClickListener{ onClick = function()
      local text = ids.et_content.getText().toString()
      local tokens = {}
      local p = ""
      for line in text:gmatch("([^\n]*)\n?") do
          if line == "" then
              if p ~= "" then table.insert(tokens, p) p = "" end
          else
              p = p .. line .. "\n"
          end
      end
      if p ~= "" then table.insert(tokens, p) end
      showTokenList(tokens, 3, ids.et_content, undoStack, redoStack, thm)
  end })

  ids.btn_full_text.setOnClickListener(View.OnClickListener{ onClick = function()
      if isTokenMode then
        isTokenMode = false
        Toast.makeText(activity, "Returned to full text mode", 0).show()
      else
        Toast.makeText(activity, "Already in full text mode", 0).show()
      end
  end })

  ids.btn_open_tool.setOnClickListener(View.OnClickListener{ onClick = function() openExtraTools() end })

  ids.btn_menu.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local popup = PopupMenu(activity, v)
      local menu = popup.getMenu()
      menu.add(0, 1, 0, getStr("btn_recent"))
      menu.add(0, 2, 0, getStr("btn_settings"))
      menu.add(0, 3, 0, getStr("btn_about"))
      menu.add(0, 4, 0, getStr("btn_contact"))
      popup.setOnMenuItemClickListener(PopupMenu.OnMenuItemClickListener{
        onMenuItemClick = function(item)
          local id = item.getItemId()
          if id == 1 then showRecentFiles()
          elseif id == 2 then showSettings()
          elseif id == 3 then showAbout()
          elseif id == 4 then contactDev() end
          return true
        end
      })
      popup.show()
    end
  })

  ids.et_content.addTextChangedListener(TextWatcher{
    beforeTextChanged = function(s, start, count, after)
      if not isSystemChange then
         table.insert(undoStack, s.toString())
         if #undoStack > 50 then table.remove(undoStack, 1) end
         for k in pairs(redoStack) do redoStack[k] = nil end
      end
    end,
    onTextChanged = function(s, start, before, count)
        -- no stats
    end
  })

  activity.setContentView(view)
end

loadConfig()
loadRecentFiles()
tts_engine = TextToSpeech(activity, TextToSpeech.OnInitListener({
  onInit = function(status)
    if status == TextToSpeech.SUCCESS then
      pcall(function() tts_engine.setLanguage(Locale(config.lang)) end)
    end
  end
}))
showEditor()