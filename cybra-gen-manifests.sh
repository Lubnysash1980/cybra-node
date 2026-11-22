#!/data/data/com.termux/files/usr/bin/bash
# Авто-генерація manifest.json для модулів без нього
set -u
cd "$HOME/CYBRA" || exit 1

CREATED=0; SKIPPED=0; FAILED=0

# Визначення категорії за номером/назвою
categorize() {
    local name=$1
    case "$name" in
        module_2[0-2][0-9]_*) echo "taxi_core" ;;
        module_23[0-5]_*)    echo "taxi_ai" ;;
        module_236_*|module_237_*|module_238_*|module_239_*) echo "taxi_analytics" ;;
        module_24[0-5]_*)    echo "taxi_media" ;;
        module_246_*|module_24[7-8]_*|module_2[45][0-9]_*) echo "taxi_payment" ;;
        module_25[0-9]_*)    echo "taxi_ui" ;;
        ai-fixer|autofix)    echo "infra_fix" ;;
        notifier)            echo "infra_notify" ;;
        pool_v3)             echo "infra_pool" ;;
        rpc)                 echo "infra_rpc" ;;
        security)            echo "infra_security" ;;
        *)                   echo "misc" ;;
    esac
}

# Опис за назвою
purpose_of() {
    local name=$1
    case "$name" in
        *book_ride)         echo "Бронювання поїздки" ;;
        *cancel_ride)       echo "Скасування поїздки" ;;
        *ride_status)       echo "Статус поїздки" ;;
        *ride_history)      echo "Історія поїздок" ;;
        *estimate_price)    echo "Розрахунок вартості" ;;
        *select_tariff)     echo "Вибір тарифу" ;;
        *schedule_ride)     echo "Запланована поїздка" ;;
        *repeat_ride)       echo "Повторна поїздка" ;;
        *favorite_route)    echo "Улюблений маршрут" ;;
        *saved_addresses)   echo "Збережені адреси" ;;
        *driver_register)   echo "Реєстрація водія" ;;
        *driver_status)     echo "Статус водія" ;;
        *accept_ride)       echo "Прийняття поїздки" ;;
        *complete_ride)     echo "Завершення поїздки" ;;
        *driver_earnings)   echo "Заробіток водія" ;;
        *driver_documents)  echo "Документи водія" ;;
        *driver_rating)     echo "Рейтинг водія" ;;
        *dispatch_nearest)  echo "Диспетчеризація: найближчий" ;;
        *dispatch_batch)    echo "Диспетчеризація: пакетна" ;;
        *surge_pricing)     echo "Підвищений тариф" ;;
        *ride_payment)      echo "Оплата поїздки" ;;
        *ride_receipt)      echo "Чек поїздки" ;;
        *ride_refund)       echo "Повернення коштів" ;;
        *escrow_ride)       echo "Ескроу поїздки" ;;
        *driver_payout)     echo "Виплата водію" ;;
        *tip_driver)        echo "Чайові водію" ;;
        *subscription)      echo "Підписка" ;;
        *wallet_topup)      echo "Поповнення гаманця" ;;
        *payment_history)   echo "Історія платежів" ;;
        *promo_code)        echo "Промокод" ;;
        *ai_dispatcher)     echo "AI диспетчер" ;;
        *ai_chat_support)   echo "AI чат-підтримка" ;;
        *ai_route_optimize) echo "AI оптимізація маршруту" ;;
        *ai_demand_forecast) echo "AI прогноз попиту" ;;
        *ai_driver_scoring) echo "AI скоринг водіїв" ;;
        *ai_dispute)        echo "AI суперечки" ;;
        *rider_analytics)   echo "Аналітика пасажирів" ;;
        *driver_analytics)  echo "Аналітика водіїв" ;;
        *fleet_analytics)   echo "Аналітика автопарку" ;;
        *taxi_metrics)      echo "Метрики таксі" ;;
        *virtual_map)       echo "Віртуальна карта" ;;
        *map_zones)         echo "Зони карти" ;;
        *route_preference)  echo "Переваги маршруту" ;;
        *parking_priority)  echo "Пріоритет паркування" ;;
        *video_recorder)    echo "Відеозапис" ;;
        *media_player)      echo "Медіаплеєр" ;;
        *payment_instant)   echo "Миттєвий платіж" ;;
        *payment_commission) echo "Комісія платежу" ;;
        *payment_contract)  echo "Контракт платежу" ;;
        *wallet_connect)    echo "Підключення гаманця" ;;
        *wallet_list)       echo "Список гаманців" ;;
        *wallet_balance)    echo "Баланс гаманця" ;;
        *price_adaptive)    echo "Адаптивна ціна" ;;
        *price_per_km)      echo "Ціна за км" ;;
        *ai_match)          echo "AI підбір" ;;
        *ai_zone_optimize)  echo "AI оптимізація зон" ;;
        *rating_view)       echo "Перегляд рейтингу" ;;
        *rating_comments)   echo "Коментарі рейтингу" ;;
        *eco_global)        echo "Еко-глобальне" ;;
        *ui_theme)          echo "UI тема" ;;
        *taxi_menu)         echo "Головне меню таксі" ;;
        ai-fixer)           echo "AI автофіксер" ;;
        autofix)            echo "Автофікс" ;;
        notifier)           echo "Нотифікатор" ;;
        pool_v3)            echo "Пул v3" ;;
        rpc)                echo "RPC" ;;
        security)           echo "Безпека" ;;
        *)                  echo "Модуль $name" ;;
    esac
}

# Redis prefix з коду
redis_prefix_of() {
    local dir=$1
    local found=$(grep -hoE 'KEY="[^"]+"' "$dir/bin"/*.sh "$dir/main.sh" 2>/dev/null | head -1 | sed 's/KEY="//;s/"//')
    [ -z "$found" ] && found="cybra:module:$(basename "$dir" | sed 's/^module_[0-9]*_//'):data"
    echo "$found"
}

# Count bin files
count_bin() { ls "$1/bin" 2>/dev/null | wc -l | tr -d ' '; }

# ── MAIN LOOP ──
for m in modules/*/; do
    [ -d "$m" ] || continue
    name=$(basename "$m")
    [ "$name" = "node_modules" ] && continue

    # Skip if manifest exists
    if [ -f "$m/manifest.json" ]; then
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    # Skip if no code at all
    if [ ! -f "$m/main.sh" ] && [ ! -d "$m/bin" ]; then
        continue
    fi

    cat=$(categorize "$name")
    purpose=$(purpose_of "$name")
    prefix=$(redis_prefix_of "$m")
    bins=$(count_bin "$m")
    version="1.0.0"
    has_main="false"; [ -f "$m/main.sh" ] && has_main="true"

    cat > "$m/manifest.json" <<MANIFEST
{
  "name": "$name",
  "version": "$version",
  "category": "$cat",
  "description": "$purpose",
  "type": "redis-module",
  "redis_prefix": "$prefix",
  "entry": {
    "main": $has_main,
    "bin_count": $bins
  },
  "auto_generated": true,
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
MANIFEST

    CREATED=$((CREATED+1))
done

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Створено: $CREATED"
echo "  ⏭  Пропущено (вже мали): $SKIPPED"
echo "  ❌ Помилок: $FAILED"
echo "═══════════════════════════════════════"
