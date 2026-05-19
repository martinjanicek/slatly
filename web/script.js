// Lightweight i18n + language switcher. Loads ./i18n/<lang>.json on demand,
// rewrites every element with [data-i18n="path.to.key"] to the matching value.
// Persists the chosen language in localStorage; defaults to the browser locale
// if it matches one of the supported ones, otherwise English.

const SUPPORTED = ['en', 'cs', 'de', 'fr', 'es'];
const STORAGE_KEY = 'zaluzky.lang';

const cache = {};

function detectInitial() {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && SUPPORTED.includes(stored)) return stored;
    const nav = (navigator.language || 'en').slice(0, 2).toLowerCase();
    if (SUPPORTED.includes(nav)) return nav;
    return 'en';
}

async function load(lang) {
    if (cache[lang]) return cache[lang];
    const res = await fetch(`i18n/${lang}.json`);
    if (!res.ok) throw new Error(`Missing translation for ${lang}`);
    const json = await res.json();
    cache[lang] = json;
    return json;
}

function getByPath(obj, path) {
    return path.split('.').reduce((acc, key) => (acc && acc[key] !== undefined ? acc[key] : undefined), obj);
}

async function apply(lang) {
    const dict = await load(lang);
    document.documentElement.lang = lang;
    document.querySelectorAll('[data-i18n]').forEach((el) => {
        const key = el.getAttribute('data-i18n');
        const value = getByPath(dict, key);
        if (typeof value !== 'string') return;
        if (el.tagName === 'META') {
            el.setAttribute('content', value);
        } else if (el.tagName === 'TITLE') {
            document.title = value;
        } else {
            el.textContent = value;
        }
    });
    // Swap localized image sources (used by the howto device screenshots).
    document.querySelectorAll('[data-localized-src]').forEach((el) => {
        const pattern = el.getAttribute('data-localized-src');
        if (!pattern) return;
        el.setAttribute('src', pattern.replace('{lang}', lang));
    });
    const currentLabel = document.getElementById('langCurrent');
    if (currentLabel) currentLabel.textContent = lang.toUpperCase();
    localStorage.setItem(STORAGE_KEY, lang);
}

function setupLangMenu() {
    const btn = document.getElementById('langBtn');
    const menu = document.getElementById('langMenu');
    if (!btn || !menu) return;

    btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const expanded = btn.getAttribute('aria-expanded') === 'true';
        btn.setAttribute('aria-expanded', String(!expanded));
        menu.hidden = expanded;
    });

    menu.querySelectorAll('button[data-lang]').forEach((b) => {
        b.addEventListener('click', () => {
            const lang = b.getAttribute('data-lang');
            apply(lang).catch(console.error);
            menu.hidden = true;
            btn.setAttribute('aria-expanded', 'false');
        });
    });

    document.addEventListener('click', (e) => {
        if (!menu.hidden && !menu.contains(e.target) && e.target !== btn) {
            menu.hidden = true;
            btn.setAttribute('aria-expanded', 'false');
        }
    });
}

/* Showcase parallax — the two watches drift in opposite directions as the
 * section passes through the viewport. Decent: total amplitude ±25px each. */
function setupShowcaseParallax() {
    const section = document.querySelector('.showcase');
    const watchA = document.querySelector('.showcase-art .watch-a');
    const watchB = document.querySelector('.showcase-art .watch-b');
    if (!section || !watchA || !watchB) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    const amplitude = 25;
    let ticking = false;
    const update = () => {
        const rect = section.getBoundingClientRect();
        const vh = window.innerHeight || document.documentElement.clientHeight;
        // progress goes 0→1 as the section travels from below the viewport
        // bottom up past the viewport top.
        const total = rect.height + vh;
        const raw = (vh - rect.top) / total;
        const p = Math.max(0, Math.min(1, raw));
        const offset = (p - 0.5) * 2 * amplitude; // -amp → +amp
        // Watch A: drifts top→bottom (starts above, ends below).
        watchA.style.setProperty('--py-a', `${-offset}px`);
        // Watch B: drifts bottom→top (opposite direction).
        watchB.style.setProperty('--py-b', `${offset}px`);
        ticking = false;
    };
    const onScroll = () => {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(update);
    };
    update();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll, { passive: true });
}

document.addEventListener('DOMContentLoaded', () => {
    setupLangMenu();
    apply(detectInitial()).catch(console.error);
    setupShowcaseParallax();
});
