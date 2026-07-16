# Journal de preuves · Helpdesk Atlas

*Livrable 5 du sujet : « logs, timestamps, tailles, temps réels, commandes ». C'est la **colonne vertébrale** des preuves RPO/RTO : chaque affirmation faite en soutenance ou dans un livrable doit pointer vers une ligne d'ici.*

**Conventions** : heure locale Europe/Paris, format `AAAA-MM-JJ hh:mm`. Captures nommées `AAAA-MM-JJ_hhmm_sujet.png` dans `docs/captures/`. Réflexe pendant un test : lancer `date` avant/après chaque étape (le prompt horodaté fait foi sur les captures).

---

## 1. Journal chronologique

| Date/heure | Événement / action | Commande(s) clé(s) | Résultat / métrique (durée, taille) | Preuve | Opérateur |
|---|---|---|---|---|---|
| 2026-07-04 ⬜hh:mm | Interconnexion vRack validée | `scripts/test-cluster.sh` | latence < 1 ms, SSH croisé OK | capture ⬜ | harry |
| 2026-07-04 ⬜hh:mm | Test perte d'un nœud (quorum) | `scripts/test-failover.sh`, `pvecm status` | Quorate: Yes à 2/3 votes, réintégration < 60 s | capture ⬜ | harry |
| 2026-07-05 ⬜hh:mm | Recette dns01 (zones + reverses + récursion) | 5× `dig` | 5/5 conformes | capture ⬜ | harry |
| 2026-07-05 ⬜hh:mm | Recette segmentation (deny inter-VLAN par défaut) | ping ADMIN→MGMT sans règle | bloqué, loggé côté fw01 | capture ⬜ | harry |
| 2026-07-05 ⬜hh:mm | Binlogs MariaDB opérationnels | `mariadb-binlog --base64-output=decode-rows -vv …` | CREATE/INSERT/DROP lisibles, rejouables | capture ⬜ | harry |
| 2026-07-⬜ | Rotation d'un secret DB (exposition → révocation) | `openssl rand -base64 24`, `ALTER USER…` | ancien secret révoqué, nouveau hors VCS | entrée journal de bord | harry |
| 2026-07-06 (heure facture à compléter) | Achat Additional IP `51.75.38.225/32` | Manager OVH | facturation **mensuelle** ; montant exact ⬜ €/mois | facture/capture Manager ⬜ | harry |
| 2026-07-06 21:39 | Migration MGMT → VLAN 90 validée | `ifreload -a`, `pvecm status`, pings inter-VLAN, `dig` | hv01/hv02 sur `vmbr1.90`; 3/3 votes; deux nœuds `A,V,NMW`; routes hv02 10.20/10.30 présentes. Durée de coupure MGMT non chronométrée. | sorties terminal / capture pvecm ⬜ | harry |
| 2026-07-06 21:40–21:41 | Reboot post-migration de dns01 | `qm reboot 110`, pings, `dig`, `systemctl is-active named` | retour ICMP en **~12 s** ; IP `10.90.0.10/24`; DNS direct, inverse et externe OK ; `named` actif | sorties terminal ⬜ | harry |
| 2026-07-06 (heure exacte à compléter) | Additional IP assignée à hv01 + vMAC créée | Manager OVH | service `ns3201873.ip-146-59-47.eu`; vMAC `02:00:00:ff:3e:98` | capture Manager ⬜ | harry |
| 2026-07-06 (heure exacte à compléter) | WAN public sur fw01 : /32 + far gateway + vMAC | `qm set 100 -net0 …bridge=vmbr0,firewall=1`; OPNsense `WAN_OVH_GW` | IP WAN `51.75.38.225/32`, GW `146.59.47.254`; NAT sortant validé | config OPNsense/Proxmox ⬜ | harry |
| 2026-07-06 (heure exacte à compléter) | Contre-recette sortie Internet après bascule WAN | dns01 : ping/dig/curl ; glpi01 : getent/curl | 0 % perte vers 9.9.9.9 ; DNS externe et interne OK ; **IP vue = 51.75.38.225** depuis dns01 et glpi01 | sorties `curl ifconfig.me` ⬜ | harry |
| 2026-07-05 21:37 | Installation GLPI **11.0.8** complète (rétro-datée via mtime `config_db.php` — la doc avait pris du retard sur l'exécution) | installeur web via tunnel ; DB db01/glpi_app | 442 tables dans glpidb ; vhost nginx root=`public`, socket php8.4 | mtime config_db.php + `SHOW TABLES` | harry |
| 2026-07-05 ~18:30 | **INCIDENT — destruction accidentelle du template tpl-debian13 (9000)** lors du sweep de nettoyage des VM d'essai (101/105/1000) | `qm destroy` en série | Impact prod : nul (full clones) ; blocage futur rp01/mail01/zbx01. Détecté le 10/07. Anti-récidive : `--protection 1` + tag TEMPLATE sur le nouveau template | tasks Proxmox UPID `6A4A8649` | harry |
| 2026-07-10 21:05 (UTC) | Test d'exposition entrante WAN : 22 et 443 **filtrés** depuis l'extérieur | `bash /dev/tcp` + `curl -m 3` (3 méthodes) | Timeout sur les 2 ports = deny all implicite opérationnel | sorties terminal PC | harry |
| 2026-07-10 21:11:15 (UTC) | Reboot de validation fw01 (WAN public) | `qm reboot 100` + boucle ping dns01→9.9.9.9 | **Coupure ≈ 45 s** (retour à seq 45/48) ; contre-recette : ping 0 % perte, dig OK, IP vue `51.75.38.225` depuis dns01 **et** glpi01 | sortie ping horodatée | harry |
| 2026-07-10 ~21:18 (UTC) | Nettoyage reliquats lab : destruction 90909 (linked clone) puis 1001 (template de test) | `qm destroy --purge` (ordre clone→base imposé par ZFS) | Plus aucune conf VM ne référence vmbr2 | tasks Proxmox + `qm list` | harry |
| 2026-07-10 ~21:22 (UTC) | Retrait `vmbr2` + MASQUERADE + `ip_forward=0` sur hv01 (fin du provisoire) | édition `/etc/network/interfaces` (backup fait), `ifreload -a`, `iptables -t nat -D` | Chaîne POSTROUTING vide ; `vmbr2 does not exist` ; forwarding hôte désactivé ; contre-recette dns01 : 0 % perte, IP vue `51.75.38.225` → **TRAVAUX-02 CLOS** | sorties terminal | harry |
| 2026-07-10 ~21:24 (UTC) | Durcissement GLPI : comptes par défaut désactivés + `install.php` supprimé + superadmin nominatif créé | GUI GLPI + `rm` ; requête SQL avant/après | `glpi`/`tech`/`normal`/`post-only` → `is_active=0` (4/4) | requêtes SQL avant/après | harry |
| 2026-07-10 21:26:22 (UTC) | Timer `glpi-cron` déployé + reboot de validation glpi01 | timer systemd (1 min, Persistent) ; `qm reboot 220` | HTTP 200 au retour ; nginx/php-fpm/timer actifs seuls → **glpi01 RECETTÉ** (réserve : TLS via rp01) | sorties terminal | harry |
| 2026-07-12 ~09:00 (UTC) | **ÉCART détecté & corrigé** : DHCP dnsmasq actif sur MGMT (plage 10.90.0.41–245 héritée de la conf LAN initiale OPNsense ; bail .208 servi à la VM template) | GUI OPNsense Services→Dnsmasq (désactivation) + contre-test | `busybox udhcpc` : **No DHCPOFFERS** ; conforme « tout statique » ; DNS interne inchangé (dns01 seul, dnsmasq écoutait sur 53053) | capture GUI + sortie udhcpc | harry |
| 2026-07-12 ~08:00–10:00 (UTC) | **Re-fabrication template tpl-debian13 v4** (post-incident du 05/07) | recette v3 + purge `dhcpcd-base` + fix deadlock regen-ssh-keys + protection | Clone de validation : clés d'hôte régénérées, SSH par clé OK, **password refusé** (`Permission denied (publickey)`) ; `protection: 1`, tags TEMPLATE | tasks Proxmox + double test SSH | harry |
| 2026-07-12 08:34–08:36 (UTC) | **Premier backup PBS complet** des 4 VM prod (fw01, dns01, glpi01, db01) → datastore `atlas-backups` (100 Go dédié, pbs01 sur hv02) | `vzdump --mode snapshot --storage pbs01` | **4/4 OK en 101 s**, ~13 GiB utiles ; fs-freeze OK sauf fw01 (pas d'agent FreeBSD, accepté — config XML statique) ; compte moindre privilège `pve-backup@pbs` | sorties vzdump | harry |
| 2026-07-12 08:38:57–08:39:15 (UTC) | **Vérification datastore** : job verify quotidien créé + exécuté | Verify job PBS | **4/4 groupes, 0 erreur, TASK OK** en 18 s | log tâche PBS | harry |
| 2026-07-12 08:43:47–08:43:53 (UTC) | Job quotidien 21:00 validé (Run now) : mode **Exclude** (120 pbs01 + 9000 exclus — récursivité et immuabilité ; toute VM future incluse d'office) | Datacenter→Backup, storage pbs01 | 4 VM en **4 s** (dirty-bitmaps) ; Count=2 par groupe ; prune keep-daily=7/keep-weekly=4 + GC quotidiens | capture Content PBS | harry |
| 2026-07-12 08:45:07–08:53:28 (UTC) | **TEST R2 : restauration complète glpi01 → VM 999** depuis snapshot verify-OK (première mesure RTO réelle — détail §2 bis) | `qmrestore pbs01:...vm/220... 999 --unique 1` + validation isolée puis raccordement IP décalée | **Restore : 18 s** ; services OK ~2 min ; **bout-en-bout 8 min 21 s** ; refus `glpi_app`@`.99` par MariaDB = preuve moindre privilège ; RTO réel estimé 2-3 min (IP identique en incident) vs exigence ≤ 40 min | Task History + captures console | harry |
| 2026-07-12 ~10:30 (UTC) | Politique de rétention créée (l'affirmation du pack précédent était planifiée, pas réalisée — écart doc/réel corrigé) : prune quotidien keep-daily=7/keep-weekly=4 + GC quotidien | GUI PBS Prune & GC Jobs + Run now | Prune : 0 suppression (conforme, historique < 7 j) ; séquence nocturne backup 21:00 → prune → GC | capture écran jobs | harry |
| 2026-07-13 (UTC) | **DÉCISION** : TLS via **CA interne** (vs Let's Encrypt) — motif : « trust interne documenté » = texte du sujet ; service interne ; zéro exposition entrante ; livrables chaîne de confiance + rotation. **DÉCISION** : Ansible écarté pour cette itération (arbitrage temps vs preuves PRA) — runbooks rejoués + futur script recette.sh à la place | discussion d'équipe | tracé | ce journal | harry |
| 2026-07-13 ~15:30 (UTC) | rp01 provisionné (**premier clone du template v4**) : rituel R0, aucun APIPA (purge dhcpcd validée en réel), SSH clés-only hérité | `qm clone 9000 210 --full` | pings rituels OK | sorties terminal | harry |
| 2026-07-13 ~15:50 (UTC) | **CA interne créée** : racine « Atlas Internal Root CA » EC P-256 5 ans (clé au coffre) + cert `helpdesk.atlas.local` SAN 1 an ; script `make-ca.sh` versionné, .crt dans Git, clés exclues (.gitignore vérifié : `git ls-files ca/` vide) | openssl | `openssl verify : OK` | ca/ dans le repo | harry |
| 2026-07-13 15:59–16:02 (UTC) | **rp01 recette TLS** : Nginx TLS1.2+/HTTP2, redirect 80→443, HSTS, rate limiting, proxy→glpi01 | `curl -skI` + `curl --cacert` (sans -k) local **et** depuis le poste client | **HTTP/2 200 via la chaîne CA→cert, cookie glpi_ en bout de chaîne** | sorties curl | harry |
| 2026-07-14 ~08:00 (UTC) | **VPN WireGuard admin en service** : instance wg-admin (UDP 51820, 10.60.0.0/24), peer harry-pc + **PSK**, split tunnel ; règles WAN (seule règle entrante) + groupe WireGuard ; ACL récursion dns01 étendue à 10.60/24 | GUI OPNsense + wg-quick | Handshake OK ; ping 10.60.0.1 et 10.90.0.10 (ttl=63) 0 % perte ; **remplace les tunnels SSH** (ProxyJump = accès de secours documenté) | wg show + pings | harry |
| 2026-07-14 ~08:15 (UTC) | Leçons debug VPN : (1) pas de handshake = peer non-Enabled/non rattaché — WireGuard ignore silencieusement les inconnus (propriété anti-scan) ; (2) champ DNS client = dépendance dure au tunnel ; (3) `.local` réservé au mDNS par systemd-resolved → **split-DNS** `resolvectl domain atlas '~atlas.local'` persisté en PostUp ; (4) tiret cadratin dans config copiée détecté via `cat -A` | diagnostic sockstat/wg show serveur | résolution atlas.local OK à travers le VPN ; leçon DAT : préférer `.internal` en itération 2 | sorties dig/resolvectl | harry |
| 2026-07-14 ~08:40 (UTC) | URL de base GLPI → `https://helpdesk.atlas.local` (prérequis liens corrects dans les notifications mail01) | GUI/SQL glpi_configs | SELECT de contrôle OK | capture | harry |
| 2026-07-14 08:45:31–08:46:14 (UTC) | **Reboot de validation rp01** | `qm reboot 210` + `curl --cacert` via VPN | HTTP/2 200 au retour en **43 s**, chaîne TLS auto-relancée → **rp01 RECETTÉ, PHASE 4 CLOSE** | sorties terminal | harry |
| 2026-07-14 ~08:55 (UTC) | Règle **floating** « deny direct glpi01:80 » (quick, log) — leçon : règles évaluées sur l'interface d'ENTRÉE ; l'intra-VLAN rp01→glpi01 ne traverse pas fw01 (aucune règle Pass nécessaire) ; 2 règles DMZ initiales inertes supprimées | Firewall→Floating | Contre-test : exit 28 depuis VPN **et** dns01 ; HTTP/2 200 via rp01 intact | sorties curl + Live View | harry |
| 2026-07-14 ~09:30 (UTC) | **Template v5** = v4 + cloud-init (NoCloud, lecteur ide2) ; regen-ssh-keys retiré (redondant) ; --ciuser/--sshkeys au template. Incident mineur : 1re consécration sans préparation intérieure (cloud-init non installé) détecté et refait ; protection héritée ×2 (998) | apt cloud-init + cloud-init clean + re-consécration | provisionnement sans console via --ipconfig0 | qm config 9000 | harry |
| 2026-07-14 ~10:10 (UTC) | **mail01 provisionné (VM 230) = recette v5** : hostname/IP/DNS injectés par cloud-init, SSH par clé au premier boot, zéro noVNC | `qm clone` + `qm set --ipconfig0 ip=10.20.0.20/24,gw=10.20.0.1` | hostname=mail01, eth0=10.20.0.20/24, clés d'hôte uniques (fingerprint neuf) | sortie ssh | harry |
| 2026-07-15 18:33 (UTC, horodatage Mailpit) | **Postfix mail01 + chaîne ticket→mail VALIDÉE** (Démo 1 exécutée par l'équipe : création, suivi, résolution du ticket #4) — contre-vérifié le 16/07 : postfix actif, `mynetworks` = 127.0.0.0/8 + glpi01 + zbx01, listen 10.20.0.20:25, Mailpit :8025 | GLPI notifications + `curl mailpit/api/v1/messages` | **38 mails** en boîte ; cycle complet #4 : « Nouveau suivi » + « Ticket résolu » vers alice.martin@ et admin@ | API Mailpit (total + sujets) | équipe |
| 2026-07-15 22:42:45–22:48:03 (UTC) | **Réplication pvesr 15 min activée** (6 VM : fw01, dns01, rp01, glpi01, mail01, db01) hv01→hv02 | `pvesr create-local-job <id>-0 hv02 --schedule "*/15"` ×6 + `pvesr schedule-now` | 1re passe complète en **5 min 18 s** (fw01 154,6 s · dns01 30,7 s · rp01 28,1 s · glpi01 48,0 s · mail01 37,5 s · db01 46,9 s), 6 jobs OK, FailCount 0 | `pvesr status` (log C1 22:55) | harry |
| 2026-07-15 22:41 & 22:55 (UTC) | **TEST C1 — recette cluster non intrusive** (2 passages : avant/après activation pvesr) | `bash scripts/test-cluster.sh \| tee /root/recette-cluster_*.log` | 1er passage 9/10 (pvesr pas encore créés — attendu) ; 2e passage **10 PASS / 0 FAIL** : quorum 3/3, QDevice A,V, link0 connected, vRack 0,634 ms 0 % perte, SSH croisé, storages, 6 jobs pvesr | `docs/captures/2026-07-15_2255_recette-cluster-C1.log` | harry |
| 2026-07-15 22:43:55–22:51:58 (UTC) | **R1 rejoué en réel** : dump glpidb + rotation binlog + backup VM + verify datastore | `mariadb-dump --single-transaction --flush-logs --master-data=2`, `vzdump --all --exclude 120 --storage pbs01`, verify via API PBS | dump **1 s** (274 Ko, gzip OK, binlog.000009 ouvert) ; backup **10 VM en 22 s** (incrémental) ; verify **10/10 groupes, 0 erreur en 62 s**. Étape « push dump → pbs01 » : ⬜ (choix client PBS/rsync à trancher) | sorties vzdump + task verify PBS | harry |
| 2026-07-15 22:52:55–22:53:52 (UTC) | **TEST C2 — migration live dns01** hv01→hv02→hv01 (ping -D continu depuis poste VPN) | `qm migrate 110 hv02 --online --with-local-disks` (option **obligatoire**, disque local ZFS — leçon : la réplique pvesr sert de base, delta ~1 Mo) | aller **24 s** / retour **18 s**, downtime QEMU **47/41 ms** ; **4 pings perdus par sens** (~4 s perçues) = réapprentissage MAC vRack OVH, pas la virtualisation | `docs/captures/2026-07-15_2252_ping-migration-dns01.log` + `_migration-live-dns01.log` | harry |
| 2026-07-15 22:44 (UTC) | **ÉCART détecté & corrigé** : db01 en fuseau `Europe/London` (BST, +0100) — convention projet = UTC ; l'horodatage du dump R1 était décalé d'une heure | `timedatectl set-timezone UTC` (db01) | db01 en UTC ; ⚠️ même écart constaté sur glpi01/mail01/zbx01 (+ pbs01 en +02:00) — correction à planifier (backlog) | `timedatectl` avant/après | harry |
| 2026-07-15 22:49 (UTC) | **ÉCART détecté (non corrigé)** : le job PBS quotidien ne configure que `exclude 120` — le template 9000 ET les VM hors plan 330 (adm01) / 920 (admin01) sont sauvegardés, contrairement à la doc « 9000 exclu » | log vzdump 21:00 + `pvesh get /cluster/backup` | à trancher : ajouter 9000 (± 330/920) à l'exclude ou assumer et corriger la doc | log task vzdump | harry |
| 2026-07-15 23:04:24–23:04:30 (UTC) | **Destruction VM hors plan 330 (adm01) et 920 (admin01)** — décision harry (« mauvaises VM ») ; rituel respecté : `qm list` avant, `--protection 0` sur 920 (flag hérité + onboot=1) | `qm stop` ×2, `qm set 920 --protection 0`, `qm destroy --purge` ×2 | 8 VM restantes = plan d'adressage exact ; groupes PBS vm/330 & vm/920 conservés (purge naturelle keep-daily=7) | `qm list` avant/après | harry |
| 2026-07-15 23:05:42–23:05:46 (UTC) | **Fuseaux corrigés → UTC** sur glpi01, mail01, zbx01, dns01, rp01 (héritage template Europe/London) ; hv01/hv02 déjà UTC ; **pbs01 refusé via API** (`pve-backup@pbs` sans Sys.Modify → à faire via GUI root@pam) ; template 9000 à corriger à la prochaine révision | `timedatectl set-timezone UTC` ×5 | 5/5 VM en UTC ; solde l'écart détecté à 22:44 | sorties timedatectl | harry |
| 2026-07-15 23:06:31–23:07:24 (UTC) | **R1 étape 3 SOLDÉE** : dépôt `pbs-client` trixie + proxmox-backup-client 4.2.2 sur db01 ; creds root-only (`/root/.pbs-env` + `/root/.pbs-pass`, 0600, fingerprint pinné) ; premier push réel du dump | `proxmox-backup-client backup glpidb-dumps.pxar:/backup` | install 5 s ; push **< 1 s** ; snapshot `host/db01/2026-07-15T23:07:24Z` (274,6 Kio) listé côté PBS | `snapshot list host/db01` | harry |
| 2026-07-15 ~23:10 (UTC) | pbs01 passé en UTC (GUI root@pam — l'API refusait avec `pve-backup@pbs`, sans Sys.Modify) — dernier serveur hors convention ; contrôle API : `timezone: UTC`, localtime = time | GUI PBS Configuration→Time | tous les serveurs (hv01, hv02, 8 VM, pbs01) en UTC ; reste template 9000 (à sa prochaine révision) | GET /nodes/localhost/time | harry |
| 2026-07-15 ~23:11 (UTC) | **Écart exclude soldé** : job PBS quotidien aligné sur la doc — template 9000 ajouté à l'exclude (immuabilité ; VM 330/920 déjà détruites) | `pvesh set /cluster/backup/backup-a42c7587-5689 --exclude 120,9000` | `exclude = 120,9000` vérifié ; périmètre du job = exactement les 7 VM prod | `pvesh get /cluster/backup` | harry |
| 2026-07-15 23:16:05–23:16:06 (UTC) | **R1 automatisé** : timer systemd `glpidb-backup` sur db01 (quotidien **20:30 UTC**, Persistent=true, 30 min avant le job vzdump 21:00) — script dump + gzip -t + push pbs01 + rétention locale 7 j | `systemctl enable --now glpidb-backup.timer` + test réel `systemctl start glpidb-backup.service` | SERVICE_OK ; snapshot `host/db01/2026-07-15T23:16:06Z` (549,9 Kio, 2 dumps) ; prochain passage 16/07 20:30 UTC | `list-timers` + `snapshot list host/db01` | harry |
| 2026-07-16 (UTC) | **DÉCISION** : durcissement firewall **simulé** (TEMP allow-all DMZ/ADMIN conservées) — arbitrage temps vs preuves PRA ; matrice de flux complétée F01–F25 (livrable 15 §2.2 : + F19 db01→pbs01:8007, F20 SSH admin, F21 checks actifs zbx, F22 NTP, F23-F25 zone LAN 10) = référence d'implémentation + argumentaire jury §2.1 | édition livrable 15 | segmentation démontrée là où elle existe (WAN silencieux, floating deny, LAN10 deny-all) ; généralisation documentée ~2 h post-POC | livrable 15 §2 | harry |
| 2026-07-14 17:27 (BST) | **zbx01 provisionné + Zabbix Server 7.0.28 en service** : clone template v5, DB `zabbix` créée sur db01 (compte moindre privilège `zbx_app`@`10.30.0.20`), schéma importé (204 tables), backend connecté | `qm clone 9000 320`, `mariadb -h 10.30.0.10 -u zbx_app -p zabbix < server.sql.gz`, `systemctl restart zabbix-server` | Service `active (running)`, tous les workers démarrés (pollers/trappers/history syncers/alert manager), aucune erreur `[Z3001]`/`[Z3005]` en log | `systemctl status zabbix-server` + `zabbix_server.log` ⬜ capture | harry |
| 2026-07-15 09:40–10:15 (BST) | **Déploiement zabbix-agent2 sur 7 hôtes** (glpi01, db01, mail01, dns01, rp01, hv01, hv02) + hosts créés dans le frontend, templates "Linux by Zabbix agent" | `apt install zabbix-agent2` × 7, config Server/ServerActive/Hostname, création host frontend | **7/7 hosts ZBX vert**, aucune règle fw01 supplémentaire nécessaire (flux existants suffisants) | Monitoring → Hosts, capture ⬜ | harry |
| 2026-07-16 07:36:47–07:36:48 (UTC) | **Zone LAN 10 — dns01** (procédure 16, étape ②) : ACL récursion étendue à `10.10.0.0/24` ; A `desk01`→10.10.0.50 ; nouvelle zone reverse **`0.10.10.in-addr.arpa`** (piège /24 respecté) + PTR ; serial → 2026071601 ; backups `.bak-2026-07-16_0736` sur dns01 | édition via `qm guest exec 110` ; `named-checkconf` + `named-checkzone` ×2 avant `rndc reload` | checkzone 2/2 OK ; recette `dig` A + PTR conformes depuis dns01 **et** depuis le poste VPN | sorties dig | harry + Claude Code |
| 2026-07-16 07:37:53–07:37:54 (UTC) | **Routes de zone LAN10 sur hv01 ET hv02** (procédure 16, étape ④/routes) : `10.10.0.0/24 via 10.90.0.1 dev vmbr1.90` ajoutée à chaud + persistée en `post-up` dans `/etc/network/interfaces` (backup `/root/interfaces.bak-lan10-2026-07-16_0737`) | `sed -i` + `ip route add` (sans ifreload — MGMT non coupé en journée) | route active et persistée sur les 2 nœuds | `ip route` + extrait interfaces | harry + Claude Code |
| 2026-07-16 07:42:04–07:42:13 (UTC) | **desk01 provisionné (VM 410, full clone v5)** : `qm clone 9000 410 --full --storage zfs-data` (9 s), net0 vmbr1 **tag 10**, 2 vCPU/2 Go, cloud-init `ip=10.10.0.50/24 gw=10.10.0.1`, DNS 10.90.0.10, vga qxl ; `protection:1` hérité du template **conservé volontairement** (VM permanente) | `qm clone` + `qm set` ×3 | `qm config 410` conforme au plan ; démarrage différé en attente zone fw01 | qm config 410 | harry + Claude Code |
| 2026-07-16 ~08:00–09:29 (UTC) | **Zone LAN VLAN 10 finalisée sur fw01 (GUI, étape ①)** : VLAN 10 (`vlan04`) + interface **USERS** (opt3, 10.10.0.1/24, statique, pas de DHCP) préexistants — **écart doc/réel : la zone s'appelle USERS, pas LAN10** ; ajout des **5 règles Pass** sur USERS : ① ICMP→USERS address (diag gw uniquement — préserve les contre-tests de segmentation) ② TCP/UDP 53→10.90.0.10 ③ TCP 443→10.20.0.10 ④⑤ **TEMP** TCP 80/443→any (apt, à retirer après install) ; deny-all implicite loggé conservé | GUI OPNsense (piloté via Claude in Chrome) + Apply changes | « changes applied successfully » ; recette par le rituel desk01 (ligne suivante) | captures Firewall→Rules→USERS | harry + Claude Code |
| 2026-07-16 09:30:26–09:30:45 (UTC) | **Premier boot desk01 + rituel de validation réseau** : cloud-init OK (hostname, eth0=10.10.0.50/24, gw, resolv.conf) ; ping passerelle 10.10.0.1 **3/3, 0 % perte** ; `dig helpdesk.atlas.local` → rp01/10.20.0.10 (ACL récursion 10.10/24 validée) ; `curl -I https://deb.debian.org` → **HTTP/2 200** (TEMP apt) ; rituel adapté : pings 9.9.9.9/dns01 remplacés par dig+curl (ICMP restreint à la passerelle par design) | `qm start 410` + `qm guest exec` (pings/dig/curl) | 4/4 contrôles réseau conformes | sorties guest exec | harry + Claude Code |
| 2026-07-16 09:30:52–09:34:35 (UTC) | **desk01 : bureau installé** — xfce4 + xfce4-goodies + lightdm + firefox-esr (**3 min 43 s**, log `/root/install-xfce.log`) ; compte **demo.user** créé (uid 1001, `--allow-bad-names` — NAME_REGEX refuse le point —, `--disabled-password`, mdp à définir par l'opérateur hors chat/VCS) | `apt-get install` via `qm guest exec` + `adduser` | marqueur `/root/XFCE_OK` horodaté | install-xfce.log | harry + Claude Code |
| 2026-07-16 09:34:50–09:35:05 (UTC) | **desk01 : confiance CA interne (procédure 16 §7)** : `atlas-root.crt` (SHA1 26:6E:14:81…) → magasin système (`update-ca-certificates` done) + `policies.json` firefox-esr (ImportEnterpriseRoots + Install) ; `graphical.target` par défaut | guest exec (cert poussé en base64) | contre-test : `curl --cacert … https://helpdesk.atlas.local` → **HTTP/2 200** ET `curl` sans option (magasin système) → **HTTP/2 200** | sorties curl | harry + Claude Code |
| 2026-07-16 09:35:23–09:35:43 (UTC) | **Reboot de validation desk01** : retour en **~20 s** — lightdm `active`, IP 10.10.0.50 revenue, ping gw OK, HTTPS helpdesk 200 — tout revient seul | `qm reboot 410` + guest exec | 4/4 au retour | sorties guest exec | harry + Claude Code |
| 2026-07-16 10:30:13–10:35 (UTC) | **Dry-run DEMO 4 (VM supprimée/restauration/migration)** : 999 `glpi01-demo` vérifiée sur hv01 (`link_down=1`, tag 20, sans protection/onboot) ; boot complet confirmé via agent puis **shutdown propre en 7 s** (prérequis destroy) ; 3 backups vm/220 sur pbs01 (dernier `2026-07-15T22:49:54Z`), pipeline awk/sort/tail testé verbatim ; zfs-data actif 2 nœuds (257/176 GiB libres) ; **PIÈGE CORRIGÉ : `ssh root@hv02` par NOM échouait (host key inconnue) dans les 2 sens** → clés vérifiées par empreinte (identiques IP/nom) puis enregistrées, ÉTAPE 5 et RETOUR sécurisés | `qm status/config`, `pvesm list/status`, `ssh-keyscan` + `ssh-keygen -lf` | démo jouable de bout en bout ; réserve : migration = copie 15G intégrale (pas de pvesr sur 999) → prévoir 2-5 min | sorties terminal | harry + Claude Code |
| 2026-07-16 09:36:15–09:39 (UTC) | **Recette desk01 (§9)** : dig A+PTR conformes ; accès direct `http://10.20.0.11` → **exit 28** (floating deny) ; ping→10.30.0.10 (ADMIN) et →10.90.0.11 (MGMT) : **100 % perte**, 6+6 blocks `Default deny` visibles en Live View (captures) ; **découverte** : NTP UDP 123 sortant bloqué/loggé → backlog flux F22 (NTP interne ou règle avant gel). Restent : contrôle visuel cadenas (noVNC), compte GLPI demo.user + ticket→Mailpit, mdp session demo.user | guest exec + GUI Live View (filtres 10.30.0.10 / 10.90.0.11 + action=block) | 5/7 contrôles §9 ✅, 2 reportés (actions manuelles) | captures Live View + sorties guest exec | harry + Claude Code |

*Nota horodatage : les serveurs sont en UTC (Paris = UTC+2 en été). Les entrées du 12/07 marquées (UTC) proviennent des horloges serveur ; les heures GUI Proxmox/PBS affichent l'heure locale.*

*(Une ligne par événement significatif — installation, test, incident, correction. Les ⬜hh:mm des 04-05/07 : retrouver l'heure via `history`, les horodatages des captures existantes ou les tasks Proxmox.)*

---

## 2 bis. Preuve — TEST R2 du 12/07/2026 (répétition de l'incident 1, mesure de référence)
*Restauration de glpi01 vers une VM temporaire (999), prod intacte, IP décalée pour coexistence.*

| Étape | Heure UTC | Delta cumulé | Preuve |
|---|---|---|---|
| T0 — Lancement `qmrestore` (snapshot 08:34:16Z, **verify OK**) | 08:45:07 | — | Task History |
| Restauration terminée (~2,6 GiB utiles / 15 GiB) | 08:45:25 | **18 s** | Task `VM 999 - Restore`, Status OK |
| Démarrage VM (isolée `link_down=1`, anti-conflit IP/ARP) | 08:45:51 | 44 s | Task History |
| Services validés : nginx, php-fpm, glpi-cron actifs ; HTTP répond (500 attendu, DB inaccessible = isolation voulue) | ~08:47 | ~2 min | capture console |
| Raccordement réseau (IP décalée .99) ; GLPI atteint db01 | 08:53:28 | **8 min 21 s** | header `Date:` du curl |

**Enseignements** : RTO bout-en-bout **8 min 21 s**, dont l'essentiel = manipulations propres au *test* (isolation volontaire, changement d'IP, ifup après replug net0). Le refus `glpi_app`@`10.20.0.99` par MariaDB **valide le moindre privilège** (compte restreint à .11). En incident réel : restauration à IP identique → zéro blocage, **RTO technique ~2-3 min**. Exigence ≤ 40 min : **marge ×5 à ×15**.

Commandes exécutées : `date` · `qmrestore pbs01:backup/vm/220/2026-07-12T08:34:16Z 999 --storage zfs-data --unique 1` · `qm set 999 --net0 virtio,bridge=vmbr1,tag=20,firewall=1,link_down=1` · `qm start 999` · (console) `systemctl is-active nginx php8.4-fpm glpi-cron.timer` · `curl -sI http://127.0.0.1` · `sed -i 's/10.20.0.11/10.20.0.99/' /etc/network/interfaces.d/ens18` · `qm set 999 --net0 ...` (sans link_down) · `ifup ens18` · pings gateway/db01 · `curl -sI http://127.0.0.1` · `date` · nettoyage `qm stop 999 && qm destroy 999 --purge`.

---

## 2. Preuve — Incident 1 : perte du stockage primaire (restore full)
*Alimente : runbook R2 colonne « Mesuré », cahier de recette T07, slide 8. Cible : **RTO ≤ 40 min**. La démo officielle rejouera le scénario en conditions réelles (IP identique + mode dégradé lecture seule) — le test du 12/07 (§2 bis) donne la mesure de référence.*

| Repère | Heure | Preuve |
|---|---|---|
| T0 — constat / décision | ⬜ | capture console VM détruite |
| Choix du snapshot PBS (verify OK) | ⬜ | capture liste snapshots |
| Fin de restauration sur hv02 | ⬜ | capture tâche verte + taille restaurée : ⬜ Go |
| Service répond (HTTP 200) | ⬜ | capture navigateur |
| Mode dégradé lecture seule actif | ⬜ | capture bannière + écriture refusée |
| **Tfin — RTO mesuré** | **⬜ min** | tableau récapitulatif signé |

Commandes exactes exécutées : ⬜ (coller ici, dans l'ordre, avec leurs sorties tronquées).

## 3. Preuve — Incident 2 : suppression ≥ 10 tickets (restore granulaire)
*Alimente : R3, T08, slide 9. Cibles : tickets restaurés, postérieurs intacts, **RPO ≤ 20 min**.*

| Repère | Valeur | Preuve |
|---|---|---|
| Nb tickets supprimés | ⬜ (≥ 10) | capture GLPI avant/après suppression |
| T_incident identifié dans les binlogs | ⬜ (position + timestamp) | extrait `mariadb-binlog` |
| Base temporaire à T_incident − 1 s | ⬜ | `SELECT COUNT(*)` comparés |
| Tickets réinjectés | ⬜ | capture GLPI : tickets revenus |
| Tickets créés APRÈS l'incident | intacts ✔ | capture ticket témoin post-incident |
| **RPO démontré** | **⬜ min** | delta dernier point restaurable vs incident |

## 4. Preuve — Bascule DR (R4) et retour (R5)

| Repère | Heure/valeur | Preuve |
|---|---|---|
| Perte hv01 simulée | ⬜ | capture OVH/ping |
| Quorum conservé (2/3) | ⬜ | `pvecm status` sur hv02 |
| 6 VM redémarrées sur hv02 (ordre R4) | ⬜ | captures qm list |
| Additional IP déplacée ; même vMAC réapparue sur hv02 | ⬜ | capture Manager (IP + vMAC sur serveur cible) |
| Service complet re-rendu | ⬜ (RTO bascule : ⬜ min) | parcours ticket→mail |
| Delta de données (dernière réplication) | ⬜ min (**RPO**) | timestamps pvesr |
| Retour arrière sans perte | ticket créé pendant la bascule visible ✔ | capture |

## 5. Preuves récurrentes — sauvegardes
*Alimente : « taux de succès sauvegardes » (Zabbix) + livrable supervision.*

| Date | Job | Statut | Taille | Durée | Verify |
|---|---|---|---|---|---|
| 2026-07-12 08:34 (UTC) | Backup initial 4 VM (manuel, vzdump→pbs01) | ✅ OK | ~13 GiB utiles (50 GiB provisionnés, dédup/sparse) | 101 s | ✅ 4/4, 0 erreur |
| 2026-07-12 08:43 (UTC) | Job quotidien (Run now, mode Exclude) | ✅ OK | incrémental (dirty-bitmaps) | **4 s** | ✅ (job verify quotidien) |
| 2026-07-15 21:00 (UTC) | PBS quotidien automatique (1er passage planifié) | ✅ OK | incrémental (10 VM dont 320/330/920/9000 — cf. écart exclude) | ~2 min | ✅ (verify 22:50) |
| 2026-07-15 22:49 (UTC) | Rejeu R1 : vzdump 10 VM (Run now équivalent CLI) | ✅ OK | incrémental dirty-bitmaps, 98-100 % réutilisé | **22 s** | ✅ 10/10, 0 erreur, 62 s |
| 2026-07-15 22:43 (UTC) | Dump glpidb + flush binlog (`/backup` sur db01, inclus dans backup VM) | ✅ OK | 274 Ko | 1 s | n/a (gzip -t OK) |
| 2026-07-15 23:07 (UTC) | Push dédié dump glpidb → pbs01 (proxmox-backup-client, groupe `host/db01`) | ✅ OK | 274,6 Kio | < 1 s | n/a (⬜ automatisation quotidienne à planifier) |

Taux de succès sur la période : **4 / 4 jobs documentés = 100 %** (à tenir à jour quotidiennement — c'est la métrique « taux de succès sauvegardes » exigée, future sonde Zabbix). Les passages quotidiens intermédiaires (13-14/07) sont visibles dans les snapshots PBS (ex. vm/920 : 14/07 21:00 + 15/07 21:01) — les recenser lors du prochain pointage.

*Le journal est « la colonne vertébrale » : ces lignes alignent le journal sur les colonnes Mesuré des runbooks R1/R3/R4/R5 (le R2 y figure déjà, test réel du 12/07). À coller dans le tableau chronologique, section 1. Adapter les heures si besoin.*

> ✅ **pvesr et R1 : mesures réelles au tableau chronologique section 1** (15/07 22:42 et 22:43 UTC). **R3, R4, R5 : NON REJOUÉS À CE JOUR** — position assumée ci-dessous (décision 16/07, arbitrage temps). Ne JAMAIS présenter les estimations comme des mesures.

| Runbook | Statut honnête (16/07/2026) | Ce qu'on peut affirmer au jury (avec preuve) | Estimation (à annoncer comme telle) |
|---|---|---|---|
| **R3** (incident 2, point-in-time) | Procédure écrite, **non rejouée**. Mécanique de base prouvée : binlogs ROW lisibles et rejouables (CREATE/INSERT/DROP décodés le 05/07), dump quotidien + `--flush-logs` automatisés (timer 15/07) | « la chaîne dump + binlogs est en place et vérifiée quotidiennement ; le rejeu `--stop-datetime` est documenté pas à pas » | bout-en-bout ~20-30 min (si rejoué avant soutenance : remplacer par la mesure, ici ET dans 02-runbooks) |
| **R4** (bascule DR) | Procédure écrite, **non rejouée**. Briques prouvées UNE PAR UNE : réplication 15 min active (cycles ~2 s mesurés), quorum 2/3 sans intervention (test perte de nœud 04/07 + C3 à venir), IP move documenté OVH, VM démarrables sur hv02 (C2 : dns01 a tourné sur hv02 le 15/07) | « chaque maillon de la bascule est testé individuellement ; le RPO ≤ 15 min est garanti par construction (capture pvesr réelle) » | RTO ~20-30 min (IP move 5-10 min + démarrages) |
| **R5** (retour arrière) | Procédure écrite, **non rejouée** | « procédure symétrique de R4, réplication inversée — même mécanique que celle démontrée en C2 » | ~40 min, coupure perçue = fenêtre WAN |

**Rappel cohérence** : les colonnes Mesuré R3/R4/R5 de `02-runbooks-PRA.md` restent **vides** (c'est voulu). Si un test est rejoué d'ici la soutenance, remplir LES DEUX fichiers avec la mesure réelle.
