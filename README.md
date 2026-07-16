# Roadmap — Projet PRA/DR « Helpdesk Atlas »

> **Master 1 IRS**
> Objectif : déployer un portail GLPI segmenté + PRA/DR mesurable (RPO ≤ 20 min, RTO ≤ 40 min)
> Domaine interne : `atlas.local`
> Plateau : **2 serveurs dédiés OVH SYS-1** (eu-central-waw), interconnectés en **vRack**, virtualisation **Proxmox VE 9**, pare-feu **OPNsense**, sauvegardes **Proxmox Backup Server**.
> *(L'architecture initiale sur matériel physique — FortiGate/FortiSwitch, domaine `atlas.lan` — a été abandonnée au profit du cloud ; ce README fait foi.)*

---

## Plan d'adressage

| Zone | VLAN | Subnet | Gateway (fw01) |
|---|---|---|---|
| DMZ | 20 | 10.20.0.0/24 | 10.20.0.1 |
| ADMIN | 30 | 10.30.0.0/24 | 10.30.0.1 |
| MGMT | 90 | 10.90.0.0/24 | 10.90.0.1 |
| WAN | — | 51.75.38.225/32 (Additional IP OVH, vMAC) | 146.59.47.254 (far gateway) |

Accès d'administration : **VPN WireGuard sur fw01** (UDP 51820, 10.60.0.0/24, split tunnel + split-DNS `~atlas.local`) — seul flux entrant. Tunnels SSH/ProxyJump conservés en accès de secours.

## Inventaire des VMs

Convention VMID : **1xx = MGMT (90) · 2xx = DMZ (20) · 3xx = ADMIN (30)** · 9000 = template.

| Hostname | VMID | Rôle | Zone | IP | État |
|---|---|---|---|---|---|
| `fw01.atlas.local` | 100 | OPNsense (trunk 20/30/90 + WAN) | — | .1 de chaque zone | ✅ recetté |
| `dns01.atlas.local` | 110 | DNS interne BIND9 | MGMT | 10.90.0.10 | ✅ recetté |
| `pbs01.atlas.local` | 120 | Proxmox Backup Server (**sur hv02**) | MGMT | 10.90.0.20 | ✅ en service |
| `guac01.atlas.local` | 130 | Bastion Guacamole *(optionnel)* | MGMT | 10.90.0.30 | ⬜ |
| `rp01.atlas.local` | 210 | Reverse proxy Nginx (TLS) | DMZ | 10.20.0.10 | ✅ recetté |
| `glpi01.atlas.local` | 220 | GLPI 11.0.8 (Nginx + PHP-FPM) | DMZ | 10.20.0.11 | ✅ recetté |
| `mail01.atlas.local` | 230 | Relais SMTP **Postfix** | DMZ | 10.20.0.20 | ✅ recetté |
| `db01.atlas.local` | 310 | MariaDB 11.8 (base glpidb) | ADMIN | 10.30.0.10 | ✅ recetté |
| `zbx01.atlas.local` | 320 | Supervision Zabbix | ADMIN | 10.30.0.20 | ⬜ |
| `tpl-debian13` | 9000 | Template Debian 13 **v5** cloud-init (protégé) | — | — | ✅ |

Hyperviseurs : `hv01` (production) et `hv02` (cible DR + pbs01) sur le VLAN 90 via `vmbr1.90` ; quorum assuré par un QDevice externe (3 votes). CNAME `helpdesk.atlas.local` → rp01.

---

## Phase 1 — Fondation infrastructure ✅ TERMINÉ

- [x] 2× OVH SYS-1 + vRack ; cluster Proxmox « atlas » (hv01+hv02+QDevice, quorum 3/3, test de perte de nœud validé)
- [x] ZFS mirror (`zfs-data`) sur chaque nœud
- [x] fw01 OPNsense : trunk VLAN 20/30/90, interfaces par zone, deny inter-VLAN par défaut
- [x] **TRAVAUX-01** : hyperviseurs migrés sur VLAN 90 (MGMT)
- [x] **TRAVAUX-02** : WAN public Additional IP + vMAC sur fw01 ; exposition 22/443 testée filtrée ; reboot fw01 chronométré (coupure ≈ 45 s) ; WAN provisoire vmbr2/MASQUERADE retiré — **chemin unique via fw01**
- [x] Template `tpl-debian13` **v4** : SSH clés-only testé, purge dhcpcd-base, regen-ssh-keys corrigé, `--protection 1` + tag (anti-suppression, leçon de l'incident du 05/07)
- [x] Rituel de provisionnement R0 documenté (tag VLAN avant boot, IP statique, pings rituels, reboot de validation)
- [x] Écart DHCP corrigé : Dnsmasq OPNsense désactivé, contre-test « No DHCPOFFERS » — réseau 100 % statique

## Phase 2 — Services applicatifs 🚧 EN COURS

- [x] `db01` — MariaDB 11.8, bind 10.30.0.10, **binlogs ROW 7 j testés** (rejouables via `mariadb-binlog`)
- [x] Compte `glpi_app`@`10.20.0.11` à privilèges minimaux (glpidb.* uniquement) ; secret hors VCS (rotation testée après exposition d'un premier secret)
- [x] `glpi01` — GLPI **11.0.8**, Nginx root `/var/www/glpi/public`, PHP-FPM 8.4, 442 tables
- [x] Durcissement GLPI : `install.php` supprimé, comptes par défaut (`glpi`/`tech`/`normal`/`post-only`) **désactivés** (preuves avant/après), superadmin **nominatif**
- [x] Timer systemd `glpi-cron` (1 min, persistant au reboot)
- [x] mail01 — Postfix relay vers Mailpit
- [ ] `mail01` — **Postfix** relay (MailHog abandonné : la métrique Zabbix « file SMTP » exige une vraie queue Postfix)
- [x] Configuration SMTP GLPI
- [x] **Test critique #1** : parcours complet ticket → mail → résolution
- [x] Test de résilience de la file Postfix

## Phase 3 — DNS interne ✅ TERMINÉ

- [x] `dns01` — BIND9, zone `atlas.local` (tous les A + CNAME helpdesk→rp01)
- [x] Zones reverse `0.20.10` / `0.30.10` / `0.90.10.in-addr.arpa` (piège /24 vs /16 corrigé et documenté)
- [x] Récursion limitée aux subnets internes ; forwarders Quad9 (9.9.9.9 + 149.112.112.112)
- [x] Recette : A, 3× PTR, résolution externe — 5/5
- [x] `resolv.conf` de toutes les VM → 10.90.0.10
- [x] Fichiers de zone à verser dans Git (`docs/` ou `configs/`)

## Phase 4 — Sécurisation TLS ✅ TERMINÉ (14/07)

- [x] **Décision tracée** : CA interne « Atlas Internal Root CA » (EC P-256, racine 5 ans au coffre, script `make-ca.sh` versionné dans `ca/`)
- [x] `rp01` — Nginx TLS 1.2+/HTTP2, redirection HTTP→HTTPS, rate limiting, HSTS ; reboot de validation 43 s
- [x] Cert serveur `helpdesk.atlas.local` (SAN) ; chaîne validée par `curl --cacert` sans -k (rp01 + poste client)
- [x] CA racine importée sur le poste de démo (cadenas « PME Atlas »)
- [x] Accès HTTP direct à glpi01 bloqué (**floating rule**, contre-tests 2 zones — leçon : règles évaluées sur l'interface d'entrée, l'intra-VLAN ne traverse pas fw01)
- [ ] Runbook rotation des certificats (à rédiger)

## Phase 5 — Administration & bastion

- [ ] `guac01` — Guacamole (**optionnel**, peut sauter si le temps manque ; les tunnels SSH + journal font office de traçabilité d'accès)
- [ ] Comptes PVE nominatifs + TOTP ; fermeture de 8006 en public
- [x] Comptes de service dédiés au fil de l'eau : `glpi_app` (DB), `pve-backup@pbs` (backups, rôle DatastoreBackup)
- [ ] **Durcissement sshd hérité v3** : rejouer clés-only sur dns01/glpi01/db01 (le template v4 le règle pour les futures VM)

## Phase 6 — Supervision Zabbix

- [ ] `zbx01` — Zabbix server (vérifier compat MariaDB 11.8 / Debian 13)
- [ ] Agents sur : db01, glpi01, mail01, rp01, dns01, pbs01, hv01, hv02
- [ ] **Indicateurs métiers exigés** : uptime GLPI (check HTTPS via rp01) · latence DB · **taux de succès sauvegardes** · **file SMTP Postfix** · disque · santé services
- [ ] Alertes (mail via mail01)
- [ ] **Tableau de bord PRA/DR** pour la soutenance (lisible par un jury non technique)

## Phase 7 — Sauvegardes 🚧 LARGEMENT ENTAMÉ

- [x] `pbs01` sur **hv02** (séparation du domaine de panne — décision d'architecture documentée) ; datastore dédié 100 Go ; **non auto-sauvegardé** (récursivité, reconstructible ~20 min)
- [x] Premier backup complet 4 VM : **101 s**, ~13 GiB utiles ; **verify 4/4, 0 erreur**
- [x] Job quotidien 21:00, mode **Exclude** (pbs01+template exclus, toute VM future incluse d'office) ; incrémental mesuré : **4 s**
- [x] Verify quotidien + prune (7 j / 4 sem) + GC quotidiens
- [x] Binlogs db01 actifs (ROW, 7 j) — le pilier du RPO 20 min
- [ ] `mariadb-dump` quotidien poussé vers pbs01 (complément binlogs, base du point-in-time)
- [ ] **Réplication pvesr 15 min** hv01→hv02 (6 VM critiques) — le RPO de la bascule DR
- [ ] Chiffrement des sauvegardes au repos (natif PBS : encryption côté client à activer, clé au coffre)
- [ ] Sonde Zabbix « fraîcheur des dumps + succès des jobs »

## Phase 8 — PRA/DR : preuves et démonstration (LA partie évaluée)

- [x] hv02 opérationnel comme cible (pbs01 y tourne ; storage pbs partagé au cluster)
- [x] **Test R2 réel (12/07)** : glpi01 restauré → VM temporaire ; **restore 18 s**, bout-en-bout **8 min 21 s** (RTO réel estimé 2-3 min à IP identique) ; refus ACL DB = preuve moindre privilège. Marge ×5-15 vs RTO ≤ 40 min
- [ ] Runbook incident #1 (perte stockage → restore complète + **mode dégradé lecture seule**) — à jouer en conditions de démo
- [ ] Runbook incident #2 (≥ 10 tickets supprimés → point-in-time binlogs, tickets postérieurs intacts) — RPO à démontrer
- [ ] Runbook bascule DR (hv01→hv02, **IP move OVH** : l'Additional IP + vMAC se déplacent vers hv02) + retour arrière
- [ ] Exécution chronométrée des 2 incidents : journal horodaté, captures Zabbix, tailles, temps réels
- [ ] **Prouver** RPO ≤ 20 min et RTO ≤ 40 min

## Phase 9 — Livrables documentaires (en parallèle, pas à la fin)

- [x] Pack de livrables 00–13 structuré (`docs/livrables/`) ; journal de preuves **tenu au fil de l'eau** (rattrapé et à jour au 12/07)
- [x] Preuves terminal horodatées (`docs/preuves/`) + captures (`docs/captures/`)
- [ ] DAT : intégrer les décisions récentes (pbs01 sur hv02, chemin WAN unique, TLS)
- [ ] Matrice de risques + BIA light — compléter
- [ ] Runbooks R0–R5 : colonnes « mesuré » à remplir avec les chiffres réels
- [ ] Budget (04) : montant mensuel Additional IP (facture OVH) + totaux
- [ ] Slides de soutenance (10-12) : archi, risques, PRA, démos, RPO/RTO, leçons
- [ ] **Gel infra à J-4** → preuves → ≥ 2 répétitions complètes

---

## Conseils transverses

### Gestion du temps
- Phases 1-3 + 7 (backups) : **faites**. Le chemin critique restant : **rp01 → mail01 → zbx01 → incidents**.
- Garder ≥ 30-40 % du temps pour la phase 8 : c'est elle qui rapporte les points.

### Traçabilité
- Journal horodaté : `docs/livrables/11-journal-de-preuves.md` — une ligne par événement, dans les minutes qui suivent (`date` avant/après chaque manip).
- Tout passe en Git : scripts, configs (BIND, Nginx, OPNsense exportée), runbooks. Zéro clic-clic non tracé.
- Troisième source d'horodatage : Task History Proxmox (UPID) + commits Git.

### Chiffres à retenir (mesurés)
| Mesure | Valeur | Exigence |
|---|---|---|
| Restore PBS glpi01 | **18 s** | — |
| Test restauration bout-en-bout | **8 min 21 s** | RTO ≤ 40 min |
| Backup incrémental 4 VM | **4 s** | — |
| Backup initial 4 VM | 101 s | — |
| Coupure reboot fw01 | ≈ 45 s | — |
| Verify datastore | 4/4, 0 erreur | — |

### Critères d'acceptation du sujet
- [x] Déployable sur plateau virtualisé segmenté
- [x] Interface web HTTPS avec certificat valide (trust interne documenté) — phase 4 close le 14/07
- [ ] S'intègre à un relais SMTP existant → **mail01**
- [ ] Indicateurs de santé pour la supervision → **zbx01**
- [x] Mécanismes de sauvegarde/restauration documentés (RPO/RTO) — restauration déjà testée à blanc
- [x] Traçabilité et procédures rejouables (Git + journal + runbooks)

---

*Dernière mise à jour : 2026-07-14 — refonte complète après pivot cloud OVH (l'ancienne roadmap FortiGate/atlas.lan est obsolète).*
