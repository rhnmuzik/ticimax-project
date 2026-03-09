// Sadece değişen ürünleri Ticimax formatında Excel oluştur

const Database = require("better-sqlite3");
const ExcelJS = require("exceljs");
const path = require("path");
const fs = require("fs");

const DB_PATH = path.join(__dirname, "../data/core.db");
const TEMPLATE_PATH = path.join(__dirname, "../data/ticimax-import/ticimax-template.xlsx");
const OUTPUT_PATH = path.join(__dirname, "../data/ticimax-import/ticimax-changes.xlsx");

const db = new Database(DB_PATH);

// Son import zamanını al
const getLastImportTime = () => {
    const result = db.prepare(`
        SELECT MAX(updated_at) as last_import
        FROM products
        WHERE status = 'active'
    `).get();

    return result?.last_import || null;
};

// Son importtan beri değişen ürünleri al
const getChangedProducts = (lastImportTime) => {
    if (!lastImportTime) {
        console.log("⚠️  Henüz import yapılmamış, tüm aktif ürünler alınıyor");
        return db.prepare(`
            SELECT 
                sku,
                variant_id,
                product_id,
                product_name,
                brand,
                stock,
                buy_price,
                sale_price,
                currency,
                vat_rate,
                vat_included,
                barcode,
                updated_at
            FROM products
            WHERE status = 'active'
            ORDER BY updated_at DESC
        `).all();
    }

    // Son importtan 1 saniye önce bir referans noktası oluştur
    const referenceTime = new Date(new Date(lastImportTime).getTime() - 1000).toISOString();

    return db.prepare(`
        SELECT 
            sku,
            variant_id,
            product_id,
            product_name,
            brand,
            stock,
            buy_price,
            sale_price,
            currency,
            vat_rate,
            vat_included,
            barcode,
            updated_at
        FROM products
        WHERE status = 'active'
        AND updated_at > ?
        ORDER BY updated_at DESC
    `).all(referenceTime);
};

(async () => {
    console.log("🔍 Son import zamanı kontrol ediliyor...");

    const lastImportTime = getLastImportTime();
    if (lastImportTime) {
        console.log(`📅 Son import: ${lastImportTime}`);
    }

    const changes = getChangedProducts(lastImportTime);

    if (changes.length === 0) {
        console.log("ℹ️  Son importtan beri değişiklik yok");
        process.exit(0);
    }

    console.log(`📊 ${changes.length} değişiklik bulundu`);

    // Template'i oku
    const templateWb = new ExcelJS.Workbook();
    await templateWb.xlsx.readFile(TEMPLATE_PATH);
    const templateSheet = templateWb.worksheets[0];

    // Yeni workbook oluştur
    const outputWb = new ExcelJS.Workbook();
    const outputSheet = outputWb.addWorksheet('Değişiklikler');

    // Header'ı kopyala
    const headerRow = templateSheet.getRow(1);
    const col = {};

    headerRow.eachCell((cell, colNumber) => {
        const cellValue = cell.value;
        outputSheet.getCell(1, colNumber).value = cellValue;

        // Header stilini kopyala
        outputSheet.getCell(1, colNumber).font = cell.font;
        outputSheet.getCell(1, colNumber).fill = cell.fill;
        outputSheet.getCell(1, colNumber).alignment = cell.alignment;
        outputSheet.getCell(1, colNumber).border = cell.border;

        // Kolon genişliğini kopyala
        const templateCol = templateSheet.getColumn(colNumber);
        if (templateCol.width) {
            outputSheet.getColumn(colNumber).width = templateCol.width;
        }

        // Kolon mapping
        if (cellValue) {
            col[String(cellValue).trim().toUpperCase()] = colNumber;
        }
    });

    // Verileri ekle
    let rowIndex = 2;
    let stockChanges = 0;
    let priceChanges = 0;

    for (const product of changes) {
        const row = outputSheet.getRow(rowIndex);

        // Değişiklik tipini belirle
        if (product.stock !== null) stockChanges++;
        if (product.sale_price !== null) priceChanges++;

        // Ticimax formatında doldur
        if (col["URUNID"]) row.getCell(col["URUNID"]).value = product.variant_id || 0;
        if (col["URUNKARTIID"]) row.getCell(col["URUNKARTIID"]).value = product.product_id || 0;
        if (col["STOKKODU"]) row.getCell(col["STOKKODU"]).value = product.sku;
        if (col["VARYASYONKODU"]) row.getCell(col["VARYASYONKODU"]).value = product.sku;
        if (col["BARKOD"]) row.getCell(col["BARKOD"]).value = product.barcode;
        if (col["URUNADI"]) row.getCell(col["URUNADI"]).value = product.product_name;
        if (col["ONYAZI"]) row.getCell(col["ONYAZI"]).value = product.product_name;
        if (col["MARKA"]) row.getCell(col["MARKA"]).value = product.brand;
        if (col["STOKADEDI"]) row.getCell(col["STOKADEDI"]).value = product.stock || 0;
        if (col["ALISFIYATI"]) row.getCell(col["ALISFIYATI"]).value = product.buy_price;
        if (col["SATISFIYATI"]) row.getCell(col["SATISFIYATI"]).value = product.sale_price;
        if (col["PARABIRIMI"]) row.getCell(col["PARABIRIMI"]).value = product.currency || "TRY";
        if (col["KDVORANI"]) row.getCell(col["KDVORANI"]).value = product.vat_rate || 20;
        if (col["KDVDAHIL"]) row.getCell(col["KDVDAHIL"]).value = product.vat_included ? 1 : 0;
        if (col["URUNAKTIF"]) row.getCell(col["URUNAKTIF"]).value = 1;
        if (col["TEDARIKCI"]) row.getCell(col["TEDARIKCI"]).value = "RHNMUSIC";

        row.commit();
        rowIndex++;
    }

    // Kaydet
    await outputWb.xlsx.writeFile(OUTPUT_PATH);

    console.log("✅ Excel oluşturuldu: ticimax-changes.xlsx");
    console.log(`📍 Konum: ${OUTPUT_PATH}`);
    console.log(`📊 Toplam: ${changes.length} ürün`);
    console.log(`   - Stok değişimi: ${stockChanges}`);
    console.log(`   - Fiyat değişimi: ${priceChanges}`);

})().catch(err => {
    console.error("❌ Hata:", err.message);
    process.exit(1);
});
