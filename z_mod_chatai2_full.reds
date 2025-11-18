module Chatai2Mod

// Импорты для фреймворка телефона
import PhoneExtension.System.*
import PhoneExtension.Classes.*
import PhoneExtension.DataStructures.*
// Импорт для PlayerPuppet, DelayCallback
import PlayerPuppet

// --- 1. ОПРЕДЕЛЕНИЕ КЛАССА-СЛУШАТЕЛЯ (ВЕСЬ КОНТАКТ) ---
public class Chatai2ContactListener extends PhoneEventsListener {
    public func GetContactHash() -> Int32 {
        return 99887766;
    }
    private let m_dialogController: wref<MessengerDialogViewController>;

    public func GetContactData(isText: Bool) -> ref<ContactData> {
        let c = new ContactData();
        c.hash = 99887766;
        c.localizedName = "Мой Первый Контакт";
        c.contactId = "mod_chatai2_simple_contact";
        c.id = "CHT02";
        c.avatarID = t"PhoneAvatars.Avatar_Judy";
        c.questRelated = true;
        c.isCallable = false;

        if isText {
            c.type = MessengerContactType.SingleThread;
            c.messagesCount = 1;
        }
        return c;
    }

    public func ShowDialog(m: wref<MessengerDialogViewController>) -> Bool {
        FTLog("Chatai2: ShowDialog() called.");
        this.m_dialogController = m;
        m.ClearMessagesCustom();
        m.ClearRepliesCustom();

        m.PushMessageCustom(
            "Привет, Чумба! Это кастомный контакт.",
            MessageViewType.Received,
            "Мой Первый Контакт",
            true
        );
        
        m.PushReplyCustom(
            1,
            "Отлично, работает!",
            false,
            false,
            true
        );
        FTLog("Chatai2: Reply added.");
        return true;
    }

    public func ActivateReply(messageID: Int32) {
        if messageID == 1 {
            // Ответ на "Отлично, работает!"
            this.m_dialogController.PushMessageCustom(
                "Рад слышать! Чем могу помочь дальше?",
                MessageViewType.Received,
                "Мой Первый Контакт",
                true
            );
            
            this.m_dialogController.PushReplyCustom(
                2,
                "Больше не нужно, спасибо.",
                false,
                false,
                true
            );
        }
    }
}

// --- 2. КЛАСС КОЛБЭКА ДЛЯ ОТЛОЖЕННОГО ЗАПУСКА ---
public class Chatai2InitCallback extends DelayCallback {
    private let m_player: wref<PlayerPuppet>;

    public static func Create(player: ref<PlayerPuppet>) -> ref<Chatai2InitCallback> {
        let cb = new Chatai2InitCallback();
        cb.m_player = player;
        return cb;
    }

    public func Call() -> Void {
        let system = PhoneExtensionSystem.GetInstance(this.m_player);
        let hash: Int32 = 99887766;

        // Если система не готова, повторяем запуск с увеличенной задержкой 0.50
        if !IsDefined(system) || !system.IsReady() {
            FTLog("Chatai2: System not ready yet, retrying...");
            GameInstance.GetDelaySystem(this.m_player.GetGame()).DelayCallback(
                Chatai2InitCallback.Create(this.m_player),
                0.50
            );
            return;
        }

        // --- СИСТЕМА ГОТОВА: РЕГИСТРАЦИЯ КОНТАКТА ---
        FTLog("Chatai2: PhoneExtensionSystem READY. Initializing listener...");

        if !system.IsCustomContact(hash) {
            let listener = new Chatai2ContactListener();
            system.Register(listener);

            // Отправка уведомления, чтобы контакт появился в списке
            system.NotifyNewMessageCustom(
                hash,
                "Мой Первый Контакт",
                "У вас новое сообщение!"
            );

            FTLog("Chatai2: Listener registered and notified.");
        } else {
            FTLog("Chatai2: Contact already exists.");
        }
    }
}

// --- 3. ГЛОБАЛЬНЫЙ ХУК ЗАПУСКА ---
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Void {
    wrappedMethod();

    let player = this as PlayerPuppet;

    // отложенный запуск (начальная задержка 0.50)
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(
        Chatai2InitCallback.Create(player),
        0.50
    );
    FTLog("Chatai2: Initializer hook attached to PlayerPuppet.");
}