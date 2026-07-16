# Cahier de recette — jeux de tests & résultats · Helpdesk Atlas
*Livrable 8. Structure = les 3 recettes de la Partie B §7. Chaque test : préparé AVANT, exécuté avec captures/timings, verdict. Tests déjà passés pré-remplis.*

**Format d'un test** : ID · Objectif · Pré-requis · Étapes · Résultat attendu · Résultat obtenu · Preuve (capture/log) · Verdict ✅/❌ · Date/opérateur.

## A. Recette fonctionnelle (parcours utilisateur)
| ID | Test | Attendu | Verdict |
|---|---|---|---|
| F01 | Création ticket avec PJ par un agent | Ticket créé, PJ liée | ⬜ |
| F02 | Notification mail à la création | Mail reçu < 1 min (file Postfix vide ensuite) | ✅ |
| F03 | Affectation + suivi + résolution + clôture | Statuts corrects, mails à chaque étape | ✅ |
| F04 | Recherche/filtres + rapport volumétrie | Résultats cohérents | ⬜ |
| F05 | Accès HTTPS (cert valide/trust documenté) | Pas d'alerte non documentée | ⬜ |

## B. Recette technique (infrastructure & PRA)
| ID | Test | Attendu | Verdict |
|---|---|---|---|
| T01 | Interconnexion vRack (latence, SSH croisé) | < 1 ms, scripts OK | ✅ 04/07 — captures test-cluster.sh |
| T02 | Tolérance perte d'un nœud (quorum) | Quorate: Yes à 2/3 votes, réintégration < 60 s | ✅ 04/07 — test-failover.sh |
| T03 | Segmentation : deny inter-VLAN par défaut | Ping bloqué sans règle (log firewall) | ✅ 05/07 (ADMIN) — à re-capturer après matrice finale ⬜ |
| T04 | Résolution DNS interne + reverses + récursion | 5 dig conformes | ✅ 05/07 |
| T05 | Binlogs opérationnels (ROW, rejouables) | INSERT/DROP visibles via mariadb-binlog | ✅ 05/07 |
| T06 | Sauvegarde PBS + verify + taux de succès mesuré | Jobs verts, métrique Zabbix | ⬜ |
| T07 | **Incident 1** : restore full + mode dégradé RO | **RTO mesuré ≤ 40 min** | ⬜ (journal + runbook R2) |
| T08 | **Incident 2** : restauration sélective ≥ 10 tickets | Tickets restaurés, post-incident intacts, **RPO ≤ 20 min** | ⬜ (R3) |
| T09 | Bascule DR hv01→hv02 + retour | Service re-rendu, delta ≤ 15 min, retour sans perte | ⬜ (R4/R5) |
| T10 | Reboot à froid de chaque VM | IP + services reviennent seuls | ✅ dns01 le 06/07 : ICMP revenu en ~12 s, `named` actif, DNS direct/inverse/externe OK · ⬜ autres |
| T11 | Supervision : alerte réelle déclenchée (ex. stop mariadb 2 min) | Alerte Zabbix + retour vert | ⬜ |
| T12 | Restore programmé (preuve pour livrable supervision) | Tâche planifiée + rapport | ⬜ |
| T13 | Migration MGMT natif → VLAN 90 | hv01/hv02 sur `vmbr1.90`, dns01 tag 90, quorum 3/3, inter-VLAN et DNS intacts | ✅ 06/07 — `pvecm` 3 votes, QDevice `A,V,NMW`, routes hv02 et reboot dns01 validés |
| T14 | WAN public Additional IP OVH | sortie dns01/glpi01 = 51.75.38.225, WAN /32, far gateway, aucune exposition non voulue, reboot fw01 | 🔶 06/07 — WAN/NAT/DNS validés ; test entrant, reboot fw01 et retrait vmbr2 encore à faire |

## C. Recette documentaire (conformité & rejouabilité)
| ID | Test | Attendu | Verdict |
|---|---|---|---|
| D01 | Un runbook (tirage au sort) déroulé par un NON-auteur | Résultat obtenu sans aide extérieure | ⬜ |
| D02 | Check-list des 9+ livrables déposés | 100% présents | ⬜ |
| D03 | Journal de preuves : chaque affirmation RPO/RTO → une preuve horodatée | Traçabilité complète | ⬜ |
| D04 | Repo Git : configs/scripts versionnés, pas de secret en clair | grep secrets vide | ⬜ |

## D. Non-conformités & contre-recette (Partie B §7)
| ID | Constat | Plan d'action | Re-test | Statut |
|---|---|---|---|---|
| NC1 | ⬜ | | | |
