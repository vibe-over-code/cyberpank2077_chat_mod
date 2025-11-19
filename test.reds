module MySimpleContact

import PhoneExtension.DataStructures.*
import PhoneExtension.Classes.*
import PhoneExtension.System.*
import PlayerPuppet

// Уникальный хеш контакта
public static func MyContactHash() -> Int32 = 9001122

// ================================
//  Контакт
// ================================
public class MyContactListener extends PhoneEventsListener {

    private let m_dialog: wref<MessengerDialogViewController>;

    public func GetContactHash() -> Int32 = MyContactHash()

    public func GetContactLocalizedName() -> String = "Чат-Ай Мини"

    public func GetContactData(isText: Bool) -> ref<ContactData> {
        let c = new ContactData();
        c.hash = MyContactHash();
        c.localizedName = "Чат-Ай Мини";
        c.contactId = "ChatAiMini";
        c.id = "CHATMINI";
        c.avatarID = t"PhoneAvatars.Avatar_Unknown";
        c.questRelated = false;
        c.isCallable = false;

        if isText {
            c.type = MessengerContactType.SingleThread;
            c.lastMesssagePreview = "Привет! Это тестовый контакт.";
            c.messagesCount = 1;
            c.unreadMessegeCount = 1;
            ArrayInsert(c.unreadMessages, 0, 1);
        }

        return c;
    }

    public func ShowDialog(m: wref<MessengerDialogViewController>) -> Bool {
        this.m_dialog = m;

        m.ClearMessagesCustom();
        m.ClearRepliesCustom();

        // первое сообщение
        m.PushMessageCustom(
            "Привет! Это простой тестовый контакт.",
            MessageViewType.Received,
            "Чат-Ай Мини",
            true
        );

        // одна кнопка ответа
        m.PushReplyCustom(
            1,
            "Круто!",
            false,
            false,
            true
        );

        return true;
    }

    public func ActivateReply(messageID: Int32) -> Void {
        if messageID == 1 {
            this.m_dialog.PushMessageCustom(
                "Отлично, контакт работает!",
                MessageViewType.Received,
                "Чат-Ай Мини",
                true
            );
        }
    }
}

// ================================
//  Регистрация контакта при старте
// ================================

@addField(NewHudPhoneGameController)
private let m_myContact: ref<MyContactListener>;

@wrapMethod(NewHudPhoneGameController)
protected cb func OnInitialize() -> Bool {
    let ret = wrappedMethod();

    let syst = PhoneExtensionSystem.GetInstance(this.GetPlayerControlledObject());
    if !IsDefined(this.m_myContact) {
        this.m_myContact = new MyContactListener();
    }
    syst.Register(this.m_myContact);

    // Добавляем уведомление "новое сообщение"
    syst.NotifyNewMessageCustom(
        MyContactHash(),
        "Чат-Ай Мини",
        "Привет! Ты получил тестовое сообщение."
    );

    return ret;
}

@wrapMethod(NewHudPhoneGameController)
protected cb func OnUninitialize() -> Bool {
    let ret = wrappedMethod();
    let syst = PhoneExtensionSystem.GetInstance(this.GetPlayerControlledObject());
    if IsDefined(this.m_myContact) {
        syst.Unregister(this.m_myContact);
    }
    return ret;
}
