// src/server.cjs
// Ticimax API → Flutter Mobile App köprüsü
// Başlatmak için: node src/server.cjs

require("dotenv").config({ path: require("path").resolve(__dirname, "../.env") });

const express = require("express");
const fs      = require("fs");
const path    = require("path");

const api  = require("./lib/ticimax-api.cjs");
const PORT = process.env.SERVER_PORT ?? 3099;

const app = express();
app.use(express.json());

// Flutter'dan gelen isteklere CORS izni
app.use((req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    if (req.method === "OPTIONS") return res.sendStatus(200);
    next();
});

// Bağlantı log klasörü
const PAYLOADS_DIR = path.resolve(__dirname, "../data/connect-payloads");
if (!fs.existsSync(PAYLOADS_DIR)) fs.mkdirSync(PAYLOADS_DIR, { recursive: true });

// ── LOGGER ────────────────────────────────────────────────

function log(method, path, status) {
    const ts = new Date().toISOString();
    console.log(`[${ts}] ${method.padEnd(6)} ${path} → ${status}`);
}

// ── ROUTES: Siparişler ────────────────────────────────────

// GET /orders?sayfa=1&sayfaBasina=20&durum=0
app.get("/orders", async (req, res) => {
    try {
        const data = await api.getOrders(req.query);
        log("GET", "/orders", 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", "/orders", 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// GET /orders/:id
app.get("/orders/:id", async (req, res) => {
    try {
        const data = await api.getOrderDetail(req.params.id);
        log("GET", `/orders/${req.params.id}`, 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", `/orders/${req.params.id}`, 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── ROUTES: Ürünler ───────────────────────────────────────

// GET /products?sayfa=1&sayfaBasina=20
app.get("/products", async (req, res) => {
    try {
        const data = await api.getProducts(req.query);
        log("GET", "/products", 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", "/products", 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── ROUTES: Stok ─────────────────────────────────────────

// GET /stock/:sku
app.get("/stock/:sku", async (req, res) => {
    try {
        const data = await api.getStock(req.params.sku);
        log("GET", `/stock/${req.params.sku}`, 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", `/stock/${req.params.sku}`, 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// POST /stock/:sku  { miktar: 5 }
app.post("/stock/:sku", async (req, res) => {
    try {
        const { miktar } = req.body;
        const data = await api.updateStock(req.params.sku, miktar);
        log("POST", `/stock/${req.params.sku}`, 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("POST", `/stock/${req.params.sku}`, 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── ROUTES: Connect Webhook ───────────────────────────────

// POST /connect-webhook
// Ticimax Connect → bu endpoint'e payload gönderir → JSON olarak kaydeder
app.post("/connect-webhook", (req, res) => {
    const payload = req.body;
    const ts      = Date.now();
    const action  = String(payload?.action ?? payload?.eylem ?? "unknown")
                        .replace(/[^a-zA-Z0-9_-]/g, "_");
    const fname   = `${action}_${ts}.json`;
    const fpath   = path.join(PAYLOADS_DIR, fname);

    fs.writeFileSync(fpath, JSON.stringify(payload, null, 2), "utf8");
    log("POST", "/connect-webhook", 200);
    console.log(`   💾 Payload kaydedildi: ${fname}`);
    res.json({ ok: true, saved: fname });
});

// GET /connect-payloads  → kaydedilen payload listesi
app.get("/connect-payloads", (req, res) => {
    try {
        const files = fs.readdirSync(PAYLOADS_DIR)
            .filter(f => f.endsWith(".json"))
            .sort()
            .reverse()
            .slice(0, 100)
            .map(f => {
                const content = JSON.parse(
                    fs.readFileSync(path.join(PAYLOADS_DIR, f), "utf8")
                );
                return { file: f, payload: content };
            });
        log("GET", "/connect-payloads", 200);
        res.json({ ok: true, count: files.length, data: files });
    } catch (e) {
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── HEALTH ────────────────────────────────────────────────

app.get("/health", (req, res) => {
    res.json({ ok: true, ts: new Date().toISOString() });
});

// ── START ─────────────────────────────────────────────────

app.listen(PORT, () => {
    console.log("─────────────────────────────────────");
    console.log(`🚀 Ticimax API Server başladı: http://localhost:${PORT}`);
    console.log("─────────────────────────────────────");
    console.log(`📦 GET  /products`);
    console.log(`📦 GET  /orders`);
    console.log(`📦 GET  /stock/:sku`);
    console.log(`📦 POST /stock/:sku`);
    console.log(`🔗 POST /connect-webhook   ← Ticimax Connect endpoint`);
    console.log(`🔗 GET  /connect-payloads  ← Flutter payload görüntüleyici`);
    console.log("─────────────────────────────────────");
});
