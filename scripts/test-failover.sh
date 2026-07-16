#!/usr/bin/env bash
# test-failover.sh — Test C3 : perte du noeud hv02, guidé et horodaté (à lancer sur hv01)
# Le script N'ETEINT PAS hv02 lui-même : il vous demande de le faire (poweroff ou Manager OVH),
# puis surveille le quorum, chronomètre la réintégration et journalise tout.
# Usage : bash test-failover.sh | tee /root/test-failover_$(date +%F_%H%M).log
set -u

TARGET_IP="${TARGET_IP:-10.90.0.12}"
TARGET_NAME="${TARGET_NAME:-hv02}"

stamp() { date '+%F %T'; }
say()   { printf '%s %s\n' "$(stamp)" "$*"; }
quorum_snapshot() { pvecm status 2>/dev/null | grep -E "Quorate|Total votes|Expected votes" ; }

say "=== TEST C3 — perte de $TARGET_NAME ==="
say "Pré-vol : état nominal attendu (3/3, Quorate: Yes)"
quorum_snapshot
pvecm status 2>/dev/null | grep -q "Quorate:.*Yes" || { say "ABANDON : cluster déjà non quorate."; exit 1; }
read -rp "$(stamp) Backup PBS < 24h et verify OK ? [oui/NON] " CONF
[ "$CONF" = "oui" ] || { say "ABANDON : faire un R1 d'abord."; exit 1; }

say ">>> ACTION MANUELLE : éteignez $TARGET_NAME maintenant"
say "    option propre  : ssh $TARGET_IP 'systemctl poweroff'"
say "    option radicale: reboot/hard stop via le Manager OVH (vrai test de panne)"
read -rp "$(stamp) Appuyez sur Entrée UNE FOIS l'ordre d'extinction envoyé... " _
T0=$(date +%s); say "T0 noté."

say "Attente de la perte de $TARGET_NAME (ping)..."
while ping -c1 -W1 "$TARGET_IP" >/dev/null 2>&1; do sleep 2; done
T_DOWN=$(date +%s); say "$TARGET_NAME injoignable après $((T_DOWN-T0)) s."

say "--- PENDANT LA PANNE : le quorum doit rester Yes à 2/3 SANS intervention ---"
for i in 1 2 3; do
  sleep 10
  say "contrôle $i/3 :"; quorum_snapshot
done
if pvecm status 2>/dev/null | grep -q "Quorate:.*Yes"; then
  say "PASS  Quorum conservé (QDevice supplée $TARGET_NAME). Aucun 'pvecm expected 1' nécessaire."
else
  say "FAIL  Quorum perdu — vérifier le QDevice (corosync-qnetd, port 5403/tcp) AVANT de continuer."
fi
say "Contrôle service conseillé depuis un poste VPN : curl -I https://helpdesk.atlas.local (attendu 200)."
read -rp "$(stamp) Service GLPI vérifié ? Notez le résultat, puis Entrée... " _

say ">>> ACTION MANUELLE : redémarrez $TARGET_NAME (Manager OVH)."
read -rp "$(stamp) Entrée une fois l'ordre de boot envoyé... " _
T_BOOT=$(date +%s)

say "Attente du retour ping de $TARGET_NAME..."
until ping -c1 -W1 "$TARGET_IP" >/dev/null 2>&1; do sleep 5; done
T_PING=$(date +%s); say "$TARGET_NAME répond au ping (+$((T_PING-T_BOOT)) s après ordre de boot)."

say "Attente de la réintégration cluster (3/3)..."
until pvecm status 2>/dev/null | awk '/^Total votes:/{v=$3} END{exit v!=3}'; do sleep 5; done
T_JOIN=$(date +%s)
say "PASS  Réintégration : 3/3 votes, +$((T_JOIN-T_PING)) s après le retour ping (attendu < 60 s)."
quorum_snapshot

say "Post-contrôles : pvesr status (jobs repartent), pbs01/zbx01 up, 'qm list' sans doublon."
say "=== FIN — archiver ce log dans docs/preuves/ et reporter les mesures dans 17-procedure-test-cluster.md ==="
