const Database = require("better-sqlite3");
const fs = require("fs");
const path = require("path");
const { XMLParser } = require("fast-xml-parser");

const DB_PATH = path.join(__dirname, "../../data/core.db");
const XML_PATH = path.join(__dirname, "../../data/4c.xml");

// 🔥 Filtrelenecek kategori
const TARGET_CATEGORY_ID = "616";

const db = new Database(DB_PATH, { readonly: true });
const parser = new XMLParser({ ignoreAttributes: false });

const normalize = s => String(s || "").trim().toUpperCase();

const xml = parser.parse(fs.readFileSync(XML_PATH, "utf8"));

const dbSkus = new Set(
    db.prepare("SELECT sku FROM products").all().map(r => normalize(r.sku))
);

const missing = [];

function walk(node) {
    if (!node || typeof node !== "object") return;

    if (node.UrunKartiID && node.KategoriID == TARGET_CATEGORY_ID) {

        if (node.UrunSecenek?.Secenek) {
            const arr = Array.isArray(node.UrunSecenek.Secenek)
                ? node.UrunSecenek.Secenek
                : [node.UrunSecenek.Secenek];

            for (const s of arr) {
                const sku = normalize(s.StokKodu);

                if (!dbSkus.has(sku)) {
                    missing.push({
                        sku,
                        name: node.UrunAdi,
                        category: node.Kategori,
                        price: s.SatisFiyati,
                        currency: s.ParaBirimiKodu
                    });
                }
            }
        }
    }

    for (const k in node) walk(node[k]);
}

walk(xml);

console.log("Kategori:", TARGET_CATEGORY_ID);
console.log("Missing Count:", missing.length);

if (missing.length > 0) {
    console.log("──────── Missing Products ────────");
    missing.forEach(p => {
        console.log(`${p.sku}`);
    });
}