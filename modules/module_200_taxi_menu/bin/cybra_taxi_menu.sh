#!/data/data/com.termux/files/usr/bin/bash
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
