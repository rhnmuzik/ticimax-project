const Database = require("better-sqlite3");
const ExcelJS = require("exceljs");
const path = require("path");

const DB_PATH = path.join(__dirname, "../data/core.db");
const EXCEL_PATH = path.join(__dirname, "../data/site_products.xlsx");

const db = new Database(DB_PATH);

// ---------------- HELPERS ----------------

const normalizeSku = v =>
    String(v || "").trim().toUpperCase();

const normalizeVariantId = v =>
    String(v || "").trim();

const normalizeNumber = v => {
    if (v === null || v === undefined || v === "") return null;
    if (typeof v === "number") return v;

    const cleaned = String(v).replace(",", ".");
    const n = Number(cleaned);
    return isNaN(n) ? null : n;
};

const normalizeBoolean = v => {
    if (v === true || v === 1) return 1;
    if (v === false || v === 0) return 0;

    const s = String(v || "").toLowerCase().trim();
    if (s === "true" || s === "1") return 1;
    if (s === "false" || s === "0") return 0;

    return 0;
};

const normalizeBarcode = v => {
    if (!v) return null;

    // ExcelJS rich text durumu
    if (typeof v === "object" && v.text) {
        return String(v.text).trim();
    }

    if (typeof v === "number") {
        return v.toString();
    }

    const s = String(v).trim();
    return s.replace(/\.0$/, "");
};

const normalizeMarketplaceStatus = v => {
    if (!v) return null;

    const s = String(v || "").toLowerCase().trim();

    // "null" string'ini null'a çevir
    if (s === "null" || s === "") return null;

    // Marketplace adlarını normalize et
    if (s.includes("hb") || s.includes("hepsiburada")) return "hb";
    if (s.includes("n11")) return "n11";
    if (s.includes("trendyol")) return "trendyol";
    if (s.includes("4c")) return "4c";
    if (s.includes("macom")) return "macom";
    if (s.includes("maske")) return "maske";

    return s || null;
};

// ---------------- UPSERT ----------------

const upsert = db.prepare(`
  INSERT INTO products (
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
    source,
    status
  )
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 'active')

  ON CONFLICT(variant_id) DO UPDATE SET
    sku           = excluded.sku,
    product_id    = excluded.product_id,
    product_name  = excluded.product_name,
    brand         = excluded.brand,
    stock         = excluded.stock,
    buy_price     = excluded.buy_price,
    sale_price    = excluded.sale_price,
    currency      = excluded.currency,
    vat_rate      = excluded.vat_rate,
    vat_included  = excluded.vat_included,
    barcode       = excluded.barcode,
    status        = 'active',
    updated_at    = CURRENT_TIMESTAMP
`);

const setStatus = db.prepare(`
  UPDATE products
  SET status = ?,
      updated_at = CURRENT_TIMESTAMP
  WHERE variant_id = ?
`);

// ---------------- MAIN ----------------

(async () => {

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(EXCEL_PATH);

    const sheet = workbook.worksheets[0];
    const header = sheet.getRow(1);

    const col = {};
    header.eachCell((cell, i) => {
        col[cell.value] = i;
    });

    const excelVariantIds = new Set();
    let processedCount = 0;
    let nullMarketplaceCount = 0;

    const transaction = db.transaction(() => {

        // 1️⃣ Excel'i oku ve upsert et
        sheet.eachRow((row, rowNo) => {
            if (rowNo === 1) return;

            const variantId = normalizeVariantId(
                row.getCell(col["URUNID"]).value
            );

            if (!variantId) return;

            const sku = normalizeSku(
                row.getCell(col["STOKKODU"]).value
            );

            const barcode = normalizeBarcode(
                row.getCell(col["BARKOD"]).value
            );

            const marketplaceStatus = normalizeMarketplaceStatus(
                row.getCell(col["PAZARYERIAKTIFLISTESI"]).value
            );

            excelVariantIds.add(variantId);
            processedCount++;

            if (!marketplaceStatus) {
                nullMarketplaceCount++;
            }

            upsert.run(
                sku,
                variantId,
                row.getCell(col["URUNKARTIID"]).value || null,
                row.getCell(col["URUNADI"]).value || null,
                row.getCell(col["MARKA"]).value || null,
                normalizeNumber(row.getCell(col["STOKADEDI"]).value) ?? 0,
                normalizeNumber(row.getCell(col["ALISFIYATI"]).value),
                normalizeNumber(row.getCell(col["SATISFIYATI"]).value),
                row.getCell(col["PARABIRIMI"]).value || null,
                normalizeNumber(row.getCell(col["KDVORANI"]).value),
                normalizeBoolean(row.getCell(col["KDVDAHIL"]).value),
                barcode
            );
        });

        // 2️⃣ DB'deki tüm ürünleri kontrol et
        const dbRows = db.prepare(`
      SELECT variant_id FROM products
    `).all();

        for (const r of dbRows) {
            const dbVariant = normalizeVariantId(r.variant_id);

            if (excelVariantIds.has(dbVariant)) {
                setStatus.run('active', dbVariant);
            } else {
                setStatus.run('removed', dbVariant);
            }
        }

    });

    transaction();

    console.log("────────────────────────");
    console.log("✅ Excel senkron tamamlandı");
    console.log(`📊 İşlenen ürün: ${processedCount}`);
    console.log(`⚠️  Null marketplace: ${nullMarketplaceCount}`);
    console.log("🔄 Status alanı otomatik düzeltildi");
})();
