// Ticimax'ten Excel'i direkt indir ve site_products.xlsx olarak kaydet

const https = require("https");
const fs = require("fs");
const path = require("path");

require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

const STORE_URL = process.env.TICIMAX_STORE_URL;
const UYE_KODU = process.env.TICIMAX_UYE_KODU;

if (!STORE_URL || !UYE_KODU) {
    console.error("❌ .env dosyasında TICIMAX_STORE_URL veya TICIMAX_UYE_KODU eksik!");
    process.exit(1);
}

// Ticimax Excel export URL'i (gerçek URL'i öğrenmemiz gerekiyor)
const EXCEL_URL = `${STORE_URL}/Admin/UrunYonetimi.aspx?export=excel&uyeKodu=${UYE_KODU}`;
const OUTPUT_PATH = path.join(__dirname, "../data/site_products.xlsx");

console.log("📥 Ticimax'ten Excel indiriliyor...");
console.log(`   URL: ${EXCEL_URL}`);

const file = fs.createWriteStream(OUTPUT_PATH);

https.get(EXCEL_URL, (response) => {
    if (response.statusCode !== 200) {
        console.error(`❌ HTTP ${response.statusCode}: ${EXCEL_URL}`);
        process.exit(1);
    }

    response.pipe(file);

    file.on("finish", () => {
        file.close();
        console.log("✅ Excel başarıyla indirildi: site_products.xlsx");
    });
}).on("error", (err) => {
    fs.unlink(OUTPUT_PATH, () => { });
    console.error(`❌ İndirme hatası: ${err.message}`);
    process.exit(1);
});
