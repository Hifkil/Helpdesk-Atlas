# Matrice de risques + BIA light · Helpdesk Atlas
*Livrable 3. Échelles : Probabilité/Impact 1-4. Criticité = P×I. Pré-rempli avec les risques réels du projet — compléter, ajuster les cotations en équipe.*

## 1. Matrice de risques

| ID | Risque | P | I | Crit. | Mitigation en place | Résiduel / action |
|---|---|---|---|---|---|---|
| R01 | Panne disque NVMe | 2 | 3 | 6 | ZFS mirror sur chaque nœud | Surveillance SMART/zpool via Zabbix ⬜ |
| R02 | Perte d'un hyperviseur | 2 | 4 | 8 | Cluster + QDevice + réplication 15 min + runbook R4 | Bascule manuelle : décision < 10 min |
| R03 | Erreur humaine (suppression tickets) | 3 | 3 | 9 | Binlogs ROW + dump quotidien + runbook R3 | Test point-in-time programmé |
| R04 | Corruption/perte VM | 2 | 4 | 8 | PBS quotidien + verify + runbook R2 | ⬜ test restore programmé (livrable supervision) |
| R05 | Compromission compte admin | 2 | 4 | 8 | Clés SSH only, comptes nominatifs, TOTP ⬜, 8006 non exposé ⬜ | Journalisation des actions PVE |
| R06 | Fuite de secret (DB, etc.) | 2 | 3 | 6 | Comptes restreints par IP, secrets hors VCS, rotation (éprouvée 1×) | — |
| R07 | Panne fw01 (SPOF assumé) | 2 | 4 | 8 | Réplique ZFS + redémarrage sur hv02 (RTO ~3 min) | CARP documenté comme évolution |
| R08 | Défaillance QDevice (VPS tiers) | 2 | 2 | 4 | Cluster reste quorate à 2/3 ; critique seulement pendant panne simultanée d'un nœud | Check Zabbix du qnetd ⬜ |
| R09 | Saturation SMTP / mails non partis | 2 | 2 | 4 | Métrique Zabbix « file Postfix » (exigence sujet) | Alerte sur seuil ⬜ |
| R10 | Indisponibilité datacenter OVH waw | 1 | 4 | 4 | Sauvegardes ⬜ copie hors site (Dedibackup/autre région) | Décision copie hors site à prendre |
| R11 | Dérive de configuration non tracée | 2 | 3 | 6 | Journal de bord, repo Git, exports de config | Discipline d'équipe |
| R12 | Échec de démo en soutenance | 2 | 4 | 8 | Répétitions ×2, check-list démo (QDevice/VPS up !), captures de secours si live impossible | Plan B : dérouler les preuves enregistrées |
| R13 | ⬜ | | | | | |

## 2. BIA light (analyse d'impact métier)

| Service | Impact si indisponible | Tolérance métier | RTO cible | RPO cible | Dépendances |
|---|---|---|---|---|---|
| GLPI (tickets) | Les employés ne peuvent plus déclarer/suivre les incidents IT | Heures ouvrées : fort | ≤ 40 min | ≤ 20 min | db01, dns01, rp01, fw01 |
| MariaDB | GLPI totalement HS (données) | Critique | ≤ 40 min | ≤ 20 min | fw01, dns01 |
| Notifications mail | Dégradé : tickets traités sans alerte | Moyen (mode dégradé acceptable) | ≤ 4 h | ≤ 1 h | mail01 |
| Supervision | Perte de visibilité (pas d'impact utilisateur direct) | Faible court terme | ≤ 8 h | — | zbx01 |
| Sauvegardes | Risque différé (pas d'impact immédiat) | Aucune sauvegarde > 24 h = inacceptable | ≤ 24 h | — | pbs01 |
| DNS interne | Pannes en cascade (résolutions) | Fort | ≤ 1 h | — | dns01 |

**Priorité de reprise (ordre de redémarrage)** : fw01 → dns01 → db01 → mail01 → glpi01 → rp01 → zbx01 → pbs01.

## 3. ⬜ Acceptation des risques
Une phrase par risque résiduel accepté, signée « équipe projet » (ex. R07 : SPOF firewall accepté au regard du RTO exigé et documenté comme évolution).
