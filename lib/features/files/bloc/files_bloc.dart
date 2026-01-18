import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';

import '../../../utils.dart';

// ==================== EVENTS ====================

abstract class FilesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class RefreshFiles extends FilesEvent {}

class ShareFile extends FilesEvent {
  final FileSystemEntity file;

  ShareFile({required this.file});

  @override
  List<Object?> get props => [file.path];
}

class DeleteFile extends FilesEvent {
  final FileSystemEntity file;

  DeleteFile({required this.file});

  @override
  List<Object?> get props => [file.path];
}

// ==================== STATE ====================

class FilesState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<FileSystemEntity> rawFiles;
  final List<FileSystemEntity> processedFiles;

  const FilesState({
    this.isLoading = false,
    this.error,
    this.rawFiles = const [],
    this.processedFiles = const [],
  });

  FilesState copyWith({
    bool? isLoading,
    String? error,
    List<FileSystemEntity>? rawFiles,
    List<FileSystemEntity>? processedFiles,
    bool clearError = false,
  }) {
    return FilesState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      rawFiles: rawFiles ?? this.rawFiles,
      processedFiles: processedFiles ?? this.processedFiles,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, rawFiles, processedFiles];
}

// ==================== BLOC ====================

class FilesBloc extends Bloc<FilesEvent, FilesState> {
  FilesBloc() : super(const FilesState(isLoading: true)) {
    on<RefreshFiles>(_onRefreshFiles);
    on<ShareFile>(_onShareFile);
    on<DeleteFile>(_onDeleteFile);
  }

  Future<void> _onRefreshFiles(
    RefreshFiles event,
    Emitter<FilesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      String path = await getDownloadsPath();
      final directory = Directory(path);
      final entities = await directory.list().toList();

      final allFiles =
          entities.whereType<File>().toList()..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );

      final processedFiles =
          allFiles
              .where((f) => f.path.split('/').last.startsWith('TurboGauge'))
              .toList();
      final rawFiles =
          allFiles
              .where((f) => !f.path.split('/').last.startsWith('CameraRecording'))
              .toList();

      AnalyticsService().trackEvent(
        AnalyticsEvents.filesLoaded,
        properties: {
          "totalFiles": allFiles.length,
          "processedFiles": processedFiles.length,
          "rawFiles": rawFiles.length,
        },
      );

      emit(
        state.copyWith(
          isLoading: false,
          processedFiles: processedFiles,
          rawFiles: rawFiles,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error loading files: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onShareFile(ShareFile event, Emitter<FilesState> emit) async {
    try {
      await Share.shareXFiles([
        XFile(event.file.path),
      ], text: 'Shared from TurboGauge');
    } catch (e) {
      emit(state.copyWith(error: 'Failed to share file: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteFile(DeleteFile event, Emitter<FilesState> emit) async {
    try {
      await event.file.delete();
      // Refresh files after deletion
      add(RefreshFiles());
    } catch (e) {
      emit(state.copyWith(error: 'Failed to delete file: ${e.toString()}'));
    }
  }
}
