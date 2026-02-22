local json_path = "data/dialog_map.json"
local generator_bat = "run_generator.bat"

local lastJson = nil
local pendingJson = nil
local storageReady = false

local last_msg_id = nil -- защита от повторных уведомлений


--------------------------------------------------------------------
-- AUTORUN GENERATOR VIA BAT
--------------------------------------------------------------------
local function launch_generator()
    if is_launched then return end
    
    print("[CHATAI] Attempting to launch generator via .bat...")
    
    -- В CET os.execute часто заблокирован. 
    -- Используем pcall, чтобы игра не вылетала, если метод недоступен
    pcall(function()
        -- Мы используем команду 'start', чтобы запустить батник и сразу забыть о нем
        -- Это не блокирует поток игры
        os.execute('start "" "' .. generator_bat .. '"')
    end)
    
    is_launched = true
end


--------------------------------------------------------------------
-- CLEANER: оставляет только JSON-блок { ... }
--------------------------------------------------------------------
local function extract_json_block(s)
    if not s or s == "" then return "" end

    local first = s:find("{", 1, true)
    local last  = s:match(".*()}", 1)

    if not first or not last then return "" end
    return s:sub(first, last)
end


--------------------------------------------------------------------
-- JSON DECODER
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
            elseif c == "\\" then
                local esc = str:sub(pos+1,pos+1)
                if esc == '"' then table.insert(buf,'"')
                elseif esc == "\\" then table.insert(buf,"\\")
                elseif esc == "n" then table.insert(buf,"\n")
                elseif esc == "t" then table.insert(buf,"\t")
                elseif esc == "r" then table.insert(buf,"\r")
                end
                pos = pos + 2
            else
                table.insert(buf,c)
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
        return tonumber(str:sub(s,pos-1))
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
            if str:sub(pos,pos) == "}" then pos = pos + 1 return obj end
            while true do
                skip()
                local k = parse_value()
                skip()
                pos = pos + 1 -- :
                local v = parse_value()
                obj[k] = v
                skip()
                if str:sub(pos,pos) == "}" then pos = pos + 1 break end
                pos = pos + 1 -- ,
            end
            return obj
        end

        if c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if str:sub(pos,pos) == "]" then pos = pos + 1 return arr end
            while true do
                table.insert(arr, parse_value())
                skip()
                if str:sub(pos,pos) == "]" then pos = pos + 1 break end
                pos = pos + 1
            end
            return arr
        end

        if c:match("[%d%-]") then return parse_number() end
        if str:sub(pos,pos+3) == "null"  then pos = pos+4 return nil end
        if str:sub(pos,pos+3) == "true"  then pos = pos+4 return true end
        if str:sub(pos,pos+4) == "false" then pos = pos+5 return false end

        return nil
    end

    return parse_value()
end


--------------------------------------------------------------------
-- Получение ChataiStorage
--------------------------------------------------------------------
local function getStorage()
    local cont = Game.GetScriptableSystemsContainer()
    if not cont then return nil end
    return cont:Get(CName.new("ChataiPhone.ChataiStorage"))
end


--------------------------------------------------------------------
-- Отправка JSON → Redscript
--------------------------------------------------------------------
local function sendToStorage(raw)
    local storage = getStorage()
    if not storage then return false end

    local data = json_decode(raw)
    if not data then return false end

    local corpName = data.corp_name or "Chatai JSON"
    local npcText  = data.npc_text  or "..."

    storage:SetCorpName(corpName)
    storage:SetNpcText(npcText)

    storage:ClearReplies()

    if data.replies then
        for _, r in ipairs(data.replies) do
            if r.id and r.text then
                storage:AddReply(r.id, r.text)
            end
        end
    end

    if data.answers then
        for idstr, text in pairs(data.answers) do
            local id = tonumber(idstr)
            if id then storage:AddAnswer(id, text) end
        end
    end

    print("[CHATAI] Data synced.")

    ----------------------------------------------------------------
    -- УМНОЕ УВЕДОМЛЕНИЕ (без спама)
    ----------------------------------------------------------------
    local current_id = data.msg_id or npcText

    if current_id ~= last_msg_id then
        storage:TriggerNotification(corpName, npcText)
        print("[CHATAI] New message → notification sent.")
        last_msg_id = current_id
    else
        print("[CHATAI] Same message → silent update.")
    end

    return true
end


--------------------------------------------------------------------
-- EVENTS
--------------------------------------------------------------------
registerForEvent("onInit", function()
    launch_generator()
end)

registerForEvent("onUpdate", function(delta)
    if not storageReady then
        local s = getStorage()
        if s then
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
        lastJson = raw
        if storageReady then
            sendToStorage(raw)
        else
            pendingJson = raw
        end
    end
end)
