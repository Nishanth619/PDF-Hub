import 'package:dio/dio.dart';

class ApiService {
  final String baseUrl = 'http://localhost:8000/api';
  final Dio _dio = Dio();

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.interceptors.add(LogInterceptor(
      responseBody: true,
      requestBody: true,
      requestHeader: false,
      responseHeader: false,
    ));
  }

  // Convert PDF to other formats
  Future<Map<String, dynamic>> convertPdf(String fileData, String outputFormat) async {
    try {
      // Check if file data is too large
      if (fileData.length > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('File too large. Please select a smaller file.');
      }
      
      final response = await _dio.post('/convert', 
        data: {
          'file_data': fileData,
          'output_format': outputFormat,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to convert PDF: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else if (e.type == DioExceptionType.sendTimeout) {
        errorMessage += 'Send timeout. Failed to send data to the server.';
      } else if (e.type == DioExceptionType.badCertificate) {
        errorMessage += 'Bad certificate. There might be an SSL issue.';
      } else if (e.type == DioExceptionType.badResponse) {
        errorMessage += 'Bad response from server.';
      } else if (e.type == DioExceptionType.cancel) {
        errorMessage += 'Request was cancelled.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage += 'Connection error. Please check your internet connection.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to convert PDF: $e');
    }
  }

  // Merge multiple PDFs
  Future<Map<String, dynamic>> mergePdfs(List<String> pdfFiles) async {
    try {
      final response = await _dio.post('/merge', 
        data: {
          'pdf_files': pdfFiles,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to merge PDFs: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to merge PDFs: $e');
    }
  }

  // Split PDF into multiple files
  Future<Map<String, dynamic>> splitPdf(String fileData, String pages) async {
    try {
      final response = await _dio.post('/split', 
        data: {
          'file_data': fileData,
          'pages': pages,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to split PDF: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to split PDF: $e');
    }
  }

  // Compress PDF
  Future<Map<String, dynamic>> compressPdf(String fileData, int quality) async {
    try {
      final response = await _dio.post('/compress', 
        data: {
          'file_data': fileData,
          'quality': quality,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to compress PDF: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to compress PDF: $e');
    }
  }

  // Rotate PDF
  Future<Map<String, dynamic>> rotatePdf(String fileData, int rotation, String pages) async {
    try {
      final response = await _dio.post('/rotate', 
        data: {
          'file_data': fileData,
          'rotation': rotation,
          'pages': pages,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to rotate PDF: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to rotate PDF: $e');
    }
  }

  // Add watermark to PDF
  Future<Map<String, dynamic>> addWatermark(String fileData, String watermarkText, double opacity) async {
    try {
      final response = await _dio.post('/watermark', 
        data: {
          'file_data': fileData,
          'watermark_text': watermarkText,
          'opacity': opacity,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to add watermark: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to add watermark: $e');
    }
  }

  // Add page numbers to PDF
  Future<Map<String, dynamic>> addPageNumbers(String fileData, String position) async {
    try {
      final response = await _dio.post('/pagenumber', 
        data: {
          'file_data': fileData,
          'position': position,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to add page numbers: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to add page numbers: $e');
    }
  }

  // OCR PDF
  Future<Map<String, dynamic>> ocrPdf(String fileData) async {
    try {
      final response = await _dio.post('/ocr', 
        data: {
          'file_data': fileData,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to OCR PDF: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to OCR PDF: $e');
    }
  }

  // Convert images to PDF
  Future<Map<String, dynamic>> imagesToPdf(List<String> images) async {
    try {
      final response = await _dio.post('/imagetopdf', 
        data: {
          'images': images,
        }
      );
      return response.data;
    } on DioException catch (e) {
      String errorMessage = 'Failed to convert images to PDF: ';
      if (e.response != null) {
        errorMessage += 'Server responded with status ${e.response?.statusCode}';
        if (e.response?.data != null) {
          errorMessage += ' - ${e.response?.data}';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage += 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage += 'Receive timeout. The server took too long to respond.';
      } else {
        errorMessage += e.message ?? e.toString();
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to convert images to PDF: $e');
    }
  }
}