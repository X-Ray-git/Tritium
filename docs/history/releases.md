# å‘å¸ƒè®°å½•

## v0.1.0

ä»“åº“åˆå§‹ç‰ˆæœ¬ã€‚åç»­ç‰ˆæœ¬å¿…é¡»é€šè¿‡ `scripts/release.sh` åˆ›å»ºï¼›è„šæœ¬ä¼šåœ¨è¿™é‡Œè¿½åŠ å¯å¤ç°çš„
å‘å¸ƒå‘½ä»¤ï¼Œannotated tag çš„è¯´æ˜ä½œä¸º GitHub Release notesã€‚

## v0.2.0

```bash
./scripts/release.sh 0.2.0 -m $'- feat: å¯¹é½\220å\217ªè¯»å¯¼è\210ªã\200\201æ\255£æ\226\207æ¸²æ\237\223ã\200\201å\233\236ç\255\224æ¨ªæ»\221ä¸\216å\233¾ç\211\207æµ\217è§\210ä½\223éª\214\n- fix: ä¿®å¤\215ä¸\213æ\213\211å\210·æ\226°ã\200\201è¯\204è®ºé¢\204å\212 è½½ã\200\201é\230\205è¯»é¡µæ \207é¢\230æ\212\226å\212¨ä¸\216è®¾ç½®é¡µå®\211å\205¨è·\235ç¦»\n- chore: å¯¹é½\220 Auto Folo ç\232\204æ\226\207æ¡£ç»´æ\212¤ä¸\216ç\255¾å\220\215å\217\221å¸\203æµ\201ç¨\213' --push
```

## v0.2.1

```bash
./scripts/release.sh 0.2.1 -m $'- feat: å¯¹é½\220å\217ªè¯»å¯¼è\210ªã\200\201æ\255£æ\226\207æ¸²æ\237\223ã\200\201å\233\236ç\255\224æ¨ªæ»\221ä¸\216å\233¾ç\211\207æµ\217è§\210ä½\223éª\214\n- fix: ä¿®å¤\215ä¸\213æ\213\211å\210·æ\226°ã\200\201è¯\204è®ºé¢\204å\212 è½½ã\200\201é\230\205è¯»é¡µæ \207é¢\230æ\212\226å\212¨ä¸\216è®¾ç½®é¡µå®\211å\205¨è·\235ç¦»\n- fix: æ\201¢å¤\215å·²éª\214è¯\201å\217¯ç\224¨ç\232\204 GitHub Actions Java å\217\221å¸\203ç\216¯å¢\203\n- chore: å¯¹é½\220 Auto Folo ç\232\204æ\226\207æ¡£ç»´æ\212¤ä¸\216ç\255¾å\220\215 Release æµ\201ç¨\213'
```

## v0.3.0

```bash
./scripts/release.sh 0.3.0 -m $'- feat: add session-scoped recommendation de-duplication and verified feedback\n- feat: add draggable body reading progress for articles, answers and pins\n- test: cover recommendation refresh, feedback batching and progress seeking' --push
```

## v0.4.0

```bash
./scripts/release.sh 0.4.0 -m $'- feat: å®\214å\226\204åº\224ç\224¨å\206\205é\223¾æ\216¥ã\200\201æ\255£æ\226\207æ¸²æ\237\223ä¸\216ç»\237ä¸\200å\217\215é¦\210\n- feat: æ\224¯æ\214\201é¦\226é¡µè·\237æ\211\213æ¨ªæ»\221å\222\214å\233\236ç\255\224è¿\236ç»\255å\210\206é¡µ\n- fix: ä¿®æ\255£ç»\237è®¡è¯\255ä¹\211ã\200\201ç\203\255æ¦\234å\255\227æ®µã\200\201å°\201é\235¢æ¯\224ä¾\213ä¸\216é\207\215å¤\215å\210\206é¡µ\n- docs: æ\233´æ\226° Fourier å\217\202è\200\203å\205³ç³»ä¸\216éª\214æ\224¶è®°å½\225' --push
```

## v0.4.1

```bash
./scripts/release.sh 0.4.1 -m $'- fix: keep reply previews and thread panels at a stable safe-area width\n- fix: restore question links inside selectable article content, including articles opened from history\n- test: cover same-route navigation, tap, drag, and long-press link regressions' --push
```

## v0.4.2

```bash
./scripts/release.sh 0.4.2 -m $'- fix: allow answer, question, article, pin, and user links to open same-type targets with different IDs\n- fix: coalesce duplicate SelectionArea and flutter_html callbacks without blocking later revisits\n- test: cover real selectable-link navigation, same-type route matrix, and duplicate callback window\n- chore: allow the Android debug app to coexist with the signed release app' --push
```

## v0.4.3

```bash
./scripts/release.sh 0.4.3 -m $'- fix: stabilize Android text selection across paragraphs, lists, quotes, and inline code\n- fix: add bounded image retries and avoid main PageView rebuilds\n- ci: apply the versioned Flutter selection patch before release builds'
```

## v0.4.4

```bash
./scripts/release.sh 0.4.4 -m $'- fix: prevent emoji HTML attributes from leaking into comments and article text\n- fix: normalize emoji text nodes only once and preserve image and link attributes\n- test: cover existing emoji images, nested content, and code literals' --push
```

## v0.4.5

```bash
./scripts/release.sh 0.4.5 -m $'- fix: restore paragraph and heading line breaks in selectable HTML content\n- test: verify rendered block positions and target actual text glyphs for link gestures\n- test: pass all 156 regression tests including emoji, selection, navigation, and comments' --push
```

## v0.4.6

```bash
./scripts/release.sh 0.4.6 -m $'- æ\226°å¢\236ç\237¥ä¹\216 /video/ é\223¾æ\216¥åº\224ç\224¨å\206\205æ\222\255æ\224¾ï¼\214æ\255£æ\226\207è§\206é¢\221å°\201é\235¢å\222\214æ \207é¢\230å\217¯ç\233´æ\216¥è¿\233å\205¥æ\222\255æ\224¾å\231¨ã\200\202\n- æ\224¯æ\214\201æ\222\255æ\224¾æ\232\202å\201\234ã\200\201è¿\233åº¦æ\213\226å\212¨ã\200\201æ¨ªå±\217å\205¨å±\217ã\200\201å\220\216å\217°æ\232\202å\201\234å\222\214å¤±è´¥é\207\215è¯\225ã\200\202\n- å\217\202è\200\203 Hydrogen ä¸\216ç\237¥ä¹\216++è§£æ\236\220è§\206é¢\221æº\220ï¼\214ä¿®æ\255£ video ä¸\216 zvideo é\223¾æ\216¥æ··ç\224¨ï¼\214è§\206é¢\221å°\201é\235¢ä¸\215å\206\215è¿\233å\205¥å\233¾ç\211\207ç\224»å»\212ã\200\202\n- æ\234¬å\234°é\235\231æ\200\201å\210\206æ\236\220ã\200\201163 é¡¹æµ\213è¯\225å\222\214 Android Debug æ\236\204å»ºé\200\232è¿\207ï¼\233ç\234\237å®\236è®¾å¤\207æ\222\255æ\224¾ä¸\216å\205¨å±\217ä½\223éª\214å¾\205éª\214æ\224¶ã\200\202' --push
```
