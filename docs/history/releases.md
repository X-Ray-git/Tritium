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
