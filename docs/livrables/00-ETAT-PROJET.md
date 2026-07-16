# 📦 ÉTAT DU PROJET — Helpdesk Atlas (document de reprise)

> **Rôle** : capturer l'intégralité de l'avancement au **14 juillet 2026 (après recette rp01+TLS/CA interne, VPN WireGuard admin, template v5 cloud-init et provisionnement mail01)** pour reprendre le travail
> à tout moment (par Harry, un coéquipier, ou une future session d'assistance).
> Se lit avec : `JOURNAL-DE-BORD.md`, les runbooks, et le board Miro.

---

## 1. Contexte & règles du jeu

- **Projet** : « Helpdesk Atlas » — PRA/DR Master 1 IRS (sujet : DANNOUNE Mohamed-Amine). GLPI-like + PRA mesurable. **RPO ≤ 20 min, RTO ≤ 40 min**, à prouver (journal horodaté, captures, tailles).
- **Équipe** : 3 personnes. Harry = PRA/infra/runbooks. Thibault = archi/dossier client. Quentin = qualité/soutenance.
- **Consignes Kalla (compte rendu de juillet)** :
  - 3 notes : infrastructure / soutenance / livrables. **Livrables + soutenance >> POC** (le POC appuie, ne porte pas).
  - Livrables = tout le document de cadrage **+ budget, but, ressources** (explicitement demandés).
  - Une personne **tirée au hasard** présente → les 3 doivent maîtriser TOUT.
  - Jury : Kalla + un intervenant **non technique**, possiblement en posture RP client.
  - Pas d'accès VM nécessaire pour le prof ; les serveurs seront supprimés après.
- **Deadline interne fixée** : infra **gelée à J-4** de la soutenance → 3 jours pleins pour preuves + répétitions (≥ 2 répétitions complètes où chacun présente tout, seul).
- **Incidents à démontrer** (sujet) : ① perte stockage primaire → restore complet + mode dégradé lecture seule ; ② suppression ≥ 10 tickets → restauration sélective point-in-time sans perte des tickets postérieurs.

## 2. Décisions d'architecture (avec justifications — à reprendre dans le DAT)

| Décision | Choix | Justification courte |
|---|---|---|
| Hébergement | 2× OVH SYS-1 (Varsovie) | Infra physique perdue ; SYS-1 = meilleur ratio (29,99€ HT, install offerte, vRack inclus) ; France indisponible à ce prix, Australie rejetée (latence ~300 ms incompatible démo + narratif client) ; Varsovie ≈ 30 ms = OK. Hetzner/Scaleway comparés (cf. budget). |
| Virtualisation | Proxmox VE 9 + ZFS mirror | Template OVH officiel ; ZFS mirror = redondance disque + **réplication pvesr** inter-nœuds (RPO minutes) ; VE 8 EOL 09/2026. |
| Cluster | 2 nœuds + **QDevice** sur VPS externe | Quorum 3 votes ; survie à la perte d'un nœud sans `pvecm expected 1` ; témoin hors domaine de panne (site tiers). Testé OK. |
| Pare-feu | **OPNsense** (vs pfSense) | Licence BSD franche, MAJ 2×/an, API REST, éditeur UE (Deciso). Les deux cités par le sujet. |
| Redondance FW | Réplication ZFS + bascule manuelle (**pas CARP**) | RTO exigé 40 min ; CARP = RTO 1 s mais complexité forte = sur-ingénierie ; documenté comme évolution possible. |
| WAN public | **Additional IP OVH 51.75.38.225/32** + vMAC `02:00:00:ff:3e:98` sur fw01 | ✅ **TRAVAUX-02 clos le 10/07** : exposition 22/443 testée filtrée (3 méthodes), reboot de validation fw01 chronométré (coupure ≈ 45 s), `vmbr2`/MASQUERADE/ip_forward retirés de hv01. Chemin unique : tout le trafic passe par fw01. |
| Zones réseau | MGMT = **VLAN 90** ; DMZ = VLAN 20 ; ADMIN = VLAN 30 | ✅ Les trois zones circulent taggées sur le vRack ; hyperviseurs sur `vmbr1.90`, dns01 en port d'accès tag 90, fw01 en trunk 20/30/90. |
| DNS interne | BIND9 (dns01), zone `atlas.local` + 3 reverses /24 | Récursion restreinte aux 3 zones, forwarders Quad9, listen-on IP unique. |
| Accès admin | Tunnel SSH (+ Tailscale possible sur hyperviseurs uniquement) ; cible = bastion Guacamole | Nominal (DAT) : VPN → Guacamole. Hors bande : SSH/Tailscale, documenté comme accès d'urgence. |
| TLS | **CA interne « Atlas Internal Root CA »** (EC P-256, racine 5 ans au coffre, cert serveur `helpdesk.atlas.local` SAN 1 an), terminaison sur rp01 | ✅ **DÉCISION 14/07 + recetté** : motif = « trust interne documenté » (texte du sujet), service interne, zéro exposition. Script `make-ca.sh` versionné (ca/), .crt dans Git, clés hors VCS. Chaîne validée par `curl --cacert` sans -k depuis rp01 ET depuis un poste client. |
| Accès admin | **VPN WireGuard sur fw01** (UDP 51820, subnet 10.60.0.0/24, PSK, split tunnel + split-DNS `~atlas.local`) | ✅ En service le 14/07 — remplace les tunnels SSH (ProxyJump conservé en accès de secours documenté). Seul flux entrant ; silencieux aux scans. L'endpoint = Additional IP → suit l'IP move en bascule DR (R4). |

## 3. Infrastructure — état exact

### Serveurs
| Rôle | Nom OVH | IP publique | Hostname | MGMT |
|---|---|---|---|---|
| Hyperviseur 1 | ns3201873.ip-146-59-47.eu | 146.59.47.185 | hv01 | 10.90.0.11 |
| Hyperviseur 2 | ns3201919.ip-146-59-47.eu | 146.59.47.158 | hv02 | 10.90.0.12 |

- SYS-1 : Xeon-E 2136 (6c/12t), 32 Go, 2× NVMe 512 Go **ZFS mirror** (pool `data`), datacenter eu-central-waw-a.
- Storage cluster : `zfs-data` (zfspool, images+rootdir, nodes hv01,hv02). Les VM vont TOUJOURS sur zfs-data (jamais `local` — réservé ISO).
- **Cluster `atlas`** : corosync via vRack (`--link0` 10.90.0.x). QDevice = VPS existant de Harry (corosync-qnetd, port 5403/tcp, via IP publique du VPS). `pvecm status` = 3 votes attendus. **Test de perte de nœud réalisé et documenté** (scripts `test-cluster.sh`, `test-failover.sh` dans le repo).
- Auth Proxmox : root@pam (mdp défini via `passwd`) + comptes à créer/créés `membre2@pve`, `membre3@pve` (PVEAdmin, **GUI only**, TOTP recommandé).

### Réseau
- **vRack pn-1331495** : les 2 serveurs y sont. Interface vRack = `enp3s0f1` (les deux nœuds).
- `vmbr0` = réseau public (enp3s0f0). `vmbr1` = bridge vRack **VLAN aware** sans IP. `vmbr1.90` porte le MGMT des hyperviseurs (`10.90.0.11/24` sur hv01, `.12/24` sur hv02).
- ~~`vmbr2`~~ : **supprimé le 10/07** (bloc interfaces + MASQUERADE + `ip_forward=0`, backup `/root/interfaces.bak-wan-2026-07-10`). Les 2 VM d'essai qui le référençaient (1001 template de test + 90909 son linked clone) ont été détruites. hv01 ne route plus rien : fw01 est l'unique chemin.
- **Routes statiques sur les deux hyperviseurs** : `10.20.0.0/24` et `10.30.0.0/24 via 10.90.0.1 dev vmbr1.90`. Vérifiées sur hv02 le 06/07.
- resolv.conf hv01/hv02 : `search atlas.local` + `nameserver 10.90.0.10` + fallback 9.9.9.9. ⚠️ Vérifier OPNsense (System→Settings→General→DNS = 10.90.0.10).

### Plan d'adressage (= zones OPNsense)
| VM | VMID | VLAN | IP | RAM | État |
|---|---|---|---|---|---|
| fw01 (OPNsense 26.1) | 100 | trunk 20/30/90 | .1 de chaque zone ; WAN `51.75.38.225/32` | 3 Go (ballooning désactivé) | ✅ Recetté, reboot de validation OK (coupure ≈ 45 s) |
| dns01 (BIND9) | 110 | 90 | 10.90.0.10 | 1 Go | ✅ Recetté, reboot post-migration OK (~12 s) |
| pbs01 (PBS 4.x, **sur hv02**) | 120 | 90 | 10.90.0.20 | 3 Go | ✅ En service (ISO officielle, datastore 100 Go, jobs quotidiens) |
| guac01 (Guacamole) | 130 | 90 | 10.90.0.30 | 2 Go | ⬜ Optionnel (peut sauter) |
| rp01 (Nginx RP+TLS) | 210 | 20 | 10.20.0.10 | 2 Go | ✅ **Recetté le 14/07** (TLS CA interne, HSTS, rate-limit, reboot validé 43 s) — **PHASE 4 CLOSE** |
| glpi01 (GLPI 11.0.8) | 220 | 20 | 10.20.0.11 | 4 Go | ✅ Recetté le 10/07 ; URL de base → https://helpdesk.atlas.local ; accès direct :80 bloqué (floating) |
| mail01 (Postfix relay vers Mailpit) | 230 | 20 | 10.20.0.20 | 1 Go | ✅ recetté le 14/07 (1er clone cloud-init v5, SSH OK dès le boot)|
| db01 (MariaDB 11.8) | 310 | 30 | 10.30.0.10 | 3 Go | ✅ Recetté |
| zbx01 (Zabbix) | 320 | 30 | 10.30.0.20 | 3 Go | ⬜ À faire |

**pbs01 volontairement placé sur hv02** : séparation du domaine de panne — la prod tourne sur hv01, les sauvegardes résident sur le nœud opposé. pbs01 n'est **pas** sauvegardé lui-même (récursivité) : il est reconstructible en ~20 min (ISO + config) et son datastore est protégé par le ZFS mirror de hv02. Exclu du job de backup avec le template 9000.

Convention VMID : 1xx = MGMT (**tag 90**), 2xx = DMZ (tag 20), 3xx = ADMIN (tag 30). `fw01` reste un trunk sans tag Proxmox, avec sous-interfaces VLAN dans OPNsense. Template = 9000.

### OPNsense (fw01) — configuré
- Interfaces : WAN=`vtnet0` (`51.75.38.225/32`, vMAC `02:00:00:ff:3e:98`, GW `WAN_OVH_GW`=`146.59.47.254`, *far gateway*) ; MGMT=`vlan90` (`10.90.0.1/24`) ; DMZ=`vlan20` (`10.20.0.1/24`) ; ADMIN=`vlan30` (`10.30.0.1/24`). `Block private networks` et `Block bogon networks` sont recochés sur le WAN public.
- NAT outbound : **Automatic**. Sortie publique contrôlée depuis dns01 et glpi01 : `51.75.38.225`. DHCP : désactivé partout (tout statique). Règles WAN entrantes : aucune ouverture volontaire à ce stade.
- ⚠️ **Règles TEMP allow-all sur DMZ et ADMIN** → à remplacer par la matrice de flux AVANT gel (backlog durcissement).
- Faux positif connu : mémoire 99% côté Proxmox = cache ARC ZFS FreeBSD. Réel ≈ 20% (jauge interne). Réponse jury préparée.

### Template VM
- ⚠️ **INCIDENT 05/07 ~16:30 UTC** : le template v3 (9000) a été **détruit par accident** lors du sweep de nettoyage des VM d'essai (101/105/1000), UPID `6A4A8649`. Impact prod : nul (full clones). Détecté le 10/07, re-fabriqué le 12/07.
- `tpl-debian13` **v5** (14/07) = v4 + **cloud-init** (datasource NoCloud/ConfigDrive, lecteur `--ide2 zfs-data:cloudinit`) : provisionnement **sans console** via `qm set --ipconfig0 ip=…,gw=… --nameserver --searchdomain` + `--ciuser root --sshkeys`. Le hostname est dérivé du `--name` du clone. `regen-ssh-keys.service` **retiré** (cloud-init régénère lui-même les clés d'hôte au premier boot — redondance supprimée). Recetté par mail01 : SSH par clé dès le premier boot, IP/DNS/hostname corrects, zéro noVNC.
  - ⚠️ Les clones v5 nomment l'interface **`eth0`** (plus `ens18`) — adapter toutes les commandes/configs.
  - ⚠️ Rappel ×2 vécu : le flag `protection` se propage aux clones (999 le 12/07, 998 le 14/07) → `--protection 0` avant destruction des VM de travail.
- `tpl-debian13` **v4** (re-fabriquée et validée par clone de test le 12/07) : Debian 13.5, qemu-guest-agent, **SSH clés-only appliqué ET testé** (login par clé OK, `Permission denied (publickey)` en mode password), couleurs bash, réseau neutre (`iface ens18 inet manual`), anonymisée. **Protégée** : `--protection 1` + tags `TEMPLATE,ne-pas-supprimer` (rend `qm destroy` impossible sans lever le flag).
- **Nouveautés v4 vs v3** (leçons Debian 13) :
  1. `apt purge dhcpcd-base` **obligatoire** : l'installeur Debian 13 l'installe d'office ; sinon les clones héritent d'un client DHCP actif (APIPA 169.254.x + resolv.conf écrasé en boucle).
  2. `regen-ssh-keys.service` **sans** `ExecStartPost=systemctl restart ssh` : provoquait un **deadlock systemd** (Before=ssh + restart imbriqué) si déclenché hors boot. Le `Before=ssh.service` suffit.
  3. Le durcissement sshd doit être **vérifié par grep** (le sed v3 n'avait jamais été réellement appliqué — cause du SSH par mot de passe constaté sur les clones v3).
  4. Le flag `protection` **se propage aux clones** ; le retirer (`--protection 0`) avant de détruire une VM de test clonée.
- Historique v1→v3 conservé : bugs regen-ssh-keys (ConditionFileNotEmpty + verrou debconf → `ssh-keygen -A` + `ConditionPathExists=!`).
- **Full clone toujours** (linked = pas de migration/réplication possible — vérifié en vrai le 10/07 : destruction de 1001 bloquée par son linked clone 90909, ordre inverse requis).

### Rituel de provisionnement (définitif — runbook R0)
```
0. AVANT boot : Hardware → `vmbr1` + tag de zone (**90=MGMT, 20=DMZ, 30=ADMIN**), RAM du plan
1. hostnamectl set-hostname X ; sed -i 's/debian/X/g' /etc/hosts
2. sed -i '/ens18/d' /etc/network/interfaces        (purge héritage réseau ; dhcpcd déjà purgé en v4)
3. cat > /etc/network/interfaces.d/ens18  (IP statique + gateway de zone)
4. cat > /etc/resolv.conf  (search atlas.local ; nameserver 10.90.0.10)
5. systemctl restart networking
6. Pings rituels : passerelle / 9.9.9.9 / dns01 (+ flux spécifiques)
7. Fin de VM : REBOOT de validation (IP + services reviennent seuls)
```

## 4. Services en production

### dns01 — ✅ recetté
- named.service (alias bind9), zones : `atlas.local` (tous les A + CNAME `helpdesk`→rp01) ; reverses **`0.20.10`/`0.30.10`/`0.90.10.in-addr.arpa`** (⚠️ piège /24 vs /16 corrigé — leçon documentée). Serial courant : 2026070502.
- Options : recursion limitée 10.20/30/90, forwarders 9.9.9.9 + 149.112.112.112, listen-on 10.90.0.10.
- Recette passée : A, 3× PTR, récursion externe. resolv.conf de dns01 pointe sur lui-même (choix documenté).

### db01 — ✅ recetté
- MariaDB 11.8, config `/etc/mysql/mariadb.conf.d/60-atlas.cnf` : bind 10.30.0.10, **binlog ROW** dans `/var/log/mysql/` (répertoire créé à la main — leçon Debian 13), expire 7j, max 100M, server_id 310, buffer pool 1G.
- Base `glpidb` (utf8mb4_unicode_ci). Compte **`glpi_app`@`10.20.0.11`** (restreint à l'IP de glpi01, droits limités à glpidb.*). Secret régénéré via `openssl rand -base64 24`, **stocké hors VCS** (premier secret, trop faible et compromis, révoqué — leçon documentée).
- Binlogs testés : CREATE/INSERT/DROP visibles via **`mariadb-binlog`** (pas mysqlbinlog sur MariaDB 11).
- RAM VM à confirmer passée 2→3 Go.

### glpi01 — ✅ recetté (12/07)
- **GLPI 11.0.8** installé (installation effective le 05/07 21:37, redécouverte le 10/07 — la doc avait pris du retard sur l'exécution). 442 tables dans `glpidb`, connexion via `glpi_app`@db01 validée (`SELECT 1` + `SHOW GRANTS` = droits limités à glpidb.*).
- Vhost nginx : `server_name glpi01.atlas.local helpdesk.atlas.local`, **root = `/var/www/glpi/public`**, socket `php8.4-fpm.sock`. HTTP :80 uniquement (TLS viendra sur rp01).
- **Durcissement (exigence sujet)** : comptes par défaut `glpi`/`tech`/`normal`/`post-only` désactivés (`is_active=0`, preuve SQL avant/après), `install/install.php` supprimé, compte superadmin **nominatif** créé (secret hors VCS).
- **Timer `glpi-cron`** (systemd, chaque minute, `Persistent=true`) : actif, survit au reboot. Nota : service `Type=oneshot` → `inactive (dead)` entre deux déclenchements = normal.
- Reboot de validation le 10/07 21:26 UTC : HTTP 200 au retour, tout revient seul.
- ⚠️ Backlog : sshd_config hérité du template v3 (`PermitRootLogin yes`, password accepté) — **à corriger sur dns01/glpi01/db01** avant gel (2 min/VM, sed documenté dans la recette v4).

### pbs01 — ✅ en service (12/07, sur hv02)
- Installé via **ISO officielle PBS 4.x** (appliance dédiée, pas de passage par le template). Système sur scsi0 32 Go, **datastore `atlas-backups` sur scsi1 100 Go dédié** (ext4, ~97 Go utiles).
- Compte **moindre privilège** `pve-backup@pbs`, rôle `DatastoreBackup` sur le datastore (peut écrire/lire, pas purger ni administrer). Raccordement cluster : `pvesm add pbs pbs01` avec fingerprint pinné — storage partagé, visible des deux nœuds.
- **Premier backup complet 12/07 08:34–08:36 UTC** : 4 VM (fw01, dns01, glpi01, db01) en 101 s, ~13 GiB utiles. fs-freeze/thaw OK partout sauf fw01 (pas d'agent FreeBSD — accepté et documenté : config OPNsense = XML statique).
- **Verify 12/07 08:39 UTC : 4/4, 0 erreur, TASK OK** (job de vérification quotidien créé, re-verify 30 j).
- **Job quotidien 21:00** (Datacenter → Backup) : mode **Exclude** (120 pbs01 + 9000 template exclus, toute VM future incluse d'office), storage pbs01, snapshot. Validé par Run now : 4 VM en **4 s** (dirty-bitmaps).
- Prune (`keep-daily=7, keep-weekly=4`) + GC quotidiens côté PBS.
- Reste : pousser les dumps SQL de db01 vers le datastore (complément binlogs pour l'incident 2).

### Test R2 — ✅ première mesure RTO réelle (12/07)
- Restauration de glpi01 → VM 999 depuis le snapshot du matin (verify OK) : **restore en 18 s** (08:45:07→08:45:25 UTC), services actifs à ~2 min, **bout-en-bout 8 min 21 s** (dont l'essentiel = manips propres au test : isolation link_down, IP décalée .99, debug ifup).
- Le refus `glpi_app`@`10.20.0.99` par MariaDB = **preuve du moindre privilège** (compte restreint à .11). Note runbook R2 : *en incident réel, la VM restaurée reprend l'IP d'origine → zéro blocage, RTO technique ~2-3 min*. Exigence ≤ 40 min : **marge ×5 à ×15**.
- Leçon : `qm set net0` à chaud provoque un unplug/replug → refaire `ifup` dans l'invité.

## 6. Reste à faire (ordre recommandé)

1. ~~TRAVAUX-02~~ ✅ · ~~glpi01~~ ✅ · ~~pbs01~~ ✅ · ~~rp01/TLS (phase 4)~~ ✅ 14/07 · ~~VPN admin~~ ✅ 14/07 · ~~template v5 cloud-init~~ ✅ 14/07
2. ~~mail01~~ ✅ **fait (validé Démo 1 le 15/07, contre-vérifié 16/07)** : Postfix actif, `mynetworks` = glpi01 + zbx01, chaîne ticket→mail complète (38 mails Mailpit, cycle ticket #4 : création/suivi/résolution). ⚠️ reboot de validation mail01 : à confirmer s'il a été joué.
3. **zbx01** (agents partout, checks HTTP via rp01/DB/backups/SMTP queue/disque, dashboard PRA/DR jury).
4. ~~Réplication pvesr 15 min hv01→hv02 (6 VM)~~ ✅ **15/07 22:42 UTC** (1re passe 5 min 18 s ; C1 10/10 + C2 migration live 24 s/18 s, downtime < 50 ms, rejoués le même soir) · ~~dumps SQL db01 → pbs01~~ ✅ **15/07 23:07 UTC** (proxmox-backup-client 4.2.2, dépôt pbs-client, push < 1 s vers `host/db01`) — ~~automatisation quotidienne~~ ✅ **15/07 23:16 UTC** : timer `glpidb-backup` (20:30 UTC quotidien, Persistent). **Item 4 entièrement clos.**
5. **Matrice de flux** + retrait des 2 règles TEMP + règles fines — en s'appuyant sur la leçon « interface d'entrée » (les règles s'évaluent sur l'interface de la zone SOURCE ; l'intra-VLAN ne traverse pas fw01).
6. Durcissement résiduel : sshd clés-only sur dns01/glpi01/db01 (héritage v3) ; GUI OPNsense listen MGMT only ; comptes PVE nominatifs + TOTP ; fermer 8006 public.
7. **Incidents 1 & 2** en conditions de démo (mode dégradé lecture seule ; point-in-time binlogs ≥ 10 tickets) + bascule R4/retour R5 (IP move — le VPN suit automatiquement, endpoint = Additional IP).
8. Budget 04 (facture OVH) → gel J-4 → preuves → ≥ 2 répétitions.
   (+ Schéma Miro : vue « mode dégradé » avec chiffres mesurés — cadre v2 déjà créé.)

## 7. Pièges connus & leçons (anti-sèche soutenance)

- Reverse DNS /24 = `0.X.10.in-addr.arpa` (pas `X.10`) ; checkzone ne détecte pas une zone au mauvais nom.
- Debian 13 : `/var/log/mysql` à créer ; outils `mariadb-*` ; service `named` (alias bind9) ; unit qemu-guest-agent activée par udev (pas d'enable).
- Clones : penser tag VLAN AVANT boot ; purger l'héritage réseau ; `ssh-keygen -A` si SSH mort.
- hyperviseurs : routes statiques vers VLAN taggés obligatoires (sinon VM saines injoignables).
- OPNsense : interfaces OPT naissent en deny-all (≠ LAN) ; « Refusing to operate on linked unit »-style faux problèmes ; mémoire 99% = ARC.
- Secrets : openssl rand, jamais en clair dans commandes/historique/VCS (purger `history` après un `--password` en CLI ; Proxmox stocke le secret PBS dans `/etc/pve/priv/storage/pbs01.pw`).
- pvecm add : si « hostname verification failed » → /etc/hosts une seule entrée (IP privée) + updatecerts, sinon `--fingerprint` (méthode officielle).
- Debian 13 (suite) : `dhcpcd-base` installé d'office par l'installeur → à purger (APIPA 169.254.x + resolv.conf écrasé sinon) ; `dhclient` absent → tester le DHCP avec `busybox udhcpc`.
- OPNsense : le DHCP est servi par **Dnsmasq** (pas Kea) — plage par défaut héritée du LAN initial à désactiver (écart « tout statique » détecté le 12/07, corrigé, contre-test No DHCPOFFERS).
- systemd : jamais de `systemctl restart X` dans un `ExecStartPost` d'une unité `Before=X` → deadlock (jobs en attente circulaire ; `systemctl cancel` pour purger).
- `grep -r` ne suit pas les symlinks (sites-enabled) → `grep -R`.
- Sweep de nettoyage : **toujours `qm list` + relire les VMID avant un destroy en série** (perte du template 9000 le 05/07) ; les templates portent désormais `--protection 1` + tag.
- **Règles pf/OPNsense : évaluées sur l'interface d'ENTRÉE du paquet** (= zone source du flux) ; l'intra-VLAN ne traverse jamais fw01 (règles inertes) → block multi-zones = **floating rule** (quick, direction in).
- systemd-resolved réserve `*.local` au mDNS → timeout via le stub 127.0.0.53 ; contournement : routing domain `resolvectl domain <if> '~atlas.local'` (persisté en PostUp wg-quick). Itération 2 : préférer `.internal`.
- WireGuard : pas de handshake = souvent le peer non-Enabled/non rattaché (le service ignore silencieusement les inconnus — propriété anti-scan) ; champ `DNS =` client = dépendance dure au tunnel (perte de résolution si tunnel mort) → split-DNS PostUp plus robuste.
- Config copiée depuis chat/GUI/PDF : passer `cat -A` avant usage (tiret cadratin U+2014 vécu dans AllowedIPs).
- cloud-init (v5) : régénère les clés d'hôte lui-même (regen-ssh-keys retiré) ; hostname dérivé du --name du clone ; interface nommée `eth0` sur les clones.
- vzdump/PBS : premier passage complet, suivants en secondes (dirty-bitmaps) ; fw01 sans agent = pas de fs-freeze (accepté, config XML statique) ; ne jamais sauvegarder pbs01 vers lui-même (récursivité).
- - Zabbix server : `DBHost` est commenté par défaut dans `zabbix_server.conf` → sans décommenter, le serveur tente une connexion par **socket Unix local** (`/run/mysqld/mysqld.sock`) même si `DBHost` est renseigné plus bas mais mal formé — vérifier avec `grep -n "^DB"` après édition, pas seulement relire à l'œil.
- Import du schéma SQL Zabbix (`server.sql.gz`) échoue avec une DB distante en **binlog ROW actif** (`ERROR 1419 : SUPER privilege required`) : les triggers du schéma nécessitent `log_bin_trust_function_creators=1` côté MariaDB (ajouté à `60-atlas.cnf`, persistant). Un import interrompu à mi-chemin laisse la base dans un état partiel → `DROP DATABASE` + recréation avant de rejouer l'import.

## 8. Fichiers & outils existants

- Repo : `github.com/Hifkil/Helpdesk-Atlas` — y ranger : `docs/JOURNAL-DE-BORD.md`, `docs/captures/`, `docs/runbooks/R0-R5`, `scripts/test-cluster.sh`, `scripts/test-failover.sh`, ce pack de livrables.
- Miro : board archi — cadre « Architecture Atlas v2 — OVH (cible) » généré (modifiable ; placement Zabbix/Guacamole sur hv02 à valider en équipe).
- SSH PC : ProxyJump via hv01 pour 10.20/30/90.*. L'ancien réseau `192.168.100.0/24` n'est plus le WAN nominal et sera retiré avec `vmbr2`.
