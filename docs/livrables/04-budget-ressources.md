# Budget, but & ressources · Helpdesk Atlas
*Livrable explicitement demandé par Kalla. Chiffres réels du projet — vérifier les montants du jour avant dépôt (⬜).*

## 1. But (rappel une ligne)
Portail de tickets interne + PRA/DR prouvé (RPO ≤ 20 min / RTO ≤ 40 min) pour la PME Atlas, sur plateau virtualisé segmenté.

## 2. Ressources
**Humaines** : 3 étudiants × ⬜ h/semaine × ~3 semaines (valorisation optionnelle : ⬜ j/h × taux journalier fictif pour le narratif client).
**Matérielles/services** :
| Ressource | Fournisseur | Rôle |
|---|---|---|
| 2× serveur dédié SYS-1 (Xeon-E 2136, 32 Go, 2× NVMe 512) | OVH (eu-central-waw) | Hyperviseurs hv01/hv02 |
| vRack | OVH | Réseau privé inter-serveurs (inclus) |
| Additional IP 51.75.38.225 + vMAC | OVH | WAN public fw01 — commandée et mise en service le 06/07/2026 ; facturation mensuelle, montant exact à recopier de la facture |
| VPS existant | (déjà possédé) | Témoin de quorum QDevice — coût marginal 0 |
| Logiciels : Proxmox VE/PBS, OPNsense, Debian, GLPI, MariaDB, Zabbix, BIND9, Postfix, Nginx | open source | 0 € licence |

## 3. Coûts du projet (POC, ~1 mois)
| Poste | Unité | Qté | HT/mois | Total HT | Total TTC |
|---|---|---|---|---|---|
| SYS-1 | serveur | 2 | 29,99 € | 59,98 € | **71,98 €** |
| Frais d'installation | — | 2 | 0 € (offerts, promo) | 0 € | 0 € |
| Additional IP | mois | 1 | **⬜ €** | **⬜ €** | **⬜ €** |
| vRack / trafic (illimité UE) | — | — | inclus | 0 € | 0 € |
| **Total projet (1 mois)** | | | | **59,98 € + coût IP HT** | **71,98 € + coût IP TTC** |

Le montant de l'Additional IP n'est pas déduit d'une estimation : le recopier depuis la facture OVH, puis calculer le coût par membre à partir du total TTC. Résiliation à l'issue de la soutenance (VM supprimées — conforme consigne).

## 4. Comparatif fournisseurs (justification du choix — démarche d'achat)
| Option | Config comparable | Coût 1er mois (2 srv) | Réseau privé | Points bloquants |
|---|---|---|---|---|
| **OVH SYS (retenu)** | 6c/12t, 32 Go, 2× NVMe | ~72 € TTC | vRack inclus | France indisponible au tarif promo → Varsovie (30 ms, UE) |
| OVH SYS Australie | idem, 29,99 € | ~72 € TTC | vRack | **Rejeté** : ~300 ms — inexploitable (admin + démo), narratif client incohérent |
| Hetzner (auction) | Ryzen 3600, 64 Go | ~85-100 € | vSwitch gratuit | Prix enchères variables au moment T ; hors UE-souveraineté FR (reste UE/RGPD) |
| Scaleway Dedibox | gamme Pro 32-64 Go | ~250 € (frais install = 1 mois + engagement) | RPNv2 | **Rejeté** : frais + engagement 12-36 mois incompatibles avec 1 mois |
| Scaleway Elastic Metal | facturation horaire | à chiffrer ⬜ | Private Networks | Compétitif si extinction hors usage ; non retenu (visibilité prix) |
| SYS-GAME (toutes régions) | Ryzen, moins cher/CPU | — | **pas de vRack** | **Rejeté** : incompatible cluster |

## 5. Projection « client » (TCO 12 mois — pour le dossier d'appel d'offre)
| Scénario | Coût annuel estimé | Commentaire |
|---|---|---|
| Hébergé OVH (2× SYS-1 + IP) | `(59,98 € + IP mensuelle HT) × 12` | Sans investissement matériel ; inclut bande passante |
| On-premise équivalent | ⬜ serveurs ~3-4 k€ amortis 4 ans + électricité + onduleur | À chiffrer pour le comparatif |
| Option copie hors site (Storage Box/objet) | + ~50-60 €/an | Renforce le 3-2-1 (recommandation) |

## 6. Décisions d'optimisation documentées
- 32 Go retenus vs 64 Go (+20 €HT/mois/serveur) : besoin mesuré ~19-22 Go alloués → dimensionnement au juste besoin, marge documentée.
- Options débit garanti (jusqu'à ~200 €) refusées : besoin < 100 Go/mois vs 500 Mbit/s inclus.
- CARP non retenu : coût en complexité sans exigence de continuité (RTO 40 min).
