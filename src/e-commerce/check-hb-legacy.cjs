const Database = require("better-sqlite3");
const ExcelJS = require("exceljs");
const path = require("path");
const fs = require("fs");

const DB_PATH = path.join(__dirname, "../../data/core.db");
const HB_PATH = path.join(__dirname, "../../data/marketplace/hb.xlsx");
const LOG_PATH = path.join(__dirname, "../../logs/hb-legacy.log");

const db = new Database(DB_PATH);

// ---------------- HELPERS ----------------

const normalize = v => String(v || "").trim();

// ---------------- MAIN ----------------

(async () => {

    console.log("🔎 HB Legacy Kontrol Başladı");

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

    // 2️⃣ HB Excel oku
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(HB_PATH);

    // 👉 Sheet adı sabit
    const sheet = workbook.getWorksheet("Listelerim");

    if (!sheet) {
        console.error("❌ 'Listelerim' sheet'i bulunamadı!");
        console.log("Mevcut sheetler:");
        workbook.worksheets.forEach(ws => {
            console.log("-", ws.name);
        });
        process.exit(1);
    }

    // 3️⃣ Header mapping (case-insensitive)
    const header = sheet.getRow(1);

    const col = {};
    header.eachCell((cell, i) => {
        col[String(cell.value).trim().toUpperCase()] = i;
    });

    const sellerStockCol = col["SATICI STOK KODU"];
    const skuCol = col["SKU"];

    if (!sellerStockCol) {
        console.error("❌ 'Satıcı Stok Kodu' kolonu bulunamadı!");
        process.exit(1);
    }

    if (!skuCol) {
        console.error("❌ 'SKU' kolonu bulunamadı!");
        process.exit(1);
    }

    // 4️⃣ Legacy kontrol
    const legacy = [];

    sheet.eachRow((row, rowNo) => {
        if (rowNo === 1) return;

        const sellerStock = normalize(
            row.getCell(sellerStockCol).value
        );

        const sku = normalize(
            row.getCell(skuCol).value
        );

        if (!sellerStock) return;

        if (!siteVariantSet.has(sellerStock)) {
            legacy.push({
                sellerStock,
                sku
            });
        }
    });

    console.log("⚠️ HB Legacy Ürün Sayısı:", legacy.length);

    // 5️⃣ Log yaz
    // 5️⃣ Log yaz
    if (legacy.length > 0) {

        const lines = legacy
            .map(l => l.sku)
            .filter(Boolean);

        fs.writeFileSync(LOG_PATH, lines.join("\n"), "utf8");

        console.log("📝 Liste logs/hb-legacy.log dosyasına yazıldı");

    } else {
        console.log("✅ HB Legacy yok");
    }

})();