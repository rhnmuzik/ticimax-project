// Test script - XML'de olup DB'de olmayan ürünleri bul

const Database = require("better-sqlite3");
const { XMLParser } = require("fast-xml-parser");
const fs = require("fs");
const path = require("path");

const DB_PATH = path.join(__dirname, "../data/core.db");
const db = new Database(DB_PATH);

const newProducts = [];
const parser = new XMLParser({ ignoreAttributes: false });

// 4c ve maske (Ticimax formatı)
const ticimaxFiles = [
    { name: '4c', path: path.join(__dirname, "../data/4c.xml") },
    { name: 'maske', path: path.join(__dirname, "../data/maske.xml") },
];

for (const xmlFile of ticimaxFiles) {
    if (!fs.existsSync(xmlFile.path)) {
        console.log(`⚠️  ${xmlFile.name}.xml bulunamadı`);
        continue;
    }

    console.log(`📄 ${xmlFile.name}.xml okunuyor...`);
    const xmlContent = fs.readFileSync(xmlFile.path, 'utf8');
    const xml = parser.parse(xmlContent);
    const urunler = xml?.Root?.Urunler?.Urun || [];
    const urunArray = Array.isArray(urunler) ? urunler : [urunler];

    console.log(`   Toplam ürün: ${urunArray.length}`);

    for (const urun of urunArray) {
        const secenekler = urun?.UrunSecenek?.Secenek;
        if (!secenekler) continue;

        const secenekArray = Array.isArray(secenekler) ? secenekler : [secenekler];

        for (const secenek of secenekArray) {
            const sku = String(secenek.StokKodu || '').trim().toUpperCase();
            if (!sku) continue;

            const exists = db.prepare(`
                SELECT 1 FROM products WHERE sku = ? LIMIT 1
            `).get(sku);

            if (!exists) {
                newProducts.push({
                    supplier: xmlFile.name,
                    sku: secenek.StokKodu,
                    name: urun.UrunAdi,
                    category: urun.KategoriTree || urun.Kategori,
                    price: secenek.SatisFiyati,
                    stock: secenek.StokAdedi || 0,
                    currency: secenek.ParaBirimiKodu || secenek.ParaBirimi,
                });
            }
        }
    }
}

// macom (ikas formatı)
const macomPath = path.join(__dirname, "../data/macom.xml");
if (fs.existsSync(macomPath)) {
    console.log(`📄 macom.xml okunuyor...`);
    const xmlContent = fs.readFileSync(macomPath, 'utf8');
    const xml = parser.parse(xmlContent);
    const products = xml?.products?.product || [];
    const productArray = Array.isArray(products) ? products : [products];

    console.log(`   Toplam ürün: ${productArray.length}`);

    for (const product of productArray) {
        const variants = product?.variants?.variant || [];
        const variantArray = Array.isArray(variants) ? variants : [variants];

        for (const variant of variantArray) {
            const sku = String(variant.sku || '').trim().toUpperCase();
            if (!sku) continue;

            const exists = db.prepare(`
                SELECT 1 FROM products WHERE sku = ? LIMIT 1
            `).get(sku);

            if (!exists) {
                const pricesObj = variant?.prices?.price;
                const price = pricesObj?.sellPrice || pricesObj?.buyPrice || 0;
                const currency = pricesObj?.currency || 'TRY';

                const stocksObj = variant?.stocks?.stock;
                const stock = stocksObj?.stockCount || 0;

                newProducts.push({
                    supplier: 'macom',
                    sku: variant.sku,
                    name: product.name,
                    category: product.tags?.tag?.name || '',
                    price: price,
                    stock: stock,
                    currency: currency,
                });
            }
        }
    }
}

db.close();

console.log("\n📊 Sonuç:");
console.log(`   Toplam yeni ürün: ${newProducts.length}`);

// Tedarikçilere göre grupla
const bySupplier = {};
newProducts.forEach(p => {
    if (!bySupplier[p.supplier]) bySupplier[p.supplier] = 0;
    bySupplier[p.supplier]++;
});

console.log("\n📦 Tedarikçilere göre:");
Object.entries(bySupplier).forEach(([supplier, count]) => {
    console.log(`   ${supplier}: ${count} ürün`);
});

// İlk 5 ürünü göster
if (newProducts.length > 0) {
    console.log("\n🔍 İlk 5 ürün:");
    newProducts.slice(0, 5).forEach(p => {
        console.log(`   ${p.sku} - ${p.name.substring(0, 50)}... (${p.supplier})`);
    });
}
