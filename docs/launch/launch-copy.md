# Slatly launch copy

Drafty napříč všemi kanály. Každý má vlastní tón — ne kopírovat doslova mezi nimi, Google odhalí duplicate content a komunity ti vyčtou „spam every platform" syndrom.

**Best timing (US/EU mix):**
- **Hacker News:** úterý-čtvrtek, **15:00–18:00 ČAS** (= 09:00–12:00 ET, ráno pro US/Kanadu)
- **Product Hunt:** úterý-čtvrtek, **09:00 ČAS** (= 00:01 PT spuštění)
- **Reddit:** úterý-čtvrtek, **15:00–18:00 ČAS**
- **LinkedIn:** úterý 10:00 ČAS

Doporučená sekvence (rozprostřeno na ~2 týdny — nestřílet vše naráz):
1. **Den 1, út-čt:** Show HN _(nejvyšší tech ROI, pokud propadne, zbytek to ovlivní málo)_
2. **Den 1+5h:** r/AppleWatch (pokud Show HN pomalý) _nebo_ Day 2 (pokud HN dobrý → soustřeď se na komentáře)
3. **Den 2:** Home Assistant Community
4. **Den 3:** r/homeautomation
5. **Den 4:** Indie Hackers
6. **Den 5:** awesome-apple-watch PR
7. **Den 7-10:** Product Hunt (vyžaduje schedule + hunter)
8. **Den 10+:** forum.somfy.fr _(opatrně, brand-aware comment, ne marketing pitch)_

---

## 1. Show HN _(Hacker News)_

**Title** (max ~80 chars):
```
Show HN: Slatly – Apple Watch app that controls Somfy blinds standalone
```

**URL field:** `https://slatly.punkhive.com/`

**Text** (Hacker News doporučuje nechat URL prázdné a popisovat v textu, ale lepší je URL field + komentář pod thread. Pokud chceš text post: pod 1000 znaků):

První komentář pod vlastní post _(post first comment immediately after submit):_

```
Hey HN — author here.

Slatly is a watchOS + iOS app that drives Somfy ExteriorVenetianBlind
devices (the motorised exterior venetian blinds with tiltable slats,
typical of European single-family homes) directly from the Apple Watch.

The interesting part: the Watch app is fully standalone after a one-time
iPhone sign-in. It contains a complete OAuth + REST client against the
Overkiz cloud and talks to Somfy directly over LTE / Wi-Fi. No iPhone
proxy. No HomeKit bridge. No local hub. Just the watch and the cloud.

Why: I have these blinds at home and the official Somfy Watch app
doesn't exist for this device class. HomeKit scenes work but only
through the iPhone. I wanted to literally tap the watch and have
the blinds tilt while I'm walking around the house with no phone.

How: Digital Crown maps 1:1 to Somfy's "orientation" parameter
(0–100, slat tilt). Vertical drag on the blind graphic maps to
"closure" (0–100, how far the blind travels). Both commit in one
setClosureAndOrientation call = one motor cycle, not two.

Credentials live in iCloud Keychain (kSecAttrSynchronizable=true),
so they sync watch ↔ phone with no extra entitlement. Scenes are
multi-blind presets edited on iPhone, runnable from the watch with
WatchConnectivity for instant push.

Stack: Swift 6, xcodegen, SwiftUI on both targets. URLProtocol-mocked
Swift Testing suite for the Overkiz wrapper. Watch is the actual
product; the iOS host is mostly a wrapper because Apple's 2025-26
tooling refuses watchOS-only App Store submissions.

Code (MIT) including the OverkizKit SwiftPM library:
https://github.com/martinjanicek/slatly

App Store (free, $0.99 in some markets):
https://apps.apple.com/us/app/slatly/id6769497680

Happy to dig into Watch standalone networking, Keychain sync,
or the Overkiz API specifically.
```

**Po submitu:**
- **Stay glued to the thread for 4-6 hours.** Reply to every comment within ~30 minutes. HN ranking algorithm vidí response time jako engagement signal.
- Ne defenzivní tón. Tech otázky jsou často skutečně tech.
- Ne self-upvote, ne friends. HN to detekuje a banuje.

---

## 2. r/AppleWatch _(3M subscribers)_

Subreddit má **strict self-promo rules** (typicky 9:1 ratio = na 1 promo post musíš mít 9 non-promo participations). Pokud nejsi aktivní v komunitě, podání bude pravděpodobně smazáno automatem.

**Bezpečnější verze:** ne „launch" post, ale **„I built this thing because Apple Watch deserves better blind controls"** — soft, story-driven, ne čistá reklama.

**Title:**
```
I built Slatly: my Apple Watch finally controls my Somfy blinds without the iPhone nearby
```

**Body:**
```
After 2 years of "open Home app → wait for iPhone → tap scene → wait"
I wrote my own standalone watchOS app. The whole reason for an Apple
Watch in the first place is to leave the phone, so why was I still
chained to it for the simplest house control?

It's called Slatly. Digital Crown rotates the slat tilt (0–90°),
vertical drag sets exact closure (0–100%). Both commit as a single
motor cycle. No iPhone proxy. No HomeKit bridge. Just OAuth tokens
synced via iCloud Keychain, then the watch talks to Somfy's cloud
directly over LTE/Wi-Fi.

If you have Somfy exterior venetian blinds on a Connexoon, TaHoma
or Cozytouch box: https://slatly.punkhive.com/
Free, open source (MIT), available in EN/CS/DE/FR/ES.

(Mods: I'm the author. Code: github.com/martinjanicek/slatly,
no analytics, no servers, no tracking.)
```

**Po submitu:** vraťme se za 30 minut, koukni jestli mod nezatáhl. Pokud ano, napiš mod messsage „first-time poster, open source, no monetisation" — někdy přepustí.

---

## 3. r/homeautomation _(1M subscribers)_

Tady je publikum dospělejší a tolerantnější k makers. Předpokládá, že znají Somfy, HomeKit, Home Assistant.

**Title:**
```
Made a free Apple Watch app for Somfy ExteriorVenetianBlind that works without the phone
```

**Body:**
```
TL;DR: standalone watchOS app for Somfy/TaHoma/Connexoon/Cozytouch
exterior venetian blinds. Open source MIT. Uses the official Overkiz
cloud API the same way Home Assistant's Overkiz integration does.

Why: Apple's Home app on the Watch needs the iPhone for every command
(WatchConnectivity proxy). Slatly replaces that with a full OAuth +
REST client running on watchOS itself, so the Watch app actually works
when the iPhone is downstairs / off / out of Bluetooth range.

Architecture:
  - watchOS app → Apple Watch
  - Credentials: iCloud Keychain (kSecAttrSynchronizable)
  - Network: direct LTE/Wi-Fi → Somfy OAuth → Overkiz REST API
  - Scenes: iCloud Keychain mirror + WatchConnectivity push for
    instant cross-device sync between phone and watch
  - Per-device overrides (custom name, slat color, "My" position):
    local UserDefaults

Limitations:
  - Currently only ExteriorVenetianBlind. RollerShutter is plausible
    future scope.
  - Apple Watch needs LTE or Wi-Fi reach (Bluetooth-only watch =
    needs iPhone nearby, same as any other watchOS app).

Code (Swift 6 + SwiftPM library wrapping the Overkiz OAuth flow):
https://github.com/martinjanicek/slatly

App Store: https://apps.apple.com/us/app/slatly/id6769497680
```

---

## 4. Home Assistant Community Forum

**Kategorie:** Third party integrations → tag „somfy", „overkiz", „apple-watch"

**Title:**
```
Standalone watchOS app for Somfy blinds (Overkiz API) — could be useful alongside HA
```

**Body:**
```
Hi all,

I'm the author of OverkizKit, a small Swift library that wraps the
Somfy / Overkiz OAuth + exec/apply flow. It powers Slatly, my Apple
Watch app for Somfy ExteriorVenetianBlind devices.

Sharing here because the HA Overkiz integration solves the "from a
browser / dashboard" side of the same problem, and Slatly solves the
"from the wrist when I left my phone in the kitchen" side. Both use
the same upstream API.

The Swift library is MIT and may interest anyone building Apple
ecosystem clients for Overkiz devices (not just blinds — Overkiz
supports 6000+ devices from 60 brands).

Slatly itself: https://slatly.punkhive.com/
Library code: https://github.com/martinjanicek/slatly

Happy to compare notes on Overkiz quirks I hit
(token refresh timing, exec endpoint quirks, regional shard routing).
```

---

## 5. Indie Hackers

Indie Hackers preferuje **story-driven** post se zaměřením na journey, ne na product spec.

**Title:**
```
After 6 months I shipped a free open source Apple Watch app for my smart blinds — here's the build journey
```

**Body (zkrácená verze, ~400 slov, story tone):**
```
I have Somfy exterior venetian blinds on my house. Every morning I'd
wake up, walk barefoot to the bedroom corner, fish for my iPhone,
unlock it, tap the Home app, tap a scene, wait 2 seconds for it to
proxy through to the watch, tap accept, wait for the cloud.

It bothered me enough that I started writing my own watchOS app.

Six months later, Slatly is live on the App Store. The differentiator:
the Watch is fully standalone. It contains a complete OAuth + REST
client against the Somfy/Overkiz cloud, so the Apple Watch talks to
the blinds directly over LTE/Wi-Fi. No iPhone needed at runtime. The
phone is only there for the first sign-in.

Some specifics I wish I'd known on day one:

→ Apple's tooling refuses watchOS-only app submissions. You ship a
  tiny iOS host wrapper or you don't ship at all. (Apple Developer
  Forums thread 738218.)

→ iCloud Keychain with kSecAttrSynchronizable is the cleanest cross-
  device credential sync. No CloudKit entitlement, no servers.

→ WatchConnectivity's updateApplicationContext is enough for
  scene-level data. You don't need transferUserInfo or transferFile
  unless you're moving binary blobs.

→ For a brand-new app, Bing's IndexNow protocol gets you crawled in
  hours instead of days. Worth setting up alongside Google Search
  Console.

→ A static marketing site beats a SPA. Slatly's site is 5 pre-rendered
  HTML files (one per language), JSON-LD on every page, llms.txt for
  AI search engines. Hosted on Cloudflare Pages for $0.

Today's launch numbers:
  - $0 hosting (Cloudflare Pages free tier)
  - $0 backend (there is no backend)
  - 5 languages: EN, CS, DE, FR, ES
  - MIT licensed: github.com/martinjanicek/slatly
  - App Store: free in most regions, $0.99 in some

Happy to dig into any of these in the comments. AMA.

Site: slatly.punkhive.com
```

---

## 6. awesome-apple-watch (PR na 738/awesome-apple-watch)

**PR title:**
```
Add Slatly: standalone Somfy ExteriorVenetianBlind controller for Apple Watch
```

**PR body / README diff:**

Najít sekci „**Open Source Apps**" (nebo nejbližší relevant) v `README.md` a přidat:

```markdown
- [Slatly](https://github.com/martinjanicek/slatly) - Standalone
  watchOS app that controls Somfy ExteriorVenetianBlind devices
  via the Overkiz cloud API. Runs without the paired iPhone over
  LTE or Wi-Fi. Includes OverkizKit, a SwiftPM library wrapping
  the Somfy OAuth + exec/apply flow.
```

**Po submitu PR:** napsat krátký nice intro v PR description. Awesome list maintainers obvykle mergují kvalitní PRs během dní až týdnů.

---

## 7. Product Hunt

**Pre-launch checklist:**
- Najdi **huntera** (uživatel s 500+ followers, hunt history). Můžeš se ucházet sám, ale ze starého účtu jsou tractionu lepší.
- Naplánuj na **úterý-čtvrtek, 00:01 PT** (= 09:01 ČAS). To dává plný 24h "Today" window.
- **Připrav:** 3 obrázky (1280×800 nebo 1280×720), 1 gif/video (=screen recording App Store preview až ho budeš mít), tagline, description.

**Tagline (max 60 znaků):**
```
Control your Somfy blinds straight from Apple Watch
```

**Description (~260 znaků):**
```
Slatly lets your Apple Watch control Somfy exterior venetian blinds
directly over LTE or Wi-Fi — no iPhone, no hub at runtime. Digital
Crown tilts the slats, drag-to-closure, multi-blind scenes. Open
source (MIT), no analytics, free.
```

**First comment** (post immediately, sets the tone):
```
Hi PH! I'm Martin, author of Slatly.

Built this because every existing Apple Watch path to Somfy blinds
needed the iPhone within Bluetooth range — which defeats the point
of an Apple Watch. Slatly's watchOS app is fully standalone after
first sign-in: full OAuth + REST client running on the wrist, talking
to Somfy's cloud directly over LTE/Wi-Fi.

If you have Somfy ExteriorVenetianBlind devices on a Connexoon,
TaHoma or Cozytouch box, give it a spin. Free on the App Store,
MIT source on GitHub. Happy to answer anything.
```

---

## 8. forum.somfy.fr _(opatrně, French)_

Toto je oficiální Somfy fórum. **Marketing post tam smažou.** Co ale můžeš:

- Hledej již otevřené threads typu „Apple Watch + TaHoma", „App pour Apple Watch", „Somfy on watchOS".
- V relevantním threadu odpověz krátce a věcně: "I built a third-party app that does exactly this — slatly.punkhive.com — happy to take feedback."
- **Nikdy** neotvírej standalone „Hey there's my app" post.

French translation pripravená:

```
Bonjour à tous,

Si quelqu'un cherche une vraie app Apple Watch pour piloter ses stores
extérieurs Somfy en autonomie (sans iPhone à proximité), j'ai développé
une app tierce qui fait exactement cela — Slatly. Elle utilise l'API
Overkiz officielle, comme les apps Somfy / TaHoma / Cozytouch.

Open source, gratuite, App Store. https://slatly.punkhive.com/

Disclaimer : je suis l'auteur, ce n'est pas affilié à Somfy. Heureux
de répondre aux questions.
```

---

## 9. LinkedIn (Martin Janíček osobní profil)

**Tone:** profesionální, story-driven, ne hard sell. CZ + EN dvojjazyčně? Asi jen EN.

**Body:**
```
I shipped Slatly today — a free, open-source Apple Watch app that
controls Somfy ExteriorVenetianBlind devices directly from the wrist,
with no iPhone proxy required at runtime.

Why a side project on this scale: I have these blinds at home, the
HomeKit + iPhone path was painful, and the Apple Watch deserves to
actually be useful for the small daily moments. Six months of
weekends and evenings later, here's what came out:

→ watchOS 10 + iOS 17 app, Swift 6, SwiftPM
→ Standalone OAuth + REST against the Somfy/Overkiz cloud
→ iCloud Keychain for cross-device credential sync
→ WatchConnectivity for instant scene push between phone and watch
→ 5 languages (EN / CS / DE / FR / ES)
→ MIT licensed source on GitHub, no analytics, no servers

If you (or someone you know) has Somfy blinds on a Connexoon, TaHoma
or Cozytouch box, give it a try:

App Store: https://apps.apple.com/us/app/slatly/id6769497680
Marketing site: https://slatly.punkhive.com/
Source: https://github.com/martinjanicek/slatly

#AppleWatch #watchOS #SmartHome #Somfy #IndieDev #SwiftUI #OpenSource
```

---

## Kde jsem nevsadil _(úmyslně)_

- **Twitter/X** — bez audience málo páky. Můžeš tweetnout odkaz na HN/PH submission místo separate launch.
- **TikTok/Reels** — bez videa zbytečné. Až bude video s kočičkou, samostatná strategie.
- **YouTube** — viz výše.
- **Hacker News „Launch HN"** (jiné než Show HN) — to je pro YC startups. Slatly = Show HN.
- **r/iosdev, r/swift, r/SwiftUI** — relevantní pro tech post, ale konflikt s HN audience (overlap). Pokud HN nepropadne, můžeš tam dát „posted on HN" link 24h později.
- **r/macOS, r/apple** — místa s low signal-to-noise pro tento typ submitu.

---

## Tracking výsledků

V GSC + Bing Webmaster po každém launch se dívej na:
- **Referrals z newshostname** (`news.ycombinator.com`, `reddit.com`, `producthunt.com`, `linkedin.com`)
- **Brand search impressions** (= „Slatly", „Slatly watch", „Slatly Somfy")
- **Backlink count** ve **Backlinks** tabu Bing Webmaster (Bing detekuje rychleji než GSC)

Po týdnu od launch očekávej:
- 5–20 quality backlinks → ranking pro `slatly` brand search
- 50–200 impressions/day v GSC pro long-tail keywords
- první AI citations v ChatGPT search / Perplexity pokud dotaz obsahuje „somfy apple watch"
