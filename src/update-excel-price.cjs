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
// DB'den fiyatları al
// ------------------
const priceMap = new Map();
const rows = db
    .prepare(
        `SELECT variant_id,
            buy_price,
            sale_price,
            currency,
            vat_rate,
            vat_included
     FROM products
     WHERE status = 'active'`
    )
    .all();

for (const r of rows) {
    priceMap.set(String(r.variant_id), {
        buy_price: r.buy_price,
        sale_price: r.sale_price,
        currency: r.currency,
        vat_rate: r.vat_rate,
        vat_included: Number(r.vat_included), // 0/1 olarak normalize et
    });
}

console.log("💰 DB fiyat kayıt:", priceMap.size);

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

    const requiredCols = [
        "URUNID",
        "ALISFIYATI",
        "SATISFIYATI",
        "PARABIRIMI",
        "KDVORANI",
        "KDVDAHIL",
    ];

    for (const c of requiredCols) {
        if (!col[c]) {
            console.error(`❌ Kolon bulunamadı: ${c}`);
            process.exit(1);
        }
    }

    let updated = 0;
    let notFound = 0;

    sheet.eachRow((row, rowNo) => {
        if (rowNo === 1) return;

        const variantId = String(row.getCell(col["URUNID"]).value || "").trim();
        if (!variantId) return;

        if (priceMap.has(variantId)) {
            const data = priceMap.get(variantId);
            let changed = false;

            function setIfDifferent(cellName, value) {
                const cell = row.getCell(col[cellName]);
                const oldValue = cell.value;

                // Debug: KDVDAHIL için loglama
                if (cellName === "KDVDAHIL") {
                    console.log(
                        `${variantId} | KDVDAHIL: ${oldValue} (${typeof oldValue}) → ${value} (${typeof value})`
                    );
                }

                if (cell.value !== value) {
                    cell.value = value;
                    changed = true;
                }
            }

            setIfDifferent("ALISFIYATI", data.buy_price);
            setIfDifferent("SATISFIYATI", data.sale_price);
            setIfDifferent("PARABIRIMI", data.currency);
            setIfDifferent("KDVORANI", data.vat_rate);
            setIfDifferent("KDVDAHIL", data.vat_included);

            if (changed) {
                console.log(`✅ ${variantId} güncellendi`);
                updated++;
            }
        } else {
            notFound++;
        }
    });

    await workbook.xlsx.writeFile(EXCEL_PATH);

    console.log("────────────────────────");
    console.log("✅ Excel fiyat güncellendi");
    console.log("🔄 Güncellenen satır:", updated);
    console.log("❌ Bulunamayan ürün:", notFound);
    console.log("────────────────────────");
})();
