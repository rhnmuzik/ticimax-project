// src/lib/ticimax-auth.cjs
// Ticimax WS API auth helper — .env'den YetkiKodu okur

require("dotenv").config({ path: require("path").resolve(__dirname, "../../.env") });

const STORE_URL = process.env.TICIMAX_STORE_URL?.replace(/\/$/, "");
const WS_KEY    = process.env.TICIMAX_WS_KEY;

if (!STORE_URL || !WS_KEY) {
    console.error("❌ .env dosyasında TICIMAX_STORE_URL veya TICIMAX_WS_KEY eksik!");
    console.error("   .env.example dosyasını kopyalayıp doldurun: cp .env.example .env");
    process.exit(1);
}

/**
 * Ticimax WS isteği için standart auth header'ları döner.
 * Her script bu fonksiyonu kullanarak token'ı elle girmekten kurtulur.
 */
function getHeaders() {
    return {
        "Content-Type":  "application/json",
        "YetkiKodu":     WS_KEY,
    };
}

/**
 * Ticimax WS API base URL'ini döner.
 * Örnek: https://magazan.ticimax.com/api/v3
 */
function getBaseUrl(version = "v3") {
    return `${STORE_URL}/api/${version}`;
}

module.exports = { getHeaders, getBaseUrl, STORE_URL, WS_KEY };
