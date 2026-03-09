const { execSync } = require("child_process");

const urls = {
    "../data/4c.xml":
        "https://www.4cmusic.com/TicimaxXml/1A79ED3A6927460E93C0FF7D34490D31/",
    "../data/macom.xml":
        "https://ikas-exporter-app.ikasapps.com/api/exports/759bc351-6d49-4796-af14-07fcbe9b1523/bbb0cdda-0d7a-4127-a0cf-f3e36823e269.xml?templateType=1&showCategoryPath=true&showTotalStockCount=true",
    "../data/maske.xml":
        "https://www.maskemuzik.com/TicimaxXmlV2/6DFAD0D36ED64FA29794EA44D5DD4D68/"
};

for (const file in urls) {
    console.log("⬇️", file);
    execSync(`curl -L -o ${file} "${urls[file]}"`, { stdio: "inherit" });
}

console.log("✅ Tüm XML'ler indirildi");