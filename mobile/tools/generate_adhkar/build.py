"""Builds assets/data/adhkar.json from Hisn al-Muslim.

Two published copies of the book are combined, because neither has
everything:

* hisnmuslim.com's API (http://www.hisnmuslim.com/api/ar/<chapter>.json)
  has the texts with full tashkeel and the repeat counts, but no
  references.
* github.com/rn0x/hisn_almuslim_json (commit 0405ee1) has the book's
  footnotes (al-hashiya): references, and the virtue (fadl) where the book
  gives one, but texts without tashkeel.

Texts and counts come from the first, references and virtues from the
second. A footnote is only taken when the letters of both texts match
(MIN_MATCH) or when this file maps it by hand (FOOTNOTES). Nothing is
reworded: the only changes are whitespace, runs of tatweel, and splitting
a footnote into its virtue and its reference at the citation.

Quranic duas are stored as verse ranges; the app reads their text from its
own Mushaf data, so no verse is retyped.

Usage (each download in its own folder):
  python -I build.py <hisnmuslim dir> <rn0x dir> <out.json>
<hisnmuslim dir> holds husn_ar.json and c<ID>.json for each chapter used
below; <rn0x dir> holds hisn.json.
"""
import difflib
import json
import os
import re
import sys

MIN_MATCH = 0.85

# rn0x chapter titles that differ too much from hisnmuslim.com's.
RN_TITLE = {
    95: 'دعاء ركوب الدابة',
}

# Chapters whose footnotes are not one per text: chapter -> the footnote
# indices of each text, in order. Footnotes left out are word glosses, the
# evening wording (already inside the text) or narrative context.
FOOTNOTES = {
    1: [[2], [5], [3], [6]],
    # The second footnote begins "وزاد الترمذي…", so the letters don't match.
    9: [[0], [1], [2]],
    12: [[0, 1, 2, 3]],
    13: [[0, 1, 2, 3]],
    26: [[0, 1]],
    27: [[1], [2], [5], [7], [9], [11], [13], [14], [15], [16], [17], [18],
         [19], [20], [23], [25], [26], [27, 28], [29], [30], [31], [32],
         [33], [34]],
    28: [[0], [1], [2], [4], [5], [7], [8], [9], [10], [11], [12], [13],
         [15]],
}

# Where a footnote's citation starts.
CITATION = re.compile(
    r'و?(أخرجه|رواه|رواة|والبخاري|البخاري|مسلم|أبو داود|أبي داود|الترمذي|'
    r'أحمد|النسائي|ابن ماجه|الحاكم|ابن السني|الطبراني|ابن حبان|أهل السنن|'
    r'أصحاب السنن|سورة|الآيات)')
# Footnotes whose virtue and citation the rule below would cut in the
# wrong place: (chapter, footnote) -> (virtue, reference), each an exact
# piece of the footnote.
SPLITS = {
    (27, 1): ('من قالها حين يمسي أجير منهم حتى يصبح',
              'أخرجه الحاكم 1/ 562وصححه الألباني في صحيح الترغيب والترهيب 1/ 273'
              ' وعزاه إلى النسائي والطبراني وقال : وإسناد الطبراني جيد'),
    (25, 3): ('من قال ذلك دبر كل صلاة غفرت خطاياه وإن كانت مثل زبد البحر',
              'مسلم 1/ 418'),
    (49, 1): ('ما من عبد مسلم يعود مريضاً لم يحضر أجله فيقول: سبع مرات'
              '.....الحديث إلا عوفي',
              'أخرجه الترمذي وأبو داود وانظر صحيح الترمذي2/ 210 وصحيح الجامع 5/180'),
}

# A footnote that opens with one of these states the virtue first.
VIRTUE_OPENERS = ('من ', 'ما من ', 'قال صلى الله عليه وسلم')

CATEGORIES = [
    dict(id='morning', group='day', icon='sunrise', tone='yellow',
         title='أذكار الصباح', titleEn='Morning adhkar',
         chapters=[27], drop=[(27, 22)]),  # "when evening comes" only
    dict(id='evening', group='day', icon='moon', tone='indigo',
         title='أذكار المساء', titleEn='Evening adhkar',
         chapters=[27], drop=[(27, 18), (27, 19), (27, 20)]),  # morning only
    dict(id='after_prayer', group='day', icon='prayer', tone='teal',
         title='أذكار بعد الصلاة', titleEn='After prayer',
         chapters=[25]),
    dict(id='sleep', group='day', icon='bed', tone='purple',
         title='أذكار النوم', titleEn='Before sleep',
         chapters=[28, 29]),
    dict(id='waking', group='day', icon='sun', tone='orange',
         title='أذكار الاستيقاظ', titleEn='On waking up',
         chapters=[1]),
    dict(id='home', group='places', icon='house', tone='green',
         title='دخول المنزل والخروج منه', titleEn='Entering and leaving home',
         chapters=[11, 10]),
    dict(id='mosque', group='places', icon='mosque', tone='teal',
         title='دخول المسجد والخروج منه', titleEn='The mosque',
         chapters=[12, 13, 14]),
    dict(id='wudu', group='places', icon='drop', tone='blue',
         title='الوضوء', titleEn='Ablution',
         chapters=[8, 9]),
    dict(id='food', group='places', icon='food', tone='pink',
         title='الطعام والشراب', titleEn='Food and drink',
         chapters=[69, 70, 71, 68]),
    dict(id='travel', group='travel', icon='airplane', tone='blue',
         title='دعاء السفر', titleEn='Travel',
         chapters=[96, 97, 102, 103, 104, 100, 101, 105]),
    dict(id='riding', group='travel', icon='car', tone='orange',
         title='دعاء الركوب', titleEn='Riding',
         chapters=[95, 99]),
    dict(id='distress', group='duas', icon='heart', tone='red',
         title='دعاء الكرب والهم والحزن', titleEn='Distress and worry',
         chapters=[34, 35, 43]),
    dict(id='istikhara', group='duas', icon='compass', tone='green',
         title='دعاء الاستخارة', titleEn='Istikhara',
         chapters=[26]),
    dict(id='weather', group='duas', icon='cloud', tone='indigo',
         title='دعاء المطر والريح', titleEn='Rain and wind',
         chapters=[61, 62, 63, 64, 65, 66]),
    dict(id='sick', group='duas', icon='bandage', tone='pink',
         title='عيادة المريض', titleEn='Visiting the sick',
         chapters=[49, 50]),
    dict(id='quran', group='duas', icon='book', tone='teal',
         title='أدعية من القرآن الكريم', titleEn='Duas from the Quran',
         verses=[
             (2, 127, 127), (2, 128, 128), (2, 201, 201), (2, 250, 250),
             (2, 286, 286), (3, 8, 8), (3, 16, 16), (3, 38, 38),
             (3, 53, 53), (3, 147, 147), (3, 193, 194), (7, 23, 23),
             (14, 40, 41), (17, 24, 24), (17, 80, 80), (18, 10, 10),
             (20, 25, 28), (20, 114, 114), (21, 87, 87), (21, 89, 89),
             (23, 29, 29), (23, 97, 98), (23, 109, 109), (23, 118, 118),
             (25, 65, 65), (25, 74, 74), (26, 83, 83), (27, 19, 19),
             (28, 16, 16), (28, 24, 24), (46, 15, 15), (59, 10, 10),
             (66, 8, 8), (71, 28, 28),
         ]),
    dict(id='prophetic', group='duas', icon='sparkle', tone='purple',
         title='أدعية نبوية جامعة', titleEn='Comprehensive prophetic duas',
         chapters=[24]),
]

SURAHS = {
    2: 'البقرة', 3: 'آل عمران', 7: 'الأعراف', 14: 'إبراهيم', 17: 'الإسراء',
    18: 'الكهف', 20: 'طه', 21: 'الأنبياء', 23: 'المؤمنون', 25: 'الفرقان',
    26: 'الشعراء', 27: 'النمل', 28: 'القصص', 46: 'الأحقاف', 59: 'الحشر',
    66: 'التحريم', 71: 'نوح',
}

# Counts the text itself states, checked against the API's REPEAT.
SPOKEN_COUNTS = [('ثلاثمرات', 3), ('اربعمرات', 4), ('سبعمرات', 7),
                 ('عشرمرات', 10), ('مائهمره', 100)]


def skeleton(text):
    text = re.sub(r'[ً-ْٰـ]', '', text)
    text = re.sub(r'[^ء-ي]', '', text)
    for a, b in (('أ', 'ا'), ('إ', 'ا'), ('آ', 'ا'), ('ى', 'ي'), ('ة', 'ه')):
        text = text.replace(a, b)
    return text


def clean(text):
    text = re.sub('ـ{2,}', '', text)
    # A harakah stranded between spaces carries no letter.
    text = re.sub(r'\s+[ً-ْ]+(?=\s)', '', text)
    text = text.replace('‌', '').replace('﻿', '')
    return re.sub(r'\s+', ' ', text).strip()


def split_footnote(cid, k, note):
    """(virtue or None, reference) of footnote [k] of chapter [cid]."""
    note = clean(note)
    if (cid, k) in SPLITS:
        virtue, ref = SPLITS[(cid, k)]
        assert virtue in note and ref in note, (cid, k)
        return virtue, ref
    m = CITATION.search(note)
    if m and m.start() > 0 and note.startswith(VIRTUE_OPENERS):
        return note[:m.start()].strip(' .،,'), note[m.start():].strip(' .')
    return None, note.strip(' .')


def main(hisn_dir, rn_dir, out_path):
    index = json.load(open(os.path.join(hisn_dir, 'husn_ar.json'),
                           encoding='utf-8-sig'))['العربية']
    titles = {c['ID']: clean(c['TITLE']) for c in index}
    rn = json.load(open(os.path.join(rn_dir, 'hisn.json'),
                        encoding='utf-8-sig'))

    def rn_chapter(cid):
        name = RN_TITLE.get(cid) or max(
            rn, key=lambda k: difflib.SequenceMatcher(
                None, skeleton(k), skeleton(titles[cid])).ratio())
        return rn[name]

    report = []
    categories = []
    for cat in CATEGORIES:
        items = []
        for surah, start, end in cat.get('verses', []):
            ayahs = str(start) if start == end else f'{start}–{end}'
            items.append({
                'quran': {'surah': surah, 'from': start, 'to': end},
                'count': 1,
                'reference': f'سورة {SURAHS[surah]}، {ayahs}',
            })
        chapters = cat.get('chapters', [])
        for cid in chapters:
            data = json.load(open(os.path.join(hisn_dir, f'c{cid}.json'),
                                  encoding='utf-8-sig'))
            texts = list(data.values())[0]
            source = rn_chapter(cid)
            notes = source['footnote']
            for i, entry in enumerate(texts):
                if (cid, i) in cat.get('drop', []):
                    continue
                text = clean(entry['ARABIC_TEXT'])
                count = int(entry['REPEAT']) or 1
                sk = skeleton(text)
                for word, n in SPOKEN_COUNTS:
                    if word in sk and n != count:
                        report.append(f'{cat["id"]} c{cid}#{i}: count '
                                      f'{count} -> {n} (stated in the text)')
                        count = n
                if cid in FOOTNOTES:
                    picked = FOOTNOTES[cid][i]
                else:
                    ratio = difflib.SequenceMatcher(
                        None, sk, skeleton(source['text'][i])
                    ).ratio() if i < len(source['text']) else 0
                    if ratio < MIN_MATCH or len(notes) != len(texts):
                        report.append(f'{cat["id"]} c{cid}#{i}: no reference '
                                      f'(match {ratio:.2f})')
                        picked = []
                    else:
                        picked = [i]
                virtues, refs = [], []
                for k in picked:
                    virtue, ref = split_footnote(cid, k, notes[k])
                    if virtue:
                        virtues.append(virtue)
                    refs.append(ref)
                item = {'text': text, 'count': count}
                if virtues:
                    item['fadl'] = '، '.join(virtues)
                if refs:
                    item['reference'] = '؛ '.join(refs)
                if len(chapters) > 1:
                    item['occasion'] = titles[cid]
                item['hisn'] = {'chapter': cid, 'id': entry['ID']}
                items.append(item)
        categories.append(
            {k: cat[k] for k in ('id', 'group', 'title', 'titleEn', 'icon',
                                 'tone')} | {'items': items})

    out = {
        'version': 1,
        'source': {
            'book': 'حصن المسلم من أذكار الكتاب والسنة، سعيد بن علي بن وهف القحطاني',
            'texts': 'http://www.hisnmuslim.com/api/ar/',
            'footnotes': 'https://github.com/rn0x/hisn_almuslim_json/blob/'
                         '0405ee1797c2ccadfe82cd41845338d54978ccb9/'
                         'hisn_almuslim.json',
        },
        'categories': categories,
    }
    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write('\n')
    for line in report:
        print(line)
    print(sum(len(c['items']) for c in categories), 'items in',
          len(categories), 'categories')


if __name__ == '__main__':
    main(*sys.argv[1:4])
