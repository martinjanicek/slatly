#!/usr/bin/env node
/* eslint-disable */
/**
 * Slatly static site builder.
 *
 * Reads ./index.html as the EN template (data-i18n attributes mark
 * localizable nodes), reads ./i18n/<lang>.json for each language and
 * writes a fully pre-rendered HTML file per language:
 *
 *   /index.html        (EN, canonical, overwrites the template after render)
 *   /cs/index.html
 *   /de/index.html
 *   /fr/index.html
 *   /es/index.html
 *
 * Also regenerates sitemap.xml so the URL set stays in sync with this list.
 */

const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const SITE = 'https://slatly.punkhive.com';

const LANGS = [
    { code: 'en', locale: 'en_US', dir: '' },
    { code: 'cs', locale: 'cs_CZ', dir: 'cs' },
    { code: 'de', locale: 'de_DE', dir: 'de' },
    { code: 'fr', locale: 'fr_FR', dir: 'fr' },
    { code: 'es', locale: 'es_ES', dir: 'es' },
];

const TEMPLATE = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');

const dicts = Object.fromEntries(
    LANGS.map((l) => [l.code, JSON.parse(fs.readFileSync(path.join(ROOT, 'i18n', `${l.code}.json`), 'utf8'))])
);

function pageUrl(lang) {
    return lang.dir ? `${SITE}/${lang.dir}/` : `${SITE}/`;
}

function getByPath(obj, dotted) {
    return dotted.split('.').reduce((a, k) => (a && a[k] !== undefined ? a[k] : undefined), obj);
}

function htmlEscape(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function jsonEscape(str) {
    // Inside <script type="application/ld+json"> we must protect against
    // a literal "</script" in user-supplied text. None of our copy contains
    // that today, but it's cheap insurance.
    return JSON.stringify(str).replace(/<\//g, '<\\/').slice(1, -1);
}

/* Replace <html lang="…"> + every [data-i18n] element/meta with the
 * localized string. Title gets the same treatment via its <title> tag. */
function applyI18n(html, dict) {
    html = html.replace(/<html\s+lang="[^"]*"/, `<html lang="${dict.__lang}"`);

    // <title data-i18n="key">…</title>
    html = html.replace(/<title([^>]*\bdata-i18n="([^"]+)"[^>]*)>[\s\S]*?<\/title>/g, (m, attrs, key) => {
        const v = getByPath(dict, key);
        return v != null ? `<title${attrs}>${htmlEscape(v)}</title>` : m;
    });

    // <meta … data-i18n="key" …>  (rewrites content attribute)
    html = html.replace(/<meta([^>]*\bdata-i18n="([^"]+)"[^>]*)>/g, (m, attrs, key) => {
        const v = getByPath(dict, key);
        if (v == null) return m;
        const next = attrs.replace(/\scontent="[^"]*"/, ` content="${htmlEscape(v)}"`);
        return `<meta${next}>`;
    });

    // Any other element with data-i18n. Self-contained text content only
    // (no nested tags) — matches the site's actual usage.
    const TEXT_TAGS = ['p', 'span', 'h1', 'h2', 'h3', 'h4', 'small', 'button', 'a', 'summary', 'li'];
    const tagPattern = TEXT_TAGS.join('|');
    const re = new RegExp(`<(${tagPattern})([^>]*\\bdata-i18n="([^"]+)"[^>]*)>([\\s\\S]*?)<\\/\\1>`, 'g');
    html = html.replace(re, (m, tag, attrs, key, inner) => {
        const v = getByPath(dict, key);
        if (v == null) return m;
        // If inner contains nested elements (a child <span>, an <svg>, …)
        // we leave it alone — safer to lose translation than to mangle DOM.
        if (/[<>]/.test(inner)) return m;
        return `<${tag}${attrs}>${htmlEscape(v)}</${tag}>`;
    });

    return html;
}

/* Swap canonical + og:url + og:locale + og:locale:alternate set to match
 * the current language. */
function applyLocaleHead(html, lang) {
    const url = pageUrl(lang);

    html = html.replace(
        /<link rel="canonical" href="[^"]+">/,
        `<link rel="canonical" href="${url}">`
    );
    html = html.replace(
        /<meta property="og:url" content="[^"]+">/,
        `<meta property="og:url" content="${url}">`
    );
    html = html.replace(
        /<meta property="og:locale" content="[^"]+">/,
        `<meta property="og:locale" content="${lang.locale}">`
    );

    // Replace the entire og:locale:alternate block with the four other locales.
    const alternates = LANGS.filter((l) => l.code !== lang.code)
        .map((l) => `    <meta property="og:locale:alternate" content="${l.locale}">`)
        .join('\n');
    html = html.replace(
        /(?:\s*<meta property="og:locale:alternate" content="[^"]+">)+/,
        '\n' + alternates
    );

    return html;
}

/* Replace the JSON-LD block with a per-language version: WebSite.inLanguage,
 * FAQPage.mainEntity (questions/answers) and SoftwareApplication.description
 * all switch to the local copy. */
function applyJsonLd(html, lang) {
    const dict = dicts[lang.code];
    const url = pageUrl(lang);

    // Pick up every q1/a1 … qN/aN pair the dictionary provides, so adding
    // a question to the JSON files automatically lands in the JSON-LD FAQ.
    const faqMain = Object.keys(dict.faq)
        .filter((k) => /^q\d+$/.test(k))
        .sort((a, b) => Number(a.slice(1)) - Number(b.slice(1)))
        .map((qk) => {
            const ak = 'a' + qk.slice(1);
            return {
                '@type': 'Question',
                name: dict.faq[qk],
                acceptedAnswer: { '@type': 'Answer', text: dict.faq[ak] },
            };
        });

    const graph = [
        {
            '@type': 'MobileApplication',
            '@id': `${SITE}/#app`,
            name: 'Slatly',
            alternateName: 'Slatly for Apple Watch',
            applicationCategory: 'LifestyleApplication',
            applicationSubCategory: 'Home Automation',
            operatingSystem: 'watchOS 10, iOS 17',
            url: SITE + '/',
            downloadUrl: 'https://apps.apple.com/us/app/slatly/id6769497680',
            installUrl: 'https://apps.apple.com/us/app/slatly/id6769497680',
            description: dict.meta.description,
            image: `${SITE}/assets/app-icon-512.png`,
            screenshot: [`${SITE}/assets/watch-list.png`, `${SITE}/assets/watch-detail.png`],
            author: { '@type': 'Person', name: 'Martin Janíček', url: 'https://github.com/martinjanicek' },
            publisher: { '@id': `${SITE}/#person` },
            offers: {
                '@type': 'Offer',
                price: '0',
                priceCurrency: 'USD',
                availability: 'https://schema.org/InStock',
            },
            inLanguage: LANGS.map((l) => l.code),
            featureList: [
                dict.features.f1_body,
                dict.features.f2_body,
                dict.features.f3_body,
                dict.features.f4_body,
            ],
        },
        {
            '@type': 'WebSite',
            '@id': `${SITE}/#website`,
            name: 'Slatly',
            url: url,
            inLanguage: lang.code,
            publisher: { '@id': `${SITE}/#person` },
        },
        {
            '@type': 'WebPage',
            '@id': `${url}#webpage`,
            url: url,
            name: dict.meta.title,
            description: dict.meta.description,
            inLanguage: lang.code,
            isPartOf: { '@id': `${SITE}/#website` },
            primaryImageOfPage: `${SITE}/assets/og-image.png`,
        },
        {
            '@type': 'Person',
            '@id': `${SITE}/#person`,
            name: 'Martin Janíček',
            url: 'https://github.com/martinjanicek',
        },
        {
            '@type': 'FAQPage',
            '@id': `${url}#faq`,
            inLanguage: lang.code,
            mainEntity: faqMain,
        },
        {
            '@type': 'HowTo',
            '@id': `${url}#howto`,
            name: dict.how.title.replace(/\.$/, ''),
            description: dict.how.eyebrow,
            inLanguage: lang.code,
            totalTime: 'PT1M',
            step: [
                {
                    '@type': 'HowToStep',
                    position: 1,
                    name: dict.how.s1_title,
                    text: dict.how.s1_body,
                    url: `${url}#how`,
                },
                {
                    '@type': 'HowToStep',
                    position: 2,
                    name: dict.how.s2_title,
                    text: dict.how.s2_body,
                    url: `${url}#how`,
                },
                {
                    '@type': 'HowToStep',
                    position: 3,
                    name: dict.how.s3_title,
                    text: dict.how.s3_body,
                    url: `${url}#how`,
                },
            ],
        },
    ];

    const blob = JSON.stringify({ '@context': 'https://schema.org', '@graph': graph }, null, 2)
        .replace(/<\//g, '<\\/');

    return html.replace(
        /<script type="application\/ld\+json">[\s\S]*?<\/script>/,
        `<script type="application/ld+json">\n${blob}\n    </script>`
    );
}

function renderLang(lang) {
    const dict = { ...dicts[lang.code], __lang: lang.code };
    let html = TEMPLATE;
    html = applyI18n(html, dict);
    html = applyLocaleHead(html, lang);
    html = applyJsonLd(html, lang);
    return html;
}

function ensureDir(p) {
    if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true });
}

function writeSitemap() {
    const today = new Date().toISOString().slice(0, 10);
    const urls = LANGS.map((l) => {
        const loc = pageUrl(l);
        const alternates = LANGS.map(
            (a) => `    <xhtml:link rel="alternate" hreflang="${a.code}" href="${pageUrl(a)}"/>`
        ).join('\n');
        const xDefault = `    <xhtml:link rel="alternate" hreflang="x-default" href="${SITE}/"/>`;
        return (
            `  <url>\n` +
            `    <loc>${loc}</loc>\n` +
            `    <lastmod>${today}</lastmod>\n` +
            `    <changefreq>monthly</changefreq>\n` +
            `    <priority>${l.code === 'en' ? '1.0' : '0.9'}</priority>\n` +
            alternates +
            '\n' +
            xDefault +
            '\n' +
            `  </url>`
        );
    }).join('\n');

    const privacy =
        `  <url>\n` +
        `    <loc>${SITE}/privacy.html</loc>\n` +
        `    <lastmod>${today}</lastmod>\n` +
        `    <changefreq>yearly</changefreq>\n` +
        `    <priority>0.3</priority>\n` +
        `  </url>`;

    const xml =
        `<?xml version="1.0" encoding="UTF-8"?>\n` +
        `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n` +
        `        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n` +
        urls +
        '\n' +
        privacy +
        '\n' +
        `</urlset>\n`;

    fs.writeFileSync(path.join(ROOT, 'sitemap.xml'), xml);
}

function main() {
    // Render non-EN first so we don't corrupt the template before it's read.
    // (TEMPLATE is held in memory above, so order doesn't actually matter,
    // but writing EN last keeps the diff easy to read.)
    for (const lang of LANGS) {
        if (lang.code === 'en') continue;
        const out = path.join(ROOT, lang.dir);
        ensureDir(out);
        fs.writeFileSync(path.join(out, 'index.html'), renderLang(lang));
        process.stdout.write(`  ✓ ${lang.dir}/index.html\n`);
    }
    fs.writeFileSync(path.join(ROOT, 'index.html'), renderLang(LANGS[0]));
    process.stdout.write(`  ✓ index.html (EN, canonical)\n`);

    writeSitemap();
    process.stdout.write(`  ✓ sitemap.xml\n`);
}

main();
