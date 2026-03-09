const fs = require("fs");
const path = require("path");
const ExcelJS = require("exceljs");
const { XMLParser } = require("fast-xml-parser");

// PATHS
const BASE_PATH = path.join(__dirname, "../../data");

const TEMPLATE_PATH = path.join(BASE_PATH, "ticimax-import/ticimax-template.xlsx");
const XML_PATH = path.join(BASE_PATH, "4c.xml");
const SKU_PATH = path.join(BASE_PATH, "ticimax-import/publish-skus.txt");
const OUTPUT_PATH = path.join(BASE_PATH, "ticimax-import/ticimax-import.xlsx");

// ---------------- HELPERS ----------------

const normalize = v => String(v || "").trim().toUpperCase();

// 🔥 Marka mapping
const mapBrand = (brand) => {
    const b = String(brand || "").trim().toUpperCase();

    if (b === "VALENCIA2") return "Valencia";
    if (b === "CORT ENDONEZYA") return "Cort";

    return brand;
};

// 🔥 Ürün Adı Formatlayıcı (SKU korumalı)
const formatProductName = (name, skuRaw) => {

    const smallWords = ["ve", "ile", "için", "veya", "ya", "da", "de", "&"];

    let formatted = String(name || "")
        .replace(/İ/g, "I")
        .replace(/İ/g, "I")
        .replace(/\u0307/g, "")
        .toLowerCase()
        .split(" ")
        .map((word, index) => {

            if (!word) return word;

            let prefix = "";
            let suffix = "";

            if (word.startsWith("(")) {
                prefix = "(";
                word = word.slice(1);
            }

            if (word.endsWith(")")) {
                suffix = ")";
                word = word.slice(0, -1);
            }

            const parts = word.split("-").map(part => {

                if (!part) return part;

                if (index !== 0 && smallWords.includes(part)) {
                    return part;
                }

                return part.charAt(0).toUpperCase() + part.slice(1);
            });

            return prefix + parts.join("-") + suffix;
        })
        .join(" ")
        .replace(/,/g, "")
        .replace(/\s+/g, " ")
        .trim();

    if (skuRaw) {
        const escaped = skuRaw.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const regex = new RegExp(escaped, "i");
        formatted = formatted.replace(regex, skuRaw);
    }

    return formatted;
};

// ---------------- BARKOD ----------------

let barcodeCounter = 1;

const generateRhnBarcode = () => {
    const today = new Date();

    const yy = String(today.getFullYear()).slice(-2);
    const mm = String(today.getMonth() + 1).padStart(2, "0");
    const dd = String(today.getDate()).padStart(2, "0");

    const prefix = `RHN${yy}${mm}${dd}`;
    const barcode = prefix + String(barcodeCounter).padStart(4, "0");

    barcodeCounter++;
    return barcode;
};

// ---------------- MAIN ----------------

(async () => {

    console.log("🚀 Ticimax Import Generator Başladı");

    const skuListRaw = fs.readFileSync(SKU_PATH, "utf8")
        .split("\n")
        .map(s => s.trim())
        .filter(Boolean);

    const skuList = skuListRaw.map(normalize);

    console.log("📦 Publish edilecek SKU:", skuList.length);

    const parser = new XMLParser({ ignoreAttributes: false });

    let xmlRaw = fs.readFileSync(XML_PATH, "utf8");
    xmlRaw = xmlRaw.replace(/\u0307/g, "");

    const xml = parser.parse(xmlRaw);

    const urunler = xml?.Root?.Urunler?.Urun || [];
    const urunArray = Array.isArray(urunler) ? urunler : [urunler];

    console.log("🔍 XML'de bulunan toplam ürün:", urunArray.length);

    const templateWb = new ExcelJS.Workbook();
    await templateWb.xlsx.readFile(TEMPLATE_PATH);

    const templateSheet = templateWb.worksheets[0];

    const outputWb = new ExcelJS.Workbook();
    const outputSheet = outputWb.addWorksheet("Import");

    const headerRow = templateSheet.getRow(1);

    const col = {};
    headerRow.eachCell((cell, colNumber) => {
        outputSheet.getCell(1, colNumber).value = cell.value;
        col[String(cell.value).trim().toUpperCase()] = colNumber;
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

            const row = outputSheet.getRow(rowIndex);

            const productName = formatProductName(urun.UrunAdi, skuRaw);

            row.getCell(col["URUNID"]).value = 0;
            row.getCell(col["URUNKARTIID"]).value = 0;
            row.getCell(col["STOKKODU"]).value = skuRaw;
            row.getCell(col["VARYASYONKODU"]).value = skuRaw;
            row.getCell(col["BARKOD"]).value = generateRhnBarcode();
            row.getCell(col["URUNADI"]).value = productName;

            if (col["ONYAZI"]) {
                row.getCell(col["ONYAZI"]).value = productName;
            }

            // 🔥 Tedarikçi sabit
            if (col["TEDARIKCI"]) {
                row.getCell(col["TEDARIKCI"]).value = "RHNMUSIC";
            }

            row.getCell(col["ACIKLAMA"]).value = urun.Aciklama || "";
            row.getCell(col["MARKA"]).value = mapBrand(urun.Marka);
            row.getCell(col["KATEGORILER"]).value = urun.KategoriTree || "";
            row.getCell(col["STOKADEDI"]).value = secenek.StokAdedi || 0;
            row.getCell(col["SATISFIYATI"]).value = secenek.SatisFiyati;
            row.getCell(col["KDVORANI"]).value = 20;
            row.getCell(col["KDVDAHIL"]).value = 1;
            row.getCell(col["PARABIRIMI"]).value = secenek.ParaBirimiKodu || secenek.ParaBirimi;
            row.getCell(col["URUNAKTIF"]).value = 0;

            row.commit();
            rowIndex++;
            writtenCount++;
        }
    }

    await outputWb.xlsx.writeFile(OUTPUT_PATH);

    console.log("✅ Import dosyası oluşturuldu:");
    console.log("📄", OUTPUT_PATH);
    console.log("📝 Yazılan ürün sayısı:", writtenCount);

})();