/*
 * generators.js — assemble la liste des fichiers générés à partir d'une configuration
 * Expose : HAGen.generateAll(cfg) -> [{ id, path, target, vm, lang, content }]
 *          HAGen.bundle(files, cfg) -> string (tous les fichiers dans un seul document Markdown)
 */
(function (HAGen) {
  "use strict";

  HAGen.generateAll = function (cfg) {
    var T = HAGen.templates;
    var h = cfg.hosts;
    var files = [
      { id: "haproxy", path: "haproxy/haproxy.cfg", target: "/etc/haproxy/haproxy.cfg", vm: h.haproxy.name, lang: "haproxy", content: T.haproxy(cfg) }
    ];

    HAGen.DB_KEYS.forEach(function (k, i) {
      var dir = "galera/node" + (i + 1) + "-" + h[k].name.toLowerCase();
      files.push({ id: "server-" + k, path: dir + "/50-server.cnf", target: "/etc/mysql/mariadb.conf.d/50-server.cnf", vm: h[k].name, lang: "ini", content: T.server(cfg, k) });
      files.push({ id: "galera-" + k, path: dir + "/60-galera.cnf", target: "/etc/mysql/mariadb.conf.d/60-galera.cnf", vm: h[k].name, lang: "ini", content: T.galera(cfg, k) });
    });

    files.push(
      { id: "sql", path: "galera/init-accounts.sql", target: "sudo mariadb < init-accounts.sql", vm: h.db1.name, lang: "sql", content: T.sqlInit(cfg) },
      { id: "wpconfig", path: "wordpress/wp-config.php", target: "/var/www/wordpress/wp-config.php", vm: h.web01.name + ", " + h.web02.name, lang: "php", content: T.wpconfig(cfg) },
      { id: "apache-wp", path: "apache/wordpress.conf", target: "/etc/apache2/sites-available/wordpress.conf", vm: h.web01.name + ", " + h.web02.name, lang: "apache", content: T.apacheWordpress(cfg) },
      { id: "apache-glpi", path: "apache/glpi.conf", target: "/etc/apache2/sites-available/glpi.conf", vm: h.glpi.name, lang: "apache", content: T.apacheGlpi(cfg) },
      { id: "ssh-linux", path: "ssh/linux-ssh-config", target: "~/.ssh/config", vm: h.adm.name, lang: "text", content: T.sshLinux(cfg) },
      { id: "ssh-windows", path: "ssh/windows-ssh-config", target: "C:\\Users\\<WINDOWS_USER>\\.ssh\\config", vm: "Poste Windows", lang: "text", content: T.sshWindows(cfg) },
      { id: "interfaces", path: "network/interfaces.txt", target: "/etc/network/interfaces", vm: "Toutes les VM Debian", lang: "text", content: T.interfaces(cfg) },
      { id: "pfsense", path: "pfsense/rules.md", target: "Interface web pfSense", vm: "pfSense", lang: "markdown", content: T.pfsense(cfg) },
      { id: "ipplan", path: "docs/ip-plan.md", target: "Documentation", vm: "—", lang: "markdown", content: T.ipPlan(cfg) }
    );
    return files;
  };

  HAGen.bundle = function (files, cfg) {
    var out = [
      "# Configuration générée — " + cfg.project.name,
      "",
      "Généré le " + new Date().toISOString().slice(0, 10) + " par generator/index.html.",
      "Aucun secret : remplacer chaque `<PASSWORD>` / `<SECRET>` avant utilisation.",
      ""
    ];
    files.forEach(function (f) {
      // Clôture de bloc plus longue que tout ``` éventuel du contenu
      var fence = f.content.indexOf("```") === -1 ? "```" : "````";
      out.push("## " + f.path, "", "- VM : " + f.vm, "- Cible : `" + f.target + "`", "", fence + f.lang, f.content.replace(/\n$/, ""), fence, "");
    });
    return out.join("\n");
  };
}(window.HAGen = window.HAGen || {}));
