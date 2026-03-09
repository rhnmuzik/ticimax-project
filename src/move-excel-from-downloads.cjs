// Downloads klasöründen en son indirilen Excel'i site_products.xlsx olarak taşı

const fs = require("fs");
const path = require("path");
const os = require("os");

const DOWNLOADS_DIR = path.join(os.homedir(), "Downloads");
const TARGET_PATH = path.join(__dirname, "../data/site_products.xlsx");

console.log("🔍 Downloads klasöründe Excel aranıyor...");

// Downloads'daki tüm .xls ve .xlsx dosyalarını bul
const files = fs.readdirSync(DOWNLOADS_DIR)
    .filter(f => f.endsWith(".xls") || f.endsWith(".xlsx"))
    .map(f => ({
        name: f,
        path: path.join(DOWNLOADS_DIR, f),
        time: fs.statSync(path.join(DOWNLOADS_DIR, f)).mtime.getTime()
    }))
    .sort((a, b) => b.time - a.time); // En yeni önce

if (files.length === 0) {
    console.error("❌ Downloads klasöründe Excel dosyası bulunamadı!");
    process.exit(1);
}

const latestFile = files[0];
console.log(`📄 Bulunan dosya: ${latestFile.name}`);

// Mevcut dosya varsa yedekle
if (fs.existsSync(TARGET_PATH)) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const backupPath = path.join(__dirname, `../data/backups/site_products_${timestamp}.xlsx`);

    const backupDir = path.dirname(backupPath);
    if (!fs.existsSync(backupDir)) {
        fs.mkdirSync(backupDir, { recursive: true });
    }

    fs.copyFileSync(TARGET_PATH, backupPath);
    console.log(`💾 Eski dosya yedeklendi: ${path.basename(backupPath)}`);
}

// Dosyayı kopyala
fs.copyFileSync(latestFile.path, TARGET_PATH);
console.log(`✅ Dosya kopyalandı: site_products.xlsx`);

// Orijinal dosyayı sil (isteğe bağlı)
// fs.unlinkSync(latestFile.path);
// console.log(`🗑️  Orijinal dosya silindi: ${latestFile.name}`);
