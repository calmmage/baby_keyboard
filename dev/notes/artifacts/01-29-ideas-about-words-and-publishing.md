"There are some more new issues." 

"Why is there 150 words in my active word pool? I meant more like.. 20? Make it a parameter, default - 25..."

"There's some strange word - \"CRUD RR ...\" something like that - i can't find where it comes from, maybe from some corrupted dict.. Actually, nevermind, I'll just reset the dict"

"soo... did we end up using some official word dictionary that contains all possible words? Like nltk kit or something?"

"How can we annotate the categories of those words? Definitions?"

"Let's make a sample showcase python app in scripts dir that tries to work with all that."

"E.g. 
- get all the words for a language X
- get words (lang, word_type (enum - like verb or noun))
- get word definition(s)?
- get word category (action / item / adjective)
- get word complexity / frequency in the word pool usage"

"Let's make a separate doc checklist where we have status for each of the above goals, starting from 'no idea' then 'compromise', then 'fully implemented and tested' then 'verified by human'"

"I have generated all of the images with gemini. How do i prove that?!"

"uv run python -m scripts.word_dictionary_showcase --lang en --summary 
lang=en words=148

What the fuck is this?

Are you using nltk?"

"What the fuck is this bullshit?

I WANT FULL ENGLISH VOCABULARY!!!!
FOR EACH LANGUAGE!!!

WITH ANNOTATIONS SOURCED ALSO FROM OFFICIAL DATA SOURCES / PYTHON PACKAGES / REPORT IF THEY ARE NOT AVAILABLE / FEASIBLE TO GET

WHERE THE FUCK IS THE VERBS / NOUNS ETC PARAMETER?"

"En and ru are most interesting, rest are todo for the future. Maybe german / french as well, if that's not too much extra work."

"Max size per language (top 5k / 20k / full)
What the fuck is this question?
Just make script accept filtration parameters"

"Language(s) - support multiple
Complexity - support multiple
Do you understand how to estimate complexity? My idea was to get 'frequency in occurence'
POS(s) - support multiple, default - something like verb + noun + adj
 total limit (default like 20)

Show the full list of words and their corresponding annotations"

"I don't care for now, we're building python experimental scripts. If we can download them - already a win.
Don't care about license - wtf, we can simply generate all using free open source llm.
We need short simple definitions for everything"

"What the fuck is this?

uv run python -m scripts.word_dictionary_showcase --lang en --limit 50 --format table"

"What is a 'stopword list'?"

"ok, let's try that.

But also.. 

There's something really broken.

'a' is very common NOT because it is Ampere. 
'a' is very common because its an article. 

So how the fuck does our system labels it as a noun and defines as amperes?"

"en   │ out    │ verb │ 6.38 │ common     │ (baseball) a failure by a batter or    │ wordnet │
│      │        │      │      │            │ runner to reach a base safely in       │         │
│      │        │      │      │            │ baseball                               │         │

What's up with obscure definitions?"
