````markdown
# Heroes-Inspired Browser Strategy Game (2026 Notes)

## Overordnet idé

Ikke lage en Heroes III-klone.

Lage et nytt spill inspirert av Heroes III, men med:

- Egne grafiske assets
- Egne regler der det er naturlig
- Gjenbruk av åpne kartformater der det er praktisk
- Moderne AI-verktøy som produksjonshjelp

Mål:

> Utnytte 2026-verktøy for å gjøre det som krevde et lite team i 1999 mulig for én hobbyutvikler.

---

# Grafikk

## Utfordring

Heroes III-assets er opphavsrettsbeskyttet.

En ren transformasjon:

```text
Heroes III sprite
        ↓
8-bit filter
        ↓
Ny sprite
````

gir sannsynligvis fortsatt et avledet verk.

## Bedre tilnærming

```text
Heroes III sprite
        ↓
Vision-LLM beskriver asset
        ↓
Strukturert beskrivelse
        ↓
AI genererer ny variant
        ↓
Pixel-art / 8-bit stil
```

Eksempel:

Original:

* Ridder
* Hest
* Lanse
* Blå/gull

Generert:

* Ny rustning
* Ny hest
* Ny silhuett
* Ny fargepalett

Resultatet skal:

* Føles kjent
* Ikke være samme asset

---

# AI-basert asset pipeline

```text
Original asset
        ↓
Beskrivelse (Vision LLM)
        ↓
JSON

{
  "type": "cavalry",
  "weapon": "lance",
  "armor": "plate",
  "colors": ["blue","gold"]
}

        ↓
Prompt-generator
        ↓
Image model
        ↓
Pixel-art generator
        ↓
Manuell QA
```

Fordel:

Originalen brukes som referanse og inspirasjon, ikke som pikselkilde.

---

# Kart

## H3M-format

Status:

* Formatet er godt dokumentert
* Flere åpne implementasjoner finnes
* VCMI fungerer som de-facto referanse

Kilder:

* VCMI
* h3m_description.english.txt
* h3m2json
* Diverse Rust/C#/Python-parsere

## Strategi

Ikke starte med spillmotor.

Start med:

```text
Read H3M
    ↓
Convert to JSON
    ↓
Render map
```

---

# Første milepæl

```text
Load H3M
    ↓
Vis kart
    ↓
Scroll kart
    ↓
Klikk helt
    ↓
Flytt helt
```

Hvis dette fungerer:

* Parser fungerer
* Renderer fungerer
* Kartdata fungerer
* Koordinatsystem fungerer

Da finnes allerede kjernen i spillet.

---

# Teknologistack

Eksisterende erfaring:

* Node.js
* TypeScript
* Vite
* GitHub Copilot
* Claude Code

Ny komponent:

* Canvas 2D

## Hvorfor Canvas 2D?

Heroes-lignende kart er i praksis:

```text
Tile → bilde
Objekt → bilde
Helt → bilde
```

Et XL-kart:

```text
144 × 144
=
20 736 tiles
```

Dette er trivielt for moderne nettlesere.

Canvas 2D gir:

* Enkel modell
* Lite kompleksitet
* Ingen tung spillmotor
* Direkte kontroll

---

# Datamodell

Eksempel:

```typescript
interface Hero {
    id: string;
    x: number;
    y: number;

    movement: number;

    army: Stack[];
    skills: Skill[];
}
```

```typescript
interface MapObject {
    type: string;
    x: number;
    y: number;
}
```

Fokus:

* Intern modell først
* Grafikk senere

---

# Gjenbruk av eksisterende kart

Kartene representerer mer enn terreng.

De inneholder:

* Balansering
* Ressursplassering
* Utforskningsmønstre
* Nivådesign
* Kampanjeflyt

Dermed kan H3M-kart brukes som:

* Testdata
* Referansemateriale
* Treningsgrunnlag

---

# Interessant fremtidig idé

Analyser store mengder Heroes-kart.

```text
1000 H3M maps
        ↓
Parser
        ↓
JSON
        ↓
Statistikk
```

Spørsmål:

* Hvor langt ligger gullgruver fra startby?
* Hvor mange vakter finnes typisk?
* Hvordan fordeles artefakter?
* Hvordan fordeles terrengtyper?

Dette kan brukes til:

* Kartgenerator
* Balansering
* AI-designassistent

---

# Viktig observasjon

Grafikken er kanskje ikke lenger den dyreste delen.

I 1999:

* Grafikk var dyrt
* Produksjon var dyrt

I 2026:

* AI hjelper med assetproduksjon
* AI hjelper med kode
* AI hjelper med dokumentasjon

De største utfordringene blir sannsynligvis:

* Spilldesign
* Kampsystem
* AI-motstandere
* Karteditor
* Konsistens i assets

Ikke selve grafikkproduksjonen.

---

# Sannsynlig utviklingsforløp

Fase 1:

"Jeg skal bare prøve å lese et H3M-kart."

Fase 2:

"Jeg skal bare vise kartet i browser."

Fase 3:

"Jeg skal bare flytte en helt."

Fase 4:

GitHub-repository får navn.

Fase 5:

GitHub-repository får logo.

Fase 6:

Det kommer issues.

Fase 7:

Det kommer pull requests.

Fase 8:

Prosjektet har plutselig eksistert i tre år.

```
```
