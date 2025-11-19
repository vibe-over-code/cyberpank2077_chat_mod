module ChataiPhone

import PhoneExtension.DataStructures.*
import PhoneExtension.Classes.*
import PhoneExtension.System.*

enum ChataiReply {
	Hello = 1,
	Who = 2
}

public class ChataiPhoneContact extends PhoneEventsListener {
	private let m_player: wref<PlayerPuppet>;
	private let m_messengerController: wref<MessengerDialogViewController>;

	public func Init(player: ref<PlayerPuppet>) -> Void {
		this.m_player = player;
	}

	// Уникальный ID контакта
	public func GetContactHash() -> Int32 = 76543210

	// Имя контакта
	public func GetContactLocalizedName() -> String = "Chatai"

	// Данные контакта
	public func GetContactData(isText: Bool) -> ref<ContactData> {
		let c = new ContactData();

		c.hash = this.GetContactHash();
		c.localizedName = this.GetContactLocalizedName();
		c.contactId = s"ChataiContact";
		c.id = s"CHAT";
		c.avatarID = t"PhoneAvatars.Avatar_Unknown";

		c.type = isText ? MessengerContactType.SingleThread : MessengerContactType.Contact;

		c.lastMesssagePreview = "Привет! Это тестовый контакт."; // preview
		c.messagesCount = 1;
		c.unreadMessegeCount = 1;
		ArrayInsert(c.unreadMessages, 0, 1);
		c.hasMessages = true;
		c.playerIsLastSender = false;
		c.playerCanReply = true;

		return c;
	}

	// Открытие диалога
	public func ShowDialog(ctrl: wref<MessengerDialogViewController>) -> Bool {
		this.m_messengerController = ctrl;

		ctrl.PushMessageCustom(
			"Привет! Ты открыл тестовый контакт.",
			MessageViewType.Received,
			this.GetContactLocalizedName(),
			false
		);

		this.PushInitialReplies();

		ctrl.m_scrollController.SetScrollPosition(1.0);
		return true;
	}

	private func PushInitialReplies() -> Void {
		this.m_messengerController.ClearRepliesCustom();

		this.m_messengerController.PushReplyCustom(
			EnumInt(ChataiReply.Hello),
			"Привет!",
			false,
			true,
			this.m_messengerController.m_hasFocus
		);

		this.m_messengerController.PushReplyCustom(
			EnumInt(ChataiReply.Who),
			"Кто ты?",
			false,
			false,
			this.m_messengerController.m_hasFocus
		);
	}

	// Обработка ответа пользователя
	public func ActivateReply(messageID: Int32) -> Void {
		this.m_messengerController.ClearRepliesCustom();

		if messageID == EnumInt(ChataiReply.Hello) {
			this.PushPlayerMessage("Привет!");
			this.PushBotMessage("И тебе привет! Рад знакомству.");
		};

		if messageID == EnumInt(ChataiReply.Who) {
			this.PushPlayerMessage("Кто ты?");
			this.PushBotMessage("Я тестовый контакт, созданный для примера.");
		};
	}

	// Вспомогательные функции
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

// Регистрация контакта
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
	let syst = PhoneExtensionSystem.GetInstance(this.GetPlayerControlledObject());

	syst.Unregister(this.m_chataiContact);
	return ret;
}
