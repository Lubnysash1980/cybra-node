#!/data/data/com.termux/files/usr/bin/bash
<<<<<<< HEAD
# CYBRA TAXI MENU
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
NOTIFY="bash $CYBRA/bin/cybra_notify.sh bar 2>/dev/null"

show_header() {{
  clear 2>/dev/null
  echo "════════════════════════════════════════════════════════════"
  echo "  🚕 CYBRA TAXI — GLOBAL SERVICE  │  40 modules (200-239)"
  echo "  $(eval $NOTIFY)"
  echo "  $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
  echo "────────────────────────────────────────────────────────────"
}}

main_menu() {{
  show_header
  echo ""
  echo "  ─── BOOKING (rider) ───"
  echo "  [200] Book ride           [201] Cancel          [202] Ride status"
  echo "  [203] History             [204] Estimate        [205] Select tariff"
  echo "  [206] Schedule            [207] Repeat          [208] Favorite route"
  echo "  [209] Saved addresses"
  echo ""
  echo "  ─── DRIVER ───"
  echo "  [210] Register            [211] Status          [212] Accept ride"
  echo "  [213] Complete            [214] Earnings        [215] Documents"
  echo "  [216] Rating"
  echo ""
  echo "  ─── DISPATCH ───"
  echo "  [217] Nearest             [218] Batch           [219] Surge"
  echo ""
  echo "  ─── PAYMENT ───"
  echo "  [220] Charge              [221] Receipt         [222] Refund"
  echo "  [223] Escrow              [224] Payout          [225] Tip"
  echo "  [226] Subscription        [227] Topup           [228] History"
  echo "  [229] Promo"
  echo ""
  echo "  ─── AI SUPPORT ───"
  echo "  [230] AI dispatcher       [231] AI chat         [232] Route optimize"
  echo "  [233] Demand forecast     [234] Driver scoring  [235] AI dispute"
  echo ""
  echo "  ─── ANALYTICS ───"
  echo "  [236] Rider               [237] Driver          [238] Fleet"
  echo "  [239] Metrics"
  echo ""
  echo "  [n] Notifications         [h] Health           [0] Exit"
  echo ""
  read -r -p "  Choice: " c
  case "$c" in
    200|201|202|203|204|205|206|207|208|209|210|211|212|213|214|215|216|217|218|219|220|221|222|223|224|225|226|227|228|229|230|231|232|233|234|235|236|237|238|239)
      MOD=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_${{c}}_*" 2>/dev/null | head -1)
      CTRL="$CYBRA/controllers/taxi_module_${{c}}.ctrl.sh"
      [ -f "$CTRL" ] && [ -n "$MOD" ] && bash "$CTRL" "$MOD/main.sh"
      read -r -p "Enter..." _ ;;
    n|N) bash "$CYBRA/bin/cybra_notify.sh" list 20; read -r -p "Enter..." _ ;;
    h|H) bash "$CYBRA/bin/cybra_health.sh" 2>&1 | tail -10; read -r -p "Enter..." _ ;;
    0|q|Q) exit 0 ;;
    *) ;;
  esac
}}

while true; do main_menu; done
=======
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null
while true; do
  clear 2>/dev/null
  echo "════ CYBRA TAXI (40 modules) ════"
  bash "$HOME/CYBRA/bin/cybra_notify.sh" bar 2>/dev/null
  echo ""
  echo "  [200] book_ride"
  echo "  [201] cancel_ride"
  echo "  [202] ride_status"
  echo "  [203] ride_history"
  echo "  [204] estimate_price"
  echo "  [205] select_tariff"
  echo "  [206] schedule_ride"
  echo "  [207] repeat_ride"
  echo "  [208] favorite_route"
  echo "  [209] saved_addresses"
  echo "  [210] driver_register"
  echo "  [211] driver_status"
  echo "  [212] accept_ride"
  echo "  [213] complete_ride"
  echo "  [214] driver_earnings"
  echo "  [215] driver_documents"
  echo "  [216] driver_rating"
  echo "  [217] dispatch_nearest"
  echo "  [218] dispatch_batch"
  echo "  [219] surge_pricing"
  echo "  [220] ride_payment"
  echo "  [221] ride_receipt"
  echo "  [222] ride_refund"
  echo "  [223] escrow_ride"
  echo "  [224] driver_payout"
  echo "  [225] tip_driver"
  echo "  [226] subscription"
  echo "  [227] wallet_topup"
  echo "  [228] payment_history"
  echo "  [229] promo_code"
  echo "  [230] ai_dispatcher"
  echo "  [231] ai_chat_support"
  echo "  [232] ai_route_optimize"
  echo "  [233] ai_demand_forecast"
  echo "  [234] ai_driver_scoring"
  echo "  [235] ai_dispute"
  echo "  [236] rider_analytics"
  echo "  [237] driver_analytics"
  echo "  [238] fleet_analytics"
  echo "  [239] taxi_metrics"
  echo "  [n] Notif [0] Exit"
  read -r -p "  Choice: " c
  case "$c" in
    200) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_200_*" | head -1); bash "$CYBRA/controllers/taxi_module_200.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    201) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_201_*" | head -1); bash "$CYBRA/controllers/taxi_module_201.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    202) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_202_*" | head -1); bash "$CYBRA/controllers/taxi_module_202.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    203) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_203_*" | head -1); bash "$CYBRA/controllers/taxi_module_203.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    204) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_204_*" | head -1); bash "$CYBRA/controllers/taxi_module_204.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    205) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_205_*" | head -1); bash "$CYBRA/controllers/taxi_module_205.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    206) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_206_*" | head -1); bash "$CYBRA/controllers/taxi_module_206.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    207) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_207_*" | head -1); bash "$CYBRA/controllers/taxi_module_207.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    208) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_208_*" | head -1); bash "$CYBRA/controllers/taxi_module_208.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    209) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_209_*" | head -1); bash "$CYBRA/controllers/taxi_module_209.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    210) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_210_*" | head -1); bash "$CYBRA/controllers/taxi_module_210.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    211) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_211_*" | head -1); bash "$CYBRA/controllers/taxi_module_211.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    212) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_212_*" | head -1); bash "$CYBRA/controllers/taxi_module_212.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    213) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_213_*" | head -1); bash "$CYBRA/controllers/taxi_module_213.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    214) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_214_*" | head -1); bash "$CYBRA/controllers/taxi_module_214.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    215) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_215_*" | head -1); bash "$CYBRA/controllers/taxi_module_215.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    216) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_216_*" | head -1); bash "$CYBRA/controllers/taxi_module_216.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    217) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_217_*" | head -1); bash "$CYBRA/controllers/taxi_module_217.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    218) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_218_*" | head -1); bash "$CYBRA/controllers/taxi_module_218.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    219) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_219_*" | head -1); bash "$CYBRA/controllers/taxi_module_219.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    220) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_220_*" | head -1); bash "$CYBRA/controllers/taxi_module_220.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    221) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_221_*" | head -1); bash "$CYBRA/controllers/taxi_module_221.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    222) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_222_*" | head -1); bash "$CYBRA/controllers/taxi_module_222.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    223) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_223_*" | head -1); bash "$CYBRA/controllers/taxi_module_223.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    224) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_224_*" | head -1); bash "$CYBRA/controllers/taxi_module_224.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    225) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_225_*" | head -1); bash "$CYBRA/controllers/taxi_module_225.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    226) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_226_*" | head -1); bash "$CYBRA/controllers/taxi_module_226.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    227) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_227_*" | head -1); bash "$CYBRA/controllers/taxi_module_227.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    228) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_228_*" | head -1); bash "$CYBRA/controllers/taxi_module_228.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    229) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_229_*" | head -1); bash "$CYBRA/controllers/taxi_module_229.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    230) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_230_*" | head -1); bash "$CYBRA/controllers/taxi_module_230.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    231) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_231_*" | head -1); bash "$CYBRA/controllers/taxi_module_231.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    232) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_232_*" | head -1); bash "$CYBRA/controllers/taxi_module_232.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    233) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_233_*" | head -1); bash "$CYBRA/controllers/taxi_module_233.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    234) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_234_*" | head -1); bash "$CYBRA/controllers/taxi_module_234.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    235) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_235_*" | head -1); bash "$CYBRA/controllers/taxi_module_235.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    236) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_236_*" | head -1); bash "$CYBRA/controllers/taxi_module_236.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    237) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_237_*" | head -1); bash "$CYBRA/controllers/taxi_module_237.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    238) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_238_*" | head -1); bash "$CYBRA/controllers/taxi_module_238.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    239) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_239_*" | head -1); bash "$CYBRA/controllers/taxi_module_239.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;
    n|N) bash "$CYBRA/bin/cybra_notify.sh" list 20; read -r _ ;;
    0|q) exit 0 ;;
  esac
done
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
