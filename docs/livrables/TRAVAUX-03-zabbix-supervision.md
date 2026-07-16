# TRAVAUX 03 — Supervision Zabbix (zbx01)

*Exécuté le 2026-07-15 · Opérateur : Harry · Statut : ✅ terminé et recetté.*

## But

Déployer une plateforme de supervision Zabbix 7.0 couvrant l'ensemble de l'infrastructure Atlas (8 hôtes), avec les métriques exigées par le sujet (uptime applicatif, latence DB, taux de succès sauvegardes, disque), un dashboard PRA/DR pour la soutenance, et une preuve d'alerte réelle fonctionnelle.

## Architecture retenue

- **zbx01** (VMID 320, VLAN 30 ADMIN, IP `10.30.0.20`) : Zabbix Server + Frontend (nginx/PHP), provisionné depuis le template `tpl-debian13` v5 (cloud-init).
- **Base de données** : réutilisation de **db01** (MariaDB existante) plutôt qu'une instance dédiée — évite une 2e base à durcir/sauvegarder ; flux zbx01↔db01 intra-VLAN ADMIN, aucune règle fw01 nécessaire.
- **Agents** : `zabbix-agent2` déployé sur les 8 hôtes (glpi01, db01, mail01, dns01, rp01, hv01, hv02, pbs01).
- **fw01 (OPNsense)** : **hors périmètre** — plugin SNMP indisponible/non fonctionnel dans le temps imparti. Décision documentée, cf. §7.

---

## Phase 1 — Provisionnement de zbx01

```bash
qm clone 9000 320 --full --name zbx01
qm set 320 --ipconfig0 ip=10.30.0.20/24,gw=10.30.0.1
qm set 320 --nameserver 10.90.0.10 --searchdomain atlas.local
qm set 320 --ciuser root --sshkeys /root/.ssh/authorized_keys
qm set 320 --net0 virtio,bridge=vmbr1,tag=30,firewall=1
qm set 320 --memory 3072
qm start 320
```

Rituel R0 standard (v5 cloud-init) : hostname et IP injectés automatiquement, SSH par clé dès le premier boot, interface `eth0`.

Recette réseau : gateway ADMIN, dns01, sortie Internet — 3/3 OK.

## Phase 2 — Installation Zabbix Server

```bash
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian13_all.deb
dpkg -i zabbix-release_latest_7.0+debian13_all.deb
apt update
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent2
```

Version installée : **Zabbix 7.0.28**, dépôt officiel `debian13` disponible nativement (pas eu besoin de fallback debian12).

### Base de données (sur db01)

```sql
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zbx_app'@'10.30.0.20' IDENTIFIED BY '<secret openssl rand -base64 24>';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zbx_app'@'10.30.0.20';
FLUSH PRIVILEGES;
```

⚠️ **Piège rencontré** : l'import du schéma SQL (`server.sql.gz`) échoue avec une DB en **binlog ROW actif** :
```
ERROR 1419 (HY000): You do not have the SUPER privilege and binary logging is enabled
```
Les triggers du schéma Zabbix nécessitent la création de fonctions, bloquée par défaut quand le binlog est actif pour un compte non-SUPER. **Correctif** (ajouté à `60-atlas.cnf`, persistant) :
```sql
SET GLOBAL log_bin_trust_function_creators = 1;
```
```ini
# /etc/mysql/mariadb.conf.d/60-atlas.cnf
log_bin_trust_function_creators = 1
```
Un import interrompu à mi-chemin laisse la base dans un état partiel : `DROP DATABASE` + recréation avant de rejouer l'import proprement.

```bash
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mariadb -h 10.30.0.10 -u zbx_app -p zabbix
```
→ **204 tables** créées.

### Configuration `zabbix_server.conf`

```ini
DBHost=10.30.0.10
DBName=zabbix
DBUser=zbx_app
DBPassword=<secret>
```

⚠️ **Piège rencontré** : `DBHost` est **commenté par défaut** dans le fichier. Sans décommenter, le serveur tente une connexion par **socket Unix local** (`/run/mysqld/mysqld.sock`, inexistant sur zbx01) même si `DBUser`/`DBPassword` sont correctement renseignés plus bas :
```
[Z3001] connection to database 'zabbix' failed: [2002] Can't connect to local server through socket '/run/mysqld/mysqld.sock'
```
**Vérification systématique après édition** :
```bash
grep -n "^DBHost\|^DBName\|^DBUser" /etc/zabbix/zabbix_server.conf
```

```bash
chmod 640 /etc/zabbix/zabbix_server.conf
chown root:zabbix /etc/zabbix/zabbix_server.conf
systemctl restart zabbix-server
systemctl enable zabbix-server
```

Log applicatif (pas dans journald, `zabbix-server` n'y écrit que les événements start/stop) :
```bash
tail -n 40 /var/log/zabbix/zabbix_server.log
```

## Phase 3 — Frontend (nginx + PHP)

```bash
nano /etc/zabbix/nginx.conf        # listen 80 ; server_name zbx01.atlas.local
nano /etc/zabbix/php-fpm.conf      # php_value[date.timezone] = Europe/Paris
rm /etc/nginx/sites-enabled/default   # sinon le vhost par défaut capte les requêtes avant celui de Zabbix
nginx -t && systemctl restart nginx php8.4-fpm
```

Assistant d'installation web (`http://zbx01.atlas.local/setup.php`) :
- **Check pre-requisites** : point bloquant *System locale* → `apt install locales && dpkg-reconfigure locales` (sélection `en_US.UTF-8`), puis `systemctl restart php8.4-fpm nginx`.
- **DB connection** : Host `10.30.0.10`, DB `zabbix`, user `zbx_app`, TLS decoché (test opérationnel sans, à revoir si durcissement futur).
- **Server name** : `superviseur-atlas`.
- Comptes par défaut `Admin`/`zabbix` → **mot de passe changé immédiatement** après premier login (durcissement, même principe que GLPI).

Entrée DNS ajoutée sur dns01 : `zbx01 IN A 10.30.0.20`.

## Phase 4 — Déploiement des agents (8 hôtes)

Procédure identique répétée sur chaque cible :
```bash
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian13_all.deb
dpkg -i zabbix-release_latest_7.0+debian13_all.deb
apt update && apt install -y zabbix-agent2
```
`/etc/zabbix/zabbix_agent2.conf` :
```ini
Server=10.30.0.20
ServerActive=10.30.0.20
Hostname=<nom-exact-de-la-vm>
```
```bash
systemctl restart zabbix-agent2 && systemctl enable zabbix-agent2
```

Côté frontend, un host créé par cible (**Data collection → Hosts → Create host**), groupe de zone (`DMZ`/`ADMIN`/`MGMT`), template `Linux by Zabbix agent`, interface Agent IP:10050.

| Host | IP | Groupe | Statut |
|---|---|---|---|
| glpi01 | 10.20.0.11 | DMZ | ✅ |
| db01 | 10.30.0.10 | ADMIN | ✅ |
| mail01 | 10.20.0.20 | DMZ | ✅ |
| dns01 | 10.90.0.10 | MGMT | ✅ |
| rp01 | 10.20.0.10 | DMZ | ✅ |
| hv01 | 10.90.0.11 | MGMT | ✅ |
| hv02 | 10.90.0.12 | MGMT | ✅ |
| pbs01 | 10.90.0.20 | MGMT | ✅ |

**Aucune règle fw01 supplémentaire n'a été nécessaire** pour les flux 10050/10051 — les règles existantes suffisaient déjà (à confirmer/documenter explicitement lors de la matrice de flux finale, point ouvert).

## Phase 5 — Métriques custom exigées par le sujet

### a) Uptime applicatif (HTTP)

Item type **HTTP agent** sur le host `Zabbix server` :
- URL : `https://helpdesk.atlas.local`
- Required status codes : `200`
- Retrieve mode : `Headers` (le mode `Body` récupère le HTML complet, incompatible avec `Type of information: Numeric` et peu lisible sur dashboard)
- SSL verify peer/host : décochés (CA interne non présente dans le trust store zbx01)
- Type of information : `Text`

Trigger :
```
nodata(/Zabbix server/app.uptime.http,2m)=1
```

### b) Latence DB

Compte MySQL dédié, lecture seule fonctionnelle uniquement (connexion) :
```sql
CREATE USER 'zbx_check'@'localhost' IDENTIFIED BY '<secret>';
GRANT USAGE ON *.* TO 'zbx_check'@'localhost';
```

Script `/usr/local/bin/db_latency_check.sh` sur db01 :
```bash
#!/bin/bash
START=$(date +%s%N)
mariadb -h 127.0.0.1 -u zbx_check -p'<secret>' -e "SELECT 1" >/dev/null 2>&1
END=$(date +%s%N)
echo $(( (END - START) / 1000000 ))
```
```bash
chown root:zabbix /usr/local/bin/db_latency_check.sh
chmod 750 /usr/local/bin/db_latency_check.sh
```
⚠️ **Piège rencontré** : le script fonctionne en `root` (test manuel) mais échoue avec `Permission denied` côté agent, car `zabbix-agent2` tourne sous l'utilisateur `zabbix`. Vérification systématique :
```bash
su -s /bin/bash zabbix -c /usr/local/bin/db_latency_check.sh
```

UserParameter (`/etc/zabbix/zabbix_agent2.d/db_latency.conf`) :
```
UserParameter=db.latency.ms,/usr/local/bin/db_latency_check.sh
```

Item Zabbix agent, clé `db.latency.ms`, units `ms`. **Mesure de référence : ~5 ms.**

Trigger :
```
avg(/db01/db.latency.ms,5m)>100
```
(seuil décidé en équipe : > 100 ms pendant 5 min)

### c) Taux de succès sauvegardes (PBS)

Token API dédié, rôle `Audit` (lecture seule métadonnées) sur pbs01 :
```bash
proxmox-backup-manager user create zbx-monitor@pbs --email monitoring@atlas.local
proxmox-backup-manager user generate-token zbx-monitor@pbs monitoring-token
proxmox-backup-manager acl update /datastore/atlas-backups Audit --auth-id 'zbx-monitor@pbs!monitoring-token'
```
⚠️ **Piège rencontré (2 points)** :
1. Format du header d'authentification PBS : `PBSAPIToken=<tokenid>:<secret>` — le séparateur est **`:`**, pas `=`. Une erreur ici renvoie `authentication failed`.
2. **L'ACL doit cibler le token explicitement**, pas seulement l'utilisateur parent (`--auth-id 'zbx-monitor@pbs!monitoring-token'`, pas `zbx-monitor@pbs` seul) : un token n'hérite pas automatiquement des permissions accordées à l'utilisateur. Erreur observée sans ce ciblage : `permission check failed - missing Datastore.Audit|Datastore.Backup`.

Script `/usr/local/bin/pbs_backup_check.sh` sur pbs01 :
```bash
#!/bin/bash
TOKEN="zbx-monitor@pbs!monitoring-token:<secret>"
LAST_BACKUP=$(curl -s -k -H "Authorization: PBSAPIToken=$TOKEN" \
  "https://127.0.0.1:8007/api2/json/admin/datastore/atlas-backups/snapshots" \
  | grep -o '"backup-time":[0-9]*' | grep -o '[0-9]*' | sort -n | tail -1)
NOW=$(date +%s)
AGE_HOURS=$(( (NOW - LAST_BACKUP) / 3600 ))
if [ "$AGE_HOURS" -le 26 ]; then echo 1; else echo 0; fi
```
```bash
chown root:zabbix /usr/local/bin/pbs_backup_check.sh
chmod 750 /usr/local/bin/pbs_backup_check.sh
```

UserParameter : `UserParameter=pbs.backup.recent,/usr/local/bin/pbs_backup_check.sh`

Item Zabbix agent, clé `pbs.backup.recent`, update interval `1h`. **Résultat : `1` (backup < 26h confirmé).**

Trigger :
```
last(/pbs01/pbs.backup.recent)=0
```

### d) Disque

Natif via le template `Linux by Zabbix agent` (`vfs.fs.size[/,pfree]`) sur tous les hôtes — aucune configuration supplémentaire requise.


## Phase 6 — Dashboard PRA/DR

Dashboard `PRA/DR Atlas`, widgets :
- Top hosts by CPU utilization (filtré sur tous les groupes de zone, pas seulement `Zabbix servers` — piège : filtre par défaut trop restrictif)
- Host availability (9/9 vert)
- Problems by severity
- Current problems
- Latence DB — historique (graph)
- Dernier backup PBS (item value)
- Uptime Helpdesk App (item value)
- System information

Widget Geomap (par défaut) retiré — non pertinent pour le narratif.

## Phase 7 — Test d'alerte réelle (T11)


**Test alternatif retenu** : arrêt volontaire de glpi01.
```bash
qm stop 220
# attente
qm start 220
```

Résultat : trigger `Application Helpdesk indisponible` (High) déclenché après le délai `nodata(2m)`, visible dans **Monitoring → Problems** à 3m15s. Retour au vert confirmé après redémarrage de glpi01 (trigger secondaire `Linux: Zabbix agent is not available` observé en transition, résolu après reprise du polling).

## Reste ouvert / limitations documentées

- **fw01** non supervisé (plugin SNMP OPNsense indisponible/non fonctionnel dans le temps imparti). Évolution possible : `bsnmpd` natif FreeBSD ou upgrade OPNsense.
- **Test T11 mariadb** remplacé par un test équivalent sur glpi01 — limitation architecturale assumée (Zabbix et glpidb partagent la même instance MariaDB).
- **Faux positif potentiel** : trigger « High memory utilization » observé sur hv01 (>90% pendant 5 min) — probablement du cache page Linux normal sur un hyperviseur (à vérifier via `free -h`, colonne `available`), pendant du faux positif ARC ZFS déjà documenté pour fw01. Seuil à ajuster ou à documenter comme non-bloquant.
- **TLS DB** (Zabbix ↔ MariaDB) désactivé pour la mise en service initiale — à réactiver si le temps le permet, cohérence avec l'exigence « chiffrement en transit » du dossier client.
