import os
import urllib.request
from PIL import Image
import io
import json

TOKEN = "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"
URL = "https://cybroncybra.com/assets/cybra-logo.png"
DIR = f"tw-assets/blockchains/smartchain/assets/{TOKEN}"

print("▶ 1. Завантажуємо логотип...")
try:
    req = urllib.request.Request(URL, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=10) as response:
        img = Image.open(io.BytesIO(response.read()))
    print("✅ Логотип завантажено")
except Exception as e:
    print(f"❌ Помилка завантаження: {e}")
    print("👉 Скачай логотип вручну, поклади в ~/CYBRA як logo.png і запусти скрипт ще раз.")
    exit(1)

print("▶ 2. Робимо розміри 256x256 та 64x64...")
os.makedirs(DIR, exist_ok=True)
img_256 = img.resize((256, 256), Image.Resampling.LANCZOS)
img_256.save(os.path.join(DIR, "logo.png"), "PNG")
img_64 = img.resize((64, 64), Image.Resampling.LANCZOS)
img_64.save("logo-64.png", "PNG")
print("✅ Розміри готові")

print("▶ 3. Створюємо info.json...")
info = {
  "name": "CYBRA",
  "symbol": "CYBRA",
  "type": "BEP20",
  "decimals": 18,
  "description": "CYBRA Token — AI-powered DeFi ecosystem on BNB Smart Chain.",
  "website": "https://cybroncybra.com",
  "explorer": f"https://bscscan.com/token/{TOKEN}",
  "status": "active",
  "id": TOKEN
}
with open(os.path.join(DIR, "info.json"), "w", encoding="utf-8") as f:
    json.dump(info, f, indent=2, ensure_ascii=False)

print("\n" + "="*50)
print("✅ ВСЕ ГОТОВО!")
print(f"📂 Файли лежать тут: {DIR}/")
print("   ├── logo.png (256x256 для Trust Wallet)")
print("   └── info.json")
print("="*50)
print("\n🚀 Що робити далі:")
print("1. Зайди на github.com/trustwallet/assets")
print("2. Натисни 'Fork' (зроби копію собі)")
print("3. Завантаж туди папку tw-assets")
print("4. Натисни 'Pull Request'")
