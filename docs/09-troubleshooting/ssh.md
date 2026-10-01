# Dépannage — SSH

Incidents réels : [INC-06](incidents.md#inc-06--ssh-permission-denied-publickey), [INC-07](incidents.md#inc-07--remote-host-identification-has-changed). Bonnes pratiques : [07-security/ssh.md](../07-security/ssh.md).

## Diagnostic universel

```bash
# SUR LE CLIENT (ADM-01) — mode très verbeux
ssh -vvv mysql01
```

Lignes utiles : `Connecting to`, `Server host key`, `Offering public key`, `Authentications that can continue`, `Permission denied`.

```bash
# SUR LE SERVEUR (console Proxmox si SSH est inaccessible)
sudo journalctl -u ssh -n 30 --no-pager
sudo sshd -t                                   # syntaxe de sshd_config
```

## Fiches

| Symptôme | Cause probable | Commandes | Correction | Validation |
|----------|----------------|-----------|------------|------------|
| `Permission denied (publickey)` | Clé publique absente de `authorized_keys`, clé privée copiée à la place, droits trop ouverts | `ls -la ~/.ssh` (serveur) ; `ssh -v` (client) | `ssh-copy-id` ; `chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/authorized_keys` | Connexion par clé |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | VM réinstallée, IP réattribuée… ou attaque | `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` (console VM) | **Après vérification** : `ssh-keygen -R <ip>` | Connexion, nouvelle empreinte acceptée |
| `Connection timed out` | Règle pfSense absente (source hors vADMIN), VM éteinte | `nc -zv -w 3 <ip> 22` ; journal pfSense | Règle vADMIN → 22 | `nc` : succeeded |
| `Connection refused` | `sshd` arrêté ou non installé | `systemctl status ssh` (console) | `sudo apt install openssh-server` ; `systemctl enable --now ssh` | Port 22 en écoute |
| `UNPROTECTED PRIVATE KEY FILE!` | Clé privée lisible par d'autres (fréquent sous Windows) | `ls -l ~/.ssh/id_ed25519` | `chmod 600 ~/.ssh/id_ed25519` (Windows : propriétés → sécurité, propriétaire seul) | Clé acceptée |
| `Too many authentication failures` | L'agent propose trop de clés | `ssh-add -l` | `IdentitiesOnly yes` + `IdentityFile` dans `~/.ssh/config` | Connexion |
| Coupé de SSH après durcissement | `PasswordAuthentication no` avant d'avoir installé la clé | Console Proxmox | Réactiver temporairement, installer la clé, re-durcir | Connexion par clé |
