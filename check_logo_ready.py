import os
import json
from PIL import Image

TOKEN = "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"
DIR = f"tw-assets/blockchains/smartchain/assets/{TOKEN}"
LOGO = os.path.join(DIR, "logo.png")
INFO = os.path.join(DIR, "info.json")

PASS = 0
FAIL = 0

def ok(msg):
    global PASS
    print(f"  ✅ {msg}")
    PASS += 1

def bad(msg):
    global FAIL
    print(f"  ❌ {msg}")
    FAIL += 1

print("════════════════════════════════════════════════════════════")
print("  🔍 АВТОПЕРЕВІРКА ЛОГОТИПУ ДЛЯ TRUST WALLET / BSCSCAN")
print("════════════════════════════════════════════════════════════\n")

# 1. Папка
print("▶ 1. Перевірка папки")
if os.path.isdir(DIR):
    ok(f"Папка існує: {DIR}")
else:
    bad(f"Папки немає: {DIR}")
    exit(1)

# 2. Логотип
print("\n▶ 2. Перевірка логотипу")
if os.path.isfile(LOGO):
    ok("Файл logo.png існує")
    try:
        img = Image.open(LOGO)
        if img.format != "PNG":
            bad(f"Формат не PNG (а {img.format})")
        else:
            ok(f"Формат: PNG")
        
        if img.size == (256, 256):
            ok(f"Розмір: 256x256 px")
        else:
            bad(f"Розмір неправильний: {img.size} (треба 256x256)")
            
        if img.mode in ("RGBA", "LA", "P"):
            ok(f"Режим: {img.mode} (підтримує прозорість)")
        else:
            print(f"  ⚠️  Режим: {img.mode} (без прозорості, може бути білий фон)")
            
    except Exception as e:
        bad(f"Не вдалося відкрити: {e}")
    
    size_kb = os.path.getsize(LOGO) / 1024
    if size_kb <= 100:
        ok(f"Розмір файлу: {size_kb:.1f} KB (ліміт 100 KB)")
    else:
        bad(f"Файл занадто великий: {size_kb:.1f} KB (треба <100 KB)")
else:
    bad("logo.png відсутній")

# 3. info.json
print("\n▶ 3. Перевірка info.json")
if os.path.isfile(INFO):
    ok("Файл info.json існує")
    try:
        with open(INFO, "r", encoding="utf-8") as f:
            data = json.load(f)
        ok("JSON валідний")
        
        required = ["name", "symbol", "type", "decimals", "explorer", "status", "id"]
        for key in required:
            if key in data:
                ok(f"Поле '{key}': {data[key]}")
            else:
                bad(f"Відсутнє поле '{key}'")
                
        if data.get("id", "").lower() == TOKEN.lower():
            ok("ID збігається з адресою контракту")
        else:
            bad(f"ID не збігається: {data.get('id')}")
            
    except Exception as e:
        bad(f"Помилка JSON: {e}")
else:
    bad("info.json відсутній")

# 4. Git
print("\n▶ 4. Перевірка Git-репозиторію")
if os.path.isdir("tw-repo/.git"):
    ok("Git-репозиторій tw-repo існує")
else:
    bad("tw-repo не існує (треба зробити git clone форку trustwallet/assets)")

# Висновок
print("\n════════════════════════════════════════════════════════════")
print(f"  РЕЗУЛЬТАТ: ✅ {PASS} PASS | ❌ {FAIL} FAIL")
print("════════════════════════════════════════════════════════════\n")

if FAIL == 0:
    print("🎉 ВСЕ ІДЕАЛЬНО! Логотип готовий до відправки на GitHub.")
    print("\n▶ Що робити далі:")
    print("  1. Зайди на https://github.com/trustwallet/assets")
    print("  2. Натисни 'Fork' (створити копію)")
    print("  3. Виконай команди нижче (заміни ТВІЙ_НІК):")
    print()
    print("     cd ~/CYBRA")
    print("     rm -rf tw-repo")
    print("     git clone https://github.com/ТВІЙ_НІК/assets.git tw-repo")
    print(f"     mkdir -p tw-repo/blockchains/smartchain/assets/{TOKEN}")
    print(f"     cp tw-assets/blockchains/smartchain/assets/{TOKEN}/* tw-repo/blockchains/smartchain/assets/{TOKEN}/")
    print("     cd tw-repo")
    print("     git add .")
    print("     git commit -m 'Add CYBRA token'")
    print("     git push")
    print("\n  4. Після push зайди на свій форк і натисни 'Compare & pull request'")
else:
    print("⚠️  Є помилки. Виправ їх і запусти перевірку знову:")
    print("     python3 check_logo_ready.py")
