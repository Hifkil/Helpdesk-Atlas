# Dossier supervision · Helpdesk Atlas
*Livrable 4 : « captures du dashboard, alertes, preuve d'un test de restore programmé ». Se remplit dès que zbx01 et pbs01 existent — structure prête.*

## 1. Architecture de supervision
- Serveur : zbx01 (10.30.0.20, zone ADMIN). Agents Zabbix sur : glpi01, db01, mail01, dns01, rp01, hv01, hv02, pbs01 (⬜ + fw01 via SNMP ou agent FreeBSD — métrique mémoire INTERNE, pas celle de Proxmox).
- Flux : agents:10050 ← zbx01 ; zbx01:10051 ← trappes (matrice de flux #6/#7).

## 2. Métriques exigées par le sujet (mapping)
| Exigence sujet | Item Zabbix | Seuil d'alerte | Capture |
|---|---|---|---|
| Uptime App | check HTTP `https://helpdesk…` (code 200 + mot-clé) | KO > 2 min | ⬜ |
| Latence DB | `mysql.ping` + temps de réponse requête témoin | > ⬜ ms | ⬜ |
| Taux de succès sauvegardes | statut dernier job PBS + âge dernier backup | échec OU > 26 h | ⬜ |
| File SMTP | `postqueue -p` (nb messages) sur mail01 | > 10 pendant 10 min | ⬜ |
| Disque | espace zfs-data + / des VM | > 80 % | ⬜ |
| (bonus) Quorum cluster | pvecm/qnetd check | votes < 3 | ⬜ |
| (bonus) Réplication pvesr | âge dernière sync | > 30 min | ⬜ |

## 3. Dashboard « PRA/DR » (à construire pour la soutenance)
Widgets : état des 9 VM · uptime app · dernière sauvegarde OK (date+taille) · âge réplication · file SMTP · graphe latence DB. ⬜ capture plein écran datée.

## 4. Alertes — preuve de fonctionnement réel
Test à réaliser (cahier de recette T11) : arrêt volontaire de mariadb 2 min → capture de l'alerte déclenchée PUIS du retour au vert. ⬜ Idem pour un échec de backup simulé.
| Alerte testée | Date | Preuve |
|---|---|---|
| DB down | ⬜ | ⬜ |
| Backup manquant | ⬜ | ⬜ |
| File SMTP | ⬜ | ⬜ |

## 5. Preuve d'un test de restore PROGRAMMÉ (exigence explicite)
- Mécanisme : ⬜ tâche planifiée (cron/PBS verify + restore mensuel automatisé d'une VM témoin vers un VMID de test, avec rapport).
- Preuve : planification (capture) + rapport d'exécution horodaté + entrée journal.

## 6. Captures d'exploitation quotidienne
⬜ Vue Problems vide (état sain) · ⬜ historique 7 jours · ⬜ latest data des métriques clés.
