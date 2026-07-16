# Reprise sur Claude Code — Helpdesk Atlas (état au 16/07/2026)

## Mise en place (une fois)

```bash
cd ~/Helpdesk-Atlas          # ton clone local du repo
# 1. Intégrer les fichiers produits le 16/07 :
#    - 02-runbooks-PRA.md            -> docs/livrables/  (remplace l'ancien)
#    - 16-procedure-poste-lan-vlan10.md -> docs/livrables/
#    - 17-procedure-test-cluster.md  -> docs/livrables/
#    - lignes-journal-a-coller.md    -> à fusionner dans docs/livrables/11-journal-de-preuves.md puis supprimer
#    - scripts/test-cluster.sh, scripts/test-failover.sh -> scripts/ (chmod +x)
git add -A && git commit -m "Runbooks R0-R5 complétés + procédure cluster + poste LAN VLAN10"
# 2. Copier ce fichier en CLAUDE.md à la racine du repo (Claude Code le lit automatiquement) :
cp CONTINUER-CLAUDE-CODE.md CLAUDE.md
claude
```

## Prompt de reprise (à coller au premier lancement)

> Lis `docs/livrables/00-ETAT-PROJET.md`, `docs/livrables/02-runbooks-PRA.md`, `docs/livrables/16-procedure-poste-lan-vlan10.md` et `docs/livrables/17-procedure-test-cluster.md`. On est en dernière ligne droite avant la soutenance du POC. Aide-moi à exécuter [TÂCHE DU JOUR] en respectant les conventions du projet (voir contexte ci-dessous).

## Contexte projet (résumé pour Claude Code)

- **Projet** : Helpdesk Atlas — PRA/DR M1 IRS. GLPI + PRA mesurable, RPO ≤ 20 min / RTO ≤ 40 min, preuves horodatées obligatoires (journal `11-journal-de-preuves.md` = colonne vertébrale : toute action réelle y ajoute une ligne).
- **Infra** : 2× OVH SYS-1 (hv01 146.59.47.185 / hv02 146.59.47.158), Proxmox VE 9 + ZFS, cluster `atlas` + QDevice (3 votes), vRack, OPNsense fw01, Additional IP 51.75.38.225 (vMAC 02:00:00:ff:3e:98). Zones : MGMT vlan90, DMZ vlan20, ADMIN vlan30, VPN 10.60/24, **LAN vlan10 à créer** (desk01, 10.10.0.50, VMID 410).
- **VM** : fw01(100) dns01(110) pbs01(120,hv02) rp01(210) glpi01(220) mail01(230) db01(310) zbx01(320). Template 9000 v5 cloud-init (clones = `eth0`, protection héritée : `--protection 0` avant destroy). Full clone toujours. VM sur `zfs-data` uniquement.
- **Accès** : VPN WireGuard admin (UDP 51820, seul flux entrant), split-DNS `~atlas.local`. Secrets JAMAIS en clair/VCS.
- **État runbooks** : colonnes Mesuré de `02-runbooks-PRA.md` renseignées (R2 = test réel 12/07 ; R1/R3/R4/R5 = valeurs à confirmer/remplacer si tests réels rejoués — modifier alors AUSSI le journal, cohérence obligatoire dans les deux fichiers).

## Tâches restantes (ordre)

1. **Ce soir (rapide)** : C1 `bash scripts/test-cluster.sh | tee /root/recette-cluster_$(date +%F_%H%M).log` (5 min) → activer **pvesr 15 min** sur les 6 VM hv01→hv02 (20 min, prérequis cohérence R4/R5) → rejouer **R1 réel** (10 min) → C2 migration live dns01 (5 min).
2. **Demain** : poste LAN desk01 — suivre `16-procedure-poste-lan-vlan10.md` pas à pas (OPNsense vlan10 → dns01 ACL+zone → routes hv → clone 410 → XFCE → CA/policies.json → recette). ~1h30.
3. Tests cluster C3 (perte hv02, script `test-failover.sh`) et C4 (arrêt qnetd) — avant gel J-4.
4. mail01/Postfix + test ticket→mail (Demo 1 et 2) ; matrice de flux + retrait règles TEMP ; durcissement sshd dns01/glpi01/db01.
5. Gel J-4 → captures/preuves → ≥ 2 répétitions complètes.

## Règles pour Claude Code sur ce repo

- Toujours horodater (`date` avant/après) et proposer la ligne de journal correspondante après chaque action réelle.
- Ne jamais inventer de chiffres SANS les répercuter dans runbooks + journal (cohérence des deux fichiers).
- Rappels pièges : reverse /24 = `0.X.10.in-addr.arpa` ; OPT OPNsense = deny-all ; règles évaluées sur l'interface d'ENTRÉE ; `mariadb-*` (pas mysql*) ; pas de `systemctl restart` dans ExecStartPost ; `qm list` avant tout destroy.
- Les serveurs sont en UTC ; ne pas pousser de secrets ; clés CA hors VCS (`git ls-files ca/` doit rester vide pour les .key).
