// Slatly site script. Texts are pre-rendered per language at build time,
// so this file only handles UI behaviour: the language switcher (which now
// navigates between localized URLs), a couple of scroll/animation effects
// and the time-of-day hero sky.

const SUPPORTED = ['en', 'cs', 'de', 'fr', 'es'];
const STORAGE_KEY = 'slatly.lang';

/* Returns the language of the *current* page, derived from its URL prefix.
 * The EN canonical lives at "/", everything else lives at "/<lang>/...". */
function currentLang() {
    const m = location.pathname.match(/^\/(cs|de|fr|es)(\/|$)/);
    return m ? m[1] : 'en';
}

function pathFor(lang) {
    // Preserve hash so a click on "FAQ" stays sticky after the switch.
    const hash = location.hash || '';
    return lang === 'en' ? '/' + hash : `/${lang}/${hash}`;
}

/* On first visit, if the browser locale matches one of our non-default
 * languages and the user is currently on the EN root, send them to the
 * localized variant. Persist the explicit choice so we never override it. */
function maybeAutoRedirect() {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) return; // user has already picked, never override
    const cur = currentLang();
    if (cur !== 'en') return; // already on a non-default page
    const nav = (navigator.language || 'en').slice(0, 2).toLowerCase();
    if (!SUPPORTED.includes(nav) || nav === 'en') return;
    // First visit, browser is non-English, we're on the EN root → redirect.
    location.replace(`/${nav}/${location.hash || ''}`);
}

function setupLangMenu() {
    const btn = document.getElementById('langBtn');
    const menu = document.getElementById('langMenu');
    const label = document.getElementById('langCurrent');
    if (!btn || !menu) return;

    if (label) label.textContent = currentLang().toUpperCase();

    btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const expanded = btn.getAttribute('aria-expanded') === 'true';
        btn.setAttribute('aria-expanded', String(!expanded));
        menu.hidden = expanded;
    });

    menu.querySelectorAll('button[data-lang]').forEach((b) => {
        b.addEventListener('click', () => {
            const lang = b.getAttribute('data-lang');
            if (!SUPPORTED.includes(lang)) return;
            localStorage.setItem(STORAGE_KEY, lang);
            if (lang === currentLang()) {
                menu.hidden = true;
                btn.setAttribute('aria-expanded', 'false');
                return;
            }
            location.href = pathFor(lang);
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
        const total = rect.height + vh;
        const raw = (vh - rect.top) / total;
        const p = Math.max(0, Math.min(1, raw));
        const offset = (p - 0.5) * 2 * amplitude;
        watchA.style.setProperty('--py-a', `${-offset}px`);
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

/* Time-of-day sky in the hero window:
 *   sunrise (5-7), day (7-17), sunset (17-20), night (else)
 * Sun rides a parabolic arc across the sky between 6:00 and 20:00; outside
 * those hours the sky switches to night and the sun is repainted as a moon
 * with twinkling stars. */
function setupTimeOfDay() {
    const sky = document.querySelector('.window-sky');
    if (!sky) return;

    const now = new Date();
    const t = now.getHours() + now.getMinutes() / 60;

    let preset;
    if (t >= 5 && t < 7) preset = 'sunrise';
    else if (t >= 7 && t < 17) preset = 'day';
    else if (t >= 17 && t < 20) preset = 'sunset';
    else preset = 'night';
    sky.classList.add('tod-' + preset);

    let sunX, sunY;
    if (t >= 6 && t <= 20) {
        const progress = (t - 6) / 14;
        sunX = 10 + progress * 80;
        sunY = 14 + Math.pow((progress - 0.5) * 2, 2) * 48;
    } else {
        sunX = 75;
        sunY = 22;
    }
    sky.style.setProperty('--sun-x', sunX + '%');
    sky.style.setProperty('--sun-y', sunY + '%');
}

/* Interactive Digital Crown: the user can drag the silver crown nub vertically
 * to control the blind tilt live, in both the big window AND the mini watch
 * UI. Releasing returns to the auto-animation after a short pause. */
function setupInteractiveCrown() {
    const scene = document.querySelector('.scene');
    const crown = document.querySelector('.hero-crown-nub');
    if (!scene || !crown) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    let dragging = false;
    let startY = 0;
    let startTilt = 50;
    let tilt = 50;
    let resumeTimer = 0;

    scene.style.setProperty('--tilt', tilt);

    const onDown = (e) => {
        dragging = true;
        startY = e.clientY;
        startTilt = tilt;
        scene.classList.add('interactive');
        clearTimeout(resumeTimer);
        try { crown.setPointerCapture(e.pointerId); } catch {}
        e.preventDefault();
    };
    const onMove = (e) => {
        if (!dragging) return;
        const dy = e.clientY - startY;
        tilt = Math.max(0, Math.min(100, startTilt + dy * 0.8));
        scene.style.setProperty('--tilt', tilt);
    };
    const onUp = (e) => {
        if (!dragging) return;
        dragging = false;
        try { crown.releasePointerCapture(e.pointerId); } catch {}
        clearTimeout(resumeTimer);
        resumeTimer = setTimeout(() => {
            scene.classList.remove('interactive');
        }, 2800);
    };

    crown.addEventListener('pointerdown', onDown);
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointercancel', onUp);
}

/* Smooth FAQ expand/collapse. */
function setupFAQAnimation() {
    document.querySelectorAll('.faq-list details').forEach((details) => {
        const summary = details.querySelector('summary');
        const body = details.querySelector('p');
        if (!summary || !body) return;

        const openBody = () => {
            body.style.height = body.scrollHeight + 'px';
            body.style.opacity = '1';
            body.style.marginTop = '12px';
            const onEnd = (e) => {
                if (e.propertyName !== 'height') return;
                body.style.height = 'auto';
                body.removeEventListener('transitionend', onEnd);
            };
            body.addEventListener('transitionend', onEnd);
        };
        const closeBody = () => {
            body.style.height = body.scrollHeight + 'px';
            requestAnimationFrame(() => {
                body.style.height = '0';
                body.style.opacity = '0';
                body.style.marginTop = '0';
            });
            const onEnd = (e) => {
                if (e.propertyName !== 'height') return;
                details.removeAttribute('open');
                body.removeEventListener('transitionend', onEnd);
            };
            body.addEventListener('transitionend', onEnd);
        };

        summary.addEventListener('click', (e) => {
            e.preventDefault();
            if (details.open) {
                closeBody();
            } else {
                details.setAttribute('open', '');
                requestAnimationFrame(openBody);
            }
        });
    });
}

/* Staggered reveal for the howto cards. */
function setupHowtoReveal() {
    const cards = document.querySelectorAll('.howto-steps li');
    if (!cards.length) return;
    cards.forEach((card, i) => card.style.setProperty('--i', String(i)));
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        cards.forEach((c) => c.classList.add('in-view'));
        return;
    }
    const obs = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add('in-view');
                obs.unobserve(entry.target);
            }
        });
    }, { threshold: 0.2, rootMargin: '0px 0px -10% 0px' });
    cards.forEach((c) => obs.observe(c));
}

/* Random howto illustration set: cartoon, LEGO or cat. */
function setupHowtoVariant() {
    const variants = ['', '-lego', '-cat'];
    const suffix = variants[Math.floor(Math.random() * variants.length)];
    document.querySelectorAll('.howto-img[data-step]').forEach((img) => {
        const step = img.getAttribute('data-step');
        img.setAttribute('src', '/assets/step' + step + suffix + '.png');
    });
}

document.addEventListener('DOMContentLoaded', () => {
    maybeAutoRedirect();
    setupLangMenu();
    setupShowcaseParallax();
    setupTimeOfDay();
    setupInteractiveCrown();
    setupHowtoVariant();
    setupHowtoReveal();
    setupFAQAnimation();
});
