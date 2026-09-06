from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    Path('test/core/extensions/providers/animewitcher_apk_sources_test.dart'),
    """      <String>[
        'objectID',
        'name',
        'poster_uri',
        'order',
        'path',
        'type',
        'poster',
        'tags',
      ],
""",
    """      <String>[
        'objectID',
        'name',
        'poster_uri',
        'order',
        'path',
        'type',
        'poster',
        'tags',
        'details',
        'mal_id',
        'malId',
        'rating',
      ],
""",
    'similar-title rating attributes',
)

replace_once(
    Path('test/core/extensions/providers/animewitcher_upcoming_unaired_test.dart'),
    """      <String>[
        'objectID',
        'name',
        'tags',
        'poster_uri',
        'order',
        'path',
        'type',
        'poster',
        'aniList_poster',
        'details',
        'dubbed',
      ],
""",
    """      <String>[
        'objectID',
        'name',
        'tags',
        'poster_uri',
        'order',
        'path',
        'type',
        'poster',
        'aniList_poster',
        'details',
        'mal_id',
        'malId',
        'rating',
        'dubbed',
      ],
""",
    'coming-soon rating attributes',
)

print('catalog rating attribute expectations updated')
