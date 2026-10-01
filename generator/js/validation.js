/*
 * validation.js — contrôles de cohérence d'une configuration d'infrastructure
 * Expose : HAGen.net (outils IPv4) et HAGen.validate(config) -> { errors, warnings }
 * Chaque problème : { path: "hosts.web01.ip", message: "..." }
 */
(function (HAGen) {
  "use strict";

  /* ------------------------------------------------------------------ IPv4 */
  var IPV4_RE = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/;

  function isIPv4(value) {
    return typeof value === "string" && IPV4_RE.test(value);
  }

  function ipToInt(ip) {
    return ip.split(".").reduce(function (acc, octet) {
      return (acc * 256) + Number(octet);
    }, 0);
  }

  function intToIp(n) {
    return [24, 16, 8, 0].map(function (shift) {
      return Math.floor(n / Math.pow(2, shift)) % 256;
    }).join(".");
  }

  function prefixSize(prefix) {
    return Math.pow(2, 32 - prefix);
  }

  /* "10.0.10.0/24" -> { base, prefix, size, network, broadcast } ou null */
  function parseCidr(cidr) {
    if (typeof cidr !== "string") { return null; }
    var parts = cidr.split("/");
    if (parts.length !== 2 || !isIPv4(parts[0]) || !/^\d{1,2}$/.test(parts[1])) { return null; }
    var prefix = Number(parts[1]);
    if (prefix < 8 || prefix > 30) { return null; }
    var size = prefixSize(prefix);
    var base = ipToInt(parts[0]);
    var network = base - (base % size);
    return { base: base, prefix: prefix, size: size, network: network, broadcast: network + size - 1 };
  }

  function inSubnet(ip, subnet) {
    if (!isIPv4(ip) || !subnet) { return false; }
    var n = ipToInt(ip);
    return n >= subnet.network && n <= subnet.broadcast;
  }

  function isUsableHost(ip, subnet) {
    var n = ipToInt(ip);
    return n > subnet.network && n < subnet.broadcast;
  }

  function overlaps(a, b) {
    return a.network <= b.broadcast && b.network <= a.broadcast;
  }

  HAGen.net = {
    isIPv4: isIPv4,
    ipToInt: ipToInt,
    intToIp: intToIp,
    parseCidr: parseCidr,
    inSubnet: inSubnet,
    prefixToMask: function (prefix) {
      return intToIp(Math.pow(2, 32) - prefixSize(prefix));
    }
  };

  /* --------------------------------------------------------------- Règles */
  var HOSTNAME_RE = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/;
  var SQL_ID_RE = /^[A-Za-z0-9_]{1,32}$/;
  var UNIX_USER_RE = /^[a-z_][a-z0-9_-]{0,31}$/;
  var CLUSTER_RE = /^[A-Za-z0-9_-]{1,64}$/;
  var DOMAIN_RE = /^(?=.{1,253}$)([A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/;

  /* Rattachement de chaque VM à son VLAN (fixé par l'architecture) */
  var HOST_VLAN = {
    web01: "web", haproxy: "web", glpi: "web", web02: "web",
    db1: "db", db2: "db", db3: "db",
    adm: "admin", guac: "admin"
  };
  HAGen.HOST_VLAN = HOST_VLAN;

  function get(obj, path) {
    return path.split(".").reduce(function (o, k) {
      return (o === undefined || o === null) ? undefined : o[k];
    }, obj);
  }

  function isPort(v) {
    return Number.isInteger(v) && v >= 1 && v <= 65535;
  }

  HAGen.validate = function (cfg) {
    var errors = [];
    var warnings = [];
    function err(path, msg) { errors.push({ path: path, message: msg }); }
    function warn(path, msg) { warnings.push({ path: path, message: msg }); }

    /* Projet */
    if (!/^[A-Za-z0-9._-]{1,64}$/.test(String(get(cfg, "project.name") || ""))) {
      err("project.name", "Nom du projet : lettres, chiffres, point, - et _ (sert de nom de fichier).");
    }
    if (!DOMAIN_RE.test(String(get(cfg, "project.domain") || ""))) {
      err("project.domain", "Domaine interne invalide (ex. lab.local).");
    }

    /* WAN */
    var wanAddr = get(cfg, "wan.address");
    var wanPrefix = get(cfg, "wan.prefix");
    var wanGw = get(cfg, "wan.gateway");
    if (!isIPv4(wanAddr)) { err("wan.address", "IP WAN invalide."); }
    if (!Number.isInteger(wanPrefix) || wanPrefix < 8 || wanPrefix > 30) {
      err("wan.prefix", "Préfixe WAN entre 8 et 30.");
    }
    if (!isIPv4(wanGw)) {
      err("wan.gateway", "Passerelle WAN invalide.");
    } else if (isIPv4(wanAddr) && Number.isInteger(wanPrefix)) {
      var wanNet = parseCidr(wanAddr + "/" + wanPrefix);
      if (wanNet && !inSubnet(wanGw, wanNet)) {
        err("wan.gateway", "La passerelle WAN n'est pas dans le réseau " + intToIp(wanNet.network) + "/" + wanPrefix + ".");
      }
      if (wanAddr === wanGw) { err("wan.gateway", "La passerelle WAN ne peut pas être l'IP de pfSense."); }
    }
    if (!isPort(get(cfg, "wan.natPortWordpress"))) {
      err("wan.natPortWordpress", "Port NAT WordPress entre 1 et 65535.");
    }
    var natGlpi = get(cfg, "wan.natPortGlpi");
    if (natGlpi !== 0 && !isPort(natGlpi)) {
      err("wan.natPortGlpi", "Port NAT GLPI entre 1 et 65535, ou 0 pour désactiver.");
    } else if (natGlpi !== 0 && natGlpi === get(cfg, "wan.natPortWordpress")) {
      err("wan.natPortGlpi", "Les ports NAT WordPress et GLPI doivent être différents.");
    }

    /* VLAN */
    var subnets = {};
    var vlanIds = {};
    Object.keys(cfg.vlans || {}).forEach(function (key) {
      var v = cfg.vlans[key];
      var base = "vlans." + key;
      if (!Number.isInteger(v.id) || v.id < 2 || v.id > 4094) {
        err(base + ".id", "Identifiant VLAN entre 2 et 4094.");
      } else if (vlanIds[v.id]) {
        err(base + ".id", "VLAN " + v.id + " déjà utilisé par " + vlanIds[v.id] + ".");
      } else {
        vlanIds[v.id] = v.name || key;
      }
      if (!/^[A-Za-z0-9_-]{1,32}$/.test(String(v.name || ""))) {
        err(base + ".name", "Nom de VLAN : lettres, chiffres, - et _ uniquement.");
      }
      var net = parseCidr(v.network);
      if (!net) {
        err(base + ".network", "Réseau CIDR invalide (ex. 10.0.10.0/24, préfixe 8 à 30).");
        return;
      }
      if (net.base !== net.network) {
        err(base + ".network", "Adresse de réseau incorrecte : " + intToIp(net.network) + "/" + net.prefix + " attendu.");
      }
      subnets[key] = net;
      if (!isIPv4(v.gateway)) {
        err(base + ".gateway", "Passerelle invalide.");
      } else if (!inSubnet(v.gateway, net) || !isUsableHost(v.gateway, net)) {
        err(base + ".gateway", "La passerelle doit être une adresse d'hôte de " + v.network + ".");
      }
    });
    var keys = Object.keys(subnets);
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        if (overlaps(subnets[keys[i]], subnets[keys[j]])) {
          err("vlans." + keys[j] + ".network", "Chevauche le réseau du VLAN " + cfg.vlans[keys[i]].name + ".");
        }
      }
    }
    if (isIPv4(wanAddr) && Number.isInteger(wanPrefix)) {
      var wanSubnet = parseCidr(wanAddr + "/" + wanPrefix);
      keys.forEach(function (k) {
        if (wanSubnet && overlaps(wanSubnet, subnets[k])) {
          err("vlans." + k + ".network", "Chevauche le réseau WAN.");
        }
      });
    }

    /* VM */
    var seenIp = {};
    var seenName = {};
    Object.keys(HOST_VLAN).forEach(function (key) {
      var h = (cfg.hosts || {})[key] || {};
      var base = "hosts." + key;
      var vlanKey = HOST_VLAN[key];
      if (!HOSTNAME_RE.test(String(h.name || ""))) {
        err(base + ".name", "Nom de VM invalide (lettres, chiffres, tirets ; pas d'espace).");
      } else if (seenName[h.name.toLowerCase()]) {
        err(base + ".name", "Nom déjà utilisé.");
      } else {
        seenName[h.name.toLowerCase()] = true;
      }
      if (!isIPv4(h.ip)) {
        err(base + ".ip", "IP invalide.");
        return;
      }
      if (seenIp[h.ip]) {
        err(base + ".ip", "IP déjà attribuée à " + seenIp[h.ip] + ".");
      } else {
        seenIp[h.ip] = h.name;
      }
      var net = subnets[vlanKey];
      if (net) {
        if (!inSubnet(h.ip, net)) {
          err(base + ".ip", "Doit appartenir au VLAN " + cfg.vlans[vlanKey].name + " (" + cfg.vlans[vlanKey].network + ").");
        } else if (!isUsableHost(h.ip, net)) {
          err(base + ".ip", "Adresse de réseau ou de diffusion : non attribuable.");
        } else if (h.ip === cfg.vlans[vlanKey].gateway) {
          err(base + ".ip", "Identique à la passerelle du VLAN.");
        }
      }
    });

    /* Ports HAProxy */
    var portNames = { http: "WordPress", glpi: "GLPI", sql: "SQL", stats: "statistiques" };
    var seenPort = {};
    Object.keys(portNames).forEach(function (p) {
      var v = get(cfg, "ports." + p);
      if (!isPort(v)) {
        err("ports." + p, "Port " + portNames[p] + " entre 1 et 65535.");
      } else if (seenPort[v]) {
        err("ports." + p, "Port déjà utilisé par " + seenPort[v] + " sur HAProxy.");
      } else {
        seenPort[v] = portNames[p];
      }
    });
    if (!isPort(get(cfg, "ports.backendHttp"))) {
      err("ports.backendHttp", "Port HTTP des serveurs web entre 1 et 65535.");
    }
    if (get(cfg, "ports.sql") !== 3306) {
      warn("ports.sql", "Port SQL non standard : les applications devront préciser le port (DB_HOST ip:port).");
    }

    /* Galera */
    if (!CLUSTER_RE.test(String(get(cfg, "galera.clusterName") || ""))) {
      err("galera.clusterName", "Nom de cluster : lettres, chiffres, - et _ (64 max).");
    }
    if (["rsync", "mariabackup"].indexOf(get(cfg, "galera.sstMethod")) === -1) {
      err("galera.sstMethod", "Méthode SST : rsync ou mariabackup.");
    }

    /* Comptes */
    ["adminUser", "haproxyAdmin"].forEach(function (k) {
      var v = String(get(cfg, "accounts." + k) || "");
      if (!UNIX_USER_RE.test(v)) {
        err("accounts." + k, "Compte Linux : minuscules, chiffres, - et _ ; commence par une lettre.");
      }
    });
    if (get(cfg, "accounts.haproxyAdmin") === "haproxy" || get(cfg, "accounts.adminUser") === "haproxy") {
      err("accounts.haproxyAdmin", "« haproxy » est réservé au compte système du paquet (incident INC-08). Utiliser par ex. haproxyadmin.");
    }
    ["statsUser", "checkUser", "wpDb", "wpUser", "glpiDb", "glpiUser"].forEach(function (k) {
      if (!SQL_ID_RE.test(String(get(cfg, "accounts." + k) || ""))) {
        err("accounts." + k, "Identifiant : lettres, chiffres et _ (32 max).");
      }
    });
    if (get(cfg, "accounts.wpDb") === get(cfg, "accounts.glpiDb")) {
      err("accounts.glpiDb", "WordPress et GLPI doivent utiliser deux bases distinctes.");
    }
    if (get(cfg, "accounts.wpUser") === get(cfg, "accounts.glpiUser")) {
      warn("accounts.glpiUser", "Même compte SQL pour WordPress et GLPI : contraire au moindre privilège.");
    }
    if (get(cfg, "accounts.checkUser") === "root") {
      err("accounts.checkUser", "Le compte de health-check ne doit jamais être root.");
    }

    return { errors: errors, warnings: warnings };
  };
}(window.HAGen = window.HAGen || {}));
