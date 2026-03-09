const Database = require("better-sqlite3");
const fs = require("fs");
const path = require("path");
const { XMLParser } = require("fast-xml-parser");

const DB_PATH = path.join(__dirname, "../data/core.db");
const XML_PATH = path.join(__dirname, "../data/maske.xml");
const LOG_PATH = path.join(__dirname, "../logs/maske-update.log");

// 🔹 Sabit USD kuru
const USD_RATE = 43.767;

const db = new Database(DB_PATH);
const parser = new XMLParser({ ignoreAttributes: false });

if (!fs.existsSync(path.dirname(LOG_PATH)))
    fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });

function log(line) {
    fs.appendFileSync(LOG_PATH, line + "\n", "utf8");
}

function now() {
    return new Date().toISOString().replace("T", " ").slice(0, 19);
}

const normalize = s => String(s || "").trim().toUpperCase();

const normalizeNumber = v => {
    if (v === undefined || v === null || v === "") return null;
    return Number(String(v).replace(",", "."));
};

// XML OKU
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
                vat_rate: normalizeNumber(s.KdvOrani),
                vat_included: s.KDVDahil === "true" ? 1 : 0,
                currency: normalize(s.ParaBirimiKodu)
            });
        }
    }

    for (const k in node) walk(node[k], list);
    return list;
}

const items = walk(xml);

// SELECT (stock dahil değil artık compare'de)
const selectStmt = db.prepare(`
  SELECT sale_price, vat_rate, vat_included, currency
  FROM products
  WHERE sku = ?
    AND source = 'maske'
    AND status = 'active'
`);

// UPDATE (stock çıkarıldı)
const updateStmt = db.prepare(`
  UPDATE products
  SET sale_price = ?,
      vat_rate = ?,
      vat_included = ?,
      currency = ?,
      updated_at = CURRENT_TIMESTAMP
  WHERE sku = ?
    AND source = 'maske'
    AND status = 'active'
`);

let updated = 0;
let skipped = 0;
let notFound = 0;
let converted = 0;

const transaction = db.transaction(() => {

    for (const i of items) {

        let salePrice = i.sale_price;
        let currency = i.currency;

        // TRY → USD dönüşümü devam ediyor
        if (currency === "TRY" && salePrice) {
            salePrice = Number((salePrice / USD_RATE).toFixed(4));
            currency = "USD";
            converted++;
        }

        const current = selectStmt.get(i.sku);

        if (!current) {
            notFound++;
            continue;
        }

        const changed =
            Number(current.sale_price) !== Number(salePrice) ||
            Number(current.vat_rate) !== Number(i.vat_rate) ||
            Number(current.vat_included) !== Number(i.vat_included) ||
            String(current.currency || "") !== String(currency || "");

        if (!changed) {
            skipped++;
            continue;
        }

        updateStmt.run(
            salePrice,
            i.vat_rate,
            i.vat_included,
            currency,
            i.sku
        );

        const line =
            `${now()} | ${i.sku} | ` +
            `PRICE: ${current.sale_price}→${salePrice} | ` +
            `CUR: ${current.currency}→${currency}`;

        log(line);
        updated++;
    }
});

transaction();

console.log("────────────────────────");
console.log(`✅ MASKE senkron tamamlandı`);
console.log(`📊 Güncellenen: ${updated}`);
console.log(`⏭️  Değişmeyen: ${skipped}`);
if (notFound > 0) {
    console.log(`⚠️  DB'de bulunamayan: ${notFound}`);
}
if (converted > 0) {
    console.log(`💱 TRY→USD dönüşüm: ${converted}`);
}