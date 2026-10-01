# pfSense — Interfaces

## Inventaire

| Interface pfSense | Périphérique | Description | IP | Rôle |
|-------------------|--------------|-------------|----|------|
| WAN | vtnet0 | WAN | 10.4.0.198/24 | Réseau labo, NAT |
| OPT1 | vtnet1.301 | vWEB | 10.0.10.254/24 | Passerelle des serveurs web |
| OPT2 | vtnet1.302 | vBDD | 10.0.20.254/24 | Passerelle des bases |
| OPT3 | vtnet1.303 | vADMIN | 10.0.30.254/24 | Passerelle administration |
| OPT4 | vtnet1.304 | vUSER | 10.0.40.254/24 | Passerelle utilisateurs |

## Procédure

**SUR PFSENSE** (*Interfaces → Assignments*)

1. Créer d'abord les VLAN ([vlans.md](vlans.md)).
2. Dans *Available network ports*, ajouter `VLAN 301 on vtnet1`, puis 302, 303, 304.
3. Pour chaque nouvelle interface (OPT1 à OPT4) :
   - cocher **Enable interface** ;
   - **Description** : `vWEB`, `vBDD`, `vADMIN`, `vUSER` ;
   - **IPv4 Configuration Type** : Static IPv4 ;
   - **IPv4 Address** : `10.0.X0.254 / 24` ;
   - **IPv4 Upstream gateway** : None (une passerelle amont ne se met que sur le WAN).
4. *Save* puis *Apply Changes*.

## Interface LAN temporaire

Une fois vADMIN opérationnel et l'accès web vérifié depuis ADM-01 (`https://10.0.30.254/`), l'interface LAN temporaire peut être désactivée. Vérifier **avant** que la règle d'accès à l'interface web existe sur vADMIN, sous peine de perdre l'accès (récupérable par la console : option *8) Shell* puis `pfctl -d` pour désactiver temporairement le filtrage).

## Vérification

**SUR PFSENSE** (*Status → Interfaces*) : 5 interfaces *up* avec la bonne IP.

**SUR WEB-01**

```bash
ping -c 2 10.0.10.254
```
