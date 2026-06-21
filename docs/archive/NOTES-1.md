# Heroes III på web/mobil — beslutningsnotat

**Dato:** 2026-06-21
**Kontekst:** Vurdering av om eksisterende single-`index.html`-spillpraksis (Claude Code, embedded JS/CSS) bør brukes til å gjenskape Heroes of Might and Magic III (1999) for web og mobil. Trigget av (a) pixel/retro-trenden, (b) "gratis" on-device AI i Chrome.

---

## Konklusjon (TL;DR)

[BESLUTNING] **Ikke gjenskap hele HoMM3.** Bygg **kampmotoren alene** som et frittstående retro-pixel-spill med egne assets og deterministisk fiende-AI. Drop Gemini Nano som motstander; bruk den eventuelt kun til flavor-tekst med graceful degradation.

Begrunnelse: full HoMM3 er ikke et single-`index.html`-prosjekt, originalassets kan ikke shippes lovlig, og "gratis AI"-vinkelen hjelper ikke på den faktisk vanskelige delen (motstander-AI) — i tillegg til at den dreper mobil-delen.

---

## Premissene som ikke holdt

| Premiss | Status | Hvorfor |
|---|---|---|
| "8-bit look er in → passer HoMM3" | [FEIL] | HoMM3 er detaljerte pre-renderte sprites i 16-bit-æraens stil, ikke 8-bit. Retro-pixel og HoMM3-grafikk er to motstridende estetikker. Velg én. |
| "Gratis AI i Chrome → bruk den" | [DELVIS FEIL] | Hjelper ikke på det harde (se under). Desktop-only dreper "mobile"-delen. |
| "Single index.html → gjenskap hele spillet" | [FEIL] | Full HoMM3 ≈ 15 år multi-utvikler-innsats (jf. VCMI). Passer ikke i én fil. |

---

## Format-status (kontekst — `.h3m` er grundig reversert)

[DOKUMENTERT] Kart-formatet er fullstendig dokumentert. Autoritetsrekkefølge:

1. **VCMI** — open-source reimplementering. Koden er fasit; ved konflikt vinner VCMI over dokumentasjon.
2. **HeroWO-js/h3m2json** — lesbar, eksekverbar feltreferanse. RoE/AB/SoD full, HotA delvis (rå tallverdier).
3. **`h3m_description.english.txt`** (Antoshkiv/Ershov) — byte-for-byte ordbok, aldrende.

[OBSERVERT] Forbehold:
- HotA divergerer kraftig fra RoE/AB/SoD; eget template-format (h3hota.com).
- `.h3c`-kampanjer er mindre eksponert — i praksis container rundt flere `.h3m` + metadata. Les VCMI-kilde direkte.
- `.h3m` er gzip-komprimert på disk; spec beskriver utpakket strøm.

[DOKUMENTERT] **Assets er copyrightet (Ubisoft).** VCMI omgår dette ved å kreve at brukeren eier spillet. En nettleser-`index.html` har ikke den luksusen → **egne assets er obligatorisk.**

---

## Chrome Prompt API (Gemini Nano) — harde fakta per mai 2026

[DOKUMENTERT]
- **Desktop only:** Windows 10/11, macOS 13+, Linux, ChromeOS på Chromebook Plus. **Ikke Android/iOS/vanlig ChromeOS.**
- Engelsk only, tekst only, ~4 GB modellnedlasting, bak flagg / origin trial.
- Egnet for fokuserte enkeltoppgaver (oppsummering, klassifisering, omskriving). Ikke storskala resonnering.
- Sitat fra folk som har shippet mot API-et: "Nano er autocomplete-klassen av LLM-er."

[INFERT] En autocomplete-klasse-modell kan ikke spille minimax-aktig strategi. Til motstander-AI vil deterministisk heuristikk/minimax slå Nano hver gang **og** kjøre på alle enheter i stedet for ~halvparten.

Tilgjengelighetssjekk hvis Nano likevel skal brukes til flavor:

```js
const status = await LanguageModel.availability();
// "available" | "downloadable" | "downloading" | "unavailable"
if (status === "available") {
  const session = await LanguageModel.create({ systemPrompt });
  // ... bruk til hero-replikker, quest-tekst, slag-rapporter
  session.destroy(); // alltid i finally
} else {
  // graceful degradation → statiske strenger
}
```

---

## Anbefalt scope

[BESLUTNING] **Kampmotoren som frittstående spill.**

- Hex-grid-slaget er selvstendig, deterministisk, endelig tilstandsrom → passer i én `index.html`.
- Egne pixel-assets (lovlig, rir 8-bit-trenden ærlig).
- Deterministisk fiende-AI (heuristikk/minimax) — ingen nettleser-LLM-avhengighet.
- Web **og** mobil, fordi ingen Nano-krav.
- Oppnåelig i uker, ikke år.

[VALGFRITT] Nano kun til *flavor* (hero-replikker, quest-tekst, prosa-slagrapporter), med fallback til statiske strenger. Spilleren mister ingenting på enheter uten modell.

---

## Eksplisitt ute av scope

- Adventure-map, by-skjermer, økonomi, rekruttering, kampanjer — fase 2+, ikke nå.
- Motstander-AI via LLM.
- Originalassets.
- Konkurranse med VCMI på "spill hele HoMM3 moderne".

---

## Åpne spørsmål / neste steg

- [ ] Hvilken creature-subset for MVP? (forslag: 2 factions, ~7 enheter hver — nok til å teste loop)
- [ ] Asset-pipeline: tegne for hånd vs. generere vs. CC-lisensiert pixel-pakke?
- [ ] AI-dybde: ren heuristikk holder for MVP; minimax/expectiminimax senere ved behov?
- [ ] Mobil-input: touch-mapping på hex-grid tidlig, ikke ettermontert.
