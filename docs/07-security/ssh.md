# Sécurité — SSH

## Principes

| Mesure | Raison |
|--------|--------|
| Authentification **par clé** uniquement | Pas de mot de passe à deviner ou à intercepter |
| Pas de connexion `root` | Traçabilité (qui a fait quoi) et `sudo` journalisé |
| SSH accepté **depuis vADMIN** uniquement | Règles pfSense + `AllowUsers`/pare-feu local |
| Clé **ed25519** protégée par une phrase de passe | Algorithme moderne ; clé volée inutilisable seule |
| Vérification des empreintes d'hôte | Protection contre l'usurpation de serveur |

## Clé publique ou clé privée ?

```text
Poste d'administration                              Serveur (ex. MYSQL-01)
~/.ssh/id_ed25519      ← clé PRIVÉE : ne sort jamais du poste
~/.ssh/id_ed25519.pub  ── copiée vers ──►   ~/.ssh/authorized_keys
                                              (liste des clés PUBLIQUES autorisées)
```

- `authorized_keys` contient des **clés publiques** : il dit « j'accepte toute personne capable de prouver qu'elle détient la clé privée correspondante ».
- La clé **privée** ne doit **jamais** être copiée sur un serveur ni dans ce dépôt. La coller dans `authorized_keys` est une erreur : la connexion échoue (`Permission denied (publickey)`) et la clé privée est exposée. Voir [INC-06](../09-troubleshooting/incidents.md#inc-06--ssh-permission-denied-publickey).

## Mise en place

**SUR ADM-01**

```bash
ssh-keygen -t ed25519 -C "adm01-admin"           # phrase de passe recommandée
ssh-copy-id <ADMIN_USER>@10.0.20.1               # ajoute la clé PUBLIQUE dans authorized_keys
ssh <ADMIN_USER>@10.0.20.1                       # test
cp configs/ssh/linux-ssh-config.example ~/.ssh/config && chmod 600 ~/.ssh/config
ssh mysql01                                      # alias défini dans ~/.ssh/config
```

**SUR CHAQUE VM** — après avoir vérifié que la connexion par clé fonctionne :

```bash
sudo nano /etc/ssh/sshd_config.d/10-hardening.conf
```

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
```

```bash
sudo sshd -t && sudo systemctl reload ssh
```

> Garder une session SSH ouverte pendant la modification : en cas d'erreur, elle permet de corriger sans passer par la console Proxmox.

## Avertissement « REMOTE HOST IDENTIFICATION HAS CHANGED »

SSH mémorise l'empreinte de chaque serveur dans `~/.ssh/known_hosts`. Si elle change, SSH **refuse** la connexion : c'est exactement ce qui se produirait lors d'une attaque de l'homme du milieu.

Avant de supprimer l'ancienne empreinte avec `ssh-keygen -R`, **vérifier la cause** :

| Cause légitime | Vérification |
|----------------|--------------|
| VM réinstallée ou recréée | Vous l'avez fait vous-même, récemment |
| IP réattribuée à une autre VM | Plan d'adressage, Proxmox |
| Clés d'hôte régénérées | Historique d'administration |

Comparer avec l'empreinte réelle, lue **depuis la console Proxmox** de la VM (canal de confiance) :

```bash
# SUR LA VM (console Proxmox)
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Si elle correspond à celle annoncée dans l'avertissement, alors seulement :

```bash
# SUR ADM-01
ssh-keygen -R 10.0.20.1
ssh mysql01      # accepter la nouvelle empreinte après comparaison
```

Détail : [INC-07](../09-troubleshooting/incidents.md#inc-07--remote-host-identification-has-changed)

## Bastion

Le poste d'administration externe passe par **ADM-01** (`ProxyJump`) : seul ADM-01 doit être joignable depuis l'extérieur. Voir [configs/ssh/windows-ssh-config.example](../../configs/ssh/windows-ssh-config.example). Guacamole offre la même centralisation via un navigateur.
