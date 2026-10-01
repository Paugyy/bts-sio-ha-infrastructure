# WordPress — Base de données

## Paramètres

| Élément | Valeur |
|---------|--------|
| Base | `wordpress` (utf8mb4) |
| Compte | `wordpress`@`10.0.10.2` |
| Privilèges | `ALL PRIVILEGES ON wordpress.*` (WordPress crée et modifie ses tables lors des mises à jour) |
| Point d'accès | `10.0.10.2:3306` (HAProxy) |
| Moteur | InnoDB (obligatoire pour Galera ; défaut de WordPress) |

## Création

**SUR MYSQL-01**

```sql
-- sudo mariadb
CREATE DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'wordpress'@'10.0.10.2' IDENTIFIED BY '<PASSWORD>';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'10.0.10.2';
SHOW GRANTS FOR 'wordpress'@'10.0.10.2';
```

Les comptes et privilèges (tables système InnoDB depuis MariaDB 10.4) sont répliqués : inutile de recréer le compte sur MYSQL-02 et MYSQL-03.

## Pourquoi `@'10.0.10.2'` ?

Un compte MariaDB est défini par **nom + hôte d'origine**. Les serveurs web ne se connectent pas directement aux nœuds : ils passent par HAProxy, qui ouvre lui-même la connexion vers le nœud. MariaDB voit donc l'IP **10.0.10.2**.

| Compte créé | Connexion depuis WEB-01 via HAProxy |
|-------------|-------------------------------------|
| `'wordpress'@'10.0.10.1'` | **Refusée** (`Access denied for user 'wordpress'@'10.0.10.2'`) |
| `'wordpress'@'10.0.10.2'` | Acceptée |
| `'wordpress'@'%'` | Acceptée, mais **trop large** (moindre privilège non respecté) |

## Vérifications

**SUR WEB-01**

```bash
mariadb -h 10.0.10.2 -u wordpress -p -e 'SHOW TABLES FROM wordpress;' | head
```

**SUR MYSQL-02**

```sql
-- Toutes les tables WordPress doivent être en InnoDB
SELECT table_name, engine FROM information_schema.tables
WHERE table_schema = 'wordpress' AND engine <> 'InnoDB';
-- attendu : aucune ligne

-- Tables sans clé primaire (à éviter avec Galera)
SELECT t.table_name FROM information_schema.tables t
LEFT JOIN information_schema.table_constraints c
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name AND c.constraint_type = 'PRIMARY KEY'
WHERE t.table_schema = 'wordpress' AND c.constraint_name IS NULL;
-- attendu : aucune ligne
```

## Extensions et Galera

Certaines extensions créent des tables **MyISAM** ou **sans clé primaire**. Avant d'installer une extension, vérifier ses tables avec les requêtes ci-dessus. Une table MyISAM n'est **pas** répliquée de manière fiable par Galera.

Sauvegarde : [10-backup-recovery/mariadb.md](../10-backup-recovery/mariadb.md)
