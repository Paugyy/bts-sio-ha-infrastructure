# Règles NAT pfSense

## Port Forward (*Firewall → NAT → Port Forward*)

| # | Statut | Interface | Proto | Destination | Port externe | Cible interne | Port interne | Description |
|---|--------|-----------|-------|-------------|--------------|---------------|--------------|-------------|
| 1 | Réel | WAN | TCP | WAN address | 8081 | 10.0.10.2 | 80 | WordPress via HAProxy |
| 2 | Réel | WAN | TCP | WAN address | 8082 | 10.0.10.3 | 80 | GLPI-01 en direct (référence : via HAProxy `10.0.10.2:8080`) |
| 3 | Réel (désactivé) | WAN | TCP | WAN address | 8083 | 10.0.10.4 | 80 | Test direct de WEB-02 |
| 4 | Réel | WAN | TCP | WAN address | 8080 | 10.0.30.2 | 8080 | Bastion Guacamole (web) |
| 5 | Réel | WAN | TCP | WAN address | 2223 | 10.0.30.2 | 22 | SSH du bastion |
| 6 | Réel | WAN | TCP | WAN address | 2224 à 2230 | WEB-01, MYSQL-01/02/03, HAProxy, GLPI-01, WEB-02 | 22 | SSH de gestion ⚠️ (à remplacer par un VPN) |
| 7 | Réel | WAN | TCP | WAN address | 2231 | 10.0.30.3 | 80 | Interface Zabbix (`/zabbix/`) |
| 8 | Réel | WAN | TCP | WAN address | 2232 | 10.0.30.3 | 22 | SSH de ZABBIX |
| 9 | Réel (06/11/2026) | WAN | TCP | WAN address | 2233 | 10.0.30.3 | 8085 | LogAnalyzer — source limitée à l'alias `LOGANALYZER_ADMIN_NETS` |

> **Jamais publiés :** 514 (Syslog), 10050 et 10051 (Zabbix), 3306 (MariaDB), UDP 161 (SNMP).

Paramètre : *Filter rule association* = **Add associated filter rule** — pfSense crée automatiquement la règle WAN correspondante.

Résultat : un client du réseau labo ouvre `http://10.4.0.198:8081` et atteint WordPress via HAProxy.

```text
Client 10.4.0.x ──► 10.4.0.198:8081 (WAN pfSense)
                         │ DNAT
                         ▼
                    10.0.10.2:80 (HAProxy) ──► WEB-01 / WEB-02
```

> La cible du NAT est **HAProxy**, jamais WEB-01 ou WEB-02 directement : sinon la panne du serveur ciblé coupe le site, et la redondance est contournée.

## NAT sortant (*Firewall → NAT → Outbound*)

| Statut | Mode | Effet |
|--------|------|-------|
| Réel | Automatic outbound NAT | Les VLAN internes sortent vers le réseau labo / Internet avec l'IP WAN `10.4.0.198` (mises à jour `apt`) |

## Point d'attention WAN privé

Le WAN est lui-même un réseau privé (`10.4.0.0/24`). Dans *Interfaces → WAN*, l'option **Block private networks and loopback addresses** doit être **décochée**, sinon tout le trafic entrant depuis le réseau labo est rejeté avant même l'évaluation du NAT.

## Vérification

```bash
# SUR UN POSTE DU RÉSEAU LABO (10.4.0.0/24)
curl -sI http://10.4.0.198:8081 | head -n 5
```

Attendu : `HTTP/1.1 200 OK` (ou `301/302` vers l'URL du site) et un en-tête `X-Served-By: WEB-0X`.
