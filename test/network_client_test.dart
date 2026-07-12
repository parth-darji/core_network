import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' hide ProgressCallback;
import 'package:core_network/core_network.dart';
import 'package:core_network/src/data/http_network_client.dart';
import 'package:core_network/src/data/dio_network_client.dart';

@GenerateMocks([http.Client, Dio, ConnectionTracker, TokenProvider])
import 'network_client_test.mocks.dart';

void main() {
  group('HttpNetworkClient (package:http)', () {
    late MockClient mockClient;
    late MockConnectionTracker mockConnectionTracker;
    late MockTokenProvider mockTokenProvider;
    late HttpNetworkClient client;

    setUp(() {
      mockClient = MockClient();
      mockConnectionTracker = MockConnectionTracker();
      mockTokenProvider = MockTokenProvider();

      when(mockConnectionTracker.isConnected).thenAnswer((_) async => true);
      when(mockTokenProvider.getAccessToken()).thenAnswer((_) async => null);

      client = HttpNetworkClient.test(
        client: mockClient,
        interceptors: [
          ConnectionInterceptor(mockConnectionTracker),
          AuthInterceptor(mockTokenProvider),
        ],
      );
    });

    test(
      'GET request returns successful response data with default version path',
      () async {
        final responsePayload = {'id': 1, 'name': 'Test Item'};
        final responseBody = jsonEncode(responsePayload);

        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as http.BaseRequest;
          expect(request.url.path, equals('/v1/test'));
          expect(request.method, equals('GET'));

          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
            request: request,
          );
        });

        final result = await client.get<Map<String, dynamic>>('/test');

        expect(result['id'], equals(1));
        expect(result['name'], equals('Test Item'));
      },
    );

    test(
      'GET request with custom fully-qualified URL bypasses base URL and versioning',
      () async {
        final responsePayload = {'custom': true};
        final responseBody = jsonEncode(responsePayload);

        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as http.BaseRequest;
          expect(request.url.host, equals('custom-domain.com'));
          expect(request.url.path, equals('/api/data'));
          expect(request.method, equals('GET'));

          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
            request: request,
          );
        });

        final result = await client.get<Map<String, dynamic>>(
          'https://custom-domain.com/api/data',
        );

        expect(result['custom'], isTrue);
      },
    );

    test(
      'POST request sends payload and returns parsed response data',
      () async {
        final requestPayload = TestPayload({'key': 'value'});
        final responsePayload = {'success': true};
        final responseBody = jsonEncode(responsePayload);

        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request = invocation.positionalArguments.first as http.Request;
          expect(request.url.path, equals('/v1/submit'));
          expect(request.method, equals('POST'));
          expect(request.body, equals(jsonEncode({'key': 'value'})));

          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            201,
            request: request,
          );
        });

        final result = await client.post<Map<String, dynamic>>(
          '/submit',
          data: requestPayload,
        );

        expect(result['success'], isTrue);
      },
    );

    test(
      'PUT request sends payload and returns parsed response data',
      () async {
        final requestPayload = TestPayload({'key': 'updated_value'});
        final responsePayload = {'success': true, 'updated': true};
        final responseBody = jsonEncode(responsePayload);

        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request = invocation.positionalArguments.first as http.Request;
          expect(request.url.path, equals('/v1/update'));
          expect(request.method, equals('PUT'));
          expect(request.body, equals(jsonEncode({'key': 'updated_value'})));

          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
            request: request,
          );
        });

        final result = await client.put<Map<String, dynamic>>(
          '/update',
          data: requestPayload,
        );

        expect(result['success'], isTrue);
        expect(result['updated'], isTrue);
      },
    );

    test(
      'Throws ForbiddenException when PUT returns status code 403',
      () async {
        final requestPayload = TestPayload({'key': 'val'});
        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request = invocation.positionalArguments.first as http.Request;
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(jsonEncode({'error': 'Forbidden access'})),
            ),
            403,
            request: request,
          );
        });

        expect(
          () => client.put<dynamic>('/update', data: requestPayload),
          throwsA(isA<ForbiddenException>()),
        );
      },
    );

    test('Throws NotFoundException when PUT returns status code 404', () async {
      final requestPayload = TestPayload({'key': 'val'});
      when(mockClient.send(any)).thenAnswer((invocation) async {
        final request = invocation.positionalArguments.first as http.Request;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'error': 'Not Found'}))),
          404,
          request: request,
        );
      });

      expect(
        () => client.put<dynamic>('/update', data: requestPayload),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'DELETE request sends payload and returns parsed response data',
      () async {
        final requestPayload = TestPayload({'id': 123});
        final responsePayload = {'deleted': true};
        final responseBody = jsonEncode(responsePayload);

        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request = invocation.positionalArguments.first as http.Request;
          expect(request.url.path, equals('/v1/remove'));
          expect(request.method, equals('DELETE'));
          expect(request.body, equals(jsonEncode({'id': 123})));

          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            200,
            request: request,
          );
        });

        final result = await client.delete<Map<String, dynamic>>(
          '/remove',
          data: requestPayload,
        );

        expect(result['deleted'], isTrue);
      },
    );

    test(
      'Throws ForbiddenException when DELETE returns status code 403',
      () async {
        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request = invocation.positionalArguments.first as http.Request;
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': 'Forbidden'}))),
            403,
            request: request,
          );
        });

        expect(
          () => client.delete<dynamic>('/remove'),
          throwsA(isA<ForbiddenException>()),
        );
      },
    );

    test(
      'Throws NotFoundException when DELETE returns status code 404',
      () async {
        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request = invocation.positionalArguments.first as http.Request;
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': 'Not Found'}))),
            404,
            request: request,
          );
        });

        expect(
          () => client.delete<dynamic>('/remove'),
          throwsA(isA<NotFoundException>()),
        );
      },
    );

    test(
      'Multipart POST request uploads files and fields successfully',
      () async {
        final multipartPayload = MultipartPayload(
          fields: {'title': 'My Document'},
          files: {
            'file': [
              NetworkFile(
                bytes: utf8.encode('Hello File Content'),
                filename: 'test.txt',
                contentType: 'text/plain',
              ),
            ],
          },
        );

        final responsePayload = {'uploadId': '999'};
        final responseBody = jsonEncode(responsePayload);

        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as http.MultipartRequest;
          expect(request.url.path, equals('/v1/upload'));
          expect(request.method, equals('POST'));
          expect(request.fields['title'], equals('My Document'));
          expect(request.files.length, equals(1));
          expect(request.files.first.field, equals('file'));
          expect(request.files.first.filename, equals('test.txt'));

          // Consume the stream to simulate network sending
          await request.finalize().drain();

          return http.StreamedResponse(
            Stream.value(utf8.encode(responseBody)),
            201,
            request: request,
          );
        });

        final result = await client.post<Map<String, dynamic>>(
          '/upload',
          data: multipartPayload,
        );

        expect(result['uploadId'], equals('999'));
      },
    );

    test('onSendProgress tracking works for POST upload', () async {
      final requestPayload = TestPayload({'data': '1234567890'});
      final responseBody = jsonEncode({'success': true});
      final List<int> sentBytesList = [];
      final List<int> totalBytesList = [];

      when(mockClient.send(any)).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as http.BaseRequest;
        await request.finalize().drain();
        return http.StreamedResponse(
          Stream.value(utf8.encode(responseBody)),
          200,
          request: request,
        );
      });

      await client.post<dynamic>(
        '/test',
        data: requestPayload,
        onSendProgress: (sent, total) {
          sentBytesList.add(sent);
          totalBytesList.add(total);
        },
      );

      expect(sentBytesList.isNotEmpty, isTrue);
      expect(sentBytesList.last, equals(totalBytesList.last));
    });

    test('onReceiveProgress tracking works for GET download', () async {
      final responseBody = 'Chunk1Chunk2Chunk3';
      final List<int> receivedBytesList = [];
      final List<int> totalBytesList = [];

      when(mockClient.send(any)).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as http.BaseRequest;
        return http.StreamedResponse(
          Stream.fromIterable([
            utf8.encode('Chunk1'),
            utf8.encode('Chunk2'),
            utf8.encode('Chunk3'),
          ]),
          200,
          contentLength: responseBody.length,
          request: request,
        );
      });

      await client.get<String>(
        '/test',
        onReceiveProgress: (received, total) {
          receivedBytesList.add(received);
          totalBytesList.add(total);
        },
      );

      expect(receivedBytesList, containsAll([6, 12, 18]));
      expect(totalBytesList.last, equals(18));
    });

    test(
      'Throws NoInternetException when ConnectionTracker is offline',
      () async {
        when(mockConnectionTracker.isConnected).thenAnswer((_) async => false);

        expect(
          () => client.get<dynamic>('/test'),
          throwsA(isA<NoInternetException>()),
        );
      },
    );

    test('Throws customized NoInternetException with custom message', () async {
      final customClient = HttpNetworkClient.test(
        client: mockClient,
        interceptors: [
          ConnectionInterceptor(
            mockConnectionTracker,
            message: 'Custom offline message',
          ),
        ],
      );

      when(mockConnectionTracker.isConnected).thenAnswer((_) async => false);

      try {
        await customClient.get<dynamic>('/test');
        fail('Should throw NoInternetException');
      } on NoInternetException catch (e) {
        expect(e.message, equals('Custom offline message'));
      }
    });

    test(
      'Throws silent NoInternetException when defaultSilentExceptions is configured',
      () async {
        final silentClient = HttpNetworkClient.test(
          client: mockClient,
          defaultSilentExceptions: {NoInternetException},
          interceptors: [ConnectionInterceptor(mockConnectionTracker)],
        );

        when(mockConnectionTracker.isConnected).thenAnswer((_) async => false);

        try {
          await silentClient.get<dynamic>('/test');
          fail('Should throw NoInternetException');
        } on NoInternetException catch (e) {
          expect(e.isSilent, isTrue);
        }
      },
    );

    test(
      'Throws AssertionError when request path is relative and does not start with slash',
      () async {
        expect(
          () => client.get<dynamic>('test'),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('Throws UnauthorizedException when status code is 401', () async {
      final errorPayload = {'message': 'Invalid session token'};

      when(mockClient.send(any)).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as http.BaseRequest;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(errorPayload))),
          401,
          request: request,
        );
      });

      expect(
        () => client.get<dynamic>('/test'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Invalid session token',
          ),
        ),
      );
    });

    test('Throws ServerException when status code is 500', () async {
      when(mockClient.send(any)).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as http.BaseRequest;
        return http.StreamedResponse(
          Stream.value(utf8.encode('Internal Server Error')),
          500,
          request: request,
        );
      });

      expect(
        () => client.get<dynamic>('/test'),
        throwsA(isA<ServerException>()),
      );
    });

    test('Throws NetworkException with parsed nested validation error message lists', () async {
      final errorPayload = {
        'success': false,
        'error': {
          'code': 'BAD_REQUEST',
          'message': ['vendorId must be a UUID', 'projectId must be a UUID'],
          'timestamp': '2026-07-12T04:22:19.336Z',
          'path': '/purchase-orders'
        }
      };

      when(mockClient.send(any)).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as http.BaseRequest;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(errorPayload))),
          400,
          request: request,
        );
      });

      expect(
        () => client.get<dynamic>('/test'),
        throwsA(
          isA<UnknownNetworkException>().having(
            (e) => e.message,
            'message',
            'vendorId must be a UUID, projectId must be a UUID',
          ),
        ),
      );
    });

    test(
      'Throws exception with isSilent set to true when silentExceptions contains the exception type',
      () async {
        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as http.BaseRequest;
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(jsonEncode({'message': 'Forbidden access details'})),
            ),
            403,
            request: request,
          );
        });

        try {
          await client.get<dynamic>(
            '/test',
            silentExceptions: {ForbiddenException},
          );
          fail('Expected ForbiddenException');
        } on NetworkException catch (e) {
          expect(e.isSilent, isTrue);
          expect(e, isA<ForbiddenException>());
        }
      },
    );

    test(
      'Injects Authorization bearer header when TokenProvider returns a valid token',
      () async {
        when(
          mockTokenProvider.getAccessToken(),
        ).thenAnswer((_) async => 'valid_access_token');

        when(mockClient.send(any)).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as http.BaseRequest;
          expect(
            request.headers['Authorization'],
            equals('Bearer valid_access_token'),
          );

          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'success': true}))),
            200,
            request: request,
          );
        });

        final result = await client.get<Map<String, dynamic>>('/test');
        expect(result['success'], isTrue);
      },
    );
  });

  group('DioNetworkClient (package:dio)', () {
    late MockDio mockDio;
    late MockConnectionTracker mockConnectionTracker;
    late MockTokenProvider mockTokenProvider;
    late DioNetworkClient client;

    setUp(() {
      mockDio = MockDio();
      mockConnectionTracker = MockConnectionTracker();
      mockTokenProvider = MockTokenProvider();

      when(mockConnectionTracker.isConnected).thenAnswer((_) async => true);
      when(mockTokenProvider.getAccessToken()).thenAnswer((_) async => null);
      when(mockDio.interceptors).thenReturn(Interceptors());

      client = DioNetworkClient.test(
        dio: mockDio,
        interceptors: [
          ConnectionInterceptor(mockConnectionTracker),
          AuthInterceptor(mockTokenProvider),
        ],
      );
    });

    test(
      'GET request returns successful response data with default version path',
      () async {
        final responsePayload = {'id': 1, 'name': 'Test Item'};

        when(
          mockDio.get<dynamic>(
            any,
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            data: responsePayload,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/v1/test'),
          ),
        );

        final result = await client.get<Map<String, dynamic>>('/test');

        expect(result['id'], equals(1));
        expect(result['name'], equals('Test Item'));
        verify(
          mockDio.get<dynamic>(
            '/v1/test',
            queryParameters: null,
            options: anyNamed('options'),
          ),
        ).called(1);
      },
    );

    test(
      'GET request with custom fully-qualified URL bypasses versioning path',
      () async {
        final responsePayload = {'custom': true};

        when(
          mockDio.get<dynamic>(
            any,
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            data: responsePayload,
            statusCode: 200,
            requestOptions: RequestOptions(
              path: 'https://custom-domain.com/api/data',
            ),
          ),
        );

        final result = await client.get<Map<String, dynamic>>(
          'https://custom-domain.com/api/data',
        );

        expect(result['custom'], isTrue);
        verify(
          mockDio.get<dynamic>(
            'https://custom-domain.com/api/data',
            queryParameters: null,
            options: anyNamed('options'),
          ),
        ).called(1);
      },
    );

    test(
      'POST request sends payload and returns parsed response data',
      () async {
        final requestPayload = TestPayload({'key': 'value'});
        final responsePayload = {'success': true};

        when(
          mockDio.post<dynamic>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onSendProgress: anyNamed('onSendProgress'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            data: responsePayload,
            statusCode: 201,
            requestOptions: RequestOptions(path: '/v1/submit'),
          ),
        );

        final result = await client.post<Map<String, dynamic>>(
          '/submit',
          data: requestPayload,
        );

        expect(result['success'], isTrue);
      },
    );

    test(
      'PUT request sends payload and returns parsed response data',
      () async {
        final requestPayload = TestPayload({'key': 'updated'});
        final responsePayload = {'success': true};

        when(
          mockDio.put<dynamic>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onSendProgress: anyNamed('onSendProgress'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            data: responsePayload,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/v1/update'),
          ),
        );

        final result = await client.put<Map<String, dynamic>>(
          '/update',
          data: requestPayload,
        );

        expect(result['success'], isTrue);
      },
    );

    test(
      'Throws ForbiddenException when PUT returns status code 403',
      () async {
        final requestPayload = TestPayload({'key': 'val'});

        when(
          mockDio.put<dynamic>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onSendProgress: anyNamed('onSendProgress'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenThrow(
          DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 403,
              data: {'error': 'Forbidden'},
              requestOptions: RequestOptions(path: '/v1/update'),
            ),
            requestOptions: RequestOptions(path: '/v1/update'),
          ),
        );

        expect(
          () => client.put<dynamic>('/update', data: requestPayload),
          throwsA(isA<ForbiddenException>()),
        );
      },
    );

    test('Throws NotFoundException when PUT returns status code 404', () async {
      final requestPayload = TestPayload({'key': 'val'});

      when(
        mockDio.put<dynamic>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onSendProgress: anyNamed('onSendProgress'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 404,
            data: {'error': 'Not Found'},
            requestOptions: RequestOptions(path: '/v1/update'),
          ),
          requestOptions: RequestOptions(path: '/v1/update'),
        ),
      );

      expect(
        () => client.put<dynamic>('/update', data: requestPayload),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'DELETE request sends payload and returns parsed response data',
      () async {
        final requestPayload = TestPayload({'id': 123});
        final responsePayload = {'deleted': true};

        when(
          mockDio.delete<dynamic>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            data: responsePayload,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/v1/remove'),
          ),
        );

        final result = await client.delete<Map<String, dynamic>>(
          '/remove',
          data: requestPayload,
        );

        expect(result['deleted'], isTrue);
      },
    );

    test(
      'Throws ForbiddenException when DELETE returns status code 403',
      () async {
        when(
          mockDio.delete<dynamic>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenThrow(
          DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 403,
              data: {'error': 'Forbidden'},
              requestOptions: RequestOptions(path: '/v1/remove'),
            ),
            requestOptions: RequestOptions(path: '/v1/remove'),
          ),
        );

        expect(
          () => client.delete<dynamic>('/remove'),
          throwsA(isA<ForbiddenException>()),
        );
      },
    );

    test(
      'Throws NotFoundException when DELETE returns status code 404',
      () async {
        when(
          mockDio.delete<dynamic>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenThrow(
          DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 404,
              data: {'error': 'Not Found'},
              requestOptions: RequestOptions(path: '/v1/remove'),
            ),
            requestOptions: RequestOptions(path: '/v1/remove'),
          ),
        );

        expect(
          () => client.delete<dynamic>('/remove'),
          throwsA(isA<NotFoundException>()),
        );
      },
    );

    test(
      'Multipart POST request uploads files and fields successfully',
      () async {
        final multipartPayload = MultipartPayload(
          fields: {'title': 'My Document'},
          files: {
            'file': [
              NetworkFile(
                bytes: utf8.encode('Hello File Content'),
                filename: 'test.txt',
                contentType: 'text/plain',
              ),
            ],
          },
        );

        final responsePayload = {'uploadId': '999'};

        when(
          mockDio.post<dynamic>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onSendProgress: anyNamed('onSendProgress'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenAnswer((invocation) async {
          final data = invocation.namedArguments[#data];
          expect(data, isA<FormData>());
          final formData = data as FormData;
          expect(formData.fields.first.key, equals('title'));
          expect(formData.fields.first.value, equals('My Document'));
          expect(formData.files.first.key, equals('file'));
          expect(formData.files.first.value.filename, equals('test.txt'));

          return Response<dynamic>(
            data: responsePayload,
            statusCode: 201,
            requestOptions: RequestOptions(path: '/v1/upload'),
          );
        });

        final result = await client.post<Map<String, dynamic>>(
          '/upload',
          data: multipartPayload,
        );

        expect(result['uploadId'], equals('999'));
      },
    );

    test('onSendProgress tracking works for POST upload', () async {
      final requestPayload = TestPayload({'data': '12345'});

      when(
        mockDio.post<dynamic>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onSendProgress: anyNamed('onSendProgress'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final progressCallback =
            invocation.namedArguments[#onSendProgress] as ProgressCallback?;
        progressCallback?.call(50, 100);
        return Response<dynamic>(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/v1/test'),
        );
      });

      bool progressCalled = false;
      await client.post<dynamic>(
        '/test',
        data: requestPayload,
        onSendProgress: (sent, total) {
          progressCalled = true;
          expect(sent, equals(50));
          expect(total, equals(100));
        },
      );

      expect(progressCalled, isTrue);
    });

    test('onReceiveProgress tracking works for GET download', () async {
      when(
        mockDio.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final progressCallback =
            invocation.namedArguments[#onReceiveProgress] as ProgressCallback?;
        progressCallback?.call(25, 100);
        return Response<dynamic>(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/v1/test'),
        );
      });

      bool progressCalled = false;
      await client.get<dynamic>(
        '/test',
        onReceiveProgress: (received, total) {
          progressCalled = true;
          expect(received, equals(25));
          expect(total, equals(100));
        },
      );

      expect(progressCalled, isTrue);
    });

    test(
      'Throws NoInternetException when ConnectionTracker is offline',
      () async {
        when(mockConnectionTracker.isConnected).thenAnswer((_) async => false);

        when(
          mockDio.get<dynamic>(
            any,
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenThrow(
          DioException(
            type: DioExceptionType.connectionError,
            requestOptions: RequestOptions(path: '/v1/test'),
          ),
        );

        expect(
          () => client.get<dynamic>('/test'),
          throwsA(isA<NoInternetException>()),
        );
      },
    );

    test(
      'Throws AssertionError when relative path does not start with a slash',
      () async {
        expect(
          () => client.get<dynamic>('test'),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('Throws TimeoutException when Dio throws timeout error', () async {
      when(
        mockDio.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.connectionTimeout,
          message: 'Timeout occurred',
          requestOptions: RequestOptions(path: '/v1/test'),
        ),
      );

      expect(
        () => client.get<dynamic>('/test'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('Throws UnauthorizedException when status code is 401', () async {
      when(
        mockDio.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 401,
            data: {'message': 'Invalid session token'},
            requestOptions: RequestOptions(path: '/v1/test'),
          ),
          requestOptions: RequestOptions(path: '/v1/test'),
        ),
      );

      expect(
        () => client.get<dynamic>('/test'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Invalid session token',
          ),
        ),
      );
    });

    test('Throws ServerException when status code is 500', () async {
      when(
        mockDio.get<dynamic>(
          any,
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            data: 'Internal Server Error',
            requestOptions: RequestOptions(path: '/v1/test'),
          ),
          requestOptions: RequestOptions(path: '/v1/test'),
        ),
      );

      expect(
        () => client.get<dynamic>('/test'),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'Throws exception with isSilent set to true when silentExceptions contains the exception type',
      () async {
        when(
          mockDio.get<dynamic>(
            any,
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenThrow(
          DioException(
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 403,
              data: {'message': 'Forbidden access details'},
              requestOptions: RequestOptions(path: '/v1/test'),
            ),
            requestOptions: RequestOptions(path: '/v1/test'),
          ),
        );

        try {
          await client.get<dynamic>(
            '/test',
            silentExceptions: {ForbiddenException},
          );
          fail('Expected ForbiddenException');
        } on NetworkException catch (e) {
          expect(e.isSilent, isTrue);
          expect(e, isA<ForbiddenException>());
        }
      },
    );

    test(
      'Throws silent NoInternetException when defaultSilentExceptions is configured',
      () async {
        final silentClient = DioNetworkClient.test(
          dio: mockDio,
          defaultSilentExceptions: {NoInternetException},
          interceptors: [],
        );

        when(
          mockDio.get<dynamic>(
            any,
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenThrow(
          DioException(
            type: DioExceptionType.connectionError,
            requestOptions: RequestOptions(path: '/v1/test'),
          ),
        );

        try {
          await silentClient.get<dynamic>('/test');
          fail('Should throw NoInternetException');
        } on NoInternetException catch (e) {
          expect(e.isSilent, isTrue);
        }
      },
    );
  });

  group('ConnectionInterceptor', () {
    late MockConnectionTracker mockConnectionTracker;

    setUp(() {
      mockConnectionTracker = MockConnectionTracker();
    });

    test(
      'onRequest throws NoInternetException with custom message if offline',
      () async {
        final interceptor = ConnectionInterceptor(
          mockConnectionTracker,
          message: 'Custom offline message',
        );

        when(mockConnectionTracker.isConnected).thenAnswer((_) async => false);

        expect(
          () => interceptor.onRequest('/test', {}, {}),
          throwsA(
            isA<NoInternetException>().having(
              (e) => e.message,
              'message',
              equals('Custom offline message'),
            ),
          ),
        );
      },
    );

    test('onRequest does not throw when online', () async {
      final interceptor = ConnectionInterceptor(mockConnectionTracker);
      when(mockConnectionTracker.isConnected).thenAnswer((_) async => true);
      await expectLater(interceptor.onRequest('/test', {}, {}), completes);
    });
  });

  group('CoreNetwork factory assertions', () {
    late MockConnectionTracker mockConnectionTracker;
    late MockTokenProvider mockTokenProvider;

    setUp(() {
      mockConnectionTracker = MockConnectionTracker();
      mockTokenProvider = MockTokenProvider();
    });

    test(
      'AssertionError is thrown when ConnectionInterceptor is not the first element',
      () async {
        expect(
          () => CoreNetwork.dio(
            baseUrl: 'https://api.test.com',
            interceptors: [
              AuthInterceptor(mockTokenProvider),
              ConnectionInterceptor(mockConnectionTracker),
            ],
          ),
          throwsA(isA<AssertionError>()),
        );

        expect(
          () => CoreNetwork.http(
            baseUrl: 'https://api.test.com',
            interceptors: [
              AuthInterceptor(mockTokenProvider),
              ConnectionInterceptor(mockConnectionTracker),
            ],
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test(
      'No assertion error is thrown when ConnectionInterceptor is the first element',
      () async {
        expect(
          () => CoreNetwork.dio(
            baseUrl: 'https://api.test.com',
            interceptors: [
              ConnectionInterceptor(mockConnectionTracker),
              AuthInterceptor(mockTokenProvider),
            ],
          ),
          returnsNormally,
        );

        expect(
          () => CoreNetwork.http(
            baseUrl: 'https://api.test.com',
            interceptors: [
              ConnectionInterceptor(mockConnectionTracker),
              AuthInterceptor(mockTokenProvider),
            ],
          ),
          returnsNormally,
        );
      },
    );
  });
}

class TestPayload implements NetworkRequestPayload {
  final Map<String, Object> data;
  const TestPayload(this.data);

  @override
  Object toBody() => data;
}
