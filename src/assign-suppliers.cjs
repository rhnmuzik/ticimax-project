

const Database = require("better-sqlite3");
const fs = require("fs");
const path = require("path");
const { XMLParser } = require("fast-xml-parser");

const DB_PATH = path.join(__dirname, "../data/core.db");

const XML_4C = path.join(__dirname, "../data/4c.xml");
const XML_MACOM = path.join(__dirname, "../data/macom.xml");
const XML_MASKE = path.join(__dirname, "../data/maske.xml");

const db = new Database(DB_PATH);
const parser = new XMLParser({ ignoreAttributes: false });

// -------------------------------------------------
// HELPERS
// -------------------------------------------------

function normalize(value) {
    return String(value || "").trim().toUpperCase();
}

function normalizeBrand(value) {
    if (!value) return "";
    return String(value)
        .trim()
        .toUpperCase()
        .replace(/İ/g, "I")
        .replace(/Ş/g, "S")
        .replace(/Ğ/g, "G")
        .replace(/Ü/g, "U")
        .replace(/Ö/g, "O")
        .replace(/Ç/g, "C")
        .replace(/[^A-Z0-9 ]/g, "")
        .replace(/\s+/g, " ");
}

// -------------------------------------------------
// BRAND MAP
// -------------------------------------------------

const BRAND_MAP = {
    "4c": new Set([
        "CREMONIA", "DADDARIO", "VALENCIA", "MAXTONE", "FUGUE",
        "PLANET WAVES", "VIC FIRTH", "TAMA", "KINGLOS", "LAGUNA",
        "CAMPS", "EVANS", "WITTNER", "RIYIN", "CHERUB", "MUSEDO",
        "PROMARK", "SABIAN", "RICO", "ARTEC", "CORT", "IBANEZ",
        "GRAPHTECH", "MADAROZZO"
    ]),
    "macom": new Set([
        "DADI", "DOMINGUEZ", "EXTREME", "MANUEL RAYMOND",
        "WELTMEISTER", "PIRASTRO", "ANTONIO SANCHEZ",
        "VICTORIA", "RODRIGUEZ", "KOALA", "ATAKAN",
        "HELENE MIA", "BARRE", "PYRAMID", "MANOL",
        "SCHALLER", "LA BELLA", "HOFHAIMER", "NUX",
        "WITTNER", "FRANCK BICHON", "THOMASTIK INFELT",
        "NUVO", "AMATI", "RIGOTTI"
    ]),
    "maske": new Set([
        "ARSENBERG", "BEATTRON", "ECHOBAN", "DUFFON",
        "RAVENNI", "BARDSEN", "MIGUEL ARTEGAS",
        "PRANZEN", "ZOPPRAN", "CARNEVILLE"
    ])
};

// -------------------------------------------------
// XML READERS
// -------------------------------------------------

function readGeneric(xmlPath) {
    const xml = fs.readFileSync(xmlPath, "utf8");
    const json = parser.parse(xml);
    const set = new Set();

    function walk(node) {
        if (!node || typeof node !== "object") return;

        if (node.UrunSecenek?.Secenek) {
            const list = Array.isArray(node.UrunSecenek.Secenek)
                ? node.UrunSecenek.Secenek
                : [node.UrunSecenek.Secenek];

            for (const s of list) {
                set.add(normalize(s.StokKodu));
            }
        }

        for (const k in node) walk(node[k]);
    }

    walk(json);
    return set;
}

function readMacom(xmlPath) {
    const xml = fs.readFileSync(xmlPath, "utf8");
    const json = parser.parse(xml);
    const set = new Set();

    const products = Array.isArray(json.products?.product)
        ? json.products.product
        : [json.product].filter(Boolean);

    for (const p of products) {
        const vars = Array.isArray(p?.variants?.variant)
            ? p.variants.variant
            : [p?.variants?.variant].filter(Boolean);

        for (const v of vars) {
            set.add(normalize(v.sku));
        }
    }

    return set;
}

// -------------------------------------------------
// LOAD XML
// -------------------------------------------------

const set4c = readGeneric(XML_4C);
const setMacom = readMacom(XML_MACOM);
const setMaske = readGeneric(XML_MASKE);

console.log("4C size:", set4c.size);
console.log("Macom size:", setMacom.size);
console.log("Maske size:", setMaske.size);

console.log("4C has EQ7545:", set4c.has("EQ7545"));
console.log("Macom has EQ7545:", setMacom.has("EQ7545"));

// -------------------------------------------------
// DB
// -------------------------------------------------

const products = db.prepare(`
  SELECT id, sku, brand, source
  FROM products
  WHERE status = 'active'
`).all();

const updateStmt = db.prepare(`
  UPDATE products
  SET source = ?, 
      source_conflict = ?,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = ?
`);

let assigned = 0;
let conflicts = 0;
let updated = 0;

const transaction = db.transaction(() => {

    for (const p of products) {

        const sku = normalize(p.sku);
        const brand = normalizeBrand(p.brand);
        const currentSource = p.source;

        const in4c = set4c.has(sku);
        const inMacom = setMacom.has(sku);
        const inMaske = setMaske.has(sku);

        const hitCount = [in4c, inMacom, inMaske].filter(Boolean).length;

        let newSource = null;
        let conflictFlag = 0;

        if (hitCount === 0) {
            newSource = null;
        }
        else if (hitCount === 1) {
            if (in4c) newSource = "4c";
            if (inMacom) newSource = "macom";
            if (inMaske) newSource = "maske";
        }
        else {
            let resolved = null;

            for (const supplier of Object.keys(BRAND_MAP)) {
                if (BRAND_MAP[supplier].has(brand)) {
                    resolved = supplier;
                    break;
                }
            }

            if (resolved) {
                newSource = resolved;
            } else {
                newSource = null;
                conflictFlag = 1;
                conflicts++;
            }
        }

        if (newSource !== currentSource || conflictFlag !== 0) {
            updateStmt.run(newSource, conflictFlag, p.id);
            updated++;
        }

        if (newSource && conflictFlag === 0) assigned++;
    }

});

transaction();

console.log("────────────────────────");
console.log("Assigned:", assigned);
console.log("Updated:", updated);
console.log("Conflicts:", conflicts);
console.log("DONE");