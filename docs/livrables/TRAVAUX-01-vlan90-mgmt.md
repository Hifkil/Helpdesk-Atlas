# TRAVAUX 01 — Migration MGMT : natif → VLAN 90 taggé

*Exécuté le 2026-07-06 · Opérateur : Harry · **Statut : ✅ terminé et recetté** · Validation finale : 21:39–21:41 Europe/Paris.*

## But
Aligner le POC sur le sujet (« MGMT = VLAN 90 ») : **toutes** les zones deviennent taggées sur le trunk vRack (90/20/30). Les IP ne changent pas, seul le tag change.

## Impact & durée
- **Durée : ~30 min.** Coupure du plan MGMT : ~5 min (fw01 LAN, dns01, IP 10.90.0.x des hyperviseurs).
- **Ce qui ne coupe PAS** : SSH/GUI des hyperviseurs via leurs IP publiques (vmbr0), les échanges DMZ↔ADMIN via fw01 (glpi01↔db01), le QDevice (il passe par Internet, port 5403).
- Corosync va se reformer après la bascule : **ne lancer aucune opération cluster** (clone, backup, migration) pendant la fenêtre. Pas de HA configurée → aucun risque de fencing.
- **Filet de sécurité** : garder un onglet ouvert sur la **console noVNC de fw01** (Proxmox GUI → VM 100 → Console). Elle marche même si tout le réseau interne est cassé.

---

## Phase 0 — Préparation (aucun impact)

Sur **hv01 ET hv02** :
```bash
cp /etc/network/interfaces /root/interfaces.bak-vlan90-$(date +%F)
grep -B1 -A9 'iface vmbr1' /etc/network/interfaces   # vérifier : bridge-vlan-aware yes
ip route | grep -E '10\.(20|30)\.0\.0'               # routes statiques présentes ? (⚠️ hv02 à vérifier — dette connue)
```
Noter les MAC existantes (on en aura besoin telles quelles) :
```bash
qm config 100 | grep net1     # fw01, patte trunk vmbr1
qm config 110 | grep net0     # dns01
```

## Phase 1 — OPNsense : créer le device VLAN 90 (aucun impact)

GUI OPNsense (https://10.90.0.1) → **Interfaces → Devices → VLAN → +** :
- Parent : `vtnet1` (comme pour les VLAN 20 et 30 déjà en place)
- VLAN tag : `90` · Description : `MGMT`
- Noter le nom du device créé (ex. `vlan0.90`). **Save.** Rien d'autre : on ne l'assigne pas encore.

## Phase 2 — OPNsense : réassigner LAN sur le VLAN 90

**Interfaces → Assignments** → ligne **LAN** : remplacer `vtnet1` par le device VLAN 90 → **Save**.

⚠️ **La session GUI tombe immédiatement — c'est normal** (le LAN attend maintenant du taggé 90, les hyperviseurs émettent encore en untaggé). Enchaîner Phase 3 sans attendre.

Les règles firewall, l'IP 10.90.0.1 et tout le reste suivent l'interface LAN : rien d'autre à toucher.

## Phase 3 — Hyperviseurs : IP MGMT sur vmbr1.90

Sur **hv02 puis hv01** (moins d'une minute d'écart), éditer `/etc/network/interfaces` :

**Avant** (bloc actuel) :
```
auto vmbr1
iface vmbr1 inet static
    address 10.90.0.11/24          # .12 sur hv02
    bridge-ports enp3s0f1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
    post-up ip route add 10.20.0.0/24 via 10.90.0.1
    post-up ip route add 10.30.0.0/24 via 10.90.0.1
```

**Après** (le bridge ne porte plus d'IP ; l'IP et les routes passent sur la sous-interface VLAN) :
```
auto vmbr1
iface vmbr1 inet manual
    bridge-ports enp3s0f1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

auto vmbr1.90
iface vmbr1.90 inet static
    address 10.90.0.11/24          # .12 sur hv02
    post-up ip route add 10.20.0.0/24 via 10.90.0.1
    post-up ip route add 10.30.0.0/24 via 10.90.0.1
```
*(Si les post-up n'existaient pas sur hv02 : c'est le moment de les ajouter — dette du 05/07.)*

Puis :
```bash
ifreload -a
ip -br a | grep vmbr1        # attendu : vmbr1 sans IP, vmbr1.90 = 10.90.0.x/24
```
Quand les **deux** nœuds sont passés : `ping -c2 10.90.0.12` depuis hv01, puis `ping -c2 10.90.0.1` (fw01 doit répondre si Phase 2 faite).

## Phase 4 — dns01 : tag 90 sur sa patte réseau

GUI Proxmox → VM **110** → Hardware → net0 → **VLAN Tag = 90** → OK (à chaud). Équivalent CLI :
```bash
qm set 110 -net0 virtio=BC:24:11:80:20:EA,bridge=vmbr1,firewall=1,tag=90
```
Rien à changer *dans* la VM : le tag est posé par le bridge (port d'accès), Debian continue de voir du non-taggé.

## Phase 5 — Recette

| # | Test | Commande | Attendu |
|---|---|---|---|
| 1 | Quorum reformé | `pvecm status` (sur les 2 nœuds) | Quorate: Yes, **3 votes** |
| 2 | Corosync sain | `journalctl -u corosync -n 20` | pas d'erreur récurrente |
| 3 | MGMT inter-nœuds | `ping 10.90.0.12` depuis hv01 | OK |
| 4 | fw01 joignable | `ping 10.90.0.1` + GUI OPNsense | OK |
| 5 | DNS | `dig +short db01.atlas.local @10.90.0.10` | 10.30.0.10 |
| 6 | Reverse | `dig +short -x 10.90.0.10 @10.90.0.10` | dns01.atlas.local. |
| 7 | Routage inter-zones intact | depuis glpi01 : `ping 10.30.0.10` | OK (règles TEMP) |
| 8 | Sortie Internet des VM | depuis dns01 : `dig +short debian.org @9.9.9.9` | réponse |
| 9 | Routes hyperviseurs | depuis hv01 : `ping 10.30.0.10` | OK |
| 10 | Reboot de validation dns01 | `reboot` puis re-tester 5 et 6 | tout revient seul |

Si le totem ne se reforme pas après 2 min : `systemctl restart corosync` sur un nœud.

## Résultat réel du 06/07/2026

- `hv01` : `vmbr1.90 = 10.90.0.11/24`; `hv02` : `vmbr1.90 = 10.90.0.12/24`.
- Routes `10.20.0.0/24` et `10.30.0.0/24 via 10.90.0.1 dev vmbr1.90` présentes sur hv02.
- Quorum : **3 votes**, `Quorate: Yes`, QDevice actif ; hv01 et hv02 en état `A,V,NMW`.
- dns01 : `net0 = virtio=BC:24:11:80:20:EA,bridge=vmbr1,firewall=1,tag=90`.
- Inter-VLAN : glpi01 (`10.20.0.11`) atteint db01 (`10.30.0.10`) ; hv01/hv02 atteignent ADMIN.
- DNS : direct `db01.atlas.local → 10.30.0.10`, inverse `10.90.0.10 → dns01.atlas.local.`, récursion externe OK.
- Reboot dns01 : retour ICMP en **environ 12 s**, `named` actif, configuration réseau et DNS persistantes.
- La durée exacte de la coupure MGMT pendant la migration n'a pas été chronométrée : ne pas inventer de valeur dans les livrables.

## Phase 6 — Rollback (si besoin)

1. Hyperviseurs : `cp /root/interfaces.bak-vlan90-* /etc/network/interfaces && ifreload -a`
2. fw01 via **console noVNC** : option `1) Assign interfaces` → réassigner LAN = `vtnet1` (répondre **No** aux questions LAGG/VLAN pour ne pas écraser les VLAN 20/30 existants).
3. dns01 : retirer le tag 90 (Hardware → net0).

## Phase 7 — Après coup

- **Option durcissement** (recette passée uniquement) : restreindre le trunk de fw01 aux seuls VLAN utiles :
  `qm set 100 -net1 virtio=<MAC_net1>,bridge=vmbr1,trunks=20;30;90`
- **Rituel R0, étape 0** devient : « vmbr1 + tag de zone : **90**=MGMT, 20=DMZ, 30=ADMIN » (plus d'exception MGMT). Vaut pour pbs01, guac01 et tout futur clone.
- Les reports DAT/état projet/journal ont été effectués dans ce pack. Reste à actualiser le schéma Miro avec l'étiquette « VLAN 90 ».
- **Journal de preuves** : entrée créée avec validation à 21:39, reboot dns01 à 21:40–21:41 et retour en ~12 s. La durée de coupure MGMT reste explicitement non mesurée.
