import time
import json
import os
import uuid
import re
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import PeftModel

# === КОНФИГУРАЦИЯ ===
# Выбери режим: "GPU" (для Q4 квантования) или "CPU" (для обычного режима)
DEVICE_MODE = "CPU" 

MODEL_ID = "Qwen/Qwen2.5-7B-Instruct"
ADAPTER_PATH = "./Qwen2.5-7B-Instruct-165929/lora_adapter"
SAVE_PATH = "data/dialog_map.json"

# Твой промпт для дообученной модели
PROMPT = 'Сгенерируй диалог в жанре киберпанк и верни ТОЛЬКО валидный JSON строго следующей структуры:\n{"msg_id": "<uuid>","corp_name": "<имя персонажа>","npc_text": "<первая реплика NPC>","replies": [{"id": 1, "text": "..."}, {"id": 2, "text": "..."}],"answers": {"1": "...", "2": "..."}}'

def load_model_explicit(mode):
    """Четкая загрузка выбранного режима"""
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    
    if mode.upper() == "GPU":
        if not torch.cuda.is_available():
            raise RuntimeError("ОШИБКА: Выбран режим GPU, но CUDA не обнаружена!")
            
        print(f">>> Запуск на GPU: Режим Q4 (4-bit quantization)")
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_use_double_quant=True,
        )
        base_model = AutoModelForCausalLM.from_pretrained(
            MODEL_ID,
            quantization_config=bnb_config,
            device_map="auto",
            dtype=torch.bfloat16
        )
    
    else: # Режим CPU
        print(f">>> Запуск на CPU: Стандартный режим (максимальная точность)")
        # На CPU bnb не работает, используем float32
        base_model = AutoModelForCausalLM.from_pretrained(
            MODEL_ID,
            device_map={"": "cpu"},
            dtype=torch.float32, 
            low_cpu_mem_usage=True
        )

    print(f">>> Подключаю адаптер: {ADAPTER_PATH}")
    model = PeftModel.from_pretrained(base_model, ADAPTER_PATH)
    model.eval()
    return model, tokenizer

def extract_json(raw_text):
    """Парсинг JSON и замена uuid"""
    try:
        # Ищем JSON в тексте (на случай если модель добавила мусор вокруг)
        match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if match:
            data = json.loads(match.group(0))
            # Подставляем реальный UUID вместо плейсхолдера
            data["msg_id"] = str(uuid.uuid4())
            return data
    except Exception as e:
        print(f"[-] Ошибка структуры JSON: {e}")
        print(f"Сырой ответ модели: {raw_text}")
    return None

def generate(model, tokenizer):
    messages = [{"role": "user", "content": PROMPT}]
    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    
    # Отправляем инпуты на то же устройство, где модель
    inputs = tokenizer(text, return_tensors="pt").to(model.device)

    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_new_tokens=512,
            temperature=0.8,
            do_sample=True,
            pad_token_id=tokenizer.eos_token_id
        )
    
    response = tokenizer.decode(outputs[0][len(inputs.input_ids[0]):], skip_special_tokens=True)
    return extract_json(response)

# ------------------ ЗАПУСК ------------------
if __name__ == "__main__":
    os.makedirs("data", exist_ok=True)
    
    try:
        model, tokenizer = load_model_explicit(DEVICE_MODE)
        print(f"[+] Модель готова к работе на {DEVICE_MODE}")
        
        while True:
            result = generate(model, tokenizer)
            if result:
                with open(SAVE_PATH, "w", encoding="utf-8") as f:
                    json.dump(result, f, ensure_ascii=False, indent=2)
                print(f"[{time.strftime('%H:%M:%S')}] JSON обновлен. Корпорация: {result.get('corp_name')}")
            
            time.sleep(10) # Пауза перед следующей итерацией
            
    except KeyboardInterrupt:
        print("\nОстановка пользователем.")
    except Exception as e:
        print(f"\n[КРИТИЧЕСКАЯ ОШИБКА]: {e}")