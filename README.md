# ShavianKey
## A native SwiftUI based Shavian (the phonemic English alphabet) keyboard.

## Usage

### KEYMAP
Tap SW (⇕) to switch between a and b submodes, or double tap it to switch between 1 and 2 modes (shavian/symbols). Press and hold to bring up all modes and submodes (this is the only way to reach SW3). [SW] should be the same size as the other keys, and is the SF symbol mount.

Any button in modes 1 or 2 can be double tapped for its other submode value (e.g. when in default 1a, double tapping will result in the 1b value in the same position: 𐑐 -> 𐑚 or 𐑨 -> 𐑧, same in 2a and 2b).

[SPC - DEL] ( ␠ - ␈ ) are two separate buttons, each 2x the size of a normal button. You can press and hold on SPC to move around the cursor like the native keyboard, and press and hold on DEL to select text (starting from where the cursor currently is). [SPC - DEL]  should be in the center of the horizontal stack. Swiping right quickly on [SPC - DEL] is ENTER, while swiping left is TAB. SPC is space, DEL is delete.left.

```
SW1a:
𐑐	𐑑	𐑒	𐑓	𐑔	𐑕	𐑖	𐑗	𐑘	𐑙
𐑤	𐑯	𐑦	𐑲	𐑨	𐑩	𐑳	𐑵	𐑬	𐑭
⇕	𐑸	𐑺     ␠       ␈     𐑼  𐑿   ·

SW1b:
𐑚	𐑛	𐑜	𐑝	𐑞	𐑟	𐑠	𐑡	𐑢	𐑣
𐑮	𐑥	𐑰	𐑱	𐑧	𐑪	𐑴	𐑫	𐑶	𐑷
⇕   𐑹  𐑻     ␠       ␈     𐑽	𐑾	⸰⁠⁠

SW2a:
0	1	2	3	4	5	6	7	8	9
~	=	/	-	:	{	[	(	<	«
⇕	.	,     ␠       ␈     !	?	‘

SW2b:
°	!	@	#	$	%	^	&	*	|
☭	+	\	_	;	}	]	)	>	»
⇕	.	,     ␠       ␈     !	?	`
```

<img width="679" height="1306" alt="ss1" src="https://github.com/user-attachments/assets/08fe686d-9919-4b01-81be-b54acf750e70" />

## Development
- [ ] MVP
  - [x] Double tap Shavian keys for their paired character (e.g. 𐑑 -> 𐑛)
  - [x] Swipe space to the right for enter & to the left for tab
  - [x] Drag on delete to slide cursor back and forth (mixed feelings about this UX)
  - [x] Key alignment math (bottom row)
    - [x] Usable, but 1x keys slightly small and unaligned
    - [x] Fix that
    - [x] Works on form factors that aren't my iPhone 12 mini
    - [x] Fixed that, now dealing with not enough vertical space?.. (fixed, needed to adjust padding post-refactor)
    - [x] I was so wrong and had to do a horrific amount of refactoring because just getting an accurate frame width at init is apparently too much
  - [x] Liquid Glass icon with icon composer
  - [ ] REFACTOR from the keymaps being held in individual arrays for each submode to SINGLE dictionary that encodes the character pair relationships
    - e.g.  for QWERTY (a -> A), Shavian (𐑐 -> 𐑚), Nums (1 -> !). This will make altering the keymap infinitely easier
  - [ ] Mode switcher
    - [x] Tapping switches to alternate keys (submode)
    - [x] Double tapping (<0.3s) switches between Shavian and Nums/Syms (and back to Shavian if in QWERTY)
    - [x] When held brings up small mode picker for Shavian/Numbers & Symbols/QWERTY boards
      - [x] Refactor switcher so it works as a drag gesture when held that autoselects 'button'
            where you 'un-tap' like how diacretics and punctuation works in the native ios KB
      - [x] SOMETIMES (always at start-up, not ideal) tapping and double tapping does not work UNTIL you use the mode picker
    - [ ] The mode switcher placement needs to behave smartly across different displays (optimized for 12 mini)
  - [ ] QWERTY mode
    - [x] You can type in CAPS, and use backspace
    - [ ] Add spacebar
    - [ ] Make it so shift works (use pair dictionary, maybe?)
  - [ ] '·' key, when held, should bring up some basic punctuation options (, . ! ? « »)?
- [ ] Intelligence
  - [ ] UI
    - [x] Design UI icons for displaying that the currently typed word is within the dictionary (dict.check), not in the dictionary (so, addable: dict.plus), or ready to be deleted (dict.x)
    - [ ] Make row as close to native ios autocorrect as possible (3 part bar with small button on the right)
    - [ ] Intelligently put corrections vs predictions in the 3 options, highlight either prediction or correction based if likelihood crosses a threshold WHILE the current word is NOT in the dictionary
  - [ ] Autocorrect
    - [ ] Native swift simple edit steps (deletion, transposition, replacement, insertion) based error checking
      - [ ] READ [this great description of a spell checker](https://www.norvig.com/spell-correct.html) and [this implementation in swift](https://airspeedvelocity.net/2015/05/02/spelling/)
      - [ ] now make it, native to swift. NEED RELIABLE DICT FIRST
  - [ ] Predictive text
    - [ ] Trie's for shavian words with frequency attached to any leaves [helpful blog post?](https://holyswift.app/trie-in-swift-autocorrect-data-structure-now-you-know-what-to-blame/)
  - [ ] Dictionary (used by both predictions & autocorrect)
    - [ ] Text corpus in Shavian for word frequency?
    - [ ] Organized by relevance
      - [ ] general dict
      - [ ] proper nouns
        - [ ] names
        - [ ] place names
      - [ ] initialisms
      - [ ] user dict (for added words)
- [ ] Extras
  - [ ] Use the top 'predictions' row in QWERTY for in-keyboard English -> Shavian transliteration
    - [ ] Dechifro or Ormin's transliterator?? Which is most easily rewritten in Swift and has a minimum of dependencies?
  - [ ] Some settings options in main app window
    - [ ] Figure out swift containers, figure out how setting file should be managed, figure out what settings are realistic to give user control over
    - [ ] Let user choose whether to have SPC-DEL or DEL-SPC      
    - [ ] Maybe let user turn off QWERTY mode? or switch it to colemak
    - [ ] 



