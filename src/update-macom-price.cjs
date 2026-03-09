const Database = require("better-sqlite3");
const fs = require("fs");
const path = require("path");
const { XMLParser } = require("fast-xml-parser");

const DB_PATH = path.join(__dirname, "../data/core.db");
const XML_PATH = path.join(__dirname, "../data/macom.xml");
const LOG_PATH = path.join(__dirname, "../logs/macom-update.log");
const MARGIN = 1.4;

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

const normalize = (s) => String(s || "").trim().toUpperCase();
const num = (v) => {
    if (v === undefined || v === null || v === "") return null;
    return Number(String(v).replace(",", "."));
};

// XML oku
const xml = parser.parse(fs.readFileSync(XML_PATH, "utf8"));
const products = Array.isArray(xml.products?.product)
    ? xml.products.product
    : [xml.product].filter(Boolean);

// DB SELECT
const selectStmt = db.prepare(`
  SELECT buy_price, sale_price, stock, currency
  FROM products
  WHERE sku = ?
    AND source = 'macom'
    AND status = 'active'
`);

// DB UPDATE
const updateStmt = db.prepare(`
  UPDATE products
  SET buy_price = ?,
      sale_price = ?,
      stock = ?,
      currency = ?,
      updated_at = CURRENT_TIMESTAMP
  WHERE sku = ?
    AND source = 'macom'
    AND status = 'active'
`);

let updated = 0;
let skipped = 0;
let notFound = 0;
let errors = 0;

const transaction = db.transaction(() => {
    for (const p of products) {
        const variants = Array.isArray(p?.variants?.variant)
            ? p.variants.variant
            : [p?.variants?.variant].filter(Boolean);

        for (const v of variants) {
            const sku = normalize(v.sku);
            if (!sku) {
                continue;
            }

            // FIX: XML'de prices.price.sellPrice olarak geliyor
            const priceData = Array.isArray(v.prices?.price)
                ? v.prices.price[0]
                : v.prices?.price;

            const buy_price = num(priceData?.sellPrice);

            if (!buy_price) {
                errors++;
                continue;
            }

            const sale_price = Number((buy_price * MARGIN).toFixed(2));

            // FIX: Stock path
            const stockData = Array.isArray(v.stocks?.stock)
                ? v.stocks.stock[0]
                : v.stocks?.stock;
            const stock = num(stockData?.stockCount) || 0;

            // FIX: Currency path
            const currency = priceData?.currency || "TRY";

            const current = selectStmt.get(sku);

            if (!current) {
                notFound++;
                continue;
            }

            const changed =
                Number(current.buy_price) !== Number(buy_price) ||
                Number(current.sale_price) !== Number(sale_price) ||
                Number(current.stock) !== Number(stock) ||
                String(current.currency || "") !== String(currency || "");

            if (!changed) {
                skipped++;
                continue;
            }

            updateStmt.run(buy_price, sale_price, stock, currency, sku);

            const line =
                `${now()} | ${sku} | ` +
                `BUY: ${current.buy_price}→${buy_price} | ` +
                `SALE: ${current.sale_price}→${sale_price} | ` +
                `STOCK: ${current.stock}→${stock}`;

            log(line);
            updated++;
        }
    }
});

transaction();

console.log("────────────────────────");
console.log(`✅ MACOM senkron tamamlandı`);
console.log(`📊 Güncellenen: ${updated}`);
console.log(`⏭️  Değişmeyen: ${skipped}`);
if (notFound > 0) {
    console.log(`⚠️  DB'de bulunamayan: ${notFound}`);
}
if (errors > 0) {
    console.log(`❌ Hatalı: ${errors}`);
}
