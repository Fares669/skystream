import 'package:animewitcher/core/extensions/providers/animewitcher_native_provider.dart';
import 'package:animewitcher/core/storage/settings_repository.dart';
import 'package:animewitcher/core/storage/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestStorageService extends StorageService {
  @override
  bool isHighQualityPostersEnabled() => false;

  @override
  bool isEpisodeImagesFromAniZipEnabled() => false;
}

Map<String, dynamic> _stringField(String value) => <String, dynamic>{
  'stringValue': value,
};

Map<String, dynamic> _doubleField(double value) => <String, dynamic>{
  'doubleValue': value,
};

Map<String, dynamic> _intField(int value) => <String, dynamic>{
  'integerValue': '$value',
};

Map<String, dynamic> _boolField(bool value) => <String, dynamic>{
  'booleanValue': value,
};

Map<String, dynamic> _mapField(Map<String, dynamic> fields) =>
    <String, dynamic>{
      'mapValue': <String, dynamic>{'fields': fields},
    };

Dio _stubDio(Map<String, dynamic> animeFields) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'name':
                  'projects/animewitcher-1c66d/databases/(default)/documents/anime_list/rated-show',
              'fields': animeFields,
            },
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  const url = 'https://animewitcher.com/anime/rated-show';

  test('details score uses rating.rate and not average_rate', () async {
    final provider = AnimeWitcherNativeProvider(
      _stubDio(<String, dynamic>{
        'name': _stringField('Rated Show'),
        'average_rate': _doubleField(1.23),
        'mal_id': _stringField('20'),
        'imdb_id': _stringField('tt0409591'),
        'reviews_closed': _boolField(false),
        'rating': _mapField(<String, dynamic>{
          'rate': _doubleField(9.1),
          'num': _intField(42),
        }),
        'details': _mapField(<String, dynamic>{
          'mal_mean': _doubleField(8.73),
          'mal_num_scoring_users': _intField(668508),
          'imdb_rate': _doubleField(7.8),
          'state': _stringField('مستمر'),
        }),
      }),
      SettingsRepository(_TestStorageService()),
    );

    final item = await provider.getDetails(url);
    expect(item.syncData?['awScore'], '9.1');
    expect(item.syncData?['awScoreCount'], '42');
    expect(item.syncData?['awMalScore'], '8.73');
    expect(item.syncData?['awMalScoringUsers'], '668508');
    expect(item.syncData?['awImdbId'], 'tt0409591');
    expect(item.syncData?['awImdbScore'], '7.8');
    expect(item.imdbId, 'tt0409591');
    expect(item.syncData?['awScore'], isNot('1.23'));
  });

  test('omits a Witcher vote count when rating.num is absent', () async {
    final provider = AnimeWitcherNativeProvider(
      _stubDio(<String, dynamic>{
        'name': _stringField('Rated Show'),
        'average_rate': _doubleField(9.9),
        'rating': _mapField(<String, dynamic>{'rate': _doubleField(7.5)}),
        'details': _mapField(<String, dynamic>{
          'state': _stringField('لم يتم بثه بعد'),
        }),
      }),
      SettingsRepository(_TestStorageService()),
    );

    final item = await provider.getDetails(url);
    expect(item.syncData?['awScore'], '7.5');
    expect(item.syncData?.containsKey('awScoreCount'), isFalse);
    expect(item.syncData?['awState'], 'لم يتم بثه بعد');
  });

  test('maps IMDb score for animation details without MAL', () async {
    final provider = AnimeWitcherNativeProvider(
      _stubDio(<String, dynamic>{
        'name': _stringField('The Legend of Tarzan'),
        'imdb_id': _stringField('tt0283754'),
        'rating': _mapField(<String, dynamic>{'rate': _doubleField(8.37)}),
        'details': _mapField(<String, dynamic>{
          'imdb_rate': _doubleField(7.4),
          'state': _stringField('مكتمل'),
        }),
      }),
      SettingsRepository(_TestStorageService()),
    );

    final item = await provider.getDetails(url);
    expect(item.syncData?['awMalScore'], isNull);
    expect(item.syncData?['awImdbId'], 'tt0283754');
    expect(item.syncData?['awImdbScore'], '7.4');
  });

  test('maps reviews_closed from the anime document', () async {
    final provider = AnimeWitcherNativeProvider(
      _stubDio(<String, dynamic>{
        'name': _stringField('Rated Show'),
        'reviews_closed': _boolField(true),
        'rating': _mapField(<String, dynamic>{'rate': _doubleField(6)}),
      }),
      SettingsRepository(_TestStorageService()),
    );

    final item = await provider.getDetails(url);
    expect(item.syncData?['awReviewsClosed'], 'true');
  });
}
