const Database = require("better-sqlite3");
const ExcelJS = require("exceljs");
const path = require("path");
const fs = require("fs");

const DB_PATH = path.join(__dirname, "../../data/core.db");
const N11_PATH = path.join(__dirname, "../../data/marketplace/n11.xlsx");
const LOG_PATH = path.join(__dirname, "../../logs/n11-legacy.log");

const db = new Database(DB_PATH);

const normalize = v => String(v || "").trim();

(async () => {

    console.log("🔎 N11 Legacy Kontrol Başladı");

    // 1️⃣ Site active variant_id'leri al
    const siteRows = db.prepare(`
    SELECT variant_id
    FROM products
    WHERE status = 'active'
  `).all();

    const siteVariantSet = new Set(
        siteRows.map(r => normalize(r.variant_id))
    );

    console.log("📦 Site aktif ürün:", siteVariantSet.size);

    // 2️⃣ N11 Excel oku
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(N11_PATH);

    const sheet = workbook.worksheets[0]; // N11 genelde tek sheet

    const header = sheet.getRow(1);

    const col = {};
    header.eachCell((cell, i) => {
        col[String(cell.value).trim().toUpperCase()] = i;
    });

    // N11’de kolon adı genelde "STOK KODU"
    const stockCodeCol = col["STOK KODU"];

    if (!stockCodeCol) {
        console.error("❌ 'Stok Kodu' kolonu bulunamadı!");
        process.exit(1);
    }

    const legacy = [];

    sheet.eachRow((row, rowNo) => {
        if (rowNo === 1) return;

        const stockCode = normalize(
            row.getCell(stockCodeCol).value
        );

        if (!stockCode) return;

        if (!siteVariantSet.has(stockCode)) {
            legacy.push(stockCode);
        }
    });

    console.log("⚠️ N11 Legacy Ürün Sayısı:", legacy.length);

    if (legacy.length > 0) {

        const lines = legacy.filter(Boolean);

        fs.writeFileSync(LOG_PATH, lines.join("\n"), "utf8");

        console.log("📝 Liste logs/n11-legacy.log dosyasına yazıldı");

    } else {
        console.log("✅ N11 Legacy yok");
    }

})();