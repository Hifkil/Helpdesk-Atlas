# DAT — Dossier d'Architecture Technique · Helpdesk Atlas
*Livrable 1 (HLD/LLD). Responsable suggéré : Thibault. Les sections ⬜ sont à compléter, les autres sont pré-remplies avec l'état réel.*

## 1. But, périmètre, exigences (⚠️ demandé explicitement par Kalla)
- **But** : fournir à la PME Atlas un portail de tickets interne (GLPI) avec notifications mail, supervision, et un PRA/DR prouvé : **RPO ≤ 20 min, RTO ≤ 40 min**.
- **Périmètre** : app helpdesk, BDD, relais SMTP, reverse proxy TLS, supervision, sauvegardes/restaurations, réseau segmenté, sécurité (TLS, comptes de service, secrets), runbooks.
- ⬜ Hors périmètre (à lister : SSO/connecteurs, HA applicative, IPv6…).

## 2. Vue d'ensemble (HLD)
- ⬜ Insérer l'export du schéma Miro « Architecture Atlas v2 — OVH (cible) » + 3 phrases de lecture.
- Plateforme : 2 serveurs dédiés OVH SYS-1 (Xeon-E 2136, 32 Go, 2× NVMe ZFS mirror), datacenter eu-central-waw (UE/RGPD), cluster Proxmox VE 9 « atlas », réseau privé vRack, témoin de quorum (QDevice) sur site tiers.
- Justification hébergement : perte de l'infra physique ; comparatif OVH/Hetzner/Scaleway (cf. livrable Budget) ; Varsovie retenu (~30 ms depuis Paris), Asie-Pacifique rejeté (latence incompatible exploitation et démo).

## 3. Plan IP / VLAN (LLD)
| Zone | VLAN | Réseau | Passerelle | Rôle |
|---|---|---|---|---|
| MGMT | **90 (taggé)** | 10.90.0.0/24 | 10.90.0.1 (fw01) | Hyperviseurs (`vmbr1.90`), DNS, PBS, bastion |
| DMZ | 20 | 10.20.0.0/24 | 10.20.0.1 | Reverse proxy, GLPI, SMTP |
| ADMIN | 30 | 10.30.0.0/24 | 10.30.0.1 | BDD, supervision |
| WAN | — | **51.75.38.225/32** (Additional IP OVH) | `WAN_OVH_GW` = 146.59.47.254 | NAT sortant OPNsense + futur 443→rp01 |

Inventaire VM (VMID/IP/RAM) : reprendre le tableau de `00-ETAT-PROJET.md` §3.
Routage : hyperviseurs → routes statiques 10.20/10.30 via 10.90.0.1 sur `vmbr1.90` ; VM → passerelle de zone. Les trois zones internes circulent taggées (90/20/30) sur le vRack. Le WAN de fw01 est bridgé sur `vmbr0` avec la vMAC OVH `02:00:00:ff:3e:98`; l'ancien `vmbr2` est uniquement conservé jusqu'à la contre-recette finale.

## 4. Matrice de flux (à figer AVANT suppression des règles TEMP)
| # | Source | Destination | Port/Proto | Justification |
|---|---|---|---|---|
| 1 | Internet | rp01 | 443/tcp | Accès utilisateurs HTTPS |
| 2 | rp01 | glpi01 | 80/tcp | Proxy applicatif |
| 3 | glpi01 | db01 | 3306/tcp | Base GLPI (compte glpi_app restreint IP) |
| 4 | glpi01 | mail01 | 25/tcp | Notifications tickets |
| 5 | toutes zones | dns01 | 53/udp+tcp | Résolution interne |
| 6 | zbx01 | tous agents | 10050/tcp | Supervision |
| 7 | agents | zbx01 | 10051/tcp | Trappes actives |
| 8 | MGMT | toutes | 22/tcp | Administration |
| 9 | hv01/hv02 | pbs01 | 8007/tcp | Sauvegardes |
| 10 | ⬜ | | | compléter puis **deny all** implicite |

## 5. Sécurité
- Comptes de service : `glpi_app`@IP-restreinte, droits limités à glpidb.* ; ⬜ zabbix, pbs.
- Secrets : génération `openssl rand -base64 24`, stockage hors VCS (⬜ nommer le coffre), rotation en cas d'exposition (fait 1×, documenté).
- Accès admin : GUI Proxmox par comptes nominatifs @pve + TOTP ; root@pam = secours ; SSH par clés uniquement ; nominal cible = bastion Guacamole ; hors bande = tunnel SSH/Tailscale (documenté).
- Durcissement : pas de comptes par défaut (GLPI ⬜ à faire post-install), interfaces OPT en deny-all par défaut, WAN sans règle `Pass`/port-forward à ce stade, `Block private networks` + `Block bogon networks` actifs, dépôts à jour, ⬜ fermeture 8006 public, TLS (⬜ auto-signé + trust documenté OU Let's Encrypt si domaine réel).

## 6. Stockage & données
- ZFS mirror sur chaque nœud (pool `data` → storage `zfs-data`) ; VM en volumes simples (redondance portée par l'hôte — choix documenté).
- Binlogs MariaDB : ROW, rétention 7 j, `/var/log/mysql` (journaux de reprise séparés des données, sauvegardés indépendamment).
- ⬜ PBS : datastore, planification, vérification, rétention.

## 7. Résilience & PRA (résumé — détail dans les runbooks)
- Réplication ZFS (pvesr) hv01→hv02 toutes les 15 min (VM critiques) → RPO ≈ 15 min.
- Bascule DR manuelle assumée (runbook R4) — CARP étudié et écarté (RTO exigé 40 min vs complexité) ; évolution possible documentée.
- Quorum : 2 nœuds + QDevice site tiers (perte d'un nœud testée : cluster reste quorate).
- Mailflow : GLPI → mail01 (Postfix) → ⬜ relais sortant/boîte de démonstration.

## 8. Choix technologiques justifiés (tableau anti-question-jury)
| Sujet | Retenu | Alternative | Critères de départage |
|---|---|---|---|
| Firewall | OPNsense | pfSense | Licence, cadence MAJ, API, éditeur UE |
| Helpdesk | GLPI | Zammad/osTicket | ⬜ compléter |
| Supervision | Zabbix | Prometheus/Nagios | ⬜ compléter |
| Sauvegarde | PBS | Bacula/scripts | Intégration PVE, dédup, vérification, restauration granulaire fichiers |
| DNS | BIND9 | dnsmasq/Unbound | Zones autoritaires + récursion contrôlée |
| Redondance FW | Réplication+bascule | CARP/VRRP | RTO exigé vs complexité |
| Hébergement | OVH SYS | Hetzner/Scaleway | Prix, vRack, souveraineté, délais |

## 9. Contraintes d'hébergement (spécifiques dédié cloud)
- Pas de DHCP fournisseur ; l'Additional IP `/32` est liée à une vMAC OVH et utilise la passerelle non locale du serveur porteur (`146.59.47.254`).
- vRack : L2 privé inter-serveurs, transporte les tags VLAN (équivalent du switch physique d'origine). Toutes les zones internes sont taggées en nominal ; aucun trafic de zone non taggé n'est requis.

## 10. ⬜ Annexes
Inventaire VM complet, versions logicielles, exports de config (OPNsense config.xml, zones BIND, 60-atlas.cnf), captures.
