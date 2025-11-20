module Chatai

import RedFileSystem.*
import RedData.Json.*

public class JsonAutostartSystem extends ScriptableSystem {

    // Публичная функция для чтения и логирования JSON
    public func ReadAndLogJson() -> Void {
        FTLog("started");

        // Получаем хранилище с уникальным именем модификации, например "Chatai"
        let storage = FileSystem.GetStorage("Chatai");

        // Получаем файл dialog_map.json
        let file = storage.GetFile("dialog_map.json");

        // Читаем JSON файл как Variant (JSON возвращает Variant)
        let json = file.ReadAsJson();

        // Проверяем, что JSON файл был успешно прочитан
        if !IsDefined(json) {
            FTLog(s"Failed to parse Json of file '\(file.GetFilename())'.");
            return;
        }

        // Проверяем, что корень JSON документа — это объект
        if !json.IsObject() {
            FTLog("Expected root of Json document to be an object.");
            return;
        }

        // Приводим к типу JsonObject
        let jsonObject = json as JsonObject;

        // Логируем все ключи и значения JSON
        FTLog("Parsed JSON:");

        // Получаем список ключей JSON объекта
        let keys = jsonObject.GetKeys();
        let keysCount = ArraySize(keys);

        // Итерация по всем ключам объекта JSON
        let key = keys[0];               // Получаем ключ
        let value = jsonObject.GetKey(key); // Получаем значение для ключа

        // Логируем ключ и значение
        FTLog(s"Key: \(key), Value: \(value.ToString())");
    }

    // Метод для старта при инициализации
    public func Init() -> Void {
        // Вызываем функцию, которая будет читать и логировать JSON
        this.ReadAndLogJson();
    }
}

// Система для старта при инициализации
public class JsonAutostartInitializer extends ScriptableSystem {

    // Метод инициализации
    public func OnAttach() -> Void {
        // Создаем объект системы автозапуска
        let jsonAutostartSystem = new JsonAutostartSystem();
        // Инициализируем систему
        jsonAutostartSystem.Init();
    }
}
