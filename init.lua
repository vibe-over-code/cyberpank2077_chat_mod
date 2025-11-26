local json_path = "data/dialog_map.json"

local lastJson = nil
local pendingJson = nil
local storageReady = false


--------------------------------------------------------------------
-- CLEANER: оставляет в тексте только JSON-блок между { ... }
--------------------------------------------------------------------
local function extract_json_block(s)
    if not s or s == "" then return "" end

    local first = s:find("{", 1, true)
    local last  = s:match(".*()}", 1) -- позиция последней "}"

    if not first or not last then
        return ""
    end

    return s:sub(first, last)
end


--------------------------------------------------------------------
-- JSON DECODER (СТАБИЛЬНЫЙ, РАБОТАЕТ СО ВСЕМИ GPT ВЫВОДАМИ)
--------------------------------------------------------------------
local function json_decode(str)
    str = extract_json_block(str)
    if str == "" then return nil end

    local pos = 1
    local len = #str

    local function skip()
        while pos <= len do
            local c = str:sub(pos,pos)
            if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
                pos = pos + 1
            else break end
        end
    end

    local function parse_string()
        pos = pos + 1
        local buf = {}

        while pos <= len do
            local c = str:sub(pos,pos)

            if c == '"' then
                pos = pos + 1
                return table.concat(buf)
            end

            if c == "\\" then
                local esc = str:sub(pos+1,pos+1)
                if esc == '"' then table.insert(buf, '"')
                elseif esc == "\\" then table.insert(buf, "\\")
                elseif esc == "/" then table.insert(buf, "/")
                elseif esc == "b" then table.insert(buf, "\b")
                elseif esc == "f" then table.insert(buf, "\f")
                elseif esc == "n" then table.insert(buf, "\n")
                elseif esc == "r" then table.insert(buf, "\r")
                elseif esc == "t" then table.insert(buf, "\t")
                elseif esc == "u" then
                    local code = str:sub(pos+2, pos+5)
                    table.insert(buf, "\\u"..code)
                    pos = pos + 4
                end
                pos = pos + 2
            else
                table.insert(buf, c)
                pos = pos + 1
            end
        end

        return table.concat(buf)
    end

    local function parse_number()
        local s = pos
        while pos <= len and str:sub(pos,pos):match("[0-9%+%-%.eE]") do
            pos = pos + 1
        end
        return tonumber(str:sub(s, pos-1))
    end

    local function parse_value()
        skip()
        if pos > len then return nil end

        local c = str:sub(pos,pos)

        if c == '"' then return parse_string() end

        if c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if str:sub(pos,pos) == "}" then
                pos = pos + 1
                return obj
            end
            while true do
                skip()
                local key = parse_value()
                skip()
                pos = pos + 1
                local val = parse_value()
                obj[key] = val
                skip()
                if str:sub(pos,pos) == "}" then
                    pos = pos + 1
                    break
                end
                pos = pos + 1
            end
            return obj
        end

        if c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if str:sub(pos,pos) == "]" then pos = pos + 1; return arr end
            while true do
                table.insert(arr, parse_value())
                skip()
                if str:sub(pos,pos) == "]" then
                    pos = pos + 1
                    break
                end
                pos = pos + 1
            end
            return arr
        end

        if c:match("[%d%-]") then
            return parse_number()
        end

        if str:sub(pos,pos+3) == "null"  then pos = pos+4 return nil end
        if str:sub(pos,pos+3) == "true"  then pos = pos+4 return true end
        if str:sub(pos,pos+4) == "false" then pos = pos+5 return false end

        return nil
    end

    return parse_value()
end


--------------------------------------------------------------------
-- Получение ChataiPhone.ChataiStorage (твоя redscript система)
--------------------------------------------------------------------
local function getStorage()
    local cont = Game.GetScriptableSystemsContainer()
    if not cont then return nil end
    return cont:Get("ChataiPhone.ChataiStorage")
end



--------------------------------------------------------------------
-- Отправка JSON → Redscript Storage
--------------------------------------------------------------------
local function sendToStorage(raw)
    local storage = getStorage()
    if not storage then
        print("[CHATAI] Storage not found!")
        return false
    end

    local data = json_decode(raw)
    if not data then
        print("[CHATAI] JSON decode failed")
        return false
    end

    -- NPC TEXT
    local npcText = data.npc_text or "Новое сообщение."
    storage:SetNpcText(npcText)

    storage:ClearReplies()

    -- REPLIES
    if data.replies then
        for _, r in ipairs(data.replies) do
            if r.id and r.text then
                storage:AddReply(r.id, r.text)
            end
        end
    end

    -- ANSWERS
    if data.answers then
        for idstr, text in pairs(data.answers) do
            local id = tonumber(idstr)
            if id and text then
                storage:AddAnswer(id, text)
            end
        end
    end

    storage:SetUnread(true)
    print("[CHATAI] JSON delivered → phone storage")

    -- Push notification to phone
    local game = Game.GetGame()
    if not game then return true end

    local player = Game.GetPlayer(game)
    if not player then return true end

    local contact = player:GetPhoneExtensionSystem():GetListener(76543210)
    if contact then
        contact:SendNotification(npcText)
        print("[CHATAI] Notification sent.")
    else
        print("[CHATAI] Contact not found yet.")
    end

    return true
end



--------------------------------------------------------------------
-- onUpdate: читаем JSON файл, обновляем телефон
--------------------------------------------------------------------
registerForEvent("onUpdate", function(delta)
    if not storageReady then
        local s = getStorage()
        if s then
            print("[CHATAI] Storage detected!")
            storageReady = true

            if pendingJson then
                sendToStorage(pendingJson)
                pendingJson = nil
            end
        end
    end

    local f = io.open(json_path, "r")
    if not f then return end
    local raw = f:read("*a")
    f:close()

    if raw and raw ~= "" and raw ~= lastJson then
        print("[CHATAI] JSON updated.")
        lastJson = raw

        if storageReady then
            sendToStorage(raw)
        else
            pendingJson = raw
            print("[CHATAI] Storage not ready → queued.")
        end
    end
end)
