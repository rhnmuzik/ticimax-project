const Database = require("better-sqlite3");
const ExcelJS = require("exceljs");
const path = require("path");
const fs = require("fs");

const DB_PATH = path.join(__dirname, "../../data/core.db");
const TRENDYOL_PATH = path.join(__dirname, "../../data/marketplace/trendyol.xlsx");
const LOG_PATH = path.join(__dirname, "../../logs/trendyol-legacy.log");

const db = new Database(DB_PATH);

// ---------------- HELPERS ----------------

const normalizeBarcode = v => {
    if (!v) return null;

    if (typeof v === "object" && v.text) {
        return String(v.text).trim();
    }

    if (typeof v === "number") {
        return v.toString();
    }

    const s = String(v).trim();
    return s.replace(/\.0$/, "");
};

// ---------------- MAIN ----------------

(async () => {

    console.log("🔎 Trendyol Legacy Kontrol Başladı");

    // 1️⃣ Site aktif barkodlarını al
    const siteRows = db.prepare(`
    SELECT barcode
    FROM products
    WHERE status = 'active'
      AND barcode IS NOT NULL
  `).all();

    const siteBarcodeSet = new Set(
        siteRows.map(r => normalizeBarcode(r.barcode))
    );

    console.log("📦 Site aktif ürün:", siteBarcodeSet.size);

    // 2️⃣ Trendyol Excel oku
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(TRENDYOL_PATH);

    const sheet = workbook.worksheets[0];
    const header = sheet.getRow(1);

    const col = {};
    header.eachCell((cell, i) => {
        col[String(cell.value).trim().toUpperCase()] = i;
    });

    if (!col["BARKOD"]) {
        console.error("❌ BARKOD kolonu bulunamadı!");
        process.exit(1);
    }

    const legacy = [];

    sheet.eachRow((row, rowNo) => {
        if (rowNo === 1) return;

        const barcode = normalizeBarcode(
            row.getCell(col["BARKOD"]).value
        );

        if (!barcode) return;

        if (!siteBarcodeSet.has(barcode)) {
            legacy.push(barcode);
        }
    });

    console.log("⚠️ Trendyol Legacy Ürün Sayısı:", legacy.length);

    // 3️⃣ Log yaz
    if (legacy.length > 0) {
        fs.writeFileSync(
            LOG_PATH,
            legacy.join("\n"),
            "utf8"
        );
        console.log("📝 Liste logs/trendyol-legacy.log dosyasına yazıldı");
    } else {
        console.log("✅ Legacy ürün yok");
    }

})();