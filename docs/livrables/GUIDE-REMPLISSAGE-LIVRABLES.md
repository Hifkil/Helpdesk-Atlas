# Guide de remplissage des livrables · Helpdesk Atlas

*Mode d'emploi du pack 00→11. Règle simple : chaque ⬜ appartient à l'un de ces 3 types — et chaque type se remplit différemment.*

| Type | C'est quoi | Comment on le remplit |
|---|---|---|
| **[DÉCISION]** | Un choix à écrire en 1-3 phrases | Tout de suite, en équipe (des textes prêts à coller sont fournis ci-dessous) |
| **[CAPTURE]** | Une preuve visuelle à insérer | Au fil de l'eau, dès que la brique existe — nommage `AAAA-MM-JJ_hhmm_sujet.png` dans `docs/captures/` |
| **[MESURE]** | Un chiffre issu d'un test réel | Jamais inventé : vient d'une ligne du **journal de preuves (11)** |

**Règle d'or** : le journal (11) est la source ; les autres livrables pointent vers lui. Si un chiffre est dans un livrable mais pas dans le journal, il n'existe pas.

## Ordre de remplissage conseillé

1. **Maintenant, sans toucher l'infra** : toutes les [DÉCISION] → 03 (cotations, R13, acceptations), 04 (heures, montants), 05 (colonne « Notre réponse » — déjà quasi faite), 06 (textes), 07 (dates), 01-DAT (hors périmètre, alternatives, coffre).
2. **Au fil des installations** (glpi01, rp01, mail01, zbx01, pbs01) : les [CAPTURE] du doc concerné + une ligne au journal à chaque brique recettée.
3. **Après les incidents 1 & 2 et la bascule** (avant le gel J-4) : toutes les colonnes « Mesuré » de 02, les verdicts de 08-B, les sections 2-4 du journal.
4. **En dernier** : 09 (chiffres finaux dans les slides), 08-D02 (check-list de dépôt), relecture croisée.

---

## Livrable par livrable — quoi mettre dans chaque ⬜

### 01 — DAT
- **Hors périmètre** [DÉCISION], à coller : « Hors périmètre : SSO/annuaire externe (auth locale GLPI), haute disponibilité automatique (bascule manuelle assumée, cf. §7), IPv6, sauvegarde hors site (recommandation, cf. budget §5), gestion des postes clients. »
- **Schéma** [CAPTURE] : export PNG du cadre Miro « Architecture Atlas v2 » + 3 phrases de lecture (une par zone).
- **§4 flux #10** [DÉCISION] : ajouter `MGMT → hv01/hv02:8006 (GUI)`, `fw01 → dns01:53`, `mail01 → Internet:25/587 (relais sortant)`, puis la ligne finale « **deny all implicite** ».
- **§5 coffre** [DÉCISION], à coller : « Secrets dans un KeePassXC d'équipe (.kdbx hors dépôt) ; sur les serveurs : fichiers de conf en droits 600 ; jamais dans l'historique shell ni le VCS. »
- **§8 GLPI** [DÉCISION] : « GLPI vs Zammad/osTicket : imposé "GLPI-like" par le sujet ; référence du marché FR, workflow ITIL complet + PJ + notifications natifs, documentation abondante — départage : couverture fonctionnelle sans plugin payant. »
- **§8 Zabbix** [DÉCISION] : « Zabbix vs Prometheus/Nagios : templates agents prêts (Linux, MariaDB, HTTP), alerting et dashboards intégrés en un seul produit (vs stack Prometheus+Grafana+Alertmanager), adapté à un jury mixte ; Nagios écarté (modèle vieillissant). »
- §5/§6 (comptes zabbix/pbs, datastore PBS, TLS, 8006) : [CAPTURE]/[DÉCISION] à compléter quand les briques arrivent — le choix TLS se tranche maintenant (cf. TRAVAUX-02 phase 8).

### 02 — Runbooks
- Toutes les colonnes **« Mesuré »** = [MESURE], recopiées du journal après les tests. Rien d'autre.
- R1 étape 3 [DÉCISION] : `proxmox-backup-client backup dump.pxar:/backup --repository pbs01…` (à figer quand pbs01 existe).
- R2 étape 6 [DÉCISION], à coller : « Mode dégradé = `SET GLOBAL read_only=1;` sur db01 + message d'accueil GLPI ; preuve : une tentative d'écriture échoue (capture). »
- R3 « tables liées » [DÉCISION] : point de départ — `glpi_tickets`, `glpi_tickets_users`, `glpi_groups_tickets`, `glpi_itilfollowups`, `glpi_tickettasks`, `glpi_itilsolutions`, `glpi_documents` + `glpi_documents_items`, `glpi_ticketvalidations`. **Méthode de validation** (à faire avant l'incident 2) : créer un ticket de test complet (PJ, suivi, solution), le supprimer, puis lister dans les binlogs toutes les tables touchées par son id — c'est la liste définitive.
- R4 étape 4 : remplacée par la bascule Additional IP → texte exact dans « À reporter » ci-dessous.

### 03 — Risques & BIA
- Cotations P/I : passer 10 min à trois, voter, trancher. C'est l'exercice, pas un problème.
- **R13** [DÉCISION], proposition : « R13 — Données personnelles dans les tickets : P2×I3=6 ; POC = données fictives uniquement ; en production : RGPD (rétention, minimisation), sauvegardes chiffrées (lien exigence client §4). »
- **§3 acceptations** [DÉCISION], 3 exemples à adapter : « R07 : le SPOF pare-feu est accepté — le RTO exigé (40 min) est tenu par réplication + redémarrage (~3 min mesurés) ; CARP documenté comme évolution. » · « R02 : la bascule manuelle est assumée : une décision humaine tracée vaut mieux qu'un split-brain automatique à notre échelle. » · « R10 : le risque datacenter est accepté pour le POC ; la copie hors site est chiffrée en option budget (§5). »

### 04 — Budget
- Heures [DÉCISION], exemple honnête : « 3 × ~15 h/sem × 3 sem ≈ 135 h ; valorisation fictive pour le narratif client : 450 €/j ⇒ ≈ 7,6 k€ de prestation. »
- **Ligne Additional IP corrigée** : facturation mensuelle. Il reste à recopier le montant réel de la facture et à finaliser les totaux (§3) + le TCO client (§5).
- On-premise §5 [DÉCISION], ordre de grandeur assumé : « 2 serveurs ≈ 3,5 k€ + onduleur/switch ≈ 600 €, amortis 4 ans ≈ 85 €/mois + électricité ~30 €/mois — hors main-d'œuvre. »
- Scaleway Elastic Metal : garder « non retenu (visibilité prix) », pas besoin de chiffrer.

### 05 — Réponse aux exigences
- Colonne « Preuve » = des **pointeurs**, pas du contenu : `journal §1 ligne du 05/07`, `docs/captures/2026-07-XX_….png`, `runbook R3`. Se remplit en 20 min une fois les tests faits.
- « Dumps chiffrés » [DÉCISION à faire] : au choix `--compress` + chiffrement gpg du dump, **ou** datastore PBS chiffré (plus simple, natif) — trancher avec pbs01.

### 06 — Guide utilisateur
- Rédaction déjà complète ; restent les [CAPTURE] (après GLPI) + 3 [DÉCISION] : taille max PJ (« 2 Mo par défaut — aligner GLPI *Configuration → Générale* et `upload_max_filesize`/`post_max_size` de PHP, indiquer la valeur retenue »), mot de passe oublié (« contacter le service IT : réinitialisation par un administrateur GLPI — le self-service par mail nécessite le mail entrant, hors périmètre »), contact urgences (« poste interne fictif, ex. 4242 »).

### 07 — Transfert de compétences
- Remplir le tableau §5 avec des **vraies dates** (sessions croisées + répétition solo de chacun) — c'est aussi votre planning réel d'avant-soutenance. Cocher §4 en séance.

### 08 — Cahier de recette
- Verdicts ⬜ = au fil des tests, avec date + opérateur. T03 : re-capturer après la matrice de flux finale. D01 : tirage au sort d'un runbook déroulé par un non-auteur — planifier ce créneau dans 07 §5.

### 09 — Slides
- Structure figée ; remplacer les « XX min » par les chiffres du journal, préparer l'anti-sèche Q&R listée en bas du doc. Ne pas toucher avant d'avoir les mesures.

### 10 — Supervision
- Tout se débloque avec zbx01 + pbs01. Seuil latence DB [DÉCISION] : « > 100 ms sur la requête témoin pendant 5 min ». Test de restore programmé : tâche planifiée PBS (verify quotidien) + restore mensuel automatisé d'une VM témoin vers un VMID de test, rapport conservé.

### 11 — Journal de preuves *(nouveau — c'était le livrable manquant du pack)*
- Compléter les ⬜hh:mm des lignes des 04-05/07 (retrouver via `history`, horodatage des captures, ou l'onglet Tasks de Proxmox), puis une ligne par événement. Les sections 2-5 se remplissent pendant les tests d'incident.

---

## Mise à jour TRAVAUX-01 / TRAVAUX-02 — report effectuée le 06/07/2026

**01-DAT §3** — remplacer le tableau par :

| Zone | VLAN | Réseau | Passerelle | Rôle |
|---|---|---|---|---|
| MGMT | **90** (taggé) | 10.90.0.0/24 | 10.90.0.1 (fw01) | Hyperviseurs (vmbr1.90), DNS, PBS, bastion |
| DMZ | 20 | 10.20.0.0/24 | 10.20.0.1 | Reverse proxy, GLPI, SMTP |
| ADMIN | 30 | 10.30.0.0/24 | 10.30.0.1 | BDD, supervision |
| WAN | — | 51.75.38.225/32 (Additional IP OVH, MAC virtuelle, GW 146.59.47.254) | — | Accès public : NAT sortant + futur 443→rp01 |

**01-DAT §9** — ajouter : « Toutes les zones internes circulent **taggées** (90/20/30) sur le vRack ; plus aucun trafic untaggé en nominal. »

**00-ETAT-PROJET §2** — lignes « WAN public » et « Zones réseau » : « ✅ Additional IP 51.75.38.225 en service le 06/07 (vMAC sur vmbr0 ; bascule DR = move IP, la même vMAC unique réapparaît sur le serveur cible compatible, cf. R4 §4) » · « MGMT = VLAN 90, DMZ = 20, ADMIN = 30 — tout taggé ; hyperviseurs sur vmbr1.90 ». §3 : rituel R0 étape 0 → « tag de zone : 90/20/30 » ; convention « 1xx = MGMT (tag 90) ».

**02-runbooks R4** — reporté : déplacer l'IP via le Manager ou `POST /dedicated/server/{serviceName}/ipMove` vers `ns3201919`; attendre que la même vMAC unique `02:00:00:ff:3e:98` réapparaisse sur hv02 ; vérifier `net0` sur `vmbr0`, puis démarrer. Estimé 5-10 min. Plan B seulement : NAT provisoire équivalent à l'ancien vmbr2.

**04-budget** — ligne Additional IP passée en facturation mensuelle. Le montant et les totaux restent volontairement paramétrés tant que la facture n'a pas été recopiée.

**Miro** — à mettre à jour : étiquette « VLAN 90 » sur MGMT, « 51.75.38.225 » sur le WAN. Le fichier `Screenshot_20260706_195324.png` du pack est une capture **antérieure** à la migration et ne doit plus servir de source d'architecture finale.

---

## Check-list de dépôt (mapping sujet ↔ pack)

| Exigé par le sujet | Fichier |
|---|---|
| 1. DAT & dossier d'archi | 01 (+ schéma Miro exporté, + annexes configs) |
| 2. Runbooks PRA | 02 (éclaté en R1-R5 dans `docs/runbooks/`) |
| 3. Matrice de risques + BIA | 03 |
| 4. Supervision | 10 (+ captures) |
| 5. Journal de preuves | **11** |
| 6. Slides (10-12) | 09 → support final |
| Partie B : réponse, guide, transfert, recette | 05, 06, 07, 08 |
| Ajout Kalla : but, budget, ressources | 04 |

Repo : `docs/` (pack + captures + runbooks), `scripts/`, `configs/` (exports OPNsense/BIND/60-atlas.cnf, **sans secrets** — vérifier avec un `grep` avant push, test D04).
