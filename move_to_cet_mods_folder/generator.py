import time
import json
import os
import uuid
import re
from llama_cpp import Llama

DEVICE_MODE = "GPU" 

MODEL_PATH = "./qwen2.5-7b-Q5_K_M.gguf"
SAVE_PATH = "data/dialog_map.json"

PROMPT = 'Сгенерируй диалог в жанре киберпанк(Ви с Джонни(анархистом)) и верни ТОЛЬКО валидный JSON строго следующей структуры:\n{"msg_id": "<uuid>","corp_name": "<Имя персонажа>","npc_text": "<первая реплика NPC>","replies": [{"id": 1, "text": "..."}, {"id": 2, "text": "..."}],"answers": {"1": "...", "2": "..."}}'

def load_model(mode):
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"Файл модели {MODEL_PATH} не найден!")

    # -1 выгружает все слои на GPU. 0 оставляет всё на CPU.
    n_gpu_layers = -1 if mode.upper() == "GPU" else 0
    
    print(f"Загрузка модели на {mode.upper()}...")
    
    llm = Llama(
        model_path=MODEL_PATH,
        n_gpu_layers=n_gpu_layers,
        n_ctx=2048,           # Размер контекстного окна
        echo=False,           # Не дублировать промпт в ответе
        verbose=False         # Отключаем спам логами llama.cpp в консоль
    )
    return llm

def extract_json(raw_text):
    try:
        # Ищем JSON в тексте
        match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if match:
            data = json.loads(match.group(0))
            data["msg_id"] = str(uuid.uuid4())
            return data
    except Exception as e:
        print(f"[-] Ошибка структуры JSON: {e}")
        print(f"ответ модели:\n{raw_text}")
    return None

def generate(llm):
    # Используем встроенную поддержку Chat-формата в llama-cpp
    messages = [
        {"role": "system", "content": "You are a helpful AI assistant that outputs strictly valid JSON."},
        {"role": "user", "content": PROMPT}
    ]
    
    response = llm.create_chat_completion(
        messages=messages,
        max_tokens=512,
        temperature=0.5,
    )
    
    # Извлекаем сгенерированный текст
    raw_text = response['choices'][0]['message']['content']
    return extract_json(raw_text)

if __name__ == "__main__":
    os.makedirs("data", exist_ok=True)
    
    try:
        model = load_model(DEVICE_MODE)
        print(f"[+] Модель ({MODEL_PATH}) готова к работе на {DEVICE_MODE}")
        
        while True:
            result = generate(model)
            if result:
                with open(SAVE_PATH, "w", encoding="utf-8") as f:
                    json.dump(result, f, ensure_ascii=False, indent=2)
                print(f"[{time.strftime('%H:%M:%S')}] JSON обновлен. Корпорация: {result.get('corp_name')}")
            else:
                print(f"[{time.strftime('%H:%M:%S')}] Не удалось сгенерировать валидный JSON. Пропуск итерации.")
            
            time.sleep(10)
            
    except KeyboardInterrupt:
        print("\nОстановка пользователем.")
    except Exception as e:
        print(f"\n[КРИТИЧЕСКАЯ ОШИБКА]: {e}")