const fs = require("fs");
const path = require("path");
const https = require("https");
const http = require("http");

const urls = {
    "../data/4c.xml":
        "https://www.4cmusic.com/TicimaxXml/1A79ED3A6927460E93C0FF7D34490D31/",
    "../data/macom.xml":
        "https://ikas-exporter-app.ikasapps.com/api/exports/759bc351-6d49-4796-af14-07fcbe9b1523/bbb0cdda-0d7a-4127-a0cf-f3e36823e269.xml?templateType=1&showCategoryPath=true&showTotalStockCount=true",
    "../data/maske.xml":
        "https://www.maskemuzik.com/TicimaxXmlV2/6DFAD0D36ED64FA29794EA44D5DD4D68/"
};

async function downloadFile(url, filePath) {
    return new Promise((resolve, reject) => {
        const protocol = url.startsWith("https") ? https : http;
        const fullPath = path.resolve(__dirname, filePath);
        const dir = path.dirname(fullPath);

        // Klasör yoksa oluştur
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        const file = fs.createWriteStream(fullPath);

        protocol.get(url, { timeout: 30000 }, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`HTTP ${response.statusCode}: ${url}`));
                return;
            }

            response.pipe(file);

            file.on("finish", () => {
                file.close();
                resolve();
            });
        }).on("error", (err) => {
            fs.unlink(fullPath, () => { }); // Hatalı dosyayı sil
            reject(err);
        });
    });
}

async function main() {
    try {
        for (const [file, url] of Object.entries(urls)) {
            console.log(`⬇️  İndiriliyor: ${file}`);
            await downloadFile(url, file);
            console.log(`✅ İndirildi: ${file}`);
        }
        console.log("\n✅ Tüm XML'ler başarıyla indirildi");
    } catch (error) {
        console.error(`❌ Hata: ${error.message}`);
        process.exit(1);
    }
}

main();