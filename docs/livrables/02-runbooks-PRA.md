# Runbooks PRA — R1 à R5 (pré-remplis)
*Livrable 2. À éclater en 5 fichiers dans `docs/runbooks/`. Colonnes « Mesuré » à remplir lors des tests réels — ce sont vos preuves RPO/RTO. Le R0 (installation/provisionnement) existe déjà via le journal + rituel.*

---

## R1 — EXPORT (sauvegarde complète)
**Déclencheur** : planifié (quotidien) + avant toute opération risquée. **Objectif** : jeu de sauvegardes cohérent et vérifié sur pbs01.

| # | Étape | Commande/action | Vérif succès | Estimé | Mesuré (test réel 15/07/2026 22:43–22:52 UTC) |
|---|---|---|---|---|---|
| 1 | Dump logique BDD | `mariadb-dump --single-transaction --flush-logs --master-data=2 glpidb \| gzip > /backup/glpidb_$(date +%F_%H%M).sql.gz` | fichier > 0, exit 0 | 2 min | **1 s**, 274 Ko, gzip -t OK |
| 2 | Rotation binlog | `--flush-logs` ci-dessus ouvre un nouveau binlog | `SHOW BINARY LOGS;` nouveau fichier | 0 min | ✅ `binlog.000009` ouvert (pos 379 dans l'en-tête du dump) |
| 3 | Push dump vers pbs01 | `. /root/.pbs-env && proxmox-backup-client backup glpidb-dumps.pxar:/backup` (choix acté 15/07 : client PBS, dépôt `pbs-client` trixie ajouté sur db01, creds root-only `/root/.pbs-env`) | `proxmox-backup-client snapshot list host/db01` | 1 min | **< 1 s** — snapshot `host/db01/2026-07-15T23:07:24Z`, 274,6 Kio |
| 4 | Backup VM (toutes) | Job PBS planifié (Datacenter→Backup) — mode snapshot | tâche verte, taille loggée | 10-15 min | **22 s** — 10 VM, incrémental dirty-bitmaps (98-100 % réutilisé), RC=0 |
| 5 | Vérification intégrité | Job verify PBS | verify OK | 5 min | **62 s** — 10/10 groupes, 0 erreur, TASK OK (déclenché via API PBS, compte `pve-backup@pbs`) |
| 6 | Journal | taille + durée + statut → journal de preuves | entrée créée | 2 min | ✅ ligne du 15/07 22:43 UTC |

**DoD** : dump récent < 24 h, backup VM verify OK, métrique Zabbix « succès sauvegarde » verte.

> ✅ **Automatisé depuis le 15/07/2026 23:16 UTC** : timer systemd `glpidb-backup` sur db01 (étapes 1-3, quotidien 20:30 UTC, 30 min avant le job vzdump de 21:00 ; script `/usr/local/sbin/glpidb-backup.sh`, rétention locale 7 j). Nota : service `Type=oneshot` → `inactive (dead)` entre deux passages = normal (même comportement que glpi-cron).

---

## R2 — RESTORE FULL (incident 1 : perte stockage primaire)
**Déclencheur** : VM glpi01 perdue/corrompue. **Objectif** : service restauré **en lecture seule** sur un nouvel hôte. **RTO cible ≤ 40 min.**

| # | Étape | Commande/action | Vérif | Estimé | Mesuré |
|---|---|---|---|---|---|
| 1 | T0 : constat + décision | noter l'heure, prévenir l'équipe | journal | 2 min | |
| 2 | Identifier dernier backup valide | GUI PBS → snapshots glpi01 (verify OK) | snapshot choisi noté | 2 min | |
| 3 | Restauration vers hv02 | GUI hv02 → Restore (nouvel VMID ou même) | tâche verte | 10-15 min | |
| 4 | Adapter réseau si besoin | tag 20 présent, IP inchangée | ping gw | 2 min | |
| 5 | Démarrer + vérifier services | nginx/php up, GLPI répond | http 200 | 3 min | |
| 6 | **Mode dégradé lecture seule** | ⬜ GLPI : maintenance/lecture seule (option légale : verrous DB `SET GLOBAL read_only=1` si perte inclut db01) | bannière visible, écriture refusée | 3 min | |
| 7 | Contrôle données | ticket témoin présent | capture | 2 min | |
| 8 | Journal : T0→Tfin | RTO mesuré | ≤ 40 min ✔ | 2 min | |

**Plan B** : si backup PBS invalide → réplique ZFS (R4 partiel).

---

## R3 — RESTORE GRANULAIRE (incident 2 : suppression ≥ 10 tickets)
**Déclencheur** : suppression accidentelle d'un lot de tickets à T_incident. **Objectif** : tickets restaurés **sans perdre** ceux créés après. **RPO démontré ≤ 20 min.**

Principe : dump de la veille + rejeu des binlogs jusqu'à T_incident (point-in-time) dans une base temporaire, puis réinjection ciblée.

| # | Étape | Commande/action | Vérif | Estimé | Mesuré |
|---|---|---|---|---|---|
| 1 | Geler les écritures (fenêtre courte) | bannière GLPI / maintenance | | 2 min | |
| 2 | Identifier T_incident | logs GLPI + `mariadb-binlog --base64-output=decode-rows -vv` (chercher les DELETE) | position/timestamp notés | 5 min | |
| 3 | Restaurer dump dans base temporaire | `mariadb -e "CREATE DATABASE glpidb_pit"` + restore dump | base peuplée | 5 min | |
| 4 | Rejouer binlogs → T_incident | `mariadb-binlog --stop-datetime="…" binlog.0000NN \| mariadb glpidb_pit` | tables tickets à T-1s | 5 min | |
| 5 | Extraire les tickets supprimés | `mariadb-dump glpidb_pit glpi_tickets --where="id IN (…)"` (+ tables liées : followups, documents…) ⬜ affiner la liste des tables | dump ciblé | 5 min | |
| 6 | Réinjecter dans glpidb | import du dump ciblé | tickets visibles dans GLPI | 3 min | |
| 7 | Contrôles | ≥10 tickets revenus **ET** tickets post-incident intacts | double capture | 3 min | |
| 8 | Nettoyage + journal | DROP glpidb_pit ; RPO/RTO notés | | 2 min | |

⬜ À préparer AVANT le test : liste exacte des tables GLPI liées à un ticket (itemtypes) — à valider sur un ticket de test.

---

## R4 — BASCULE DR (perte de hv01)
**Déclencheur** : hv01 injoignable/HS. **Objectif** : service complet re-rendu depuis hv02.

| # | Étape | Commande/action | Vérif | Estimé | Mesuré |
|---|---|---|---|---|---|
| 1 | Constat + décision de bascule | ping/console/OVH status ; décision notée (bascule = acte humain assumé) | | 3 min | |
| 2 | Vérifier quorum | `pvecm status` sur hv02 → Quorate: Yes (2/3 avec QDevice) et nœud hv02 `A,V,NMW` | capture | 1 min | |
| 3 | Déplacer le WAN public | Manager OVH **Move Additional IP** vers `ns3201919.ip-146-59-47.eu`, ou API `POST /dedicated/server/{serviceName}/ipMove` avec `serviceName=ns3201919.ip-146-59-47.eu` et `ip=51.75.38.225` | l'IP puis la vMAC unique `02:00:00:ff:3e:98` apparaissent sur hv02 | 5-10 min | |
| 4 | Démarrer les répliques (ordre !) | vérifier `net0` de fw01 = même vMAC + `bridge=vmbr0`, puis fw01 → dns01 → db01 → mail01 → glpi01 → rp01 (disques via pvesr ; `qm start`) | chaque VM up ; WAN = 51.75.38.225/32 | 10 min | |
| 5 | Contrôles de service | `curl -4 ifconfig.me` = 51.75.38.225 ; DNS ; parcours ticket→mail ; dashboard Zabbix | captures | 5 min | |
| 6 | Journal : perte de données constatée | delta depuis dernière réplication (≤ 15 min) → **RPO mesuré** | ≤ 20 min ✔ | 2 min | |

⚠️ Préalables : jobs pvesr configurés (15 min) sur les 6 VM critiques (✅ **actifs depuis le 15/07/2026 22:42 UTC**, 1re passe complète en 5 min 18 s — fw01 154,6 s · dns01 30,7 s · rp01 28,1 s · glpi01 48,0 s · mail01 37,5 s · db01 46,9 s) ; routes 10.20/10.30 présentes sur hv02 via `vmbr1.90` ; `vmbr0` public présent avec le même nom sur hv02 ; serveur cible compatible vMAC. **Ne pas recréer la vMAC en fonctionnement nominal** : OVH indique qu'une vMAC unique est suspendue pendant le déplacement puis réapparaît sur le serveur cible. `vmbr2` n'est qu'un plan B de dépannage, pas un prérequis.

---

## R5 — RETOUR ARRIÈRE (hv01 réparé)
**Objectif** : revenir à la nominale **sans perdre** les données créées pendant la bascule.

| # | Étape | Commande/action | Vérif | Estimé | Mesuré |
|---|---|---|---|---|---|
| 1 | hv01 revient : NE PAS démarrer ses anciennes VM | `qm set … --onboot 0` préventif / vérifier | pas de double-run (split-brain applicatif) | 2 min | |
| 2 | Cluster sain | `pvecm status` 3/3, QDevice connecté | | 1 min | |
| 3 | Inverser la réplication | jobs pvesr hv02→hv01, attendre 1 cycle | state OK | 15-20 min | |
| 4 | Fenêtre de retour WAN | arrêter proprement fw01 sur hv02 ; déplacer `51.75.38.225` vers `ns3201873.ip-146-59-47.eu` ; attendre le retour de la même vMAC sur hv01 | IP/vMAC visibles sur hv01 | 5-10 min | |
| 5 | Dernière synchronisation + démarrage | dernière sync ; démarrage sur hv01 dans l'ordre fw01 → dns01 → db01 → mail01 → glpi01 → rp01 | services OK, pas de double-run | 10 min | |
| 6 | Ré-inverser la réplication + contrôles | remettre hv01→hv02 ; vérifier données de la période dégradée et `curl -4 ifconfig.me` | jobs verts ; ticket témoin visible ; IP 51.75.38.225 | 5 min | |


> Référence réseau OVHcloud vérifiée le 06/07/2026 : *Moving an Additional IP* (`POST /dedicated/server/{serviceName}/ipMove`) ; une vMAC unique suit le déplacement entre serveurs compatibles.
