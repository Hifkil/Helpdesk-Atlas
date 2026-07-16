# TRAVAUX 02 — WAN public : Additional IP 51.75.38.225 sur fw01

*Exécuté le 2026-07-06 · Opérateur : Harry · Pré-requis TRAVAUX-01 validé · **Statut : 🔶 bascule WAN et NAT sortant validés ; reboot final, test entrant et suppression de vmbr2 encore à faire.***

## But
Remplacer le WAN provisoire NATé (`vmbr2` / `192.168.100.0/24`) par l'Additional IP publique **51.75.38.225/32**. L'IP est désormais assignée à hv01 et utilisée par fw01 ; `vmbr2` reste temporairement présent uniquement pour permettre un rollback jusqu'à la validation finale.

## Pourquoi une MAC virtuelle ?
Le réseau OVH n'accepte sur le port du serveur que les trames des MAC déclarées (anti-spoofing). Une VM bridgée sur `vmbr0` (patte publique) doit donc émettre avec une **MAC virtuelle** générée par OVH et associée à l'Additional IP.

## Impact & durée
- **Durée : ~30 min** dont **~5 min de coupure fw01** (arrêt/redémarrage requis pour changer la MAC de net0) → pendant ce temps : plus d'inter-VLAN ni d'Internet pour les VM. Prévenir l'équipe, choisir le moment.
- L'accès admin (SSH/GUI hyperviseurs via IP publiques) n'est pas concerné.

---

## Phase 1 — Manager OVH : attacher l'IP à hv01

fw01 tourne sur **hv01** = service **ns3201873.ip-146-59-47.eu** (146.59.47.185). Vérif : `qm list | grep 100` sur hv01.

Manager → Bare Metal Cloud → **IP** → ligne `51.75.38.225` → menu **⋮** → **« Attacher à un service » / « Move »** → choisir `ns3201873...`. Attendre que la colonne *Linked Service* affiche le serveur (quelques minutes).

## Phase 2 — Manager OVH : créer la MAC virtuelle

Même ligne → **⋮** → **« Ajouter une MAC virtuelle »** → type **OVH** → nom `fw01`. Valeur obtenue et appliquée : **`02:00:00:ff:3e:98`**.

## Phase 3 — Proxmox : basculer net0 de fw01 sur vmbr0 + vMAC

```bash
qm config 100 | grep net0          # avant : BC:24:11:93:E2:7D, bridge=vmbr2, firewall=1
qm shutdown 100 --timeout 60
qm set 100 -net0 virtio=02:00:00:ff:3e:98,bridge=vmbr0,firewall=1
qm start 100
```
Côté OPNsense rien ne bouge dans les assignations : le WAN reste `vtnet0` (même position PCI), seuls le câblage et la MAC changent. **Ne jamais supprimer une carte réseau de fw01** : FreeBSD renumérote les vtnetX à l'ordre PCI et toutes les assignations sauteraient.

## Phase 4 — OPNsense : configurer le WAN public

GUI via le tunnel LAN (https://10.90.0.1), inchangé par l'opération.

1. **System → Gateways → Configuration → Add** :
   - Name `WAN_OVH_GW` · Interface `WAN` · IP **146.59.47.254**
   - ✅ **« Far Gateway / Use non-local gateway »** ← indispensable : la passerelle est hors du /32
   - ✅ Upstream Gateway · Save/Apply.
   *(Règle OVH : la passerelle d'une Additional IP = celle du serveur porteur = IP publique du serveur en .254. hv01 est en 146.59.47.185 → 146.59.47.254.)*
2. **Interfaces → WAN** :
   - IPv4 : **Static** · `51.75.38.225` / **32** · Upstream gateway : `WAN_OVH_GW`
   - ✅ **Block private networks** · ✅ **Block bogon networks** ← à **recocher** (décochés à l'époque du WAN privé — dette notée dans 00-ETAT-PROJET)
   - Save/Apply.
3. **System → Gateways** : désactiver l'ancienne `WAN_GW` (192.168.100.1). La supprimer après recette.
4. **Firewall → NAT → Outbound** : mode Automatic → vérifier que les règles se régénèrent avec la nouvelle adresse WAN.
5. **Firewall → Rules → WAN** : vide (deny all implicite) = voulu. Le `443 → rp01` viendra avec rp01.

## Phase 5 — Recette

| # | Test | Où | Attendu |
|---|---|---|---|
| 1 | WAN up | Interfaces → Overview | ✅ `51.75.38.225/32`, gateway `WAN_OVH_GW` active |
| 2 | Sortie Internet | dns01 : `ping -c3 9.9.9.9` | ✅ 3/3, 0 % perte, ~1,9 ms moyen |
| 3 | DNS externe et interne | dns01 : `dig … @9.9.9.9` puis `@10.90.0.10` | ✅ réponses conformes |
| 4 | IP vue de l'extérieur | dns01 + glpi01 : `curl -4 -s https://ifconfig.me/ip` | ✅ **51.75.38.225** depuis les deux VM |
| 5 | Exposition minimale | depuis le PC : tester 22/443 | ✅ 10/07 : timeout sur les 2 ports (3 méthodes : /dev/tcp, curl) = deny all implicite opérationnel |
| 6 | Reboot de validation fw01 | `qm reboot 100` puis re-tester 1-4 | ✅ 10/07 21:11:15 UTC : coupure ≈ **45 s** (ping horodaté dns01→9.9.9.9, retour seq 45) ; tests 1-4 re-validés, IP vue `51.75.38.225` depuis dns01 et glpi01 |

## ✅ TRAVAUX-02 CLOS le 10/07/2026 (~21:25 UTC)

- Additional IP : `51.75.38.225/32`, assignée à `ns3201873.ip-146-59-47.eu`. vMAC : `02:00:00:ff:3e:98`.
- fw01 net0 : bridge public `vmbr0`, `firewall=1` conservé. Gateway `WAN_OVH_GW` (146.59.47.254, far gateway).
- Recette 6/6 verte (tableau ci-dessus). Coupure reboot fw01 mesurée : **≈ 45 s**.
- Nettoyage effectué : les 2 VM d'essai référençant vmbr2 détruites (90909 linked clone d'abord, puis 1001 sa base — ordre imposé par ZFS) ; bloc `vmbr2` supprimé de `/etc/network/interfaces` (backup `/root/interfaces.bak-wan-2026-07-10`) ; règle MASQUERADE retirée à chaud (`iptables -t nat -D` — le post-down ne s'exécute pas lors d'une suppression de bloc + ifreload) ; `ip_forward=0` (aucun fichier sysctl ne le fixait, valeur mémoire uniquement).
- Contre-recette finale : dns01 ping 3/3 vers 9.9.9.9, IP vue `51.75.38.225` → **chemin unique via fw01, hv01 ne route plus rien**.

## Phase 6 — Nettoyage du provisoire (hv01)

```bash
grep -n -B2 -A8 'vmbr2' /etc/network/interfaces   # repérer le bloc + les post-up iptables (MASQUERADE)
cp /etc/network/interfaces /root/interfaces.bak-wan-$(date +%F)
# supprimer le bloc vmbr2 et ses post-up, puis :
ifreload -a
# si le forwarding n'a plus d'usage :
grep -r ip_forward /etc/sysctl.conf /etc/sysctl.d/ ; # remettre à 0, puis sysctl --system
iptables -t nat -L POSTROUTING -n   # plus de MASQUERADE résiduel (sinon reboot planifié)
```
Re-tester ensuite la sortie Internet d'une VM (elle passe désormais par vmbr0/fw01, plus par le NAT hôte).

## Phase 7 — Volet PRA (important pour R4)

L'Additional IP est attachée à **un** serveur. Si hv01 tombe :
1. Vérifier que hv02 est une destination compatible vMAC (`GET /dedicated/server/{serviceName}/ipCanBeMovedTo`).
2. Manager, ou API `POST /dedicated/server/{serviceName}/ipMove` avec `serviceName=ns3201919.ip-146-59-47.eu` et `ip=51.75.38.225` : déplacer l'IP vers hv02.
3. Attendre que l'IP **et la même vMAC unique `02:00:00:ff:3e:98`** réapparaissent sur hv02. OVH suspend temporairement la vMAC pendant le mouvement ; elle n'a pas à être recréée entre deux serveurs compatibles.
4. Vérifier sur la réplique de fw01 : `net0 …bridge=vmbr0,firewall=1` avec la même vMAC, puis démarrer fw01 et les autres VM dans l'ordre R4.

Compter **5-10 min** pour le volet IP, compatible avec le RTO 40 min. `vmbr2` devient uniquement un plan B de dépannage documenté, pas le chemin nominal.

## Phase 8 — Après coup

- Les reports DAT/état projet/R4/journal ont été effectués dans ce pack. Le budget attend uniquement le montant mensuel exact de la facture OVH.
- **Journal de preuves** : attache IP, vMAC, configuration WAN et sorties `ifconfig.me` reportées. L'heure exacte et la durée de coupure restent à compléter si une preuve horodatée existe ; ne pas les inventer.
- Décision d'équipe à trancher (à noter dans le DAT §5) : **TLS public réel** (nom de domaine à quelques € pointant sur 51.75.38.225 → Let's Encrypt sur rp01) **ou CA interne + trust documenté** (explicitement accepté par le sujet). Le reverse DNS de l'IP est éditable dans le Manager (crayon) si domaine réel.
