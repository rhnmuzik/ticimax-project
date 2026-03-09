// src/inspect-payloads.cjs
/**
 * Ticimax Connect payload'larını analiz eder ve "Payload Haritası" çıkarır.
 * Yakalanan JSON'lardaki ortak ve farklı alanları raporlar.
 */

const fs = require("fs");
const path = require("path");

const PAYLOADS_DIR = path.resolve(__dirname, "../data/connect-payloads");

function inspect() {
    if (!fs.existsSync(PAYLOADS_DIR)) {
        console.log("❌ data/connect-payloads klasörü henüz oluşmamış.");
        console.log("👉 sunucuyu başlatın ve Ticimax Connect'ten bir tetikleme yapın.");
        return;
    }

    const files = fs.readdirSync(PAYLOADS_DIR).filter(f => f.endsWith(".json"));
    if (files.length === 0) {
        console.log("📭 Klasör boş, henüz payload yakalanmamış.");
        return;
    }

    console.log(`🔍 ${files.length} adet payload inceleniyor...\n`);

    const result = {};

    for (const f of files) {
        try {
            const content = JSON.parse(fs.readFileSync(path.join(PAYLOADS_DIR, f), "utf8"));
            const action = f.split('_')[0]; // Dosya adından eylem adını al

            if (!result[action]) {
                result[action] = {
                    count: 0,
                    structure: new Set()
                };
            }

            result[action].count++;
            
            // Alanları haritala
            Object.keys(content).forEach(k => result[action].structure.add(k));
        } catch (e) {
            console.error(`⚠️ ${f} okunamadı:`, e.message);
        }
    }

    console.log("📊 PAYLOAD HARITASI");
    console.log("─────────────────────────────────────");

    for (const [action, info] of Object.entries(result)) {
        console.log(`🔹 Eylem: ${action} (${info.count} örnek)`);
        console.log(`   Alanlar: ${Array.from(info.structure).join(", ")}`);
        console.log("─────────────────────────────────────");
    }

    console.log("\n💡 Bu haritayı Flutter modellerini güncellemek için kullanabilirsiniz.");
}

inspect();
