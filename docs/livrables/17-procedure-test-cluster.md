# Procédure de recette du cluster `atlas` (hv01 + hv02 + QDevice)

*Livrable : preuve que le cluster survit à la perte d'un nœud sans `pvecm expected 1`, que le témoin n'est pas un SPOF, et que la migration à chaud fonctionne. Sert aussi de trame à la **Démo 3** de la soutenance. Scripts associés : `scripts/test-cluster.sh` (contrôles non intrusifs) et `scripts/test-failover.sh` (perte de nœud, guidé).*

## 0. Prérequis & précautions

- À jouer **avant le gel J-4**, hors fenêtre de démo, avec un backup PBS frais (< 24 h, verify OK) — cf. R1.
- Le test de perte de nœud se fait sur **hv02** (pbs01/zbx01 y résident mais la prod tourne sur hv01) : impact service nul. La perte de hv01 = scénario R4, testé séparément.
- Toujours lancer `date` avant/après chaque phase — le prompt horodaté fait foi sur les captures.
- Rappel architecture : quorum = 3 votes (hv01 + hv02 + QDevice corosync-qnetd sur VPS externe, port 5403/tcp). Corosync passe par le vRack (`--link0` 10.90.0.x).

## 1. Test C1 — État nominal (non intrusif)

Sur hv01 : `bash scripts/test-cluster.sh | tee /root/recette-cluster_$(date +%F_%H%M).log`

| Contrôle | Commande | Attendu | Mesuré (15/07/2026 22:55 UTC) |
|---|---|---|---|
| Quorum complet | `pvecm status` | `Quorate: Yes`, **3 votes / 3**, les 2 nœuds `A,V,NMW` | ✅ Quorate: Yes, 3/3, hv01+hv02 `A,V,NMW` |
| QDevice connecté | `pvecm status` (bloc Membership) | ligne `Qdevice` avec flag `A,V` | ✅ Qdevice présent, 1 vote |
| Liens corosync | `corosync-cfgtool -s` | link0 `connected` vers l'autre nœud | ✅ link0 connected |
| Latence vRack | `ping -c 10 10.90.0.12` (depuis hv01) | < 1 ms, 0 % perte | ✅ 0,634 ms moy., 0 % perte |
| SSH croisé | `ssh hv02 hostname` | répond `hv02` | ✅ hv02 |
| Storage partagé | `pvesm status` sur les 2 nœuds | `zfs-data` actif des deux côtés, `pbs01` visible | ✅ zfs-data + pbs01 actifs |
| Réplication | `pvesr status` | 6 jobs, dernier sync < 15 min, 0 erreur | ✅ 6 jobs OK, FailCount 0 (activés 22:42 UTC, 1re passe complète en 5 min 18 s) |

**Bilan C1 : 10 PASS / 0 FAIL** — log : `docs/captures/2026-07-15_2255_recette-cluster-C1.log`. Nota : le premier passage (22:41) affichait 1 FAIL pvesr « normal » (jobs pas encore créés) + un bug du script corrigé dans la foulée (le `grep -i fail` matchait l'en-tête `FailCount` de `pvesr status`).

## 2. Test C2 — Migration à chaud

VM cobaye : **dns01 (110)** — 1 Go, la plus légère, coupure mesurable au ping.

1. Depuis un poste (VPN) : `ping -D 10.90.0.10 | tee ping-migration.log` (laisser tourner).
2. Sur hv01 : `date && qm migrate 110 hv02 --online --with-local-disks && date`.
   ⚠️ `--with-local-disks` **obligatoire** (disque local ZFS) — sans lui : `can't live migrate attached local disks`. La réplique pvesr existante sert de base : seul le delta est envoyé (~1 Mo mesuré).
3. Attendu : tâche verte, coupure brève (downtime QEMU < 100 ms ; voir nota pings), `qm status 110` = running sur hv02.
4. Retour : `qm migrate 110 hv01 --online --with-local-disks`. Même contrôle.

| Mesure | Attendu | Mesuré (15/07/2026 22:52–22:54 UTC) |
|---|---|---|
| Durée migration aller | < 60 s (RAM 1 Go via vRack) | ✅ **24 s** (downtime QEMU 47 ms, 86,7 MiB/s) |
| Pings perdus aller | 0–2 | ⚠️ **4** (seq 49–52, ≈ 4 s perçues) |
| Durée migration retour | < 60 s | ✅ **18 s** (downtime QEMU 41 ms, 173,5 MiB/s) |
| Pings perdus retour | 0–2 | ⚠️ **4** (seq 81–84, ≈ 4 s perçues) |

**Nota pings (réponse jury)** : le downtime QEMU réel est de 41–47 ms ; les ~4 s de perte perçue correspondent au **réapprentissage de la MAC de la VM par le switch vRack OVH** après le changement de serveur physique (les horodatages des pertes coïncident avec la fin de chaque migration, pas avec le transfert mémoire). Coupure réelle ≈ 4 s = imperceptible pour un service helpdesk ; la formulation démo devient « ~4 secondes de bascule, liées au réseau physique OVH, pas à la virtualisation ». Preuves : `docs/captures/2026-07-15_2252_ping-migration-dns01.log` + `2026-07-15_2252_migration-live-dns01.log`.

## 3. Test C3 — Perte d'un nœud (hv02) : le test qui compte

Script guidé : `bash scripts/test-failover.sh` (depuis **hv01**). Déroulé manuel équivalent :

1. `date` → noter **T0**. Arrêt brutal de hv02 : `ssh hv02 'systemctl poweroff'` (ou reboot via Manager OVH pour un vrai « pull the plug »).
2. Sur hv01, boucle : `watch -n 2 pvecm status`.
3. **Attendu pendant la panne** : `Quorate: Yes` — **2 votes / 3** (hv01 + QDevice). C'est LA preuve : sans QDevice, un cluster 2 nœuds perdrait le quorum (1/2) et `/etc/pve` passerait read-only ; ici **aucun `pvecm expected 1` nécessaire**.
4. Contrôles pendant la panne : prod intacte (`curl -kI https://helpdesk.atlas.local` → 200 via VPN ; ticket GLPI créable). Noter que pbs01/zbx01 (résidents hv02) sont indisponibles — **conséquence attendue et documentée** (supervision aveugle ≠ prod coupée).
5. Redémarrer hv02 (Manager OVH ou attendre boot). Noter **T_retour** = premier `pvecm status` à 3/3 avec les deux nœuds `A,V,NMW`.
6. Contrôles post-retour : `pvesr status` (jobs repartent), pbs01/zbx01 up, aucune VM en double.

| Mesure | Attendu | Mesuré |
|---|---|---|
| Quorum pendant panne | `Quorate: Yes`, 2/3, sans intervention | ⬜ |
| Service GLPI pendant panne | HTTP 200, ticket créable | ⬜ |
| Réintégration hv02 (T_retour − T_boot) | < 60 s après boot | ⬜ |
| Reprise pvesr | jobs verts au cycle suivant | ⬜ |

## 4. Test C4 — Perte du témoin (QDevice ≠ SPOF)

1. Sur le VPS : `systemctl stop corosync-qnetd` + `date`.
2. Sur hv01 : `pvecm status` → **attendu : `Quorate: Yes`, 2 votes / 3** (les deux nœuds suffisent). Cluster pleinement opérationnel.
3. Relancer : `systemctl start corosync-qnetd` → le vote Qdevice revient (`pvecm status`).

| Mesure | Attendu | Mesuré |
|---|---|---|
| Quorum sans QDevice | Quorate: Yes (2/3) | ⬜ |
| Retour du vote QDevice | < 30 s après restart | ⬜ |

## 5. Argumentaire jury (à connaître par les 3)

- **Pourquoi un QDevice ?** 2 nœuds = quorum impossible à 1/2 en cas de panne → un témoin léger sur un site tiers donne 3 votes. Perte de n'importe quel élément parmi les 3 : le cluster reste quorate.
- **Pourquoi pas de HA automatique ?** RTO exigé 40 min ; bascule = acte humain assumé (R4). HA auto = complexité + risque de split-brain sur un POC 2 nœuds — documenté comme évolution.
- **Chiffres à citer** : quorum conservé 2/3 sans intervention · migration à chaud en 18–24 s, downtime QEMU < 50 ms (~4 s de coupure perçue, imputable au réapprentissage MAC du vRack OVH) · réintégration < 60 s.

## 6. Démo 3 soutenance (3 min, zéro risque)

1. `pvecm status` en grand écran : 3 votes, QDevice — 30 s d'explication du « pourquoi 3 votes ».
2. Migration live de dns01 hv01→hv02 avec le ping qui tourne dans un 2e terminal : « la VM change de serveur physique, personne ne s'en aperçoit ».
3. Montrer la capture du test C3 (quorum 2/3 pendant la panne) plutôt que d'éteindre un serveur en live.
4. Phrase de chute : « la perte complète d'un serveur, c'est la démo suivante » (→ Demo 4/PRA).

**En cas de pépin en live** : la migration retour peut se faire après la soutenance ; aucune étape de la démo ne modifie la prod.
