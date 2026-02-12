module ChataiPhone

import PhoneExtension.DataStructures.*
import PhoneExtension.Classes.*
import PhoneExtension.System.*

// --- ЧАСТЬ 1: ХРАНИЛИЩЕ ДАННЫХ (Мост для Lua) ---

public class ReplyData {
    public let id: Int32;
    public let text: String;
}

public class ChataiStorage extends ScriptableSystem {
    private let npcText: String;
    private let m_corpName: String; // <--- НОВОЕ ПОЛЕ: Название корпорации/контакта
    private let replies: array<ref<ReplyData>>;
    private let answers: array<String>;
    private let m_isUnread: Bool;

    public func OnAttach() -> Void {
        ArrayClear(this.replies);
        ArrayClear(this.answers);
        this.m_corpName = "Chatai JSON"; // Инициализация по умолчанию
    }

    // --- МЕТОДЫ ДЛЯ LUA ---

    // НОВЫЙ СЕТТЕР ДЛЯ ИМЕНИ КОНТАКТА
    public func SetCorpName(name: String) -> Void {
        this.m_corpName = name;
    }

    // 1. Установка текста NPC
    public func SetNpcText(text: String) -> Void {
        this.npcText = text;
    }

    // 2. Очистка ответов
    public func ClearReplies() -> Void {
        ArrayClear(this.replies);
        ArrayClear(this.answers);
    }

    // 3. Добавление варианта ответа игрока
    public func AddReply(id: Int32, text: String) -> Void {
        let r = new ReplyData();
        r.id = id;
        r.text = text;
        ArrayPush(this.replies, r);
    }

    // 4. Добавление ответа NPC на выбор игрока
    public func AddAnswer(id: Int32, text: String) -> Void {
        if id > 0 {
            let index: Int32 = id - 1;
            if index >= ArraySize(this.answers) {
                ArrayResize(this.answers, index + 1);
            }
            this.answers[index] = text;
        }
    }

    // 5. Управление статусом непрочитанного
    public func SetUnread(unread: Bool) -> Void {
        this.m_isUnread = unread;
    }

    public func IsUnread() -> Bool {
        return this.m_isUnread;
    }

    // 6. Метод для вызова уведомления (вызывать из Lua!)
    public func TriggerNotification(title: String, text: String) -> Void {
        let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
        if IsDefined(player) {
            let syst = PhoneExtensionSystem.GetInstance(player);
            // Используем title, переданный из Lua
            syst.NotifyNewMessageCustom(76543210, title, text); 
            this.SetUnread(true);
        }
    }

    // --- ГЕТТЕРЫ ---

    // НОВЫЙ ГЕТТЕР ДЛЯ ИМЕНИ КОНТАКТА
    public func GetCorpName() -> String {
        return this.m_corpName;
    }

    public func GetNpcText() -> String {
        if StrLen(this.npcText) == 0 {
            return "Connection established...";
        }
        return this.npcText;
    }

    public func GetReplies() -> array<ref<ReplyData>> {
        return this.replies;
    }

    public func GetAnswer(id: Int32) -> String {
        let index: Int32 = id - 1;
        if index >= 0 && index < ArraySize(this.answers) {
            return this.answers[index];
        }
        return "...";
    }
}

// --- ЧАСТЬ 2: СКРИПТ КОНТАКТА ---

public class ChataiPhoneContact extends PhoneEventsListener {
    private let m_player: wref<PlayerPuppet>;
    private let m_messengerController: wref<MessengerDialogViewController>;

    public func Init(player: ref<PlayerPuppet>) -> Void {
        this.m_player = player;
    }

    // Уникальный хеш контакта
    public func GetContactHash() -> Int32 = 76543210
    
    // ИСПРАВЛЕНИЕ: Теперь это динамический геттер, который берет имя из хранилища
    public func GetContactLocalizedName() -> String {
        let storage = GameInstance
            .GetScriptableSystemsContainer(this.m_player.GetGame())
            .Get(n"ChataiPhone.ChataiStorage") as ChataiStorage;
        
        if IsDefined(storage) {
            return storage.GetCorpName();
        }
        return "Chatai JSON"; // Fallback
    }

    public func GetContactData(isText: Bool) -> ref<ContactData> {
        let c = new ContactData();
        let storage = GameInstance
            .GetScriptableSystemsContainer(this.m_player.GetGame())
            .Get(n"ChataiPhone.ChataiStorage") as ChataiStorage;

        let contactName = this.GetContactLocalizedName(); // <--- ИСПОЛЬЗУЕМ ДИНАМИЧЕСКОЕ ИМЯ

        c.hash = this.GetContactHash();
        c.localizedName = contactName; // <--- ИСПОЛЬЗУЕМ ДИНАМИЧЕСКОЕ ИМЯ
        c.contactId = s"ChataiContact";
        c.id = s"CHAT";
        c.avatarID = t"PhoneAvatars.Avatar_Unknown";
        
        // Для текстовых сообщений
        if isText {
            c.type = MessengerContactType.SingleThread;
            c.lastMesssagePreview = storage.GetNpcText();
            
            // Логика непрочитанных сообщений
            ArrayClear(c.unreadMessages);
            if storage.IsUnread() {
                c.unreadMessegeCount = 1;
                ArrayPush(c.unreadMessages, 1); 
                c.playerIsLastSender = false;
            } else {
                c.unreadMessegeCount = 0;
                c.playerIsLastSender = true;
            }
        } else {
            c.type = MessengerContactType.Contact;
        }

        c.messagesCount = 1;
        c.hasMessages = true;
        c.playerCanReply = true;

        return c;
    }

    public func ShowDialog(ctrl: wref<MessengerDialogViewController>) -> Bool {
        this.m_messengerController = ctrl;

        let storage = GameInstance
            .GetScriptableSystemsContainer(this.m_player.GetGame())
            .Get(n"ChataiPhone.ChataiStorage") as ChataiStorage;

        // Снимаем флаг непрочитанного
        if storage.IsUnread() {
            storage.SetUnread(false);
        }

        let textToShow = storage.GetNpcText();
        let contactName = this.GetContactLocalizedName(); // <--- ИСПОЛЬЗУЕМ ДИНАМИЧЕСКОЕ ИМЯ

        // Показываем сообщение NPC
        ctrl.PushMessageCustom(
            textToShow,
            MessageViewType.Received,
            contactName, // <--- ИСПОЛЬЗУЕМ ДИНАМИЧЕСКОЕ ИМЯ
            false
        );

        // Показываем варианты ответов
        this.PushDynamicReplies(storage);

        // Прокрутка вниз
        ctrl.m_scrollController.SetScrollPosition(1.0);
        
        return true;
    }

    private func PushDynamicReplies(storage: ref<ChataiStorage>) -> Void {
        this.m_messengerController.ClearRepliesCustom();

        let replies = storage.GetReplies();

        for reply in replies {
            this.m_messengerController.PushReplyCustom(
                reply.id,
                reply.text,
                false, 
                true,  
                this.m_messengerController.m_hasFocus
            );
        }
    }

    public func ActivateReply(messageID: Int32) -> Void {
        this.m_messengerController.ClearRepliesCustom();

        let storage = GameInstance
            .GetScriptableSystemsContainer(this.m_player.GetGame())
            .Get(n"ChataiPhone.ChataiStorage") as ChataiStorage;

        let replies = storage.GetReplies();
        let playerText = "Unknown";

        for r in replies {
            if r.id == messageID {
                playerText = r.text;
            }
        }

        // 1. Показываем сообщение игрока
        this.PushPlayerMessage(playerText);

        // 2. Получаем и показываем ответ бота
        let botAnswer = storage.GetAnswer(messageID);
        this.PushBotMessage(botAnswer);

        // 3. Обновляем текст в хранилище
        storage.SetNpcText(botAnswer);
        
        storage.ClearReplies();
        storage.SetUnread(false);
    }

    private func PushPlayerMessage(msg: String) -> Void {
        this.m_messengerController.PushMessageCustom(
            msg,
            MessageViewType.Sent,
            "V", // Имя игрока
            false
        );
    }

    private func PushBotMessage(msg: String) -> Void {
        this.m_messengerController.PushMessageCustom(
            msg,
            MessageViewType.Received,
            this.GetContactLocalizedName(), // <--- ИСПОЛЬЗУЕМ ДИНАМИЧЕСКОЕ ИМЯ
            true // playSound
        );
    }
}

// --- ЧАСТЬ 3: РЕГИСТРАЦИЯ ---

@addField(NewHudPhoneGameController)
private let m_chataiContact: ref<ChataiPhoneContact>;

@wrapMethod(NewHudPhoneGameController)
protected cb func OnInitialize() -> Bool {
    let ret = wrappedMethod();
    let player = this.GetPlayerControlledObject();
    
    if IsDefined(player) {
        let syst = PhoneExtensionSystem.GetInstance(player);

        if !IsDefined(this.m_chataiContact) {
            this.m_chataiContact = new ChataiPhoneContact();
            this.m_chataiContact.Init(player as PlayerPuppet);
        }

        syst.Register(this.m_chataiContact);
    }
    return ret;
}

@wrapMethod(NewHudPhoneGameController)
protected cb func OnUninitialize() -> Bool {
    let ret = wrappedMethod();

    let player = this.GetPlayerControlledObject();
    if IsDefined(this.m_chataiContact) && IsDefined(player) {
        let syst = PhoneExtensionSystem.GetInstance(player);
        syst.Unregister(this.m_chataiContact);
    }

    return ret;
}