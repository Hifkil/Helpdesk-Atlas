# TRAVAUX 04 — Chaîne d'alertes & notifications (Zabbix → mail01 → Mailpit)

*Exécuté le 2026-07-15 · Opérateur : Harry · Statut : ✅ terminé — reste le T11 final (mariadb) à rejouer post-migration.*
*Se lit après `TRAVAUX-03-zabbix-supervision.md` (installation Zabbix, Thibault) — ce document le complète et clôt plusieurs de ses points ouverts.*

## But

Compléter la plateforme TRAVAUX-03 avec la 5e métrique exigée par le sujet (**file SMTP**), fermer le faux positif mémoire hyperviseurs, et rendre la chaîne d'alerte **réellement notifiante** (Zabbix → SMTP → boîte témoin). En chemin : diagnostic et correction d'un incident silencieux sur les notifications GLPI.

---

## 1. Métrique « file SMTP » (dernière des 5 exigées)

UserParameter sur mail01 (`/etc/zabbix/zabbix_agent2.d/postfix.conf`) :

```
UserParameter=postfix.queue,postqueue -p | tail -1 | awk '/^--/ {print $5} /empty/ {print 0}'
```

Test agent : `zabbix_agent2 -t postfix.queue` → `[s|0]` ✅ (l'agent tourne sous l'utilisateur `zabbix`, qui a le droit d'exécuter `postqueue` nativement sur Debian — pas de sudoers requis).

- Item : host mail01, clé `postfix.queue`, Zabbix agent, Numeric unsigned, 1m.
- Trigger : `min(/mail01/postfix.queue,10m)>10` — sévérité **Average** (seuil livrable 10 : > 10 messages pendant 10 min).

**Mapping sujet complet** : uptime app ✅ (T-03) · latence DB ✅ (T-03) · succès sauvegardes ✅ (T-03) · disque ✅ (T-03) · **file SMTP ✅ (T-04)** — 5/5.

## 2. Clôture du faux positif mémoire hv01/hv02 (point ouvert T-03 §7)

Diagnostic mesuré sur hv01 :

```
Mem: 31Gi total, 29Gi used, 1.7Gi available
ARC ZFS : 15,2 GiB   (/proc/spl/kstat/zfs/arcstats)
```

→ **La moitié de la RAM « utilisée » est le cache ARC ZFS**, libérable sous pression mémoire. Ce n'est pas du cache page Linux classique (hypothèse initiale T-03) mais le pendant Linux exact du faux positif fw01/FreeBSD déjà au DAT.

Correction : macro `{$MEMORY.UTIL.MAX}` = **95** sur hv01 et hv02 (héritée du template, surchargée au niveau host). Alerte « High memory utilization (>90% for 5m) » éteinte d'elle-même dans les 5 min. Capture avant/après au dossier.

**Décision tracée** : seuil hyperviseurs ajusté et justifié — les nœuds ZFS ont une jauge mémoire structurellement haute ; la vraie alerte utile est `available` bas, pas `used` haut.

## 3. Flux et notifications mail

### Règle fw01 — zbx01 → mail01:25

- Firewall → Rules → **ADMIN** (interface d'entrée du flux — cohérent avec la leçon floating de TRAVAUX rp01 : les règles s'évaluent là où le paquet entre).
- Créée via **alias** (`zbx01` = 10.30.0.20, `mail01` = 10.20.0.20) : la nouvelle GUI OPNsense 26.1 refuse la saisie CIDR directe dans le champ adresse. Bénéfice collatéral : règles lisibles (`zbx01 → mail01:25`) pour la matrice de flux et la soutenance.
- ⚠ Règle actuellement masquée par la TEMP allow-all ADMIN — **contre-test obligatoire au retrait des TEMP** (backlog durcissement, inchangé).

### Postfix (mail01)

`mynetworks` élargi à zbx01 (sinon `554 Relay access denied` : mail01 n'acceptait le relais que pour glpi01) :

```
mynetworks = 127.0.0.0/8, 10.20.0.11/32, 10.30.0.20/32
```

### Zabbix

- Media type **Email** : SMTP `10.20.0.20:25`, hello `zbx01.atlas.local`, from `zabbix@atlas.local`, security None. **Bouton Test → mail reçu dans Mailpit ✅** (capture « Test subject » horodatée).
- Média sur l'utilisateur Admin : Email → `admin@atlas.local`, toutes sévérités. ✅
- Action « Report problems to Zabbix administrators » activée. ✅

## 4. Incident (résolu) — notifications GLPI silencieuses

**Symptôme** : contre-test du parcours ticket→mail avant T11 : plus aucun mail depuis 12:31 (6 h de silence). 32 notifications en file, `sent_try=0`.

**Diagnostic** (SQL, preuves au journal) : tâches `queuednotification`, `mailgate`, `watcher` en **mode GLPI** (exécution au fil de la navigation web) au lieu de **CLI** — jamais ramassées par le timer `glpi-cron` (`lastrun=NULL` depuis l'installation). La recette ticket→mail du 14/07 n'avait fonctionné **que parce qu'un opérateur naviguait dans l'interface** au même moment.

**Correction** : `UPDATE glpi_crontasks SET mode=2 WHERE name IN ('queuednotification','mailgate','watcher');` — preuve SQL avant/après. File vidée au passage suivant du timer (32 mails délivrés dans Mailpit, capture). Historique `glpi_crontasklogs` : entrées « Run mode: CLI » chaque minute = **preuve d'autonomie de la chaîne**, sans session web ouverte.

**Nota outillage** : `lastrun` et `crontasklogs.date` sont des colonnes **datetime** en GLPI 11 — `FROM_UNIXTIME()` renvoie NULL dessus et a parasité le diagnostic un moment. Les requêtes du runbook utilisent désormais les colonnes brutes.

**Leçons** (reportées en §7) : checklist post-install GLPI complétée — vérifier le mode d'exécution des actions automatiques ; *une chaîne validée uniquement en présence d'un observateur n'est pas une chaîne validée*.

## 5. Compléments/rectificatifs à reporter dans TRAVAUX-03

| Point T-03 | Évolution |
|---|---|
| §Architecture « Base : réutilisation de db01 » | **Caduc** — migration de la base `zabbix` vers une MariaDB **locale à zbx01** (Thibault, 15/07). Motif tracé : suppression de la dépendance croisée supervision→db01 ; la supervision reste opérationnelle en cas de perte de la base de production. Compte `zbx_app`@`localhost`, ancien compte/base supprimés de db01 (moindre privilège). |
| §7 « T11 mariadb remplacé (instance partagée) » | **Limitation levée** par la migration → le **T11 version mariadb redevient possible** et devient le test vitrine (cf. §6). Le test `qm stop 220` de T-03 reste valable comme preuve complémentaire (panne VM ≠ panne service). |
| §7 « faux positif potentiel hv01 » | **Fermé** — cause ARC ZFS mesurée (15,2 GiB), macro 95 % appliquée hv01/hv02 (cf. §2). |
| §5a « SSL verify décochés » | Point ouvert repris ici : importer `ca-root.crt` dans le trust store de zbx01 (`/usr/local/share/ca-certificates/` + `update-ca-certificates`) puis recocher verify peer/host. Cohérence « trust interne documenté » du sujet. Effort ~5 min. |

## 6. T11 final — test d'alerte bout-en-bout (à dérouler, prérequis tous verts)

Scénario : `systemctl stop mariadb` sur db01, attente 2-3 min, `systemctl start mariadb`.

Preuves attendues (3 captures + entrée journal horodatée T0/Tfin) :
1. Dashboard PRA/DR : problème rouge (latence DB / mysql down) — **la supervision reste vivante pendant la panne de la base de prod** = démonstration directe de la décision de migration ;
2. Mail d'alerte dans Mailpit (chaîne Zabbix→Postfix→Mailpit) ;
3. Retour au vert + mail de résolution.

Bonus visuel attendu : l'item `postfix.queue` peut monter brièvement pendant la rafale — à capturer si visible.

## 7. Leçons de la session

1. **Mode CLI des actions automatiques GLPI** : `queuednotification`/`mailgate`/`watcher` sont en mode « GLPI » par défaut → notifications dépendantes de la navigation web. À vérifier systématiquement post-install (checklist mise à jour).
2. **GUI OPNsense 26.1** : champs adresse des règles = pas de CIDR inline → passer par des **alias nommés** (lisibilité matrice de flux en prime).
3. **`mynetworks` Postfix** : chaque nouvel émetteur SMTP interne doit y être ajouté explicitement (`554 Relay access denied` sinon) — zbx01 ajouté, penser aux suivants.
4. **ARC ZFS sous Linux** : même faux positif mémoire que FreeBSD/fw01 — sur tout nœud ZFS, ajuster `{$MEMORY.UTIL.MAX}` et surveiller `available`.
5. **GLPI 11 / colonnes datetime** : `lastrun`, `crontasklogs.date` ne sont pas des timestamps Unix — pas de `FROM_UNIXTIME()`.
6. **Collation `utf8mb4_bin`** (base Zabbix) : les `LIKE` y sont sensibles à la casse — pièges dans les requêtes d'audit.
7. **Indépendance de la supervision** : la panne à démontrer et l'outil qui la mesure ne doivent pas partager de dépendance — décision de migration DB locale directement plaidable devant le jury.

## Fichiers/preuves produits cette session

- Captures : « Test subject » Zabbix dans Mailpit · pluie des 32 mails GLPI · dashboard avant/après macro ARC · (à venir : les 3 du T11).
- Preuves SQL : `glpi_crontasks` avant/après (mode 1→2) · `glpi_queuednotifications` (32 envoyées, 0 en attente) · `glpi_crontasklogs` (« Run mode: CLI »).
- Config : `zabbix_agent2.d/postfix.conf` (mail01) · alias + règle fw01 ADMIN · `mynetworks` mail01 · media type/média/action Zabbix.
