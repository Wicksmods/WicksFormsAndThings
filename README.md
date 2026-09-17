# Wick's Forms and Things

> Druid loadout kit for World of Warcraft: Forever. Smart travel form keybind with resource bar, talents, pre-pull checklist, racials.

Part of the **[Wick suite](https://github.com/Wicksmods/WickSuite)**: precision addons built around a single fel-green-on-deep-purple aesthetic. Built on [WickCore](https://github.com/Wicksmods/WickCore). Wick's Travel Form grew up into this.

## What it is

- **Smart travel form.** One secure keybind that resolves to Aquatic when
  swimming, Travel outdoors, Cat indoors, and cancels the form when you are
  already in the one it would pick. The macro carries the conditionals, so it
  is right in combat too. Forever has no flying, so there is no flight clause;
  on a client that has one, the flight form is added automatically.
- **Resource bar.** Rage in Bear, energy in Cat, mana otherwise, with the mana
  bar beneath when the form hides it. Attached under the button or floating.
  Built on StatusBars, which accept the secret power values Forever hands out.
- **Talents.** Export the active build as a Blizzard import string, import a
  string as a new loadout, save builds to an account-wide library, apply one
  with a click.
- **Pre-pull checklist.** Mark of the Wild, Thorns, Omen of Clarity, Rebirth
  ready. Rows go quiet the moment combat starts.
- **Racials.** Your race's actives as cast buttons with cooldown display.

## Install

Requires **[WickCore](https://github.com/Wicksmods/WickCore)**. Extract both
folders into the Forever client's `Interface\AddOns\`.

## Usage

Bind **Smart travel form** under Key Bindings, AddOns, Wick's Forms and Things.

| Command | Effect |
|---|---|
| `/wft` | Commands |
| `/wft options` | Options page |
| `/wft kit` | Talents, checklist, racials |
| `/wft unlock` / `lock` | Drag and resize the button |
| `/wft size <32-96>` | Button size |
| `/wft bar ...` | Resource bar geometry |
| `/wft debug` | What the macro will do right now |

`/wforms` and `/wstf` are aliases.

## Compatibility

World of Warcraft: Forever, 1.60.x, Interface 16001. Requires WickCore.

## License

MIT for code (see [LICENSE](LICENSE)). Brand chrome and the "Wick's" wordmark are trademarked, see [TRADEMARK.md](https://github.com/Wicksmods/WickSuite/blob/main/TRADEMARK.md). Racial data from [talentsforever.com](https://talentsforever.com) (CC BY 4.0) via WickCore.
