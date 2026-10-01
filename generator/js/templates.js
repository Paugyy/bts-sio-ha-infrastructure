/*
 * templates.js — modèles de fichiers de configuration
 * Expose : HAGen.REFERENCE (infrastructure de référence, copie de examples/reference-infrastructure.json,
 *          embarquée car fetch() est bloqué en file://) et HAGen.templates.<nom>(cfg) -> string
 * Aucun secret n'est jamais généré : les mots de passe restent des placeholders <PASSWORD> / <SECRET>.
 */
(function (HAGen) {
  "use strict";

  HAGen.REFERENCE = {
    version: 1,
    project: { name: "bts-sio-ha-infrastructure", domain: "lab.local" },
    wan: { address: "10.4.0.198", prefix: 24, gateway: "10.4.0.254", natPortWordpress: 8081, natPortGlpi: 0 },
    vlans: {
      web: { id: 301, name: "vWEB", network: "10.0.10.0/24", gateway: "10.0.10.254" },
      db: { id: 302, name: "vBDD", network: "10.0.20.0/24", gateway: "10.0.20.254" },
      admin: { id: 303, name: "vADMIN", network: "10.0.30.0/24", gateway: "10.0.30.254" },
      user: { id: 304, name: "vUSER", network: "10.0.40.0/24", gateway: "10.0.40.254" }
    },
    hosts: {
      web01: { name: "WEB-01", ip: "10.0.10.1" },
      haproxy: { name: "HAProxy", ip: "10.0.10.2" },
      glpi: { name: "GLPI-01", ip: "10.0.10.3" },
      web02: { name: "WEB-02", ip: "10.0.10.4" },
      db1: { name: "MYSQL-01", ip: "10.0.20.1" },
      db2: { name: "MYSQL-02", ip: "10.0.20.2" },
      db3: { name: "MYSQL-03", ip: "10.0.20.3" },
      adm: { name: "ADM-01", ip: "10.0.30.1" },
      guac: { name: "Guacamole", ip: "10.0.30.2" }
    },
    ports: { http: 80, glpi: 8080, sql: 3306, stats: 8404, backendHttp: 80 },
    galera: { clusterName: "mon_cluster_galera", sstMethod: "rsync" },
    accounts: {
      adminUser: "adminsys", haproxyAdmin: "haproxyadmin", statsUser: "admin", checkUser: "haproxy_check",
      wpDb: "wordpress", wpUser: "wordpress", glpiDb: "glpi", glpiUser: "glpi"
    }
  };

  var DB_KEYS = ["db1", "db2", "db3"];

  function header(title, target, cfg) {
    return [
      "# =============================================================================",
      "# " + title,
      "# Cible : " + target,
      "# Généré par generator/index.html — projet " + cfg.project.name,
      "# Aucun secret : remplacer chaque <PASSWORD> / <SECRET> avant utilisation.",
      "# ============================================================================="
    ].join("\n");
  }

  function galeraAddress(cfg) {
    return "gcomm://" + DB_KEYS.map(function (k) { return cfg.hosts[k].ip; }).join(",");
  }

  function hostLabel(h) {
    return h.name + " (" + h.ip + ")";
  }

  /* Host:port pour DB_HOST (port omis s'il est standard côté client ? non : toujours explicite) */
  function sqlEndpoint(cfg) {
    return cfg.hosts.haproxy.ip + ":" + cfg.ports.sql;
  }

  var T = {};

  /* ----------------------------------------------------------- HAProxy */
  T.haproxy = function (cfg) {
    var h = cfg.hosts;
    var p = cfg.ports;
    var hp = h.haproxy.ip;
    var a = cfg.accounts;
    return [
      header("haproxy.cfg — " + hostLabel(h.haproxy), "/etc/haproxy/haproxy.cfg", cfg),
      "",
      "global",
      "    log /dev/log local0",
      "    log /dev/log local1 notice",
      "    chroot /var/lib/haproxy",
      "    stats socket /run/haproxy/admin.sock mode 660 level admin",
      "    stats timeout 30s",
      "    # Compte système du paquet (administration humaine : " + a.haproxyAdmin + ")",
      "    user haproxy",
      "    group haproxy",
      "    daemon",
      "",
      "defaults",
      "    log     global",
      "    mode    http",
      "    option  httplog",
      "    option  dontlognull",
      "    option  redispatch",
      "    retries 3",
      "    timeout connect 5s",
      "    timeout client  50s",
      "    timeout server  50s",
      "    timeout http-request 10s",
      "    timeout check   3s",
      "",
      "# --- WordPress (HTTP) ---------------------------------------------------------",
      "frontend fe_wordpress",
      "    bind " + hp + ":" + p.http,
      "    option forwardfor",
      "    http-request set-header X-Forwarded-Proto http",
      "    default_backend be_wordpress",
      "",
      "backend be_wordpress",
      "    balance roundrobin",
      "    option httpchk",
      "    http-check send meth GET uri /wp-login.php ver HTTP/1.1 hdr Host " + hp,
      "    http-check expect status 200-399",
      "    cookie SRV_WP insert indirect nocache httponly",
      "    http-response set-header X-Served-By %[srv_name]",
      "    default-server inter 3s fall 3 rise 2",
      "    server " + h.web01.name + " " + h.web01.ip + ":" + p.backendHttp + " check cookie web01",
      "    server " + h.web02.name + " " + h.web02.ip + ":" + p.backendHttp + " check cookie web02",
      "",
      "# --- GLPI (HTTP) --------------------------------------------------------------",
      "frontend fe_glpi",
      "    bind " + hp + ":" + p.glpi,
      "    option forwardfor",
      "    http-request set-header X-Forwarded-Proto http",
      "    default_backend be_glpi",
      "",
      "backend be_glpi",
      "    option httpchk",
      "    http-check send meth GET uri / ver HTTP/1.1 hdr Host " + h.glpi.ip,
      "    http-check expect status 200-399",
      "    http-response set-header X-Served-By %[srv_name]",
      "    server " + h.glpi.name + " " + h.glpi.ip + ":" + p.backendHttp + " check inter 5s fall 3 rise 2",
      "",
      "# --- Galera (TCP) ------------------------------------------------------------",
      "listen galera_cluster",
      "    bind " + hp + ":" + p.sql,
      "    mode tcp",
      "    option tcplog",
      "    balance roundrobin",
      "    # Compte sans privilège ni mot de passe : CREATE USER '" + a.checkUser + "'@'" + hp + "';",
      "    option mysql-check user " + a.checkUser + " post-41",
      "    timeout client 30m",
      "    timeout server 30m",
      "    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions"
    ].concat(DB_KEYS.map(function (k) {
      return "    server " + h[k].name + " " + h[k].ip + ":3306 check";
    })).concat([
      "",
      "# --- Statistiques (VLAN " + cfg.vlans.admin.name + " uniquement) -------------------------------",
      "listen stats",
      "    bind " + hp + ":" + p.stats,
      "    mode http",
      "    acl from_admin src " + cfg.vlans.admin.network,
      "    http-request deny unless from_admin",
      "    stats enable",
      "    stats uri /stats",
      "    stats refresh 10s",
      "    stats hide-version",
      "    stats auth " + a.statsUser + ":<PASSWORD>",
      ""
    ]).join("\n");
  };

  /* ------------------------------------------------------------ Galera */
  T.server = function (cfg, key) {
    var h = cfg.hosts[key];
    return [
      header("50-server.cnf — " + hostLabel(h), "/etc/mysql/mariadb.conf.d/50-server.cnf", cfg),
      "",
      "[server]",
      "",
      "[mysqld]",
      "user                    = mysql",
      "pid-file                = /run/mysqld/mysqld.pid",
      "basedir                 = /usr",
      "datadir                 = /var/lib/mysql",
      "tmpdir                  = /tmp",
      "lc-messages-dir         = /usr/share/mysql",
      "lc-messages             = en_US",
      "skip-external-locking",
      "",
      "# Écoute uniquement sur l'IP du VLAN " + cfg.vlans.db.name + " (jamais 127.0.0.1, voir INC-02)",
      "bind-address            = " + h.ip,
      "",
      "log_error               = /var/log/mysql/error.log",
      "expire_logs_days        = 10",
      "character-set-server    = utf8mb4",
      "collation-server        = utf8mb4_unicode_ci",
      "",
      "[embedded]",
      "",
      "[mariadb]",
      "",
      "[mariadb-10.11]",
      ""
    ].join("\n");
  };

  T.galera = function (cfg, key) {
    var h = cfg.hosts[key];
    var lines = [
      header("60-galera.cnf — " + hostLabel(h), "/etc/mysql/mariadb.conf.d/60-galera.cnf", cfg),
      "",
      "[galera]",
      "wsrep_on                 = ON",
      "wsrep_provider           = /usr/lib/galera/libgalera_smm.so",
      "wsrep_cluster_name       = \"" + cfg.galera.clusterName + "\"",
      "wsrep_cluster_address    = \"" + galeraAddress(cfg) + "\"",
      "wsrep_node_address       = \"" + h.ip + "\"",
      "wsrep_node_name          = \"" + h.name + "\"",
      "wsrep_sst_method         = " + cfg.galera.sstMethod
    ];
    if (cfg.galera.sstMethod === "mariabackup") {
      lines.push(
        "# Compte SST local (sur chaque nœud) :",
        "#   CREATE USER 'mariabackup'@'localhost' IDENTIFIED BY '<PASSWORD>';",
        "#   GRANT RELOAD, PROCESS, LOCK TABLES, BINLOG MONITOR ON *.* TO 'mariabackup'@'localhost';",
        "wsrep_sst_auth           = \"mariabackup:<PASSWORD>\""
      );
    }
    lines.push(
      "binlog_format            = ROW",
      "default_storage_engine   = InnoDB",
      "innodb_autoinc_lock_mode = 2",
      "wsrep_slave_threads      = 1",
      ""
    );
    return lines.join("\n");
  };

  /* --------------------------------------------------------- WordPress */
  T.wpconfig = function (cfg) {
    var a = cfg.accounts;
    var hp = cfg.hosts.haproxy.ip;
    var salts = ["AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY", "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT"];
    return [
      "<?php",
      "/**",
      " * wp-config.php — " + hostLabel(cfg.hosts.web01) + " et " + hostLabel(cfg.hosts.web02),
      " * Fichier IDENTIQUE sur les deux serveurs. Généré par generator/index.html.",
      " * Remplacer chaque <SECRET>. Ne jamais versionner ce fichier.",
      " */",
      "",
      "define( 'DB_NAME', '" + a.wpDb + "' );",
      "define( 'DB_USER', '" + a.wpUser + "' );",
      "define( 'DB_PASSWORD', '<SECRET>' );",
      "define( 'DB_HOST', '" + sqlEndpoint(cfg) + "' );",
      "define( 'DB_CHARSET', 'utf8mb4' );",
      "define( 'DB_COLLATE', '' );",
      "",
      "// https://api.wordpress.org/secret-key/1.1/salt/ — valeurs identiques sur les deux serveurs"
    ].concat(salts.map(function (s) {
      return "define( '" + s + "', " + new Array(Math.max(1, 18 - s.length)).join(" ") + "'<SECRET>' );";
    })).concat([
      "",
      "$table_prefix = 'wp_';",
      "",
      "// define( 'WP_HOME',    'http://" + hp + "' );",
      "// define( 'WP_SITEURL', 'http://" + hp + "' );",
      "",
      "if ( isset( $_SERVER['REMOTE_ADDR'], $_SERVER['HTTP_X_FORWARDED_PROTO'] )",
      "\t&& '" + hp + "' === $_SERVER['REMOTE_ADDR']",
      "\t&& 'https' === $_SERVER['HTTP_X_FORWARDED_PROTO'] ) {",
      "\t$_SERVER['HTTPS'] = 'on';",
      "}",
      "",
      "define( 'DISALLOW_FILE_EDIT', true );",
      "define( 'AUTOMATIC_UPDATER_DISABLED', true );",
      "define( 'WP_DEBUG', false );",
      "",
      "if ( ! defined( 'ABSPATH' ) ) {",
      "\tdefine( 'ABSPATH', __DIR__ . '/' );",
      "}",
      "",
      "require_once ABSPATH . 'wp-settings.php';",
      ""
    ]).join("\n");
  };

  /* ------------------------------------------------------------ Apache */
  T.apacheWordpress = function (cfg) {
    var h = cfg.hosts;
    return [
      header("wordpress.conf — " + h.web01.name + " / " + h.web02.name, "/etc/apache2/sites-available/wordpress.conf", cfg),
      "",
      "<VirtualHost *:" + cfg.ports.backendHttp + ">",
      "    ServerName wordpress." + cfg.project.domain,
      "    ServerAlias " + [h.haproxy.ip, h.web01.ip, h.web02.ip].join(" "),
      "    DocumentRoot /var/www/wordpress",
      "",
      "    <Directory /var/www/wordpress>",
      "        Options FollowSymLinks",
      "        AllowOverride All",
      "        Require all granted",
      "    </Directory>",
      "",
      "    <FilesMatch \"^(wp-config\\.php|readme\\.html|license\\.txt)$\">",
      "        Require all denied",
      "    </FilesMatch>",
      "",
      "    RemoteIPHeader X-Forwarded-For",
      "    RemoteIPInternalProxy " + h.haproxy.ip,
      "",
      "    ErrorLog ${APACHE_LOG_DIR}/wordpress-error.log",
      "    CustomLog ${APACHE_LOG_DIR}/wordpress-access.log combined",
      "</VirtualHost>",
      ""
    ].join("\n");
  };

  T.apacheGlpi = function (cfg) {
    var h = cfg.hosts;
    return [
      header("glpi.conf — " + hostLabel(h.glpi), "/etc/apache2/sites-available/glpi.conf", cfg),
      "",
      "<VirtualHost *:" + cfg.ports.backendHttp + ">",
      "    ServerName glpi." + cfg.project.domain,
      "    ServerAlias " + h.glpi.ip + " " + h.haproxy.ip,
      "    DocumentRoot /var/www/glpi/public",
      "",
      "    <Directory /var/www/glpi/public>",
      "        Require all granted",
      "        RewriteEngine On",
      "        RewriteCond %{HTTP:Authorization} ^(.+)$",
      "        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]",
      "        RewriteCond %{REQUEST_FILENAME} !-f",
      "        RewriteRule ^(.*)$ index.php [QSA,L]",
      "    </Directory>",
      "",
      "    RemoteIPHeader X-Forwarded-For",
      "    RemoteIPInternalProxy " + h.haproxy.ip,
      "",
      "    ErrorLog ${APACHE_LOG_DIR}/glpi-error.log",
      "    CustomLog ${APACHE_LOG_DIR}/glpi-access.log combined",
      "</VirtualHost>",
      ""
    ].join("\n");
  };

  /* --------------------------------------------------------------- SQL */
  T.sqlInit = function (cfg) {
    var a = cfg.accounts;
    var hp = cfg.hosts.haproxy.ip;
    return [
      "-- =============================================================================",
      "-- init-accounts.sql — à exécuter UNE fois SUR " + cfg.hosts.db1.name + " (sudo mariadb < init-accounts.sql)",
      "-- Répliqué automatiquement par Galera. Remplacer chaque <PASSWORD>.",
      "-- Hôte '" + hp + "' : toutes les connexions applicatives passent par HAProxy.",
      "-- =============================================================================",
      "",
      "-- Health-check HAProxy : aucun privilège, aucun mot de passe",
      "CREATE USER IF NOT EXISTS '" + a.checkUser + "'@'" + hp + "';",
      "ALTER USER '" + a.checkUser + "'@'" + hp + "' WITH MAX_USER_CONNECTIONS 10;",
      "",
      "-- WordPress",
      "CREATE DATABASE IF NOT EXISTS " + a.wpDb + " CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
      "CREATE USER IF NOT EXISTS '" + a.wpUser + "'@'" + hp + "' IDENTIFIED BY '<PASSWORD>';",
      "GRANT ALL PRIVILEGES ON " + a.wpDb + ".* TO '" + a.wpUser + "'@'" + hp + "';",
      "",
      "-- GLPI",
      "CREATE DATABASE IF NOT EXISTS " + a.glpiDb + " CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
      "CREATE USER IF NOT EXISTS '" + a.glpiUser + "'@'" + hp + "' IDENTIFIED BY '<PASSWORD>';",
      "GRANT ALL PRIVILEGES ON " + a.glpiDb + ".* TO '" + a.glpiUser + "'@'" + hp + "';",
      ""
    ].join("\n");
  };

  /* --------------------------------------------------------------- SSH */
  function sshHosts(cfg, jump) {
    var order = ["web01", "haproxy", "glpi", "web02", "db1", "db2", "db3", "guac"];
    var out = [];
    order.forEach(function (k) {
      var h = cfg.hosts[k];
      out.push("Host " + h.name.toLowerCase());
      out.push("    HostName " + h.ip);
      if (k === "haproxy") { out.push("    User " + cfg.accounts.haproxyAdmin); }
      if (jump) { out.push("    ProxyJump " + jump); }
      out.push("");
    });
    return out;
  }

  T.sshLinux = function (cfg) {
    return [
      header("~/.ssh/config — " + hostLabel(cfg.hosts.adm), "~/.ssh/config (chmod 600)", cfg),
      "",
      "Host *",
      "    User " + cfg.accounts.adminUser,
      "    IdentityFile ~/.ssh/id_ed25519",
      "    IdentitiesOnly yes",
      "    StrictHostKeyChecking ask",
      "    ServerAliveInterval 30",
      ""
    ].concat(sshHosts(cfg, null)).join("\n");
  };

  T.sshWindows = function (cfg) {
    var adm = cfg.hosts.adm.name.toLowerCase();
    return [
      header("config OpenSSH Windows (rebond par " + cfg.hosts.adm.name + ")", "C:\\Users\\<WINDOWS_USER>\\.ssh\\config", cfg),
      "",
      "Host *",
      "    User " + cfg.accounts.adminUser,
      "    IdentityFile C:/Users/<WINDOWS_USER>/.ssh/id_ed25519",
      "    IdentitiesOnly yes",
      "    StrictHostKeyChecking ask",
      "    ServerAliveInterval 30",
      "",
      "Host " + adm,
      "    HostName <ADM01_ADDRESS>",
      "    Port <ADM01_PORT>",
      ""
    ].concat(sshHosts(cfg, adm)).join("\n");
  };

  /* -------------------------------------------------- Réseau / pfSense */
  T.interfaces = function (cfg) {
    var net = HAGen.net;
    var out = [header("/etc/network/interfaces — extrait par VM", "/etc/network/interfaces (interface à adapter : ip link)", cfg), ""];
    Object.keys(HAGen.HOST_VLAN).forEach(function (k) {
      var h = cfg.hosts[k];
      var v = cfg.vlans[HAGen.HOST_VLAN[k]];
      var prefix = net.parseCidr(v.network).prefix;
      out.push("# --- SUR " + h.name + " (VLAN " + v.id + " " + v.name + ") — tag Proxmox : " + v.id);
      out.push("auto ens18");
      out.push("iface ens18 inet static");
      out.push("    address " + h.ip + "/" + prefix);
      out.push("    gateway " + v.gateway);
      out.push("");
    });
    return out.join("\n");
  };

  T.pfsense = function (cfg) {
    var h = cfg.hosts;
    var v = cfg.vlans;
    var p = cfg.ports;
    var w = cfg.wan;
    var dbIps = DB_KEYS.map(function (k) { return h[k].ip; }).join(", ");
    var lines = [
      "# Règles pfSense — " + cfg.project.name,
      "",
      "Généré par `generator/index.html`. Politique **deny-by-default** : seuls les flux listés sont autorisés.",
      "",
      "## Interfaces",
      "",
      "| Interface | VLAN | IP | Réseau |",
      "|-----------|------|----|--------|",
      "| WAN | — | " + w.address + "/" + w.prefix + " (passerelle " + w.gateway + ") | — |"
    ];
    ["web", "db", "admin", "user"].forEach(function (k) {
      var prefix = HAGen.net.parseCidr(v[k].network).prefix;
      lines.push("| " + v[k].name + " | " + v[k].id + " | " + v[k].gateway + "/" + prefix + " | " + v[k].network + " |");
    });
    lines.push(
      "",
      "## Alias",
      "",
      "| Alias | Valeur |",
      "|-------|--------|",
      "| HAPROXY | " + h.haproxy.ip + " |",
      "| WEB_SERVERS | " + h.web01.ip + ", " + h.web02.ip + " |",
      "| GALERA_NODES | " + dbIps + " |",
      "| ADMIN_HOSTS | " + h.adm.ip + ", " + h.guac.ip + " |",
      "| WEB_PORTS | " + p.http + ", " + p.glpi + " |",
      "",
      "## NAT (Port Forward)",
      "",
      "| Interface | Port externe | Cible | Port interne | Description |",
      "|-----------|--------------|-------|--------------|-------------|",
      "| WAN | " + w.natPortWordpress + " | " + h.haproxy.ip + " | " + p.http + " | WordPress via HAProxy |"
    );
    if (w.natPortGlpi) {
      lines.push("| WAN | " + w.natPortGlpi + " | " + h.haproxy.ip + " | " + p.glpi + " | GLPI via HAProxy |");
    }
    lines.push(
      "",
      "Décocher *Block private networks* sur le WAN si celui-ci est un réseau privé.",
      "",
      "## Règles",
      "",
      "| Interface | Action | Proto | Source | Destination | Port | Description |",
      "|-----------|--------|-------|--------|-------------|------|-------------|",
      "| " + v.web.name + " | Pass | TCP | HAPROXY | GALERA_NODES | " + 3306 + " | HAProxy vers Galera |",
      "| " + v.web.name + " | Block | any | " + v.web.name + " net | RFC1918 | any | Autres accès internes |",
      "| " + v.web.name + " | Pass | TCP | " + v.web.name + " net | any | 80, 443 | Mises à jour |",
      "| " + v.db.name + " | Block | any | " + v.db.name + " net | RFC1918 | any | Les bases n'initient rien en interne |",
      "| " + v.db.name + " | Pass | TCP | " + v.db.name + " net | any | 80, 443 | Mises à jour |",
      "| " + v.admin.name + " | Pass | TCP | ADMIN_HOSTS | " + v.web.name + " net, " + v.db.name + " net | 22 | SSH |",
      "| " + v.admin.name + " | Pass | TCP | ADMIN_HOSTS | HAPROXY | " + [p.http, p.sql, p.glpi, p.stats].join(", ") + " | Tests et statistiques |",
      "| " + v.admin.name + " | Pass | TCP | ADMIN_HOSTS | " + v.admin.name + " address | 443 | Interface pfSense |",
      "| " + v.user.name + " | Pass | TCP | " + v.user.name + " net | HAPROXY | WEB_PORTS | Services publiés |",
      "| " + v.user.name + " | Block | any | " + v.user.name + " net | RFC1918 | any | Aucun accès direct aux serveurs |",
      "| " + v.user.name + " | Pass | TCP | " + v.user.name + " net | any | 80, 443 | Navigation |",
      "",
      "Ajouter sur chaque VLAN : DNS (53) et NTP (123) vers l'adresse pfSense du VLAN.",
      ""
    );
    return lines.join("\n");
  };

  T.ipPlan = function (cfg) {
    var lines = [
      "# Plan d'adressage — " + cfg.project.name,
      "",
      "## VLAN",
      "",
      "| VLAN | Nom | Réseau | Passerelle |",
      "|------|-----|--------|------------|"
    ];
    ["web", "db", "admin", "user"].forEach(function (k) {
      var v = cfg.vlans[k];
      lines.push("| " + v.id + " | " + v.name + " | " + v.network + " | " + v.gateway + " |");
    });
    var roles = {
      web01: "WordPress", haproxy: "Load-balancer", glpi: "GLPI", web02: "WordPress",
      db1: "Galera", db2: "Galera", db3: "Galera", adm: "Administration", guac: "Accès distant"
    };
    lines.push(
      "",
      "## VM",
      "",
      "| VM | IP | VLAN | Rôle |",
      "|----|----|------|------|"
    );
    Object.keys(HAGen.HOST_VLAN).forEach(function (k) {
      var h = cfg.hosts[k];
      lines.push("| " + h.name + " | " + h.ip + " | " + cfg.vlans[HAGen.HOST_VLAN[k]].id + " | " + roles[k] + " |");
    });
    var hp = cfg.hosts.haproxy.ip;
    lines.push(
      "",
      "## Points d'accès",
      "",
      "| Service | Adresse |",
      "|---------|---------|",
      "| WordPress | http://" + hp + (cfg.ports.http === 80 ? "" : ":" + cfg.ports.http) + "/ |",
      "| WordPress (WAN) | http://" + cfg.wan.address + ":" + cfg.wan.natPortWordpress + "/ |",
      "| GLPI | http://" + hp + ":" + cfg.ports.glpi + "/ |",
      "| SQL (applications) | " + sqlEndpoint(cfg) + " |",
      "| Statistiques HAProxy | http://" + hp + ":" + cfg.ports.stats + "/stats |",
      "| Cluster Galera | " + cfg.galera.clusterName + " — " + galeraAddress(cfg) + " |",
      ""
    );
    return lines.join("\n");
  };

  HAGen.templates = T;
  HAGen.DB_KEYS = DB_KEYS;
}(window.HAGen = window.HAGen || {}));
