import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../../../../domain/cloud_sync/cloud_sync_models.dart';
import '../../../../domain/cloud_sync/cloud_sync_provider.dart';

class WebDavSyncProvider implements CloudSyncProvider {
  WebDavSyncProvider({
    required Future<WebDavConfig?> Function() loadConfig,
  }) : _loadConfig = loadConfig;

  final Future<WebDavConfig?> Function() _loadConfig;

  @override
  CloudSyncProviderType get providerType => CloudSyncProviderType.webdav;

  @override
  String get displayName => 'WebDAV';

  @override
  Future<bool> isConfigured() async {
    final config = await _loadConfig();
    return config != null && config.baseUrl.trim().isNotEmpty;
  }

  @override
  Future<void> validateConnection() async {
    final config = await _requiredConfig();
    await validateConnectionWithConfig(config);
  }

  Future<void> validateConnectionWithConfig(WebDavConfig config) async {
    final request = await _openRequest(
      method: 'PROPFIND',
      targetPath: '',
      config: config,
    );
    request.headers.set('Depth', '0');
    request.headers.set('Content-Type', 'application/xml; charset=utf-8');
    request.write('''
<?xml version="1.0" encoding="utf-8" ?>
<propfind xmlns="DAV:">
  <prop>
    <displayname />
  </prop>
</propfind>
''');

    final response = await _closeRequest(
      request,
      notFoundCode: CloudSyncExceptionCode.invalidConfiguration,
      defaultMessage: 'Unable to validate WebDAV connection',
    );
    await response.drain<void>();
  }

  @override
  Future<RemoteSyncPackageMeta?> getRemoteMeta() async {
    final config = await _requiredConfig();
    final request = await _openRequest(
      method: 'PROPFIND',
      targetPath: config.remotePath,
      config: config,
    );
    request.headers.set('Depth', '0');
    request.headers.set('Content-Type', 'application/xml; charset=utf-8');
    request.write('''
<?xml version="1.0" encoding="utf-8" ?>
<propfind xmlns="DAV:">
  <prop>
    <getlastmodified />
    <getetag />
    <getcontentlength />
  </prop>
</propfind>
''');

    final response = await _closeRequest(
      request,
      allowNotFound: true,
      defaultMessage: 'Unable to fetch WebDAV metadata',
    );
    if (response.statusCode == HttpStatus.notFound) {
      return null;
    }

    final body = await utf8.decodeStream(response);
    final document = XmlDocument.parse(body);
    final responseNode = document.findAllElements('d:response').isNotEmpty
        ? document.findAllElements('d:response').first
        : document.findAllElements('response').first;
    final propNode = responseNode.findAllElements('d:prop').isNotEmpty
        ? responseNode.findAllElements('d:prop').first
        : responseNode.findAllElements('prop').first;

    final lastModified = _firstElementText(propNode, ['d:getlastmodified', 'getlastmodified']);
    final etag = _firstElementText(propNode, ['d:getetag', 'getetag']);
    final sizeText =
        _firstElementText(propNode, ['d:getcontentlength', 'getcontentlength']);

    return RemoteSyncPackageMeta(
      path: config.remotePath,
      updatedAt: lastModified == null
          ? DateTime.now()
          : HttpDate.parse(lastModified).toLocal(),
      etag: etag,
      sizeBytes: sizeText == null ? null : int.tryParse(sizeText),
    );
  }

  @override
  Future<void> uploadPackage(SyncPackageUpload upload) async {
    final config = await _requiredConfig();
    await _ensureRemoteDirectoryExists(config, upload.path);
    final request = await _openRequest(
      method: 'PUT',
      targetPath: upload.path,
      config: config,
    );
    request.headers.contentType = ContentType.parse(upload.contentType);
    request.add(upload.bytes);
    final response = await _closeRequest(
      request,
      defaultMessage: 'WebDAV upload failed',
    );
    await response.drain<void>();
  }

  Future<void> _ensureRemoteDirectoryExists(
    WebDavConfig config,
    String remoteFilePath,
  ) async {
    final directoryPath = _extractDirectoryPath(remoteFilePath);
    if (directoryPath == null || directoryPath.isEmpty) {
      return;
    }

    final segments = directoryPath
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return;
    }

    var currentPath = '';
    for (final segment in segments) {
      currentPath = '$currentPath/$segment';
      final request = await _openRequest(
        method: 'MKCOL',
        targetPath: '$currentPath/',
        config: config,
      );
      final response = await request.close();
      final statusCode = response.statusCode;
      await response.drain<void>();

      if (statusCode == HttpStatus.created ||
          statusCode == HttpStatus.methodNotAllowed) {
        continue;
      }
      if (statusCode == HttpStatus.unauthorized ||
          statusCode == HttpStatus.forbidden) {
        throw const CloudSyncException(
          CloudSyncExceptionCode.authenticationFailed,
        );
      }
      if (statusCode == HttpStatus.conflict ||
          statusCode == HttpStatus.notFound) {
        throw CloudSyncException(
          CloudSyncExceptionCode.invalidConfiguration,
          message: 'Unable to create WebDAV directory: $statusCode',
        );
      }
      throw CloudSyncException(
        CloudSyncExceptionCode.unknown,
        message: 'Unable to create WebDAV directory: $statusCode',
      );
    }
  }

  @override
  Future<DownloadedSyncPackage?> downloadPackage(String path) async {
    final config = await _requiredConfig();
    final request = await _openRequest(
      method: 'GET',
      targetPath: path,
      config: config,
    );
    final response = await _closeRequest(
      request,
      allowNotFound: true,
      defaultMessage: 'WebDAV download failed',
    );
    if (response.statusCode == HttpStatus.notFound) {
      return null;
    }

    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final meta = await getRemoteMeta();
    return DownloadedSyncPackage(
      path: path,
      bytes: bytes,
      meta: meta,
    );
  }

  @override
  Future<void> deletePackage(String path) async {
    final config = await _requiredConfig();
    final request = await _openRequest(
      method: 'DELETE',
      targetPath: path,
      config: config,
    );
    final response = await _closeRequest(
      request,
      allowNotFound: true,
      defaultMessage: 'WebDAV delete failed',
    );
    if (response.statusCode == HttpStatus.notFound) {
      return;
    }
    await response.drain<void>();
  }

  Future<WebDavConfig> _requiredConfig() async {
    final config = await _loadConfig();
    if (config == null) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.notConfigured,
      );
    }
    return config;
  }

  Future<HttpClientRequest> _openRequest({
    required String method,
    required String targetPath,
    required WebDavConfig config,
  }) async {
    try {
      final client = HttpClient();
      final url = Uri.parse(config.baseUrl).resolve(_normalizePath(targetPath));
      final request = await client.openUrl(method, url);
      final authToken = base64Encode(
        utf8.encode('${config.username}:${config.appPassword}'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Basic $authToken');
      return request;
    } on FormatException catch (error) {
      throw CloudSyncException(
        CloudSyncExceptionCode.invalidConfiguration,
        message: error.message,
      );
    } on SocketException catch (error) {
      throw CloudSyncException(
        CloudSyncExceptionCode.networkError,
        message: error.message,
      );
    }
  }

  Future<HttpClientResponse> _closeRequest(
    HttpClientRequest request, {
    bool allowNotFound = false,
    CloudSyncExceptionCode notFoundCode = CloudSyncExceptionCode.remoteFileNotFound,
    required String defaultMessage,
  }) async {
    try {
      final response = await request.close();
      final statusCode = response.statusCode;
      if (allowNotFound && statusCode == HttpStatus.notFound) {
        return response;
      }
      if (statusCode >= 200 && statusCode < 300) {
        return response;
      }
      if (statusCode == HttpStatus.unauthorized ||
          statusCode == HttpStatus.forbidden) {
        throw const CloudSyncException(
          CloudSyncExceptionCode.authenticationFailed,
        );
      }
      if (statusCode == HttpStatus.notFound) {
        throw CloudSyncException(
          notFoundCode,
          message: '$defaultMessage: $statusCode',
        );
      }
      throw CloudSyncException(
        CloudSyncExceptionCode.unknown,
        message: '$defaultMessage: $statusCode',
      );
    } on SocketException catch (error) {
      throw CloudSyncException(
        CloudSyncExceptionCode.networkError,
        message: error.message,
      );
    } on HandshakeException catch (error) {
      throw CloudSyncException(
        CloudSyncExceptionCode.networkError,
        message: error.message,
      );
    }
  }

  String _normalizePath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.startsWith('/')) {
      return './${normalized.substring(1)}';
    }
    return normalized;
  }

  String? _extractDirectoryPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final cleaned = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final lastSlash = cleaned.lastIndexOf('/');
    if (lastSlash <= 0) {
      return null;
    }
    return cleaned.substring(0, lastSlash);
  }

  String? _firstElementText(XmlElement parent, List<String> names) {
    for (final name in names) {
      final elements = parent.findAllElements(name);
      if (elements.isNotEmpty) {
        return elements.first.innerText.trim();
      }
    }
    return null;
  }
}
