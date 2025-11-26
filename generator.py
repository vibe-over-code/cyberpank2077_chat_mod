#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import re
import time
import random
import json
import os
from difflib import SequenceMatcher
from llama_cpp import Llama
import unicodedata

MODEL_PATH = "gemma-3n-E4B-it-IQ4_NL.gguf"
SAVE_PATH = "data/dialog_map.json"
os.makedirs("data", exist_ok=True)

CORPS = ["Arasaka", "Militech", "Biotechnica", "Petrochem", "Kang Tao", "Zetatech"]
ACTS = ["киберимпланты", "военная техника", "системы безопасности", "нейротехнологии"]

FALLBACK = [
    "Идите нахуй.",
    "Заткнись, жестянка.",
    "Ты мне мозги плавишь.",
    "Опять реклама? Вот ведь дерьмо.",
    "заебало",
    "Суки как вы заебали."
]


def clean(text):
    """Очищает текст от нестандартных, управляющих, невидимых и мусорных символов,
    сохраняя юникодные буквы, цифры, стандартную пунктуацию и переносы строк.
    """
    if not text:
        return ""

    cleaned_chars = []

    for ch in text:
        # Убираем управляющие кроме \n и \t
        if unicodedata.category(ch) == "Cc" and ch not in ("\n", "\t"):
            continue

        # Убираем невидимые форматирующие символы (Cf)
        if unicodedata.category(ch) == "Cf":
            continue

        # Разрешаем буквы, цифры, пробелы, переносы и базовую пунктуацию
        if ch.isalnum() or ch in " \n\t.,!?;:-—()[]{}\"'":
            cleaned_chars.append(ch)

        # Остальное — в мусор
        else:
            continue

    # Склеиваем
    cleaned = "".join(cleaned_chars)

    # Убираем повторяющиеся пробелы, но НЕ трогаем \n
    cleaned = re.sub(r"[ ]{2,}", " ", cleaned)

    return cleaned.strip()

def normalize_json(raw_data):
    """
    Приводит произвольный вывод модели к строгой структуре:
    {
      "npc_text": str,
      "replies": [ {"id": int, "text": str}, ... ],
      "answers": { "1": str, "2": str, ... }
    }
    """
    npc = clean(raw_data.get("npc_text", ""))

    # Нормализуем replies — всегда список объектов {id, text}
    replies_raw = raw_data.get("replies", [])
    normalized_replies = []
    for i, r in enumerate(replies_raw, start=1):
        if isinstance(r, dict):
            # если это объект, берём id и text (подстраховка)
            rid = r.get("id", None)
            try:
                rid = int(rid) if rid is not None else i
            except:
                rid = i
            text = r.get("text", "")
            text = clean(text)
        else:
            # если это просто строка — превращаем в объект
            rid = i
            text = clean(str(r))
        # игнорируем пустые реплики
        if text is None:
            text = ""
        normalized_replies.append({"id": rid, "text": text})

    # Нормализуем answers — хотим словарь с строковыми ключами
    ans_raw = raw_data.get("answers", "")
    normalized_answers = {}
    if isinstance(ans_raw, dict):
        for k, v in ans_raw.items():
            key = str(k)
            normalized_answers[key] = clean(str(v))
    else:
        # если пришла строка, превращаем в {"1": "..."}
        normalized_answers["1"] = clean(str(ans_raw))

    return {
        "npc_text": npc,
        "replies": normalized_replies,
        "answers": normalized_answers
    }


def call_model(llm, prompt, max_tokens=200):
    out = llm(
        prompt,
        max_tokens=max_tokens,
        temperature=0.8,
        top_p=0.9,
        repeat_penalty=1.1,
        stop=["</s>"]
    )
    try:
        txt = out["choices"][0]["text"]
    except:
        return ""
    return clean(txt)


def is_similar(a: str, b: str, threshold=0.7) -> bool:
    """Проверяет похожесть двух строк."""
    ratio = SequenceMatcher(None, a, b).ratio()
    return ratio >= threshold


def generate_once(llm):
    corp = random.choice(CORPS)
    act = random.choice(ACTS)

    # 1) NPC монолог
    prompt1 = f"""
Сделай рекламный монолог.
Корпорация: {corp}
Специализация: {act}
Стиль: агрессивная реклама киберпанка.
В ответе выдай только текст, ничего лишнего.
До 200 слов.
"""
    npc_text = call_model(llm, prompt1, 350) or ""

    # 2) VI ответы (пытаемся получить 2)
    replies_texts = []
    for _ in range(1):
        prompt_vi = f"""
Ты — Ви из Cyberpunk 2077, наемник жесткий, с тяжелой судьбой.
Дай короткий злой негативный ответ на рекламу от {corp}.
В ответе выдай только текст.
"""
        txt = call_model(llm, prompt_vi, 60)
        if not txt:
            txt = random.choice(FALLBACK)
        replies_texts.append(txt)

    # если два ответа почти одинаковы, оставляем 1
    if len(replies_texts) == 2 and is_similar(replies_texts[0], replies_texts[1]):
        replies_texts = replies_texts[:1]

    # Формируем replies как список объектов
    replies = []
    for i, t in enumerate(replies_texts, start=1):
        replies.append({"id": i, "text": t})

    # 3) NPC ответ (answers) — делаем строку
    prompt_ans = f"""
Сделай рекламный монолог.
Корпорация: {corp}
Специализация: {act}
Стиль: агрессивная реклама киберпанка.
В ответе выдай только текст, ничего лишнего.
До 200 слов.
"""
    ans_text = call_model(llm, prompt_ans, 80) or "Сбой рекламной сети."

    # Собираем сырые данные и нормализуем перед возвратом/сохранением
    raw = {
        "npc_text": npc_text,
        "replies": replies,
        # здесь answers может быть либо строкой, либо словарём; normalize_json обработает это
        "answers": ans_text
    }

    return normalize_json(raw)


    




# ------------------ MAIN LOOP ------------------
if __name__ == "__main__":
    print("Загрузка модели…")
    llm = Llama(model_path=MODEL_PATH, n_ctx=4096, verbose=False)

    while True:
        data = generate_once(llm)
        print(json.dumps(data, ensure_ascii=False, indent=2))

        try:
            with open(SAVE_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print("✔ JSON сохранён\n")
        except Exception as e:
            print("❌ Ошибка сохранения:", e)

        time.sleep(30)
