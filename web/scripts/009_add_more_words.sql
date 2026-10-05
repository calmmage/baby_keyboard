-- Add more words to the database
DO $$
DECLARE
  animals_id uuid;
  food_id uuid;
  family_id uuid;
  objects_id uuid;
  nature_id uuid;
  colors_id uuid;
  actions_id uuid;
BEGIN
  -- Get Topic IDs (using slugs for reliability)
  SELECT id INTO animals_id FROM topics WHERE slug = 'animals';
  SELECT id INTO food_id FROM topics WHERE slug = 'food';
  SELECT id INTO family_id FROM topics WHERE slug = 'family';
  
  -- Create new topics if they don't exist
  IF NOT EXISTS (SELECT 1 FROM topics WHERE slug = 'objects') THEN
    INSERT INTO topics (name, slug) VALUES ('Objects', 'objects') RETURNING id INTO objects_id;
  ELSE
    SELECT id INTO objects_id FROM topics WHERE slug = 'objects';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM topics WHERE slug = 'nature') THEN
    INSERT INTO topics (name, slug) VALUES ('Nature', 'nature') RETURNING id INTO nature_id;
  ELSE
    SELECT id INTO nature_id FROM topics WHERE slug = 'nature';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM topics WHERE slug = 'colors') THEN
    INSERT INTO topics (name, slug) VALUES ('Colors', 'colors') RETURNING id INTO colors_id;
  ELSE
    SELECT id INTO colors_id FROM topics WHERE slug = 'colors';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM topics WHERE slug = 'actions') THEN
    INSERT INTO topics (name, slug) VALUES ('Actions', 'actions') RETURNING id INTO actions_id;
  ELSE
    SELECT id INTO actions_id FROM topics WHERE slug = 'actions';
  END IF;

  -- Insert Words
  -- Animals
  INSERT INTO words (word_en, word_ru, word_de, topic_id) VALUES
  ('Elephant', 'Слон', 'Elefant', animals_id),
  ('Lion', 'Лев', 'Löwe', animals_id),
  ('Monkey', 'Обезьяна', 'Affe', animals_id),
  ('Bear', 'Медведь', 'Bär', animals_id),
  ('Rabbit', 'Кролик', 'Hase', animals_id),
  ('Duck', 'Утка', 'Ente', animals_id),
  ('Chicken', 'Курица', 'Huhn', animals_id),
  ('Horse', 'Лошадь', 'Pferd', animals_id),
  ('Cow', 'Корова', 'Kuh', animals_id),
  ('Pig', 'Свинья', 'Schwein', animals_id),
  ('Sheep', 'Овца', 'Schaf', animals_id),
  ('Mouse', 'Мышь', 'Maus', animals_id),
  ('Frog', 'Лягушка', 'Frosch', animals_id),
  ('Fish', 'Рыба', 'Fisch', animals_id),
  ('Bird', 'Птица', 'Vogel', animals_id)
  ON CONFLICT DO NOTHING;

  -- Food
  INSERT INTO words (word_en, word_ru, word_de, topic_id) VALUES
  ('Banana', 'Банан', 'Banane', food_id),
  ('Orange', 'Апельсин', 'Orange', food_id),
  ('Grape', 'Виноград', 'Traube', food_id),
  ('Watermelon', 'Арбуз', 'Wassermelone', food_id),
  ('Strawberry', 'Клубника', 'Erdbeere', food_id),
  ('Bread', 'Хлеб', 'Brot', food_id),
  ('Cheese', 'Сыр', 'Käse', food_id),
  ('Milk', 'Молоко', 'Milch', food_id),
  ('Egg', 'Яйцо', 'Ei', food_id),
  ('Cookie', 'Печенье', 'Keks', food_id),
  ('Juice', 'Сок', 'Saft', food_id),
  ('Water', 'Вода', 'Wasser', food_id),
  ('Cake', 'Торт', 'Kuchen', food_id),
  ('Ice Cream', 'Мороженое', 'Eis', food_id)
  ON CONFLICT DO NOTHING;

  -- Objects
  INSERT INTO words (word_en, word_ru, word_de, topic_id) VALUES
  ('Car', 'Машина', 'Auto', objects_id),
  ('Ball', 'Мяч', 'Ball', objects_id),
  ('Book', 'Книга', 'Buch', objects_id),
  ('Chair', 'Стул', 'Stuhl', objects_id),
  ('Table', 'Стол', 'Tisch', objects_id),
  ('Bed', 'Кровать', 'Bett', objects_id),
  ('Cup', 'Чашка', 'Tasse', objects_id),
  ('Spoon', 'Ложка', 'Löffel', objects_id),
  ('Fork', 'Вилка', 'Gabel', objects_id),
  ('Plate', 'Тарелка', 'Teller', objects_id),
  ('Phone', 'Телефон', 'Telefon', objects_id),
  ('Keys', 'Ключи', 'Schlüssel', objects_id),
  ('Hat', 'Шапка', 'Hut', objects_id),
  ('Shoes', 'Обувь', 'Schuhe', objects_id)
  ON CONFLICT DO NOTHING;

  -- Nature
  INSERT INTO words (word_en, word_ru, word_de, topic_id) VALUES
  ('Sun', 'Солнце', 'Sonne', nature_id),
  ('Moon', 'Луна', 'Mond', nature_id),
  ('Star', 'Звезда', 'Stern', nature_id),
  ('Cloud', 'Облако', 'Wolke', nature_id),
  ('Rain', 'Дождь', 'Regen', nature_id),
  ('Snow', 'Снег', 'Schnee', nature_id),
  ('Tree', 'Дерево', 'Baum', nature_id),
  ('Flower', 'Цветок', 'Blume', nature_id),
  ('Grass', 'Трава', 'Gras', nature_id)
  ON CONFLICT DO NOTHING;

  -- Colors
  INSERT INTO words (word_en, word_ru, word_de, topic_id) VALUES
  ('Red', 'Красный', 'Rot', colors_id),
  ('Blue', 'Синий', 'Blau', colors_id),
  ('Green', 'Зеленый', 'Grün', colors_id),
  ('Yellow', 'Желтый', 'Gelb', colors_id),
  ('Black', 'Черный', 'Schwarz', colors_id),
  ('White', 'Белый', 'Weiß', colors_id)
  ON CONFLICT DO NOTHING;

  -- Actions
  INSERT INTO words (word_en, word_ru, word_de, topic_id) VALUES
  ('Run', 'Бежать', 'Laufen', actions_id),
  ('Jump', 'Прыгать', 'Springen', actions_id),
  ('Sleep', 'Спать', 'Schlafen', actions_id),
  ('Eat', 'Есть', 'Essen', actions_id),
  ('Drink', 'Пить', 'Trinken', actions_id),
  ('Play', 'Играть', 'Spielen', actions_id)
  ON CONFLICT DO NOTHING;

END $$;
