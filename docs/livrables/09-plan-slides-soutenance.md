# Plan des slides de soutenance (10-12) · Helpdesk Atlas
*Livrable 6 du sujet. Jury mixte : Kalla (technique) + intervenant NON technique possiblement en RP client → chaque slide doit parler aux deux. Responsable : Quentin, mais chacun doit pouvoir présenter TOUT.*

| # | Slide | Message clé (1 phrase) | Contenu | Qui parle aux non-techniciens |
|---|---|---|---|---|
| 1 | Titre & équipe | « Helpdesk Atlas : un service de tickets qui survit aux pannes » | Noms, rôles, date | ✔ |
| 2 | Besoin & objectifs | Le client veut créer/suivre/résoudre des tickets, ET la garantie de reprise | But, RPO≤20/RTO≤40 expliqués simplement (« on perd au pire 20 min de travail, on redémarre en 40 ») | ✔✔ |
| 3 | Réponse & budget | Une solution open source hébergée UE pour ~74 € TTC le mois de projet | Tableau budget + TCO annuel client | ✔✔ RP client |
| 4 | Architecture | 2 serveurs, 3 zones étanches, 1 pare-feu | Schéma Miro v2 simplifié + légende couleurs | ✔ analogie « quartiers + poste de garde » |
| 5 | Le pivot (leçon) | Infra physique perdue → reconstruction cloud en X jours | Avant/après, ce que ça prouve (rejouabilité !) | ✔✔ storytelling fort |
| 6 | Sécurité | Moindre privilège, secrets protégés, tout tracé | 4-5 mesures concrètes (deny par défaut, comptes nominatifs+TOTP, rotation secret éprouvée) | ✔ |
| 7 | Stratégie de sauvegarde | 2 mécanismes complémentaires : copies quotidiennes + réplication continue | PBS (quotidien, vérifié) + pvesr 15 min ; le pourquoi de chacun | ✔ analogie « photocopies du soir + carbone en continu » |
| 8 | **Démo/Preuve incident 1** | VM détruite → service restauré en XX min (< 40) | Chrono réel, captures journal, mode dégradé RO | ✔✔ le moment fort |
| 9 | **Démo/Preuve incident 2** | 15 tickets supprimés → restaurés sans perdre les suivants | Avant/après, binlogs expliqués en 1 phrase (« la boîte noire de la base ») | ✔✔ |
| 10 | Supervision | On ne promet pas, on mesure | Dashboard Zabbix : uptime, latence DB, succès backups, file mail | ✔ |
| 11 | Risques & limites assumées | On sait ce qu'on n'a pas fait, et pourquoi | Top 3 matrice (SPOF firewall→évolution CARP, copie hors site, bascule manuelle) | ✔✔ maturité |
| 12 | Bilan & leçons | RPO/RTO tenus, 9 livrables, 3 leçons d'ingénierie | Chiffres finaux + leçons (template v1→v3, reverse DNS, diagnostic 3 couches) + ouverture | ✔ |

## Préparation démo (check-list jour J)
- ⬜ VPS QDevice up · serveurs up · pas de règle TEMP restante · GLPI avec données réalistes (≥ 30 tickets variés)
- ⬜ Plan A : démo live (bascule test-failover + restore court) · Plan B : captures/vidéo si réseau salle défaillant
- ⬜ Anti-sèche Q&R : mémoire 99% fw01 (ARC ZFS) ; pourquoi Varsovie ; pourquoi pas CARP ; pourquoi OPNsense ; où sont les secrets ; que se passe-t-il si le QDevice tombe
- ⬜ 2 répétitions complètes minimum, chacun en solo, chrono ≤ temps imparti
