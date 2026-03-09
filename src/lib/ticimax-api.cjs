// src/lib/ticimax-api.cjs
// Ticimax WS API wrapper — tüm istekler buradan geçer

const axios           = require("axios");
const { getHeaders, getBaseUrl } = require("./ticimax-auth.cjs");

const BASE = getBaseUrl("v3");

// ── Yardımcı ──────────────────────────────────────────────

async function get(path, params = {}) {
    const res = await axios.get(`${BASE}${path}`, {
        headers: getHeaders(),
        params,
    });
    return res.data;
}

async function post(path, body = {}) {
    const res = await axios.post(`${BASE}${path}`, body, {
        headers: getHeaders(),
    });
    return res.data;
}

// ── Siparişler ────────────────────────────────────────────

/**
 * Sipariş listesini çeker.
 * @param {object} opts - { baslangicTarih, bitisTarih, durum, sayfa, sayfaBasina }
 */
async function getOrders(opts = {}) {
    return get("/siparis/liste", {
        baslangicTarih: opts.baslangicTarih ?? "",
        bitisTarih:     opts.bitisTarih ?? "",
        durum:          opts.durum ?? "0",
        sayfa:          opts.sayfa ?? 1,
        sayfaBasina:    opts.sayfaBasina ?? 20,
    });
}

/**
 * Sipariş detayını çeker.
 * @param {number|string} siparisId
 */
async function getOrderDetail(siparisId) {
    return get("/siparis/detay", { siparisId });
}

// ── Ürünler ───────────────────────────────────────────────

/**
 * Ürün listesini çeker.
 * @param {object} opts - { sayfa, sayfaBasina, aktif }
 */
async function getProducts(opts = {}) {
    return get("/urun/liste", {
        sayfa:       opts.sayfa ?? 1,
        sayfaBasina: opts.sayfaBasina ?? 20,
        aktif:       opts.aktif ?? 1,
    });
}

/**
 * SKU'ya göre stok bilgisi çeker.
 * @param {string} sku
 */
async function getStock(sku) {
    return get("/urun/stok", { stokKodu: sku });
}

/**
 * Stok günceller.
 * @param {string} sku
 * @param {number} miktar
 */
async function updateStock(sku, miktar) {
    return post("/urun/stokguncelle", { stokKodu: sku, stokMiktari: miktar });
}

module.exports = {
    getOrders,
    getOrderDetail,
    getProducts,
    getStock,
    updateStock,
};
