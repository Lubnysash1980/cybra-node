#!/data/data/com.termux/files/usr/bin/bash
clear
echo '════════ ГОЛОВНЕ МЕНЮ (1-160) ════════'
echo '  🟢 [1] Створити контракт'
echo '  🟢 [2] Список контрактів'
echo '  🟢 [3] Статус контракту'
echo '  🟢 [4] Згенерувати лінки'
echo '  🟢 [5] Підтвердити лінк'
echo '  🟢 [6] Debug'
echo '  🟢 [7] DUAL-LICENSE ledger'
echo '  🟢 [8] CREATION-LICENSE ledger'
echo '  🟢 [9] Hardening'
echo '  🟢 [10] Підписати INVOICE'
echo '  🟢 [11] Створити INVOICE'
echo '  🟢 [12] Додати позицію'
echo '  🟢 [13] Показати INVOICE'
echo '  🟢 [14] Фіналізувати INVOICE'
echo '  🟢 [15] Експорт PII-masked'
echo '  🟢 [16] Експорт усіх + git'
echo '  🟢 [17] Перевірити PII хеш'
echo '  🟢 [18] Рішення покупця (refund)'
echo '  🟢 [19] Перевірити timeout'
echo '  🟢 [20] Статус refund'
echo '  🟢 [21] Додати умову'
echo '  🟢 [22] Показати курси'
echo '  🟢 [23] Оновити курс'
echo '  🟢 [24] Конвертер'
echo '  🟢 [25] Модуль 25'
echo '  🟢 [26] Модуль 26'
echo '  🟢 [27] Модуль 27'
echo '  🟢 [28] Модуль 28'
echo '  🟢 [29] Модуль 29'
echo '  🟢 [30] Preflight'
echo '  🟢 [31] Self-heal'
echo '  🟢 [32] Dual-backend verify'
echo '  🟢 [33] Ownership scan'
echo '  🟢 [34] Модуль 34'
echo '  🟢 [35] Модуль 35'
echo '  🟢 [36] Модуль 36'
echo '  🟢 [37] Модуль 37'
echo '  🟢 [38] Модуль 38'
echo '  🟢 [39] Модуль 39'
echo '  🟢 [40] AI Аналіз'
echo '  🟢 [41] AI Парсинг рахунку'
echo '  🟢 [42] AI Генерація умов'
echo '  🟢 [43] AI Допомога'
echo '  🟢 [44] AI Вільне питання'
echo '  🟢 [45] AI Task Bar'
echo '  🟢 [46] Executor — повний'
echo '  🟢 [47] Executor — scan'
echo '  🟢 [48] Executor — apply'
echo '  🟢 [49] Executor — список'
echo '  🟢 [50] Додати адресу'
echo '  🟢 [51] Список адрес'
echo '  🟢 [52] Історія адрес'
echo '  🟢 [53] QR-код'
echo '  🟢 [54] Telegram setup'
echo '  🟢 [55] Telegram test'
echo '  🟢 [56] Webhook список'
echo '  🟢 [57] Webhook додати'
echo '  🟢 [58] CSV контракти'
echo '  🟢 [59] CSV ledger'
echo '  🟢 [60] TXT звіт'
echo '  🟢 [61] Backup локальний'
echo '  🟢 [62] Backup хмара'
echo '  🟢 [63] Список мереж'
echo '  🟢 [64] Сканер-tx'
echo '  🟢 [65] Відкрити спір'
echo '  🟢 [66] Список спорів'
echo '  🟢 [67] Голосувати'
echo '  🟢 [68] Audit log'
echo '  🟢 [69] Audit перевірити'
echo '  🟢 [70] Сфотографувати'
echo '  🟢 [71] OCR'
echo '  🟢 [72] PDF → текст'
echo '  🟢 [73] Повний pipeline'
echo '  🟢 [74] Пошук контракту'
echo '  🟢 [75] Auto-fill контракту'
echo '  🟢 [76] AI прогін умов'
echo '  🟢 [77] Перевірка платежів'
echo '  🟢 [78] Додаткові умови'
echo '  🟢 [79] Watchdog (супервізор)'
echo '  🟢 [80] Стан системи'
echo '  🟢 [81] Перевірка 100%'
echo '  🟢 [82] Зареєструвати особу'
echo '  🟢 [83] Показати особу'
echo '  🟢 [84] Перевірити особу'
echo '  🟢 [85] Пристрій'
echo '  🟢 [86] Snapshot'
echo '  🟢 [87] Відновити з git'
echo '  🟢 [88] Відновити з snapshot'
echo '  🟢 [89] AUTO-recovery'
echo '  🟢 [90] Action log'
echo '  🟢 [91] Log verify'
echo '  🟢 [92] Зберегти контракт'
echo '  🟢 [93] Статус autosave'
echo '  🟢 [94] Останні архіви'
echo '  🟢 [95] Відновити контракт'
echo '  🟢 [96] EVO7 (7 рівнів)'
echo '  🟢 [97] EVO CONTROLLER'
echo '  🟢 [98] Parawatch (фон)'
echo '  🟢 [99] AUTOPATCH'
echo '  🟢 [100] Node manager'
echo '  🟢 [101] Hash ecosystem'
echo '  🟢 [102] Binmix daemon'
echo '  🟢 [103] Metrics'
echo '  🟢 [104] HTTP panel'
echo '  🟢 [105] Schedule (cron)'
echo '  🟢 [106] Cleanup (ротація)'
echo '  🟢 [107] Autopilot'
echo '  🟢 [108] metamask sign'
echo '  🟢 [109] metamask verify'
echo '  🟢 [110] metamask history'
echo '  🟢 [111] metamask settings'
echo '  🟢 [112] metamask deeplink'
echo '  🟢 [113] metamask batch'
echo '  🟢 [114] autonode'
echo '  🟢 [115] rpc bench'
echo '  🟢 [116] gas monitor'
echo '  🟢 [117] tx lookup'
echo '  🟢 [118] net health'
echo '  🟢 [119] qr sign'
echo '  🟢 [120] ai guardian'
echo '  🟢 [121] parlament'
echo '  🟢 [122] contract validator'
echo '  🟢 [123] multisig'
echo '  🟢 [124] timelock'
echo '  🟢 [125] anchor'
echo '  🟢 [126] zk'
echo '  🟢 [127] Модуль 127'
echo '  🟢 [128] dashboard'
echo '  🟢 [129] voice'
echo '  🟢 [130] test suite'
echo '  🟢 [131] kyc'
echo '  🟢 [132] compliance'
echo '  🟢 [133] tokens'
echo '  🟢 [134] discord'
echo '  🟢 [135] walletconnect'
echo '  🟢 [136] templates'
echo '  🟢 [137] escrow'
echo '  🟢 [138] arbitration'
echo '  🟢 [139] reputation'
echo '  🟢 [140] analytics'
echo '  🟢 [141] Portfolio Tracker'
echo '  🟢 [142] Invoice PDF Export'
echo '  🟢 [143] Email Notifications'
echo '  🟢 [144] Bitcoin Lightning'
echo '  🟢 [145] IPFS Pinning'
echo '  🟢 [146] Merkle Batching'
echo '  🟢 [147] On-chain Reputation v2'
echo '  🟢 [148] Multisig UI'
echo '  🟢 [149] Аналітика системи (AI)'
echo '  🟢 [150] Custom Scripts'
echo '  🟢 [151] Реклама (Ad Contract)'
echo '  🟢 [152] Відкат до чистої ноти EVO'
echo '  🟢 [153] Резерв 153'
echo '  🟢 [154] Менеджер посилань (Тунель)'
echo '  🟢 [155] Резерв 155'
echo '  🟢 [156] Резерв 156'
echo '  🟢 [157] Резерв 157'
echo '  🟢 [158] Резерв 158'
echo '  🟢 [159] Резерв 159'
echo '  🟢 [160] FIDIC Контракти'
echo '  🛠️  [999] АВТО-РЕМОНТ'
echo '  [0] Вихід'
read -p 'Вибір: ' choice
case $choice in
  1) bash ~/CYBRA/modules/module_1_base/main.sh ;;
  2) bash ~/CYBRA/modules/module_2_base/main.sh ;;
  3) bash ~/CYBRA/modules/module_3_base/main.sh ;;
  4) bash ~/CYBRA/modules/module_4_base/main.sh ;;
  5) bash ~/CYBRA/modules/module_5_base/main.sh ;;
  6) bash ~/CYBRA/modules/module_6_base/main.sh ;;
  7) bash ~/CYBRA/modules/module_7_base/main.sh ;;
  8) bash ~/CYBRA/modules/module_8_base/main.sh ;;
  9) bash ~/CYBRA/modules/module_9_base/main.sh ;;
  10) bash ~/CYBRA/modules/module_10_base/main.sh ;;
  11) bash ~/CYBRA/modules/module_11_base/main.sh ;;
  12) bash ~/CYBRA/modules/module_12_base/main.sh ;;
  13) bash ~/CYBRA/modules/module_13_base/main.sh ;;
  14) bash ~/CYBRA/modules/module_14_base/main.sh ;;
  15) bash ~/CYBRA/modules/module_15_base/main.sh ;;
  16) bash ~/CYBRA/modules/module_16_base/main.sh ;;
  17) bash ~/CYBRA/modules/module_17_base/main.sh ;;
  18) bash ~/CYBRA/modules/module_18_base/main.sh ;;
  19) bash ~/CYBRA/modules/module_19_base/main.sh ;;
  20) bash ~/CYBRA/modules/module_20_base/main.sh ;;
  21) bash ~/CYBRA/modules/module_21_base/main.sh ;;
  22) bash ~/CYBRA/modules/module_22_base/main.sh ;;
  23) bash ~/CYBRA/modules/module_23_base/main.sh ;;
  24) bash ~/CYBRA/modules/module_24_base/main.sh ;;
  25) bash ~/CYBRA/modules/module_25_base/main.sh ;;
  26) bash ~/CYBRA/modules/module_26_base/main.sh ;;
  27) bash ~/CYBRA/modules/module_27_base/main.sh ;;
  28) bash ~/CYBRA/modules/module_28_base/main.sh ;;
  29) bash ~/CYBRA/modules/module_29_base/main.sh ;;
  30) bash ~/CYBRA/modules/module_30_base/main.sh ;;
  31) bash ~/CYBRA/modules/module_31_base/main.sh ;;
  32) bash ~/CYBRA/modules/module_32_base/main.sh ;;
  33) bash ~/CYBRA/modules/module_33_base/main.sh ;;
  34) bash ~/CYBRA/modules/module_34_base/main.sh ;;
  35) bash ~/CYBRA/modules/module_35_base/main.sh ;;
  36) bash ~/CYBRA/modules/module_36_base/main.sh ;;
  37) bash ~/CYBRA/modules/module_37_base/main.sh ;;
  38) bash ~/CYBRA/modules/module_38_base/main.sh ;;
  39) bash ~/CYBRA/modules/module_39_base/main.sh ;;
  40) bash ~/CYBRA/modules/module_40_base/main.sh ;;
  41) bash ~/CYBRA/modules/module_41_base/main.sh ;;
  42) bash ~/CYBRA/modules/module_42_base/main.sh ;;
  43) bash ~/CYBRA/modules/module_43_base/main.sh ;;
  44) bash ~/CYBRA/modules/module_44_base/main.sh ;;
  45) bash ~/CYBRA/modules/module_45_base/main.sh ;;
  46) bash ~/CYBRA/modules/module_46_base/main.sh ;;
  47) bash ~/CYBRA/modules/module_47_base/main.sh ;;
  48) bash ~/CYBRA/modules/module_48_base/main.sh ;;
  49) bash ~/CYBRA/modules/module_49_base/main.sh ;;
  50) bash ~/CYBRA/modules/module_50_base/main.sh ;;
  51) bash ~/CYBRA/modules/module_51_base/main.sh ;;
  52) bash ~/CYBRA/modules/module_52_base/main.sh ;;
  53) bash ~/CYBRA/modules/module_53_base/main.sh ;;
  54) bash ~/CYBRA/modules/module_54_base/main.sh ;;
  55) bash ~/CYBRA/modules/module_55_base/main.sh ;;
  56) bash ~/CYBRA/modules/module_56_base/main.sh ;;
  57) bash ~/CYBRA/modules/module_57_base/main.sh ;;
  58) bash ~/CYBRA/modules/module_58_base/main.sh ;;
  59) bash ~/CYBRA/modules/module_59_base/main.sh ;;
  60) bash ~/CYBRA/modules/module_60_base/main.sh ;;
  61) bash ~/CYBRA/modules/module_61_base/main.sh ;;
  62) bash ~/CYBRA/modules/module_62_base/main.sh ;;
  63) bash ~/CYBRA/modules/module_63_base/main.sh ;;
  64) bash ~/CYBRA/modules/module_64_base/main.sh ;;
  65) bash ~/CYBRA/modules/module_65_base/main.sh ;;
  66) bash ~/CYBRA/modules/module_66_base/main.sh ;;
  67) bash ~/CYBRA/modules/module_67_base/main.sh ;;
  68) bash ~/CYBRA/modules/module_68_base/main.sh ;;
  69) bash ~/CYBRA/modules/module_69_base/main.sh ;;
  70) bash ~/CYBRA/modules/module_70_base/main.sh ;;
  71) bash ~/CYBRA/modules/module_71_base/main.sh ;;
  72) bash ~/CYBRA/modules/module_72_base/main.sh ;;
  73) bash ~/CYBRA/modules/module_73_base/main.sh ;;
  74) bash ~/CYBRA/modules/module_74_base/main.sh ;;
  75) bash ~/CYBRA/modules/module_75_base/main.sh ;;
  76) bash ~/CYBRA/modules/module_76_base/main.sh ;;
  77) bash ~/CYBRA/modules/module_77_base/main.sh ;;
  78) bash ~/CYBRA/modules/module_78_base/main.sh ;;
  79) bash ~/CYBRA/modules/module_79_base/main.sh ;;
  80) bash ~/CYBRA/modules/module_80_base/main.sh ;;
  81) bash ~/CYBRA/modules/module_81_base/main.sh ;;
  82) bash ~/CYBRA/modules/module_82_base/main.sh ;;
  83) bash ~/CYBRA/modules/module_83_base/main.sh ;;
  84) bash ~/CYBRA/modules/module_84_base/main.sh ;;
  85) bash ~/CYBRA/modules/module_85_base/main.sh ;;
  86) bash ~/CYBRA/modules/module_86_base/main.sh ;;
  87) bash ~/CYBRA/modules/module_87_base/main.sh ;;
  88) bash ~/CYBRA/modules/module_88_base/main.sh ;;
  89) bash ~/CYBRA/modules/module_89_base/main.sh ;;
  90) bash ~/CYBRA/modules/module_90_base/main.sh ;;
  91) bash ~/CYBRA/modules/module_91_base/main.sh ;;
  92) bash ~/CYBRA/modules/module_92_base/main.sh ;;
  93) bash ~/CYBRA/modules/module_93_base/main.sh ;;
  94) bash ~/CYBRA/modules/module_94_base/main.sh ;;
  95) bash ~/CYBRA/modules/module_95_base/main.sh ;;
  96) bash ~/CYBRA/modules/module_96_base/main.sh ;;
  97) bash ~/CYBRA/modules/module_97_base/main.sh ;;
  98) bash ~/CYBRA/modules/module_98_base/main.sh ;;
  99) bash ~/CYBRA/modules/module_99_base/main.sh ;;
  100) bash ~/CYBRA/modules/module_100_base/main.sh ;;
  101) bash ~/CYBRA/modules/module_101_base/main.sh ;;
  102) bash ~/CYBRA/modules/module_102_base/main.sh ;;
  103) bash ~/CYBRA/modules/module_103_base/main.sh ;;
  104) bash ~/CYBRA/modules/module_104_base/main.sh ;;
  105) bash ~/CYBRA/modules/module_105_base/main.sh ;;
  106) bash ~/CYBRA/modules/module_106_base/main.sh ;;
  107) bash ~/CYBRA/modules/module_107_base/main.sh ;;
  108) bash ~/CYBRA/modules/module_108_base/main.sh ;;
  109) bash ~/CYBRA/modules/module_109_base/main.sh ;;
  110) bash ~/CYBRA/modules/module_110_base/main.sh ;;
  111) bash ~/CYBRA/modules/module_111_base/main.sh ;;
  112) bash ~/CYBRA/modules/module_112_base/main.sh ;;
  113) bash ~/CYBRA/modules/module_113_base/main.sh ;;
  114) bash ~/CYBRA/modules/module_114_base/main.sh ;;
  115) bash ~/CYBRA/modules/module_115_base/main.sh ;;
  116) bash ~/CYBRA/modules/module_116_base/main.sh ;;
  117) bash ~/CYBRA/modules/module_117_base/main.sh ;;
  118) bash ~/CYBRA/modules/module_118_base/main.sh ;;
  119) bash ~/CYBRA/modules/module_119_base/main.sh ;;
  120) bash ~/CYBRA/modules/module_120_base/main.sh ;;
  121) bash ~/CYBRA/modules/module_121_base/main.sh ;;
  122) bash ~/CYBRA/modules/module_122_base/main.sh ;;
  123) bash ~/CYBRA/modules/module_123_base/main.sh ;;
  124) bash ~/CYBRA/modules/module_124_base/main.sh ;;
  125) bash ~/CYBRA/modules/module_125_base/main.sh ;;
  126) bash ~/CYBRA/modules/module_126_base/main.sh ;;
  127) bash ~/CYBRA/modules/module_127_base/main.sh ;;
  128) bash ~/CYBRA/modules/module_128_base/main.sh ;;
  129) bash ~/CYBRA/modules/module_129_base/main.sh ;;
  130) bash ~/CYBRA/modules/module_130_base/main.sh ;;
  131) bash ~/CYBRA/modules/module_131_base/main.sh ;;
  132) bash ~/CYBRA/modules/module_132_base/main.sh ;;
  133) bash ~/CYBRA/modules/module_133_base/main.sh ;;
  134) bash ~/CYBRA/modules/module_134_base/main.sh ;;
  135) bash ~/CYBRA/modules/module_135_base/main.sh ;;
  136) bash ~/CYBRA/modules/module_136_base/main.sh ;;
  137) bash ~/CYBRA/modules/module_137_base/main.sh ;;
  138) bash ~/CYBRA/modules/module_138_base/main.sh ;;
  139) bash ~/CYBRA/modules/module_139_base/main.sh ;;
  140) bash ~/CYBRA/modules/module_140_base/main.sh ;;
  141) bash ~/CYBRA/modules/module_141_base/main.sh ;;
  142) bash ~/CYBRA/modules/module_142_base/main.sh ;;
  143) bash ~/CYBRA/modules/module_143_base/main.sh ;;
  144) bash ~/CYBRA/modules/module_144_base/main.sh ;;
  145) bash ~/CYBRA/modules/module_145_base/main.sh ;;
  146) bash ~/CYBRA/modules/module_146_base/main.sh ;;
  147) bash ~/CYBRA/modules/module_147_base/main.sh ;;
  148) bash ~/CYBRA/modules/module_148_base/main.sh ;;
  149) bash ~/CYBRA/modules/module_149_base/main.sh ;;
  150) bash ~/CYBRA/modules/module_150_base/main.sh ;;
  151) bash ~/CYBRA/modules/module_151_base/main.sh ;;
  152) bash ~/CYBRA/modules/module_152_base/main.sh ;;
  153) bash ~/CYBRA/modules/module_153_base/main.sh ;;
  154) bash ~/CYBRA/modules/module_154_base/main.sh ;;
  155) bash ~/CYBRA/modules/module_155_base/main.sh ;;
  156) bash ~/CYBRA/modules/module_156_base/main.sh ;;
  157) bash ~/CYBRA/modules/module_157_base/main.sh ;;
  158) bash ~/CYBRA/modules/module_158_base/main.sh ;;
  159) bash ~/CYBRA/modules/module_159_base/main.sh ;;
  160) bash ~/CYBRA/modules/module_160_base/main.sh ;;
  999) python3 ~/CYBRA/bin/cybra-auto-repair.py ;;
  0) exit 0 ;;
  *) echo 'Невідома опція' ;;
esac
