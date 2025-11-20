import json
import os
import time

# --- КОНФИГУРАЦИЯ ---
# Будем использовать один и тот же файл для хранения и управления
DIALOG_MAP_FILE = r"F:\Cyberpunk 2077\r6\storages\Chatai\dialog_map.json" 
# --------------------

def create_static_dialog_map():
    """Создает или обновляет файл со всей картой диалога."""
    
    # Полностью статический, заранее написанный диалог
    static_map = {
      "current_node": "100", # Начальный узел
      "history": [],        # История сообщений, пуста при инициализации
      "nodes": {
        "100": {
          "sender": "NPC",
          "text": "Привет! Я тестовый ИИ. Что ты хочешь узнать?",
          "replies": [
            {"target_node_id": "200", "text": "Кто ты?"},
            {"target_node_id": "300", "text": "Что ты умеешь?"}
          ]
        },
        "200": {
          "sender": "NPC",
          "text": "Я ИИ, запрограммированный для генерации диалогов.",
          "replies": [
            {"target_node_id": "300", "text": "А что ты умеешь?"},
            {"target_node_id": "400", "text": "Пока."}
          ]
        },
        "300": {
          "sender": "NPC",
          "text": "Я умею хранить целые диалоги и показывать их игроку.",
          "replies": [
            {"target_node_id": "400", "text": "Понятно, пока."}
          ]
        },
        "400": {
          "sender": "NPC",
          "text": "До скорого!"
        }
      }
    }

    temp_file = DIALOG_MAP_FILE + ".tmp"
    try:
        # Атомарная запись для безопасности
        with open(temp_file, 'w', encoding='utf-8') as f:
            json.dump(static_map, f, ensure_ascii=False, indent=4)
        os.makedirs(os.path.dirname(DIALOG_MAP_FILE), exist_ok=True)
        os.replace(temp_file, DIALOG_MAP_FILE)
        print(f"[SUCCESS] Карта диалога записана в {DIALOG_MAP_FILE}")
        return static_map
    except IOError as e:
        print(f"Ошибка записи файла: {e}")
        return None

if __name__ == "__main__":
    print(f"*** ChatAI Python Map Writer Started ***")
    create_static_dialog_map()
    
    # Python-скрипт просто завершается, он не должен работать постоянно.
    # Если вы хотите, чтобы он перезаписывал файл каждые N секунд, 
    # добавьте цикл while True: time.sleep(N) и повторный вызов create_static_dialog_map().
    # Но для статического диалога это излишне.