# Plan de transfert de compétences · Helpdesk Atlas
*Livrable 7 (Partie B §6). Double usage : (a) document « client » ; (b) plan RÉEL de montée en compétence des 3 membres — exigence Kalla : n'importe qui présente tout.*

## 1. Public & objectifs
| Profil client | Objectif | Durée |
|---|---|---|
| Technicien helpdesk | Exploiter GLPI au quotidien (tickets, catégories, rapports) | 0,5 j |
| Administrateur système | Exploiter la plateforme : Proxmox, sauvegardes, supervision, runbooks | 1,5 j |
| Référent PRA | Dérouler seul R1→R5, décider une bascule | 1 j |

## 2. Programme (sessions)
1. **Architecture & réseau** (2 h) — schéma, zones, matrice de flux, adressage. Support : DAT + Miro.
2. **Exploitation quotidienne** (2 h) — GLPI admin, dashboard Zabbix, lecture des alertes, vérification des sauvegardes du matin.
3. **Sauvegardes & restaurations** (3 h) — R1 en réel, R2 sur VM de test, R3 sur tickets de test. *Méthode : le formateur observe, l'apprenant déroule le runbook seul — critère de réussite = zéro intervention du formateur.*
4. **PRA/bascule** (2 h) — R4/R5 expliqués + simulation à blanc (test-failover.sh) + critères de décision de bascule.
5. **Sécurité & comptes** (1 h) — gestion des secrets, comptes de service, TOTP, procédure de rotation.

## 3. Supports remis
DAT · runbooks R0-R5 · journal de preuves (exemples réels) · guide utilisateur · scripts (test-cluster, test-failover) · exports de configuration · accès repo Git.

## 4. Validation des acquis
Check-list par profil (⬜ à cocher en séance) : ex. Référent PRA = « a restauré une VM depuis PBS en < 20 min sans aide », « a expliqué le rôle du QDevice », « a identifié T_incident dans un binlog ».

## 5. Application interne (équipe projet — avant soutenance)
| Membre | Zones à renforcer | Sessions croisées prévues | Répétition solo faite |
|---|---|---|---|
| Harry | livrables rédactionnels, discours client | ⬜ date | ⬜ |
| Quentin | manipulation Proxmox/OPNsense, runbooks en réel | ⬜ | ⬜ |
| Thibault | BDD/binlogs, réseau/VLAN | ⬜ | ⬜ |

Règle : chaque membre déroule **une restauration complète en autonomie** avant J-2, et présente **l'intégralité** des slides une fois devant les deux autres.
