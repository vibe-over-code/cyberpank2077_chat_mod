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
    private let replies: array<ref<ReplyData>>;
    private let answers: array<String>;
    private let m_isUnread: Bool; // ФИКС 1: статус непрочитанного

    public func OnAttach() -> Void {
        // инициализация массивов — ТАК ПРАВИЛЬНО
        ArrayClear(this.replies);
        ArrayClear(this.answers);
    }

    public func SetNpcText(text: String) -> Void {
        this.npcText = text;
    }

    public func ClearReplies() -> Void {
        ArrayClear(this.replies);
        ArrayClear(this.answers);
    }

    public func AddReply(id: Int32, text: String) -> Void {
        let r = new ReplyData();
        r.id = id;
        r.text = text;
        ArrayPush(this.replies, r);
    }

    public func AddAnswer(id: Int32, text: String) -> Void {
        if id > 0 {
            let index: Int32 = id - 1;
            if index >= ArraySize(this.answers) {
                ArrayResize(this.answers, index + 1);
            }
            this.answers[index] = text;
        }
    }

    public func SetUnread(unread: Bool) -> Void {
        this.m_isUnread = unread;
    }

    public func IsUnread() -> Bool {
        return this.m_isUnread;
    }

    public func GetNpcText() -> String {
        if StrLen(this.npcText) == 0 {
            return "Ожидание данных от Lua...";
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
        return "ERROR: Answer not found for ID " + IntToString(id);
    }
}

// --- ЧАСТЬ 2: СКРИПТ КОНТАКТА ---

public class ChataiPhoneContact extends PhoneEventsListener {
    private let m_player: wref<PlayerPuppet>;
    private let m_messengerController: wref<MessengerDialogViewController>;

    public func Init(player: ref<PlayerPuppet>) -> Void {
        this.m_player = player;
    }

    public func GetContactHash() -> Int32 = 76543210
    public func GetContactLocalizedName() -> String = "Chatai JSON"

    private func SendNotification(text: String) -> Void {
        let syst = PhoneExtensionSystem.GetInstance(this.m_player);
        
        // PushSMSNotificationCustom принимает contactHash, Title, Text
        syst.NotifyNewMessageCustom(
            this.GetContactHash(), // Хеш вашего контакта
            this.GetContactLocalizedName(), // Имя контакта (заголовок)
            text // Текст последнего сообщения (превью)
        );
    }

    public func GetContactData(isText: Bool) -> ref<ContactData> {
        let c = new ContactData();

        c.hash = this.GetContactHash();
        c.localizedName = this.GetContactLocalizedName();
        c.contactId = s"ChataiContact";
        c.id = s"CHAT";
        c.avatarID = t"PhoneAvatars.Avatar_Unknown";
        c.type = isText ? MessengerContactType.SingleThread : MessengerContactType.Contact;

        let storage = GameInstance
            .GetScriptableSystemsContainer(this.m_player.GetGame())
            .Get(n"ChataiPhone.ChataiStorage") as ChataiStorage;

        c.lastMesssagePreview = storage.GetNpcText();
        c.messagesCount = 1;

        // unread
        c.unreadMessegeCount = storage.IsUnread() ? 1 : 0;
        ArrayClear(c.unreadMessages);
        if storage.IsUnread() {
            ArrayInsert(c.unreadMessages, 0, 1);
        }

        c.hasMessages = true;
        c.playerIsLastSender = false;
        c.playerCanReply = true;

        return c;
    }

    public func ShowDialog(ctrl: wref<MessengerDialogViewController>) -> Bool {
        this.m_messengerController = ctrl;

        let storage = GameInstance
            .GetScriptableSystemsContainer(this.m_player.GetGame())
            .Get(n"ChataiPhone.ChataiStorage") as ChataiStorage;

        if storage.IsUnread() {
            storage.SetUnread(false);
        }

        let textToShow = storage.GetNpcText();

        ctrl.PushMessageCustom(
            textToShow,
            MessageViewType.Received,
            this.GetContactLocalizedName(),
            false
        );

        this.PushDynamicReplies(storage);

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

        this.PushPlayerMessage(playerText);

        let botAnswer = storage.GetAnswer(messageID);
        this.PushBotMessage(botAnswer);

        storage.ClearReplies();
        // PushDynamicReplies больше не вызываем
    }

    private func PushPlayerMessage(msg: String) -> Void {
        this.m_messengerController.PushMessageCustom(
            msg,
            MessageViewType.Sent,
            this.GetContactLocalizedName(),
            false
        );
    }

    private func PushBotMessage(msg: String) -> Void {
        this.m_messengerController.PushMessageCustom(
            msg,
            MessageViewType.Received,
            this.GetContactLocalizedName(),
            true
        );
    }
}

// --- ЧАСТЬ 3: РЕГИСТРАЦИЯ ---

@addField(NewHudPhoneGameController)
private let m_chataiContact: ref<ChataiPhoneContact>;

@wrapMethod(NewHudPhoneGameController)
protected cb func OnInitialize() -> Bool {
    let ret = wrappedMethod();
    let syst = PhoneExtensionSystem.GetInstance(this.GetPlayerControlledObject());

    if !IsDefined(this.m_chataiContact) {
        this.m_chataiContact = new ChataiPhoneContact();
        this.m_chataiContact.Init(this.GetPlayerControlledObject() as PlayerPuppet);
    }

    syst.Register(this.m_chataiContact);
    return ret;
}

@wrapMethod(NewHudPhoneGameController)
protected cb func OnUninitialize() -> Bool {
    let ret = wrappedMethod();

    if IsDefined(this.m_chataiContact) {
        let syst = PhoneExtensionSystem.GetInstance(this.GetPlayerControlledObject());
        syst.Unregister(this.m_chataiContact);
    }

    return ret;
}
