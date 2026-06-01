> NOTE: This game is in Norwegian, made for my son 🇳🇴

# Båtspillet 🚤

Et lite båtspill for barn (laget for min egen gutt). 

---

## Slik starter du spillet

Enklest: **dobbeltklikk på `Båtspillet.command`** (eksporter i Script Editor så har man en app)


Spillet starter i fullskjerm. Trykk **F11** for å bytte mellom fullskjerm og
vindu. (Vil du at det skal starte i vindu, sett `START_FULLSCREEN = false` i
`src/config.lua`.)

---

## Kontroller

| Knapp | Hva den gjør |
|-------|--------------|
| **Klikk på vannet** | Båten seiler dit |
| **Piltaster / WASD** | Styr båten selv |
| **Mus mot skjermkanten** | Flytt kartet |
| **Høyreklikk + dra** | Flytt kartet |
| **Musehjul** | Zoom inn / ut |
| **C** | Sentrer kameraet på båten |
| **MELLOMROM** | Last / lever varer i havna |
| **ESC** | Tilbake til menyen |

---

## Slik spiller du

1. Trykk **Enter** eller klikk **«Seil ut!»** i menyen.
2. Seil til en havn (klikk på vannet, eller bruk piltastene).
3. Når båten er nær havna, trykk **MELLOMROM** for å laste varer.
4. Lasten viser hvilken havn den skal til. Seil dit og trykk **MELLOMROM** for
   å levere – da får du **gull**.
5. Seil nær øyene for å **oppdage** dem.

Alt er snilt: båten synker aldri, den dulter mykt borti land, og du kan ikke
tape.

---

## Utviklertaster

| Tast | Handling |
|------|----------|
| **F5** | Last scenen på nytt (rask omstart) |
| **F6** | Last datafilene på nytt (`boats.lua`, `ports.lua`) |
| **F11** | Fullskjerm av/på |
| **M** | Lyd av/på |

---

## Legge til og endre innhold

- **Ny båt eller havn:** rediger `src/data/boats.lua` eller
  `src/data/ports.lua`, og trykk **F6** i spillet. Ingen koding nødvendig.
- **Endre følelsen** (fart, zoom, farger, kart): rediger `src/config.lua`.
- **Bytte ut grafikken:** legg PNG-filer i `assets/` (se `assets/README.md`).
  Spillet tegner enkle plassholdere helt til du legger inn ekte bilder.

---

## Lagring

Spillet lagrer automatisk (gull, opplåste båter og oppdagede øyer). Filen ligger
her – ikke i selve spillmappa:

```
~/Library/Application Support/LOVE/batspillet/savegame.json
```

---

## Teknisk (kort)

- Laget for LÖVE **11.3**. Fungerer også på gamle Mac-er
