const Database = require("better-sqlite3");
const ExcelJS = require("exceljs");
const path = require("path");
const fs = require("fs");

const DB_PATH = path.join(__dirname, "../data/core.db");
const EXCEL_PATH = path.join(__dirname, "../data/site_products.xlsx");

if (!fs.existsSync(DB_PATH)) {
    console.error("❌ DB bulunamadı");
    process.exit(1);
}

if (!fs.existsSync(EXCEL_PATH)) {
    console.error("❌ Excel dosyası bulunamadı");
    process.exit(1);
}

const db = new Database(DB_PATH);

// ------------------
// DB'den stokları al
// ------------------
const stockMap = new Map();

const rows = db.prepare(`
  SELECT variant_id, stock
  FROM products
  WHERE status = 'active'
`).all();

for (const r of rows) {
    stockMap.set(String(r.variant_id), Number(r.stock));
}

console.log("📦 DB stock kayıt:", stockMap.size);

// ------------------
// Excel'i aç
// ------------------
(async () => {

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(EXCEL_PATH);

    const sheet = workbook.worksheets[0];
    const header = sheet.getRow(1);

    const col = {};
    header.eachCell((cell, i) => {
        col[cell.value] = i;
    });

    if (!col["URUNID"] || !col["STOKADEDI"]) {
        console.error("❌ Excel kolonları bulunamadı");
        process.exit(1);
    }

    let updated = 0;

    sheet.eachRow((row, rowNo) => {
        if (rowNo === 1) return;

        const variantId = String(
            row.getCell(col["URUNID"]).value || ""
        ).trim();

        if (!variantId) return;

        if (stockMap.has(variantId)) {

            const newStock = stockMap.get(variantId);
            const cell = row.getCell(col["STOKADEDI"]);

            if (Number(cell.value) !== newStock) {
                cell.value = newStock;
                updated++;
            }
        }
    });

    await workbook.xlsx.writeFile(EXCEL_PATH);

    console.log("────────────────────────");
    console.log("✅ Excel güncellendi");
    console.log("🔄 Güncellenen satır:", updated);

})();