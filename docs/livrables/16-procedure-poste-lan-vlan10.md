# Poste utilisateur desk01 — VLAN 10 « LAN » (exigence : machine desktop visible)

*Objectif : un poste de travail avec environnement de bureau, dans un VLAN utilisateurs dédié, qui déroule le parcours « employé PME Atlas » : Firefox → https://helpdesk.atlas.local → cadenas CA interne → création de ticket (Démo 1). Répond littéralement à la demande du prof : « un poste dans un VLAN LAN ».*

**Choix** : Debian 13 + XFCE, clone du template v5 (cohérent avec l'infra, ~2 Go RAM, prêt en ~30-40 min). La procédure vaut pour tout OS à bureau ; plan B Windows + scripts `WindowsUserVPN/` conservé.

## 1. Plan (nouvelle zone)

| Élément | Valeur |
|---|---|
| Zone / VLAN | **LAN — VLAN 10**, `10.10.0.0/24`, passerelle `10.10.0.1` (fw01) |
| VM | **desk01**, VMID **410** (convention étendue : 4xx = LAN tag 10) |
| IP | `10.10.0.50/24` (tout statique, comme le reste) |
| Ressources | 2 vCPU, 2 Go RAM (3 Go si Firefox rame), disque du template |
| Accès démo | Console noVNC Proxmox (aucun accès prof requis, conforme consignes) |

## 2. OPNsense (fw01) — zone LAN

1. **Interfaces → Devices → VLAN** : parent = interface trunk interne (celle qui porte déjà vlan20/30/90), tag **10**, description `LAN`.
2. **Interfaces → Assignments** : assigner → OPT, renommer **LAN10**, Enable, IPv4 statique `10.10.0.1/24`. Pas de DHCP (tout statique — Dnsmasq reste désactivé).
3. **Règles firewall — interface LAN10** (rappel leçon : les règles s'évaluent sur l'interface d'ENTRÉE = la zone source ; OPT naît en deny-all, on n'ouvre que le nécessaire) :

| # | Action | Proto | Source | Destination | Port | Motif |
|---|---|---|---|---|---|---|
| 1 | Pass | TCP/UDP | LAN10 net | 10.90.0.10 | 53 | Résolution DNS (dns01) |
| 2 | Pass | TCP | LAN10 net | 10.20.0.10 | 443 | Helpdesk via rp01 (seul chemin) |
| 3 | Pass | TCP | LAN10 net | any (WAN) | 80, 443 | apt/updates — **désactiver après install si volonté de fermer** |
| 4 | (implicite) | Block | LAN10 net | any | any | deny-all par défaut, loggé |

Nota : l'accès direct `glpi01:80` est déjà tué pour toutes les zones par la règle **floating** « deny direct glpi01:80 » — contre-test à refaire depuis desk01 (exit 28 attendu).

## 3. dns01 — étendre la récursion

Dans `named.conf.options`, ajouter `10.10.0.0/24` à l'ACL de récursion (déjà : 10.20/30/90 + 10.60). Ajouter les enregistrements :
`desk01.atlas.local. A 10.10.0.50` + PTR dans une nouvelle zone reverse `0.10.10.in-addr.arpa` (⚠️ piège /24 : `0.10.10`, pas `10.10`). Serial +1, `rndc reload`, recette `dig` A + PTR.

## 4. Hyperviseurs — route de zone

Sur hv01 **et** hv02 (comme pour 10.20/10.30) : route statique `10.10.0.0/24 via 10.90.0.1 dev vmbr1.90` (persistée dans `/etc/network/interfaces`, `ifreload -a`).

## 5. VM desk01 (runbook R0, rituel cloud-init)

```
qm clone 9000 410 --name desk01 --full --storage zfs-data
qm set 410 --net0 virtio,bridge=vmbr1,tag=10 --memory 2048 --cores 2
qm set 410 --ipconfig0 ip=10.10.0.50/24,gw=10.10.0.1 --nameserver 10.90.0.10 --searchdomain atlas.local
qm set 410 --vga qxl --agent 1        # confort console noVNC/SPICE
qm start 410
```
Pings rituels : `10.10.0.1` / `9.9.9.9` / `10.90.0.10`. ⚠️ clone v5 = interface `eth0`.

## 6. Environnement de bureau + utilisateur démo

```
apt update && apt install -y xfce4 xfce4-goodies lightdm firefox-esr    # ~5-10 min
adduser demo.user            # compte NON-root pour la démo (mdp hors VCS)
systemctl set-default graphical.target && reboot                        # reboot de validation
```
Au retour : écran de connexion LightDM dans la console noVNC → session XFCE.

## 7. Confiance CA interne (le cadenas de la démo)

```
# magasin système
cp ca-root.crt /usr/local/share/ca-certificates/atlas-root.crt && update-ca-certificates
# Firefox (magasin propre) : politique entreprise
mkdir -p /usr/lib/firefox-esr/distribution
cat > /usr/lib/firefox-esr/distribution/policies.json <<'EOF'
{ "policies": { "Certificates": {
    "ImportEnterpriseRoots": true,
    "Install": ["/usr/local/share/ca-certificates/atlas-root.crt"] } } }
EOF
```
Contre-test : `curl --cacert /usr/local/share/ca-certificates/atlas-root.crt https://helpdesk.atlas.local -I` (sans `-k`) → HTTP/2 200 ; puis Firefox → cadenas fermé, certificat « Atlas Internal Root CA ».

## 8. Côté GLPI

Créer le compte **demo.user** (profil Self-Service/post-only) — c'est lui qui crée le ticket en Démo 1 ; le technicien reste un compte séparé.

## 9. Recette desk01

| Contrôle | Attendu | Mesuré |
|---|---|---|
| dig A + PTR desk01 | OK depuis desk01 | ✅ 16/07 09:36 UTC — A=`10.10.0.50`, PTR=`desk01.atlas.local.` |
| https://helpdesk.atlas.local dans Firefox | 200, cadenas fermé, sans exception | ✅ technique 16/07 09:35 UTC : `curl --cacert` **et** magasin système → HTTP/2 200 (policies.json en place) ; ⬜ contrôle visuel du cadenas en console noVNC (session demo.user) |
| Accès direct http://10.20.0.11 | bloqué (floating), timeout | ✅ 16/07 09:36 UTC — `curl -m 5` → **exit 28** |
| ping desk01 → 10.30.0.10 (ADMIN) | **bloqué**, loggé fw01 (segmentation) | ✅ 16/07 09:36 UTC — 3+3 pings, **100 % perte** ; Live View : 6× `USERS/ICMP/block Default deny` (capture) |
| ping desk01 → 10.90.0.11 (MGMT hv) | **bloqué**, loggé fw01 | ✅ 16/07 09:36–09:37 UTC — **100 % perte** ; Live View : 6× block loggés (capture) |
| Création ticket + mail Mailpit | ticket visible, notification reçue | ⬜ à jouer (nécessite compte GLPI demo.user — §8 — et mdp session, hors périmètre automatisable) |
| Reboot de validation | LightDM + IP reviennent seuls | ✅ 16/07 09:35:23→09:35:43 UTC (**~20 s**) — lightdm actif, IP/DNS/HTTPS revenus seuls |

> **Écart doc/réel assumé (16/07)** : la zone s'appelle **USERS** (interface opt3, device `vlan04`) dans OPNsense — pas « LAN10 ». Le VLAN 10 et l'interface (10.10.0.1/24) préexistaient ; seules les règles ont été ajoutées le 16/07. Rappel : ICMP sortant limité à la passerelle (design — sinon les contre-tests de segmentation ne prouvent rien) → pings rituels vers 9.9.9.9/dns01 remplacés par `dig` + `curl`. **NTP (UDP 123) sortant est bloqué** (loggé Live View) → prévoir le flux F22 de la matrice ou pointer un NTP interne avant gel.

## 10. Impact sur les autres livrables (à répercuter)

- **Matrice de flux** : ajouter la ligne zone LAN (10) — c'est même un argument : « les utilisateurs n'atteignent que le helpdesk en 443, rien d'autre ».
- **DAT / plan d'adressage** : zone LAN 10, desk01 410, convention 4xx.
- **Backup** : le job PBS est en mode Exclude → desk01 sera sauvegardé d'office (aucune action). Le laisser : « même le poste est couvert par la politique ».
- **Schéma Miro** : desk01 dans la zone LAN (fait — cadre « Schéma des flux »).
- **Démo 1** : le parcours utilisateur démarre de desk01 (console noVNC plein écran) au lieu du VPN — plus lisible pour un jury non technique ; le VPN reste le parcours ADMIN.
