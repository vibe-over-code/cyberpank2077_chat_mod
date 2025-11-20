module Chatai

import RedFileSystem.*
import RedData.Json.*
import PlayerPuppet

// --- 1. СИСТЕМА ЧТЕНИЯ JSON ---
public class ChataiReadSystem extends ScriptableSystem {
    private const let READ_DELAY: Float = 5.0;

    public func ReadAndLogJson() -> Void {
        FTLog("Chatai: Periodic Read started");

        let storage = FileSystem.GetStorage("Chatai");
        if !IsDefined(storage) {
            FTLog("Chatai: Storage 'Chatai' not found.");
            return;
        }

        let file = storage.GetFile("dialog_map.json");
        if !IsDefined(file) {
            FTLog("Chatai: File 'dialog_map.json' not found in storage.");
            return;
        }

        let json = file.ReadAsJson();
        if !IsDefined(json) {
            FTLog(s"Chatai: Failed to parse Json of file '\(file.GetFilename())'.");
            return;
        }

        if !json.IsObject() {
            FTLog("Chatai: Expected root of Json document to be an object.");
            return;
        }

        let jsonObject = json as JsonObject;
        let keys = jsonObject.GetKeys();
        let keysCount = ArraySize(keys);

        FTLog(s"Chatai: Parsed JSON keys count = \(keysCount)");

        let i: Int32 = 0;
        while i < keysCount {
            let key = keys[i];
            let value = jsonObject.GetKey(key);
            FTLog(s"Chatai: Key: \(key), Value: \(value.ToString())");
            i += 1;
        }
    }
}

// --- 2. КОЛБЭК ДЛЯ ПОВТОРНОГО ЧТЕНИЯ JSON ---
public class JsonReadCallback extends DelayCallback {
    private let m_system: ref<ChataiReadSystem>; // используем ref, чтобы можно было хранить созданный инстанс
    private let m_player: wref<PlayerPuppet>;
    private let m_delay: Float;

    public static func Create(system: ref<ChataiReadSystem>, player: wref<PlayerPuppet>, delay: Float) -> ref<JsonReadCallback> {
        let cb = new JsonReadCallback();
        cb.m_system = system;
        cb.m_player = player;
        cb.m_delay = delay;
        return cb;
    }

    public func Call() -> Void {
        if !IsDefined(this.m_system) || !IsDefined(this.m_player) {
            FTLog("Chatai: System or Player no longer defined, stopping periodic read.");
            return;
        }

        this.m_system.ReadAndLogJson();

        GameInstance.GetDelaySystem(this.m_player.GetGame()).DelayCallback(
            JsonReadCallback.Create(this.m_system, this.m_player, this.m_delay),
            this.m_delay
        );
    }
}


// --- 3. ХУК СТАРТА НА ИГРОКЕ ---
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Void {
    wrappedMethod();

    let player = this as PlayerPuppet;
    let game = player.GetGame();

    // Пытаемся получить зарегистрированную систему
    let sysContainer = GameInstance.GetScriptableSystemsContainer(game);
    let sysRef = sysContainer.Get(n"ChataiReadSystem") as ChataiReadSystem;

    let systemForUse: ref<ChataiReadSystem> = null;

    if IsDefined(sysRef) {
        FTLog("Chatai2: Found registered ChataiReadSystem.");
        systemForUse = sysRef;
    } else {
        // Создаём локальный экземпляр
        FTLog("Chatai2: ChataiReadSystem not found. Creating local instance...");
        systemForUse = new ChataiReadSystem();
    }

    // Запускаем периодическое чтение
    GameInstance.GetDelaySystem(game).DelayCallback(
        JsonReadCallback.Create(systemForUse, player, 5.0),
        0.50
    );

    FTLog("Chatai2: Initializer hook attached to PlayerPuppet.");
}

