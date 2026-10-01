/*
 * app.js — interface du générateur (formulaire, validation en direct, aperçu, export)
 * Fonctionne hors ligne en ouvrant index.html directement (file://) : aucun module ES, aucun fetch.
 */
(function (HAGen) {
  "use strict";

  var STORAGE_KEY = "hagen-config-v1";
  var state = { cfg: null, files: [], selected: "haproxy", result: { errors: [], warnings: [] } };

  /* ------------------------------------------------------------ Schéma du formulaire */
  var VLAN_ROWS = [["web", "Web"], ["db", "Bases de données"], ["admin", "Administration"], ["user", "Utilisateurs"]];
  var HOST_ROWS = [
    ["web01", "Serveur WordPress 1"], ["haproxy", "Répartiteur HAProxy"], ["glpi", "Serveur GLPI"],
    ["web02", "Serveur WordPress 2"], ["db1", "Nœud Galera 1 (bootstrap)"], ["db2", "Nœud Galera 2"],
    ["db3", "Nœud Galera 3"], ["adm", "Poste d'administration"], ["guac", "Bastion Guacamole"]
  ];
  var SIMPLE_SECTIONS = [
    {
      title: "Projet et WAN",
      fields: [
        ["project.name", "Nom du projet", "text"],
        ["project.domain", "Domaine interne", "text"],
        ["wan.address", "IP WAN pfSense", "text"],
        ["wan.prefix", "Préfixe WAN", "number"],
        ["wan.gateway", "Passerelle WAN", "text"],
        ["wan.natPortWordpress", "Port NAT WordPress", "number"],
        ["wan.natPortGlpi", "Port NAT GLPI (0 = aucun)", "number"]
      ]
    },
    {
      title: "Ports HAProxy",
      fields: [
        ["ports.http", "WordPress", "number"],
        ["ports.glpi", "GLPI", "number"],
        ["ports.sql", "SQL", "number"],
        ["ports.stats", "Statistiques", "number"],
        ["ports.backendHttp", "HTTP des serveurs web", "number"]
      ]
    },
    {
      title: "Galera",
      fields: [
        ["galera.clusterName", "Nom du cluster", "text"],
        ["galera.sstMethod", "Méthode SST", "select", ["rsync", "mariabackup"]]
      ]
    },
    {
      title: "Comptes (aucun mot de passe n'est demandé ni généré)",
      fields: [
        ["accounts.adminUser", "Admin Linux", "text"],
        ["accounts.haproxyAdmin", "Admin HAProxy", "text"],
        ["accounts.statsUser", "Utilisateur stats", "text"],
        ["accounts.checkUser", "Compte health-check SQL", "text"],
        ["accounts.wpDb", "Base WordPress", "text"],
        ["accounts.wpUser", "Utilisateur WordPress", "text"],
        ["accounts.glpiDb", "Base GLPI", "text"],
        ["accounts.glpiUser", "Utilisateur GLPI", "text"]
      ]
    }
  ];

  /* ------------------------------------------------------------ Utilitaires */
  function $(sel, root) { return (root || document).querySelector(sel); }
  function el(tag, attrs, text) {
    var node = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) { node.setAttribute(k, attrs[k]); });
    if (text !== undefined) { node.textContent = text; }
    return node;
  }
  function clone(o) { return JSON.parse(JSON.stringify(o)); }
  function getPath(obj, path) {
    return path.split(".").reduce(function (o, k) { return o == null ? undefined : o[k]; }, obj);
  }
  function setPath(obj, path, value) {
    var parts = path.split(".");
    var last = parts.pop();
    var target = parts.reduce(function (o, k) { o[k] = o[k] || {}; return o[k]; }, obj);
    target[last] = value;
  }
  function save() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state.cfg)); } catch (e) { /* stockage indisponible */ }
  }
  function load() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }
  /* Complète une configuration importée avec les clés manquantes de la référence */
  function merge(base, incoming) {
    var out = clone(base);
    (function walk(dst, src) {
      Object.keys(src || {}).forEach(function (k) {
        if (k.charAt(0) === "$") { return; }
        if (src[k] && typeof src[k] === "object" && !Array.isArray(src[k]) && dst[k] && typeof dst[k] === "object") {
          walk(dst[k], src[k]);
        } else if (k in dst) {
          dst[k] = src[k];
        }
      });
    }(out, incoming));
    return out;
  }

  /* ------------------------------------------------------------ Construction du formulaire */
  function input(path, type, options) {
    var id = "f-" + path.replace(/\./g, "-");
    var node;
    if (type === "select") {
      node = el("select", { id: id, "data-path": path });
      options.forEach(function (o) { node.appendChild(el("option", { value: o }, o)); });
    } else {
      node = el("input", { id: id, "data-path": path, type: type === "number" ? "number" : "text", spellcheck: "false", autocomplete: "off" });
      if (type === "number") { node.setAttribute("inputmode", "numeric"); }
    }
    node.setAttribute("data-type", type);
    return node;
  }

  function buildForm() {
    var form = $("#config-form");
    form.textContent = "";

    // Sections simples (libellé + champ)
    var first = SIMPLE_SECTIONS[0];
    form.appendChild(buildSimple(first));

    // VLAN
    var vlanSection = el("fieldset", { "class": "card" });
    vlanSection.appendChild(el("legend", {}, "VLAN"));
    var vt = el("table", { "class": "grid" });
    vt.innerHTML = "<thead><tr><th>Zone</th><th>ID</th><th>Nom</th><th>Réseau (CIDR)</th><th>Passerelle</th></tr></thead>";
    var vb = el("tbody");
    VLAN_ROWS.forEach(function (row) {
      var tr = el("tr");
      tr.appendChild(el("th", { scope: "row" }, row[1]));
      [["id", "number"], ["name", "text"], ["network", "text"], ["gateway", "text"]].forEach(function (c) {
        var td = el("td");
        var inp = input("vlans." + row[0] + "." + c[0], c[1]);
        inp.setAttribute("aria-label", row[1] + " — " + c[0]);
        td.appendChild(inp);
        tr.appendChild(td);
      });
      vb.appendChild(tr);
    });
    vt.appendChild(vb);
    vlanSection.appendChild(wrapTable(vt));
    form.appendChild(vlanSection);

    // VM
    var hostSection = el("fieldset", { "class": "card" });
    hostSection.appendChild(el("legend", {}, "Machines virtuelles"));
    var ht = el("table", { "class": "grid" });
    ht.innerHTML = "<thead><tr><th>Rôle</th><th>Nom</th><th>IP</th><th>VLAN</th></tr></thead>";
    var hb = el("tbody");
    HOST_ROWS.forEach(function (row) {
      var tr = el("tr");
      tr.appendChild(el("th", { scope: "row" }, row[1]));
      ["name", "ip"].forEach(function (c) {
        var td = el("td");
        var inp = input("hosts." + row[0] + "." + c, "text");
        inp.setAttribute("aria-label", row[1] + " — " + c);
        td.appendChild(inp);
        tr.appendChild(td);
      });
      tr.appendChild(el("td", { "class": "muted", "data-vlan-of": row[0] }));
      hb.appendChild(tr);
    });
    ht.appendChild(hb);
    hostSection.appendChild(wrapTable(ht));
    form.appendChild(hostSection);

    SIMPLE_SECTIONS.slice(1).forEach(function (s) { form.appendChild(buildSimple(s)); });
  }

  function wrapTable(table) {
    var div = el("div", { "class": "table-wrap" });
    div.appendChild(table);
    return div;
  }

  function buildSimple(section) {
    var fs = el("fieldset", { "class": "card" });
    fs.appendChild(el("legend", {}, section.title));
    var grid = el("div", { "class": "fields" });
    section.fields.forEach(function (f) {
      var label = el("label", { "for": "f-" + f[0].replace(/\./g, "-") }, f[1]);
      var wrap = el("div", { "class": "field" });
      wrap.appendChild(label);
      wrap.appendChild(input(f[0], f[2], f[3]));
      grid.appendChild(wrap);
    });
    fs.appendChild(grid);
    return fs;
  }

  /* ------------------------------------------------------------ Synchronisation formulaire <-> état */
  function fillForm() {
    document.querySelectorAll("[data-path]").forEach(function (node) {
      var v = getPath(state.cfg, node.getAttribute("data-path"));
      node.value = v === undefined || v === null ? "" : String(v);
    });
  }

  function onInput(ev) {
    var node = ev.target;
    var path = node.getAttribute("data-path");
    if (!path) { return; }
    var type = node.getAttribute("data-type");
    var value = node.value.trim();
    if (type === "number") {
      value = value === "" ? NaN : Number(value);
    }
    setPath(state.cfg, path, value);
    schedule();
  }

  var timer = null;
  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(refresh, 150);
  }

  /* ------------------------------------------------------------ Validation et rendu */
  function refresh() {
    state.result = HAGen.validate(state.cfg);
    renderValidation();
    try {
      state.files = state.result.errors.length ? [] : HAGen.generateAll(state.cfg);
    } catch (e) {
      state.files = [];
      state.result.errors.push({ path: "", message: "Erreur de génération : " + e.message });
      renderValidation();
    }
    renderFiles();
    save();
  }

  function renderValidation() {
    var r = state.result;
    document.querySelectorAll("[data-path]").forEach(function (n) {
      n.removeAttribute("aria-invalid");
      n.removeAttribute("title");
    });
    document.querySelectorAll("[data-vlan-of]").forEach(function (td) {
      var key = td.getAttribute("data-vlan-of");
      var v = state.cfg.vlans[HAGen.HOST_VLAN[key]] || {};
      td.textContent = (v.id || "?") + " " + (v.name || "");
    });

    var box = $("#validation");
    box.textContent = "";
    var status = $("#status");
    if (!r.errors.length) {
      status.className = "status ok";
      status.textContent = r.warnings.length
        ? "Configuration valide — " + r.warnings.length + " avertissement(s)"
        : "Configuration valide";
    } else {
      status.className = "status ko";
      status.textContent = r.errors.length + " erreur(s) : génération suspendue";
    }

    r.errors.concat(r.warnings).forEach(function (issue, idx) {
      var isError = idx < r.errors.length;
      var li = el("li", { "class": isError ? "error" : "warning" });
      var field = issue.path ? document.querySelector('[data-path="' + issue.path + '"]') : null;
      if (field) {
        if (isError) { field.setAttribute("aria-invalid", "true"); }
        field.setAttribute("title", issue.message);
        var btn = el("button", { type: "button", "class": "link" }, issue.path);
        btn.addEventListener("click", function () { field.focus(); });
        li.appendChild(btn);
        li.appendChild(document.createTextNode(" — " + issue.message));
      } else {
        li.textContent = issue.message;
      }
      box.appendChild(li);
    });
    $("#download-all").disabled = r.errors.length > 0;
    $("#copy-file").disabled = r.errors.length > 0;
    $("#download-file").disabled = r.errors.length > 0;
  }

  function renderFiles() {
    var list = $("#file-list");
    list.textContent = "";
    if (!state.files.length) {
      $("#preview").textContent = "Corriger les erreurs pour afficher les fichiers générés.";
      $("#file-meta").textContent = "";
      return;
    }
    if (!state.files.some(function (f) { return f.id === state.selected; })) {
      state.selected = state.files[0].id;
    }
    state.files.forEach(function (f) {
      var li = el("li");
      var btn = el("button", { type: "button", "class": "file" + (f.id === state.selected ? " active" : ""), "aria-pressed": String(f.id === state.selected) }, f.path);
      btn.addEventListener("click", function () { state.selected = f.id; renderFiles(); });
      li.appendChild(btn);
      list.appendChild(li);
    });
    var file = currentFile();
    $("#file-meta").textContent = "SUR " + file.vm + "  →  " + file.target;
    $("#preview").textContent = file.content;
  }

  function currentFile() {
    return state.files.filter(function (f) { return f.id === state.selected; })[0];
  }

  /* ------------------------------------------------------------ Export */
  function download(name, content, type) {
    var blob = new Blob([content], { type: type || "text/plain;charset=utf-8" });
    var url = URL.createObjectURL(blob);
    var a = el("a", { href: url, download: name });
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  function toast(msg) {
    var t = $("#toast");
    t.textContent = msg;
    t.classList.add("show");
    setTimeout(function () { t.classList.remove("show"); }, 2000);
  }

  function bindActions() {
    $("#config-form").addEventListener("input", onInput);
    $("#config-form").addEventListener("change", onInput);

    $("#load-reference").addEventListener("click", function () {
      state.cfg = clone(HAGen.REFERENCE);
      fillForm();
      refresh();
      toast("Infrastructure de référence chargée");
    });

    $("#export-json").addEventListener("click", function () {
      download((state.cfg.project.name || "infrastructure") + ".json", JSON.stringify(state.cfg, null, 2) + "\n", "application/json");
    });

    $("#import-json").addEventListener("change", function (ev) {
      var file = ev.target.files[0];
      if (!file) { return; }
      var reader = new FileReader();
      reader.onload = function () {
        try {
          state.cfg = merge(HAGen.REFERENCE, JSON.parse(reader.result));
          fillForm();
          refresh();
          toast("Configuration importée");
        } catch (e) {
          toast("JSON invalide : " + e.message);
        }
        ev.target.value = "";
      };
      reader.readAsText(file);
    });

    $("#copy-file").addEventListener("click", function () {
      var f = currentFile();
      if (!f) { return; }
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(f.content).then(function () { toast("Copié"); }, function () { toast("Copie refusée par le navigateur"); });
      } else {
        var ta = el("textarea");
        ta.value = f.content;
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand("copy"); toast("Copié"); } catch (e) { toast("Copie impossible"); }
        ta.remove();
      }
    });

    $("#download-file").addEventListener("click", function () {
      var f = currentFile();
      if (f) { download(f.path.replace(/\//g, "_"), f.content); }
    });

    $("#download-all").addEventListener("click", function () {
      download((state.cfg.project.name || "infrastructure") + "-generated.md", HAGen.bundle(state.files, state.cfg), "text/markdown;charset=utf-8");
    });
  }

  /* ------------------------------------------------------------ Démarrage */
  document.addEventListener("DOMContentLoaded", function () {
    var stored = load();
    state.cfg = stored ? merge(HAGen.REFERENCE, stored) : clone(HAGen.REFERENCE);
    buildForm();
    fillForm();
    bindActions();
    refresh();
  });
}(window.HAGen = window.HAGen || {}));
