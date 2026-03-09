const Database = require("better-sqlite3");
const fs = require("fs");
const path = require("path");
const { XMLParser } = require("fast-xml-parser");

// ====================
// PATHS
// ====================
const DB_PATH = path.join(__dirname, "../data/core.db");
const XML_PATH = path.join(__dirname, "../data/4c.xml");
const LOG_PATH = path.join(__dirname, "../logs/4c-update.log");

// ====================
// DB
// ====================
const db = new Database(DB_PATH);

// ====================
// LOG INIT
// ====================
if (!fs.existsSync(path.dirname(LOG_PATH)))
    fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });

function log(line) {
    fs.appendFileSync(LOG_PATH, line + "\n", "utf8");
}

function now() {
    return new Date().toISOString().replace("T", " ").slice(0, 19);
}

// ====================
// HELPERS
// ====================
const parser = new XMLParser({ ignoreAttributes: false });

const normalize = s => String(s || "").trim().toUpperCase();

const normalizeNumber = v => {
    if (v === undefined || v === null || v === "") return null;
    return Number(String(v).replace(",", "."));
};

// ====================
// XML OKU
// ====================
const xml = parser.parse(fs.readFileSync(XML_PATH, "utf8"));

function walk(node, list = []) {
    if (!node || typeof node !== "object") return list;

    if (node.UrunSecenek?.Secenek) {
        const arr = Array.isArray(node.UrunSecenek.Secenek)
            ? node.UrunSecenek.Secenek
            : [node.UrunSecenek.Secenek];

        for (const s of arr) {
            list.push({
                sku: normalize(s.StokKodu),
                sale_price: normalizeNumber(s.SatisFiyati),
                stock: normalizeNumber(s.StokAdedi),
                vat_rate: normalizeNumber(s.KdvOrani),
                vat_included: s.KDVDahil === "true" ? 1 : 0,
                currency: s.ParaBirimiKodu || null
            });
        }
    }

    for (const k in node) walk(node[k], list);
    return list;
}

const items = walk(xml);

// ====================
// PREPARE STATEMENTS
// ====================
const selectStmt = db.prepare(`
  SELECT sale_price, stock, vat_rate, vat_included, currency
  FROM products
  WHERE sku = ? AND source = '4c'
`);

const updateStmt = db.prepare(`
  UPDATE products
  SET sale_price = ?,
      stock = ?,
      vat_rate = ?,
      vat_included = ?,
      currency = ?,
      updated_at = CURRENT_TIMESTAMP
  WHERE sku = ? AND source = '4c'
`);

let updated = 0;
let skipped = 0;
let notFound = 0;

// ====================
// TRANSACTION
// ====================
const transaction = db.transaction(() => {

    for (const i of items) {

        const current = selectStmt.get(i.sku);

        if (!current) {
            notFound++;
            continue;
        }

        const changed =
            Number(current.sale_price) !== Number(i.sale_price) ||
            Number(current.stock) !== Number(i.stock) ||
            Number(current.vat_rate) !== Number(i.vat_rate) ||
            Number(current.vat_included) !== Number(i.vat_included) ||
            String(current.currency || "") !== String(i.currency || "");

        if (!changed) {
            skipped++;
            continue;
        }

        updateStmt.run(
            i.sale_price,
            i.stock,
            i.vat_rate,
            i.vat_included,
            i.currency,
            i.sku
        );

        const logLine =
            `${now()} | ${i.sku} | ` +
            `Price: ${current.sale_price}→${i.sale_price} | ` +
            `Stock: ${current.stock}→${i.stock}`;

        log(logLine);
        updated++;
    }
});

transaction();

// ====================
// SUMMARY
// ====================
console.log("────────────────────────");
console.log(`✅ 4C senkron tamamlandı`);
console.log(`📊 Güncellenen: ${updated}`);
console.log(`⏭️  Değişmeyen: ${skipped}`);
if (notFound > 0) {
    console.log(`⚠️  DB'de bulunamayan: ${notFound}`);
}