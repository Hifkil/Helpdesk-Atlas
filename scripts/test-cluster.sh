#!/usr/bin/env bash
# test-cluster.sh — Recette non intrusive du cluster atlas (Test C1)
# Usage (sur hv01) : bash test-cluster.sh | tee /root/recette-cluster_$(date +%F_%H%M).log
# Sortie : PASS/FAIL par contrôle, horodaté. Aucune modification d'état.
set -u

OTHER_NODE_IP="${OTHER_NODE_IP:-10.90.0.12}"   # depuis hv01 ; exporter 10.90.0.11 si lancé depuis hv02
OTHER_NODE_NAME="${OTHER_NODE_NAME:-hv02}"
PASS=0; FAIL=0

say()  { printf '%s %s\n' "$(date '+%F %T')" "$*"; }
ok()   { say "PASS  $1"; PASS=$((PASS+1)); }
ko()   { say "FAIL  $1"; FAIL=$((FAIL+1)); }

say "=== Recette cluster atlas — $(hostname) ==="
say "pveversion: $(pveversion 2>/dev/null || echo 'indisponible')"

# 1. Quorum complet
PVECM=$(pvecm status 2>/dev/null)
echo "$PVECM"
echo "$PVECM" | grep -q "Quorate:.*Yes" && ok "Quorate: Yes" || ko "cluster non quorate"
VOTES=$(echo "$PVECM" | awk '/^Total votes:/ {print $3}')
[ "${VOTES:-0}" = "3" ] && ok "3 votes / 3 (2 noeuds + QDevice)" || ko "votes = ${VOTES:-?} (attendu 3)"

# 2. QDevice présent et votant
echo "$PVECM" | grep -Eq "Qdevice( |$)" && ok "QDevice listé dans le membership" || ko "QDevice absent du membership"
echo "$PVECM" | grep -q "Qdevice.*A,V" && ok "QDevice Alive + Vote" || say "INFO  vérifier flags QDevice manuellement (A,V attendus)"

# 3. Liens corosync
CFG=$(corosync-cfgtool -s 2>/dev/null)
echo "$CFG"
echo "$CFG" | grep -q "connected" && ok "link0 corosync connected" || ko "link corosync non connecté"

# 4. Latence vRack
if PING=$(ping -c 10 -q "$OTHER_NODE_IP" 2>/dev/null); then
  LOSS=$(echo "$PING" | grep -oP '\d+(?=% packet loss)')
  AVG=$(echo "$PING" | awk -F'/' '/rtt/ {print $5}')
  echo "$PING" | tail -2
  [ "${LOSS:-100}" = "0" ] && ok "0% perte vers $OTHER_NODE_IP" || ko "perte ${LOSS}% vers $OTHER_NODE_IP"
  awk -v a="${AVG:-999}" 'BEGIN{exit !(a<1.0)}' && ok "latence moyenne ${AVG} ms (< 1 ms)" || say "INFO  latence moyenne ${AVG:-?} ms (attendu < 1 ms sur vRack)"
else
  ko "ping $OTHER_NODE_IP impossible"
fi

# 5. SSH croisé
REMOTE=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$OTHER_NODE_IP" hostname 2>/dev/null)
[ "$REMOTE" = "$OTHER_NODE_NAME" ] && ok "SSH croisé -> $REMOTE" || ko "SSH croisé KO (reçu: '${REMOTE:-rien}')"

# 6. Storages partagés
PVESM=$(pvesm status 2>/dev/null)
echo "$PVESM"
echo "$PVESM" | grep -E "^zfs-data" | grep -q "active" && ok "zfs-data actif" || ko "zfs-data inactif"
echo "$PVESM" | grep -E "^pbs01"    | grep -q "active" && ok "storage pbs01 actif" || ko "storage pbs01 inactif"

# 7. Réplication pvesr
if PVESR=$(pvesr status 2>/dev/null) && [ "$(echo "$PVESR" | wc -l)" -gt 1 ]; then
  echo "$PVESR"
  # colonnes : JobID Enabled Target LastSync NextSync Duration FailCount State
  NJOBS=$(echo "$PVESR" | awk 'NR>1' | wc -l)
  BAD=$(echo "$PVESR" | awk 'NR>1 && ($7 > 0 || ($8 != "OK" && $8 != "SYNCING"))' | wc -l)
  [ "$BAD" -eq 0 ] && ok "pvesr : $NJOBS jobs, 0 en erreur" || ko "pvesr : $BAD job(s) en erreur ou FailCount > 0 (sur $NJOBS)"
else
  say "INFO  pvesr sans sortie sur ce noeud (jobs portés par l'autre noeud ?) — vérifier côté $OTHER_NODE_NAME"
fi

say "=== Bilan : $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && say "RECETTE C1 : OK — archiver ce log dans docs/preuves/" || say "RECETTE C1 : ECHEC — corriger avant les tests C2/C3"
exit "$FAIL"
