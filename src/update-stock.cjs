const Database = require("better-sqlite3");
const path = require("path");
const fs = require("fs");
const { XMLParser } = require("fast-xml-parser");

// ====================
// PATHS
// ====================
const dbPath = path.join(__dirname, "../data/core.db"); // <-- DB adını buraya göre ayarla
const backupDir = path.join(__dirname, "../data/backups/production");
const logPath = path.join(__dirname, "../logs/production-stock-diff.log");

// ====================
// DB EXIST CHECK
// ====================
if (!fs.existsSync(dbPath)) {
    console.error("❌ DB bulunamadı:", dbPath);
    process.exit(1);
}

// ====================
// BACKUP
// ====================
if (!fs.existsSync(backupDir))
    fs.mkdirSync(backupDir, { recursive: true });

const ts = new Date().toISOString().replace(/[:.]/g, "-");
const backupPath = path.join(backupDir, `backup_${ts}.db`);

fs.copyFileSync(dbPath, backupPath);
console.log("🛡️ Backup alındı:", backupPath);

// ====================
// DB
// ====================
const db = new Database(dbPath);

// ====================
// LOG INIT
// ====================
if (!fs.existsSync(path.dirname(logPath)))
    fs.mkdirSync(path.dirname(logPath), { recursive: true });

if (!fs.existsSync(logPath)) {
    fs.writeFileSync(
        logPath,
        "DATE | SKU | OLD | NEW | SOURCE\n",
        "utf8"
    );
}

function logLine(line) {
    fs.appendFileSync(logPath, line + "\n", "utf8");
}

function now() {
    return new Date().toISOString().replace("T", " ").slice(0, 19);
}

// ====================
// HELPERS
// ====================
const parser = new XMLParser({ ignoreAttributes: false });

const normalize = v =>
    String(v || "").trim().toUpperCase();

const toInt = v =>
    parseInt(v, 10) || 0;

// ====================
// XML READERS
// ====================

function read4C(xmlPath) {
    const xml = fs.readFileSync(xmlPath, "utf8");
    const json = parser.parse(xml);
    const map = new Map();

    function walk(obj) {
        if (!obj || typeof obj !== "object") return;

        if (obj.Urun) {
            const list = Array.isArray(obj.Urun) ? obj.Urun : [obj.Urun];

            for (const u of list) {
                const secenek = u.UrunSecenek?.Secenek;
                const arr = Array.isArray(secenek) ? secenek : [secenek];

                for (const s of arr) {
                    const sku = normalize(s?.StokKodu);
                    if (!sku) continue;
                    map.set(sku, toInt(s.StokAdedi));
                }
            }
        }

        for (const k in obj) walk(obj[k]);
    }

    walk(json);
    return map;
}

function readMacom(xmlPath) {
    const xml = fs.readFileSync(xmlPath, "utf8");
    const json = parser.parse(xml);
    const map = new Map();

    const products = Array.isArray(json.products?.product)
        ? json.products.product
        : [json.product].filter(Boolean);

    for (const p of products) {
        const vars = Array.isArray(p?.variants?.variant)
            ? p.variants.variant
            : [p?.variants?.variant].filter(Boolean);

        for (const v of vars) {
            const sku = normalize(v?.sku);
            if (!sku) continue;

            const stock = toInt(v.stocks?.stock?.stockCount);
            map.set(sku, stock);
        }
    }

    return map;
}

function readMaske(xmlPath) {
    const xml = fs.readFileSync(xmlPath, "utf8");
    const json = parser.parse(xml);
    const map = new Map();

    function walk(obj) {
        if (!obj || typeof obj !== "object") return;

        if (obj.UrunSecenek?.Secenek) {
            const list = Array.isArray(obj.UrunSecenek.Secenek)
                ? obj.UrunSecenek.Secenek
                : [obj.UrunSecenek.Secenek];

            for (const s of list) {

                const sku = normalize(s?.StokKodu);
                if (!sku) continue;

                const status = String(s?.StokDurumu || "")
                    .trim()
                    .toLowerCase();

                let stock = 0;

                if (status === "in stock") {
                    stock = 3;
                } else {
                    stock = 0;
                }

                map.set(sku, stock);
            }
        }

        for (const k in obj) walk(obj[k]);
    }

    walk(json);
    return map;
}

// ====================
// LOAD XML
// ====================
const xml4c = read4C(path.join(__dirname, "../data/4c.xml"));
const xmlMacom = readMacom(path.join(__dirname, "../data/macom.xml"));
const xmlMaske = readMaske(path.join(__dirname, "../data/maske.xml"));

console.log("📦 4C:", xml4c.size);
console.log("📦 MACOM:", xmlMacom.size);
console.log("📦 MASKE:", xmlMaske.size);

// ====================
// UPDATE
// ====================
const products = db.prepare(`
  SELECT sku, stock, source
  FROM products
  WHERE status = 'active'
`).all();

const updateStmt = db.prepare(`
  UPDATE products
  SET stock = ?, updated_at = ?
  WHERE sku = ? AND source = ?
`);

let changed = 0;

const transaction = db.transaction(() => {

    for (const p of products) {

        const sku = normalize(p.sku);
        const oldStock = Number(p.stock);

        let newStock;

        if (p.source === "4c")
            newStock = xml4c.get(sku);

        if (p.source === "macom")
            newStock = xmlMacom.get(sku);

        if (p.source === "maske")
            newStock = xmlMaske.get(sku);

        if (newStock === undefined) continue;

        if (oldStock !== newStock) {

            const line = `${now()} | ${sku} | ${oldStock} | ${newStock} | ${p.source}`;

            console.log("✅", line);
            logLine(line);

            updateStmt.run(newStock, now(), sku, p.source);
            changed++;
        }
    }

});

transaction();

console.log("────────────────────────");
console.log("🔄 Changed:", changed);

console.log("✅ Source bazlı stok senkron tamamlandı");