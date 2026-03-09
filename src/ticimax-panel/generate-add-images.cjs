const fs = require("fs");
const path = require("path");
const ExcelJS = require("exceljs");
const { XMLParser } = require("fast-xml-parser");
const Database = require("better-sqlite3");

// ---------------- PATH STANDARD ----------------

// inventory-core root
const ROOT = path.resolve(__dirname, "../../");

// data klasörü
const DATA_ROOT = path.join(ROOT, "data");

// ticimax-import klasörü
const IMPORT_PATH = path.join(DATA_ROOT, "ticimax-import");

const TEMPLATE_PATH = path.join(IMPORT_PATH, "add-images-template.xlsx");
const XML_PATH = path.join(DATA_ROOT, "4c.xml"); // XML data klasöründe
const SKU_PATH = path.join(IMPORT_PATH, "publish-skus.txt");
const OUTPUT_PATH = path.join(IMPORT_PATH, "add-images-output.xlsx");

// DB
const DB_PATH = path.join(DATA_ROOT, "core.db");
const db = new Database(DB_PATH);

// ---------------- HELPERS ----------------

const normalize = v => String(v || "").trim().toUpperCase();

(async () => {

    console.log("📸 Add Images Generator Başladı");
    console.log("📂 XML PATH:", XML_PATH);

    // SKU listesi
    const skuList = fs.readFileSync(SKU_PATH, "utf8")
        .split("\n")
        .map(s => normalize(s))
        .filter(Boolean);

    console.log("📦 İşlenecek SKU:", skuList.length);

    // XML parse
    const parser = new XMLParser({ ignoreAttributes: false });

    let xmlRaw = fs.readFileSync(XML_PATH, "utf8");
    xmlRaw = xmlRaw.replace(/\u0307/g, "");

    const xml = parser.parse(xmlRaw);

    const urunler = xml?.Root?.Urunler?.Urun || [];
    const urunArray = Array.isArray(urunler) ? urunler : [urunler];

    console.log("🔍 XML'de bulunan toplam ürün:", urunArray.length);

    // Template oku
    const templateWb = new ExcelJS.Workbook();
    await templateWb.xlsx.readFile(TEMPLATE_PATH);

    const templateSheet = templateWb.worksheets[0];

    const outputWb = new ExcelJS.Workbook();
    const outputSheet = outputWb.addWorksheet("Images");

    // Header kopyala
    const headerRow = templateSheet.getRow(1);
    headerRow.eachCell((cell, colNumber) => {
        outputSheet.getCell(1, colNumber).value = cell.value;
    });

    let rowIndex = 2;
    let writtenCount = 0;

    for (const urun of urunArray) {

        const secenekler = urun?.UrunSecenek?.Secenek;
        if (!secenekler) continue;

        const secenekArray = Array.isArray(secenekler)
            ? secenekler
            : [secenekler];

        for (const secenek of secenekArray) {

            const skuRaw = secenek.StokKodu;
            const sku = normalize(skuRaw);

            if (!skuList.includes(sku)) continue;

            // 🔥 DB’den ürün bilgisi çek
            const product = db
                .prepare(`
                    SELECT product_id, variant_id, barcode
                    FROM products
                    WHERE sku = ?
                      AND status = 'active'
                `)
                .get(skuRaw);

            if (!product) {
                console.log("❌ DB'de bulunamadı:", skuRaw);
                continue;
            }

            // XML’den resimler
            const rawImages = urun?.Resimler?.Resim;
            const images = rawImages
                ? Array.isArray(rawImages)
                    ? rawImages
                    : [rawImages]
                : [];

            images.forEach((url, index) => {

                const row = outputSheet.getRow(rowIndex);

                row.getCell(1).value = product.product_id || 0;   // URUNKARTIID
                row.getCell(2).value = product.variant_id || 0;  // URUNID
                row.getCell(3).value = product.barcode || "";    // BARKOD
                row.getCell(4).value = skuRaw;                   // STOKKODU
                row.getCell(5).value = url;                      // RESIMURL
                row.getCell(6).value = index + 1;                // SIRA

                row.commit();
                rowIndex++;
                writtenCount++;
            });
        }
    }

    await outputWb.xlsx.writeFile(OUTPUT_PATH);

    console.log("✅ Görsel import dosyası oluşturuldu:");
    console.log("📄", OUTPUT_PATH);
    console.log("🖼️ Yazılan satır:", writtenCount);

})();