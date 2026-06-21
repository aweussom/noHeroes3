# reference/

Local clones of the HoMM3 map-format authorities, used **only** while writing the Python
tooling (`tooling/h3m_to_json.py` and friends). These are **not** part of noHeroes3 and are
never shipped — the whole directory is gitignored except this file.

## Populate (run from the repo root)

```sh
git clone https://github.com/vcmi/vcmi        reference/vcmi
git clone https://github.com/HeroWO-js/h3m2json reference/h3m2json
```

The third authority, `h3m_description.english.txt` (Antoshkiv/Ershov), is a single text doc —
drop a copy in `reference/` if/when needed.

## Authority order when they disagree (see ../CLAUDE.md)

1. **VCMI** — code is ground truth.
2. **HeroWO-js/h3m2json** — readable, executable field reference.
3. **`h3m_description.english.txt`** — byte-for-byte dictionary, aging.
