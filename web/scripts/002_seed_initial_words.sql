-- Seed some initial global words for testing
-- These are accessible to everyone (user_id is null)

INSERT INTO words (user_id, word_en, word_ru, word_de) VALUES
  (NULL, 'cat', 'кот', 'Katze'),
  (NULL, 'dog', 'собака', 'Hund'),
  (NULL, 'apple', 'яблоко', 'Apfel'),
  (NULL, 'ball', 'мяч', 'Ball'),
  (NULL, 'book', 'книга', 'Buch'),
  (NULL, 'car', 'машина', 'Auto'),
  (NULL, 'sun', 'солнце', 'Sonne'),
  (NULL, 'moon', 'луна', 'Mond'),
  (NULL, 'water', 'вода', 'Wasser'),
  (NULL, 'tree', 'дерево', 'Baum'),
  (NULL, 'house', 'дом', 'Haus'),
  (NULL, 'bird', 'птица', 'Vogel'),
  (NULL, 'flower', 'цветок', 'Blume'),
  (NULL, 'star', 'звезда', 'Stern'),
  (NULL, 'fish', 'рыба', 'Fisch');
