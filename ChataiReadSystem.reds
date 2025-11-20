module Chatai

import RedFileSystem.*
import RedData.Json.*
import PlayerPuppet

// --- 1. СИСТЕМА ЧТЕНИЯ JSON (Исправлена для использования FileSystem.GetStorage("mod")) ---
// --- 1. СИСТЕМА ЧТЕНИЯ JSON (Финальная версия с прямым путём) ---
public class ChataiReadSystem extends ScriptableSystem {
    
    private const let READ_DELAY: Float = 5.0;
    
    // ВАЖНО: Определяем путь к файлу, который, как вы выяснили, работает
    private const let JSON_FILE_PATH: String = "r6/storage/Сhatai/dialog_map.json";

    public func ReadAndLogJson() -> Void {
        FTLog("Chatai: Periodic Read started (Direct Path access)");

        // 1. Прямой доступ к файлу по пути, минуя GetStorage
        let file = FileSystem.GetFile(this.JSON_FILE_PATH);
        
        if !IsDefined(file) {
            FTLog(s"Chatai: FATAL: File not found at direct path: \(this.JSON_FILE_PATH).");
            // Если вы попадаете сюда, значит, файл либо переместился, либо
            // игра не может получить к нему доступ из-за разрешений/конфликтов.
            return;
        }

        // --- Продолжаем с проверкой JSON ---
        let json = file.ReadAsJson();
        if !IsDefined(json) {
            FTLog(s"Chatai: Failed to parse Json of file '\(this.JSON_FILE_PATH)'.");
            return;
        }

        if !json.IsObject() {
            FTLog("Chatai: Expected root of Json document to be an object.");
            return;
        }

        // ... (логика чтения итерации по JSON) ...
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
    // Остальной класс ChataiReadSystem, а также JsonReadCallback и @wrapMethod остаются без изменений.
}

// --- 2. КОЛБЭК ДЛЯ ПОВТОРНОГО ЧТЕНИЯ JSON (Без изменений, выглядит корректно) ---
public class JsonReadCallback extends DelayCallback {
    // Используем wref, как это принято для систем, чтобы избежать утечек,
    // но ref тоже будет работать, если система является постоянной.
    private let m_system: ref<ChataiReadSystem>;
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

        // Продолжаем рекурсивный вызов
        GameInstance.GetDelaySystem(this.m_player.GetGame()).DelayCallback(
            JsonReadCallback.Create(this.m_system, this.m_player, this.m_delay),
            this.m_delay
        );
    }
}


// --- 3. ХУК СТАРТА НА ИГРОКЕ ---
// --- 3. ГЛОБАЛЬНЫЙ ХУК ЗАПУСКА НА ИГРОКЕ ---
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Void {
    wrappedMethod();

    let player = this as PlayerPuppet;
    let game = player.GetGame();
    let readDelay: Float = 5.0; // Значение будет перезаписано

    // 1. ПОЛУЧАЕМ КОНТЕЙНЕР СИСТЕМ (ИСПРАВЛЕНИЕ ОШИБКИ)
    let sysContainer = GameInstance.GetScriptableSystemsContainer(game);
    let systemForUse: ref<ChataiReadSystem> = sysContainer.Get(n"ChataiReadSystem") as ChataiReadSystem;
    
    // Если sysContainer.Get() вернул NULL (система не зарегистрирована), создаём её локально
    if !IsDefined(systemForUse) {
        FTLog("Chatai: ChataiReadSystem not found in container. Creating local instance.");
        systemForUse = new ChataiReadSystem();
    } else {
        FTLog("Chatai: Found registered ChataiReadSystem.");
    }

    readDelay = systemForUse.READ_DELAY; // Берем задержку из инстанса

    // Запускаем периодическое чтение
    FTLog("Chatai: Starting continuous JSON reading loop.");
    GameInstance.GetDelaySystem(game).DelayCallback(
        JsonReadCallback.Create(systemForUse, player, readDelay),
        0.50 // Начальный вызов с небольшой задержкой
    );
}