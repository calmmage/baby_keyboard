Demo media workflow (simple test)

1) Use `simple_cat_source.png` as the input frame for video generation.
2) Generate a short (1-2s) loopable clip.
3) Save returned file as `simple_cat.mp4` in this same folder.

Expected test setup in app:
- Lock effect: random/speak word mode (fullscreen)
- Show Flashcards: ON
- Flashcard Style: Simple
- Show Video Cards: ON
- Video Demo: Force Single Word: ON
- Demo Word: cat

Behavior:
- First key press shows still card.
- Second key press (before card timeout) switches same card to video.
