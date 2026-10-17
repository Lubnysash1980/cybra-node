#!/usr/bin/env python3
import os, subprocess, re
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ЧИТАЄМО ФАЙЛ ═══")
text = MENU.read_text()
print(f"  Розмір: {len(text)} байт")

# ─── 2. Знаходимо функцію print_menu і замінюємо її ───
print("═══ 2. ШУКАЄМО print_menu ═══")

# Шаблон для заміни всієї функції print_menu
pattern = re.compile(r'print_menu\(\)\s*\{.*?\n\}', re.DOTALL)

new_print_menu = r'''print_menu() {
    printf '%s\n' "${C_BOLD}  ─── ОСНОВНЕ ───${C_RESET}"
    printf '  🟢 %s[1]%s  Створити контракт\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[2]%s  Список контрактів\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[3]%s  Статус контракту\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[4]%s  Згенерувати лінки\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[5]%s  Підтвердити лінк\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[6]%s  Debug\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[7]%s  DUAL-LICENSE ledger\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[8]%s  CREATION-LICENSE ledger\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[9]%s  Hardening\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_CYAN}  ─── INVOICE ───${C_RESET}"
    printf '  🟢 %s[10]%s Підписати INVOICE (продавець)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[11]%s Створити INVOICE\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[12]%s Додати позицію\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[13]%s Показати INVOICE\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[14]%s Фіналізувати INVOICE\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_CYAN}  ─── PII MASK ───${C_RESET}"
    printf '  🟢 %s[15]%s Експорт PII-masked\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[16]%s Експорт усіх + git\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[17]%s Перевірити PII хеш\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_CYAN}  ─── REFUND ───${C_RESET}"
    printf '  🟢 %s[18]%s Фінальне рішення покупця\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[19]%s Перевірити timeout\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[20]%s Статус refund\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[21]%s Додати умову\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_CYAN}  ─── ВАЛЮТИ ───${C_RESET}"
    printf '  🟢 %s[22]%s Показати курси\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[23]%s Оновити курс\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[24]%s Конвертер\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_CYAN}  ─── СИСТЕМА ───${C_RESET}"
    printf '  🟢 %s[30]%s Preflight\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[31]%s Self-heal\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[32]%s Dual-backend verify\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[33]%s Ownership scan\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_MAGENTA}  ─── AI (офлайн) ───${C_RESET}"
    printf '  🟢 %s[40]%s AI Аналіз\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[41]%s AI Парсинг рахунку\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[42]%s AI Генерація умов\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[43]%s AI Допомога\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[44]%s AI Вільне питання\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[45]%s AI Task Bar\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_MAGENTA}  ─── AI EVOLUTION ───${C_RESET}"
    printf '  🟢 %s[46]%s Executor — повний\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[47]%s Executor — scan\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[48]%s Executor — apply\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[49]%s Executor — список\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_GREEN}  ─── ADDRESS BOOK ───${C_RESET}"
    printf '  🟢 %s[50]%s Додати адресу\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[51]%s Список адрес\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[52]%s Історія адрес\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_GREEN}  ─── INTEGRATIONS ───${C_RESET}"
    printf '  🟢 %s[53]%s QR-код\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[54]%s Telegram — setup\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[55]%s Telegram — test\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[56]%s Webhook — список\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[57]%s Webhook — додати\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_GREEN}  ─── EXPORT / BACKUP ───${C_RESET}"
    printf '  🟢 %s[58]%s CSV — контракти\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[59]%s CSV — ledger\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[60]%s TXT — звіт\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[61]%s Backup — локальний\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[62]%s Backup — хмара\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_GREEN}  ─── MULTI-CHAIN ───${C_RESET}"
    printf '  🟢 %s[63]%s Список мереж\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[64]%s Сканер-tx\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_RED}  ─── DISPUTE / AUDIT ───${C_RESET}"
    printf '  🟢 %s[65]%s Відкрити спір\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[66]%s Список спорів\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[67]%s Голосувати\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[68]%s Audit log\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[69]%s Audit — перевірити\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_RED}  ─── DOCUMENT SCANNER ───${C_RESET}"
    printf '  🟢 %s[70]%s Сфотографувати\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[71]%s OCR\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[72]%s PDF → текст\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[73]%s Повний pipeline\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_MAGENTA}  ─── РОЗШИРЕНІ ───${C_RESET}"
    printf '  🟢 %s[74]%s Пошук контракту\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[75]%s Auto-fill контракту\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[76]%s AI прогін умов\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[77]%s Перевірка платежів\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[78]%s Додаткові умови\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[79]%s Watchdog (супервізор)\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_RED}  ─── GUARDIAN (100% state) ───${C_RESET}"
    printf '  🟢 %s[80]%s Стан системи\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[81]%s Перевірка 100%%\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[82]%s Зареєструвати особу\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[83]%s Показати особу\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[84]%s Перевірити особу\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[85]%s Пристрій\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[86]%s Snapshot\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[87]%s Відновити з git\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[88]%s Відновити з snapshot\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[89]%s AUTO-recovery\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[90]%s Action log\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[91]%s Log verify\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_RED}  ─── AUTOSAVE ───${C_RESET}"
    printf '  🟢 %s[92]%s Зберегти контракт\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[93]%s Статус autosave\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[94]%s Останні архіви\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[95]%s Відновити контракт\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_RED}  ─── EVO CONTROLLERS ───${C_RESET}"
    printf '  🟢 %s[96]%s EVO7 (7 рівнів)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[97]%s EVO CONTROLLER (4 SHA)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[98]%s Parawatch (фон)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[99]%s AUTOPATCH\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "${C_MAGENTA}  ─── NODE / HASH / SYSTEM ───${C_RESET}"
    printf '  🟢 %s[100]%s Node manager\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[101]%s Hash ecosystem (5 layers)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[102]%s Binmix daemon\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[103]%s Metrics (Prometheus)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[104]%s HTTP panel\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[105]%s Schedule (cron)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[106]%s Cleanup (ротація)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[107]%s Autopilot (авто-оновлення)\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "  ${C_BOLD}─── NODE/HASH ───${C_RESET}"
    printf '  🟢 %s[121]%s parlament\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[120]%s ai guardian\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[119]%s qr sign\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[118]%s net health\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[117]%s tx lookup\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[116]%s gas monitor\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[115]%s rpc bench\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[114]%s autonode\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[113]%s metamask batch\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[112]%s metamask deeplink\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[111]%s metamask settings\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[110]%s metamask history\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[109]%s metamask verify\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[108]%s metamask sign\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "  ${C_BOLD}─── METAMASK ───${C_RESET}"
    printf '  🟢 %s[124]%s timelock\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[123]%s multisig\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[122]%s contract validator\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "  ${C_BOLD}─── ADVANCED ───${C_RESET}"
    printf '  🟢 %s[140]%s analytics\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[139]%s reputation\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[138]%s arbitration\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[137]%s escrow\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[136]%s templates\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[135]%s walletconnect\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[134]%s discord\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[133]%s tokens\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[132]%s compliance\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[131]%s kyc\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[130]%s test suite\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[129]%s voice\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[128]%s dashboard\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[126]%s zk\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[125]%s anchor\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "  ${C_BOLD}─── ORCHESTRATOR ───${C_RESET}"
    printf '  🟢 %s[150]%s Custom Scripts\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[149]%s Advanced Analytics\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[148]%s Multisig UI\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[147]%s On-chain Reputation v2\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[146]%s Merkle Batching\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[145]%s IPFS Pinning\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[144]%s Bitcoin Lightning\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[143]%s Email Notifications\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[142]%s Invoice PDF Export\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[141]%s Portfolio Tracker\n' "$C_BOLD" "$C_RESET"
    printf '\n'

    printf '%s\n' "  ${C_GREY}🟢 ready  🟡 warning  🔴 error${C_RESET}"
    printf '\n'
    printf '  %s[0]%s  Вихід\n\n' "$C_BOLD" "$C_RESET"
}'''

# Заміна
new_text, count = pattern.subn(new_print_menu, text)
if count == 0:
    print("  [!] print_menu не знайдено, спробуємо інший підхід...")
else:
    text = new_text
    print(f"  [✓] print_menu замінено")

MENU.write_text(text)
print("═══ 3. ЗБЕРЕЖЕНО ═══")

# Перевірка
r = run("grep -c 'action_' " + str(MENU))
print(f"  action_ функцій: {r.stdout.strip()}")

# Коміт
print("═══ 4. КОМІТ У GIT ═══")
run("git add modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBRA))
r = run('git commit -m "fix: restore full 150-item menu for EVO"', cwd=str(CYBRA))
print(r.stdout)
