class_name PartyText
extends RefCounted
## Every string and colour of Lalu's birthday room in one place (the Hebrew line is written
## with a proper editor: Git Bash mangles Hebrew on the command line).

const BANNER_TOP := "HAPPY BIRTHDAY"
const BANNER_NAME := "HILA"
const SIGN := "From Noam & Daniel"
const SIGN_SMALL := "with love"
const HEBREW := "מזל טוב לאלו"          ## shown only when HEBREW_OK (the default font renders it)
const HEBREW_OK := true
const CARD_TITLE := "Happy Birthday Lalu!"
const CARD_SUB := "Love, Noam & Daniel"
const CARD_AGAIN := "the party resets - play it again!"
const MENU_BUTTON := "LALU'S BIRTHDAY"
const MENU_SUB := "a present for Hila, from Noam & Daniel"
const MAP_NAME := "Lalu's Birthday"
const MAP_BLURB := "Hila's party room: a giant cake with 12 candles, 30 balloons, a pinata, five gifts, a bouncy castle, a moon corner and a slide. No fighting, only cheering."
const MODE_NAME := "Birthday Party"
const MODE_BLURB := "Blow out the candles, pop the balloons, break the pinata, open the gifts. Guests only cheer."

const GUESTS := ["Sprinkles", "Bubbles", "Muffin", "Confetti", "Pixie", "Jelly", "Waffle"]

## Hila's three things: K-pop, Rich the bully, Chuchu the bulbul
const KPOP_SIGN := "K-POP STAGE"
const KPOP_SUB := "shoot PLAY for the show"
const KPOP_HINT := "shoot PLAY  -  everybody dance!"
const KPOP_KO := "케이팝"                 ## shown only when KPOP_KO_OK (the default font renders Hangul)
const KPOP_KO_OK := true
const RICH_NAME := "RICH"
const RICH_SUB := "the hippo"
const CHUCHU_NAME := "CHUCHU"
const CHUCHU_SUB := "shoot me, I fly!"

## pink / gold / teal party palette
const PINK := Color(0.98, 0.45, 0.68)
const HOT_PINK := Color(0.96, 0.28, 0.58)
const GOLD := Color(0.99, 0.8, 0.28)
const TEAL := Color(0.22, 0.8, 0.78)
const MINT := Color(0.55, 0.92, 0.7)
const LILAC := Color(0.72, 0.58, 0.95)
const SKY := Color(0.45, 0.72, 0.98)
const CREAM := Color(0.99, 0.96, 0.9)
const PALETTE: Array[Color] = [PINK, GOLD, TEAL, LILAC, SKY, MINT, HOT_PINK]


static func color(i: int) -> Color:
    return PALETTE[posmod(i, PALETTE.size())]
