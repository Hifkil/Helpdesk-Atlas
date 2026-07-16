# Réponse aux exigences client (Partie B — appel d'offre) · Helpdesk Atlas
*Le sujet Partie B fait de vous le titulaire : chaque exigence → votre réponse + la preuve. Tableau pré-rempli, colonnes Preuve à pointer vers journal/captures/runbooks au fil de l'eau.*

## 1. Périmètre fonctionnel (§2)
| Exigence client | Notre réponse | Preuve |
|---|---|---|
| Tickets (ouverture → affectation → clôture), PJ, notification mail | GLPI 11 : workflow natif + pièces jointes ; notifications via relais Postfix (mail01) | ⬜ démo + captures parcours complet |
| Comptes agents internes (auth locale simple) | Comptes locaux GLPI, comptes par défaut désactivés | ⬜ capture gestion utilisateurs |
| Rapports de base (volumétrie, SLA simple, catégories) | Tableaux de bord et statistiques natifs GLPI | ⬜ capture dashboard |
| Interface web HTTPS certificat valide | Cible : TLS terminé sur rp01 (Nginx) — ⬜ Let's Encrypt si domaine réel, sinon CA interne + trust documenté ; rp01 reste à déployer | ⬜ capture cadenas + doc trust |

## 2. Périmètre technique (§3)
| Exigence | Réponse | Preuve |
|---|---|---|
| Déployable sur plateau virtualisé et segmenté | Cluster Proxmox VE 9 (2 nœuds), zones DMZ/ADMIN/MGMT en VLAN **20/30/90**, pare-feu OPNsense dédié, WAN public `51.75.38.225/32` | DAT §2-4, journal du 06/07, schéma Miro à actualiser |
| Interface web interne (TLS activable) | rp01 reverse proxy TLS → GLPI | ⬜ |
| Intégration relais SMTP existant | mail01 Postfix, GLPI branché dessus ; file supervisée | ⬜ ticket→mail |
| Indicateurs de santé exposés | Agents Zabbix : HTTP app, latence DB, succès sauvegardes, file SMTP, disque | ⬜ dashboard zbx |
| Sauvegarde/restauration documentées (RPO/RTO) | PBS + dumps/binlogs ; 5 runbooks avec temps estimés vs mesurés | Runbooks R1-R5, journal |
| Traçabilité et procédures rejouables | Repo Git (scripts, configs, docs), journal horodaté, runbooks testés par un non-auteur | Repo + journal |

## 3. Exigences de sécurité (§4)
| Exigence | Réponse | Preuve |
|---|---|---|
| Comptes de service moindre privilège, rotation | glpi_app restreint par IP et par base ; rotation démontrée (secret révoqué/régénéré) | journal (entrée secrets) |
| Chiffrement en transit (TLS) et au repos (sauvegardes) | TLS rp01 ; ⬜ dumps chiffrés (gpg/openssl) ou datastore PBS chiffré — à activer | ⬜ |
| Durcissement OS/services, pas de comptes par défaut | SSH clés only, deny-all par défaut inter-zones, comptes GLPI par défaut désactivés ⬜, TOTP Proxmox ⬜ | ⬜ check-list durcissement |
| Journalisation, horodatage synchronisé | NTP partout (Europe/Paris), syslog, tasks PVE nominatives | ⬜ capture tasks |

## 4. Critères d'acceptation (§5) → repris dans le cahier de recette (livrable 08)
Parcours bout-en-bout · sauvegardes opérantes + taux mesuré · granulaire ≥ 10 tickets · full dans le RTO · supervision active · dossiers complets.

## 5. Livrables du titulaire (§6) — pointeurs
HLD/LLD = DAT · Runbooks = 02 · Preuves sauvegardes = journal + PBS · Jeux de tests = 08 · Guide utilisateur = 06 · Transfert de compétences = 07.

## 6. But, budget, ressources (ajout Kalla)
→ livrable 04 dédié, résumé en introduction de ce dossier.
