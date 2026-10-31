import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/models/scan_result.dart';
import 'package:bananaguard_ai/models/condition_info.dart';
import 'package:bananaguard_ai/services/scan_service.dart';
import 'package:bananaguard_ai/services/notification_service.dart';

enum ScanStatus {
  idle,
  picking,
  uploading,
  analyzing,
  success,
  failure,
}

class ScanState {
  final ScanStatus status;
  final XFile? selectedImage;
  final Uint8List? selectedImageBytes;
  final String? fileName;
  final int fileSizeBytes;
  final double uploadProgress; // 0.0 to 1.0
  final VarietyModel? selectedVariety;
  final ScanResultModel? scanResult;
  final String? errorMessageEn;
  final String? errorMessageSi;
  final String? technicalDetails;
  final List<VarietyModel> varieties;
  final bool isBananaError; // true when backend rejected image as non-banana
  final bool isCheckingBanana; // true while running banana verification check
  final bool isBananaConfirmed; // true once image is confirmed as a banana fruit

  ScanState({
    this.status = ScanStatus.idle,
    this.selectedImage,
    this.selectedImageBytes,
    this.fileName,
    this.fileSizeBytes = 0,
    this.uploadProgress = 0.0,
    this.selectedVariety,
    this.scanResult,
    this.errorMessageEn,
    this.errorMessageSi,
    this.technicalDetails,
    this.varieties = const [],
    this.isBananaError = false,
    this.isCheckingBanana = false,
    this.isBananaConfirmed = false,
  });

  bool get isAnalyzing => status == ScanStatus.uploading || status == ScanStatus.analyzing;
  bool get isSuccess => status == ScanStatus.success;
  bool get isFailed => status == ScanStatus.failure;

  String? get errorMessage => errorMessageEn;

  String getLocalizedError(String lang) {
    if (lang == 'si') return errorMessageSi ?? errorMessageEn ?? 'විශ්ලේෂණය අසාර්ථක විය.';
    return errorMessageEn ?? errorMessageSi ?? 'Analysis failed.';
  }

  ScanState copyWith({
    ScanStatus? status,
    XFile? selectedImage,
    Uint8List? selectedImageBytes,
    String? fileName,
    int? fileSizeBytes,
    double? uploadProgress,
    VarietyModel? selectedVariety,
    ScanResultModel? scanResult,
    String? errorMessageEn,
    String? errorMessageSi,
    String? technicalDetails,
    List<VarietyModel>? varieties,
    bool clearImage = false,
    bool clearResult = false,
    bool clearVariety = false,
    bool clearError = false,
    bool? isBananaError,
    bool? isCheckingBanana,
    bool? isBananaConfirmed,
  }) {
    return ScanState(
      status: status ?? this.status,
      selectedImage: clearImage ? null : (selectedImage ?? this.selectedImage),
      selectedImageBytes: clearImage ? null : (selectedImageBytes ?? this.selectedImageBytes),
      fileName: clearImage ? null : (fileName ?? this.fileName),
      fileSizeBytes: clearImage ? 0 : (fileSizeBytes ?? this.fileSizeBytes),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      selectedVariety: clearVariety ? null : (selectedVariety ?? this.selectedVariety),
      scanResult: clearResult ? null : (scanResult ?? this.scanResult),
      errorMessageEn: clearError ? null : (errorMessageEn ?? this.errorMessageEn),
      errorMessageSi: clearError ? null : (errorMessageSi ?? this.errorMessageSi),
      technicalDetails: clearError ? null : (technicalDetails ?? this.technicalDetails),
      varieties: varieties ?? this.varieties,
      isBananaError: clearError ? false : (isBananaError ?? this.isBananaError),
      isCheckingBanana: clearImage ? false : (isCheckingBanana ?? this.isCheckingBanana),
      isBananaConfirmed: clearImage ? false : (isBananaConfirmed ?? this.isBananaConfirmed),
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  final ImagePicker _picker = ImagePicker();
  CancelToken? _cancelToken;

  ScanNotifier()
      : super(ScanState(
          varieties: VarietyModel.defaultVarieties,
          // Auto-select Cavendish (No: 1) as default — user always picks this
          selectedVariety: VarietyModel.defaultVarieties.first,
        )) {
    loadVarieties();
  }

  Future<void> loadVarieties() async {
    try {
      final list = await scanService.getVarieties();
      if (list.isNotEmpty) {
        // Keep Cavendish (first variety) auto-selected after API load
        final cavendish = list.firstWhere(
          (v) => v.id == 'cavendish',
          orElse: () => list.first,
        );
        state = state.copyWith(varieties: list, selectedVariety: cavendish);
      }
    } catch (_) {
      if (state.varieties.isEmpty) {
        state = state.copyWith(varieties: VarietyModel.defaultVarieties);
      }
    }
  }

  Future<bool> pickImage(ImageSource source) async {
    state = state.copyWith(
      status: ScanStatus.picking,
      clearError: true,
      isCheckingBanana: false,
      isBananaConfirmed: false,
      isBananaError: false,
    );
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty ? picked.name : 'banana_photo.jpg';
        state = state.copyWith(
          status: ScanStatus.idle,
          selectedImage: picked,
          selectedImageBytes: bytes,
          fileName: name,
          fileSizeBytes: bytes.lengthInBytes,
          clearResult: true,
          clearError: true,
          isCheckingBanana: true,
          isBananaConfirmed: false,
          isBananaError: false,
        );

        // Run automatic zero-latency banana check immediately
        _runBananaPreCheck(picked, bytes);
        return true;
      }
      state = state.copyWith(status: ScanStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: ScanStatus.failure,
        errorMessageEn: 'Failed to access camera or gallery.',
        errorMessageSi: 'කැමරාව හෝ ගැලරිය වෙත පිවිසීමට නොහැකි විය.',
        technicalDetails: e.toString(),
      );
    }
    return false;
  }

  Future<void> _runBananaPreCheck(XFile picked, Uint8List bytes) async {
    try {
      final res = await scanService.checkBanana(
        imageFile: picked,
        imageBytes: bytes,
      );

      final isBanana = res['is_banana'] == true;
      if (isBanana) {
        state = state.copyWith(
          isCheckingBanana: false,
          isBananaConfirmed: true,
          isBananaError: false,
        );
      } else {
        state = state.copyWith(
          isCheckingBanana: false,
          isBananaConfirmed: false,
          isBananaError: true,
          errorMessageEn: res['message_en']?.toString() ??
              'This app only supports banana fruit images. Please scan a banana and try again.',
          errorMessageSi: res['message_si']?.toString() ??
              'මෙම app එකෙහි කෙසෙල් පළතුරු පමණක් scan කළ හැක. කරුණාකර කෙසෙල් ගෙඩියක ඡායාරූපයක් ගෙන නැවත උත්සාහ කරන්න.',
        );
      }
    } catch (e) {
      debugPrint('[BananaPreCheck] Non-fatal check error: $e');
      // Fail-open so a temporary network glitch does not hard block analysis
      state = state.copyWith(
        isCheckingBanana: false,
        isBananaConfirmed: true,
      );
    }
  }

  void selectVariety(VarietyModel? variety) {
    state = state.copyWith(selectedVariety: variety, clearVariety: variety == null);
  }

  Future<bool> analyzeImage(String language) async {
    if (state.selectedImage == null) {
      state = state.copyWith(
        status: ScanStatus.failure,
        errorMessageEn: 'No banana photo selected. Please choose a photo first.',
        errorMessageSi: 'කෙසෙල් ඡායාරූපයක් තෝරාගෙන නොමැත. කරුණාකර පළමුව ඡායාරූපයක් තෝරන්න.',
        technicalDetails: 'selectedImage was null at analyzeImage call',
      );
      return false;
    }

    _cancelToken = CancelToken();
    state = state.copyWith(
      status: ScanStatus.uploading,
      uploadProgress: 0.0,
      clearResult: true,
      clearError: true,
    );

    try {
      final result = await scanService.predictScan(
        imageFile: state.selectedImage!,
        imageBytes: state.selectedImageBytes,
        varietyId: state.selectedVariety?.id,
        language: language,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            state = state.copyWith(
              status: progress >= 1.0 ? ScanStatus.analyzing : ScanStatus.uploading,
              uploadProgress: progress.clamp(0.0, 1.0),
            );
          }
        },
      );

      state = state.copyWith(
        status: ScanStatus.success,
        scanResult: result,
        uploadProgress: 1.0,
      );

      // Trigger local in-app alert for completed scan
      try {
        await notificationService.postNotification(
          title: 'Scan Analysis Complete',
          body: 'Diagnosis for ${result.condition.en}: ${result.condition.type}',
          type: 'scan_result',
          payload: result.scanId,
        );
      } catch (err) {
        debugPrint('Notification post error (non-fatal): $err');
      }

      return true;
    } on DioException catch (dioErr) {
      if (CancelToken.isCancel(dioErr)) {
        state = state.copyWith(
          status: ScanStatus.idle,
          errorMessageEn: 'Analysis was cancelled.',
          errorMessageSi: 'විශ්ලේෂණය අවලංගු කරන ලදී.',
        );
        return false;
      }

      String msgEn = 'Analysis failed. Please check connection and try again.';
      String msgSi = 'විශ්ලේෂණය අසාර්ථක විය. කරුණාකර නැවත උත්සාහ කරන්න.';
      String techDetails = 'DioException [${dioErr.type}]: ${dioErr.message}';

      if (dioErr.response?.data is Map) {
        final data = dioErr.response!.data as Map;
        final err = data['detail'];

        // Handle not_banana rejection (HTTP 422)
        if (dioErr.response?.statusCode == 422 &&
            err is Map &&
            err['code'] == 'not_banana') {
          state = state.copyWith(
            status: ScanStatus.failure,
            isBananaError: true,
            errorMessageEn: err['message_en']?.toString() ??
                'This app only supports banana fruit images.',
            errorMessageSi: err['message_si']?.toString() ??
                'මෙම app එකෙහි කෙසෙල් පළතුරු පමණක් scan කළ හැක.',
          );
          return false;
        }

        // Generic structured backend error
        if (err is Map && err['message_en'] != null) {
          msgEn = err['message_en']?.toString() ?? msgEn;
          msgSi = err['message_si']?.toString() ?? msgSi;
          techDetails = 'Backend Error: ${err['code']} - $msgEn';
        } else if (data['error'] is Map) {
          final errBlock = data['error'] as Map;
          msgEn = errBlock['message_en']?.toString() ?? msgEn;
          msgSi = errBlock['message_si']?.toString() ?? msgSi;
          techDetails = 'Backend Error: ${errBlock['code']} - $msgEn';
        }
        switch (dioErr.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            msgEn = 'Server response timed out. The server may be busy or unreachable.';
            msgSi = 'සේවාදායකයේ ප්‍රතිචාර කාලය ඉක්මවා ගියේය. කරුණාකර නැවත උත්සාහ කරන්න.';
            break;
          case DioExceptionType.connectionError:
            msgEn = 'Cannot connect to backend server at ${AppConstants.defaultApiBaseUrl}. Ensure the server is running.';
            msgSi = 'සේවාදායකය සමඟ සම්බන්ධ විය නොහැක. සේවාදායකය ක්‍රියාත්මක දැයි පරීක්ෂා කරන්න.';
            break;
          case DioExceptionType.badResponse:
            final statusCode = dioErr.response?.statusCode;
            if (statusCode == 400) {
              msgEn = 'The uploaded image could not be processed. Please try another banana photo.';
              msgSi = 'ඡායාරූපය සැකසීමට නොහැකි විය. කරුණාකර වෙනත් ඡායාරූපයක් උත්සාහ කරන්න.';
            } else if (statusCode == 413) {
              msgEn = 'Image file size is too large (max 10MB).';
              msgSi = 'ඡායාරූප ගොනුවේ ප්‍රමාණය වැඩිය (උපරිම 10MB).';
            } else if (statusCode == 500) {
              msgEn = 'Internal server error occurred while analyzing image.';
              msgSi = 'සේවාදායකයේ දෝෂයක් සිදු විය. කරුණාකර මොහොතකින් නැවත උත්සාහ කරන්න.';
            }
            break;
          default:
            break;
        }
      }

      state = state.copyWith(
        status: ScanStatus.failure,
        errorMessageEn: msgEn,
        errorMessageSi: msgSi,
        technicalDetails: techDetails,
      );
      return false;
    } catch (e, stack) {
      debugPrint('Unexpected scan error: $e\n$stack');
      state = state.copyWith(
        status: ScanStatus.failure,
        errorMessageEn: 'An unexpected error occurred while analyzing banana.',
        errorMessageSi: 'විශ්ලේෂණය කිරීමේදී අනපේක්ෂිත දෝෂයක් සිදු විය.',
        technicalDetails: e.toString(),
      );
      return false;
    } finally {
      // Guarantee the analyzing/uploading state terminates
      if (state.status == ScanStatus.uploading || state.status == ScanStatus.analyzing) {
        state = state.copyWith(
          status: ScanStatus.failure,
          errorMessageEn: 'Analysis process ended unexpectedly.',
          errorMessageSi: 'විශ්ලේෂණ ක්‍රියාවලිය අනපේක්ෂිත ලෙස අවසන් විය.',
        );
      }
    }
  }

  void cancelAnalysis() {
    _cancelToken?.cancel('Cancelled by user');
    state = state.copyWith(status: ScanStatus.idle);
  }

  void reset() {
    final cavendish = state.varieties.firstWhere(
      (v) => v.id == 'cavendish',
      orElse: () => state.varieties.isNotEmpty
          ? state.varieties.first
          : VarietyModel.defaultVarieties.first,
    );
    state = state.copyWith(
      status: ScanStatus.idle,
      clearImage: true,
      clearResult: true,
      clearError: true,
      isBananaError: false,
      isCheckingBanana: false,
      isBananaConfirmed: false,
      uploadProgress: 0.0,
      selectedVariety: cavendish,  // Always restore Cavendish on reset
    );
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier();
});
