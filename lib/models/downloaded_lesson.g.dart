// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_lesson.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadedLessonAdapter extends TypeAdapter<DownloadedLesson> {
  @override
  final int typeId = 1;

  @override
  DownloadedLesson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadedLesson(
      id: fields[0] as String,
      lessonId: fields[1] as String,
      courseId: fields[2] as String,
      title: fields[3] as String,
      videoUrl: fields[4] as String,
      localPath: fields[5] as String,
      thumbnailPath: fields[6] as String?,
      fileSize: fields[7] as int,
      downloadedAt: fields[8] as DateTime,
      status: fields[9] as DownloadStatus,
      progress: fields[10] as double,
      errorMessage: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadedLesson obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.lessonId)
      ..writeByte(2)
      ..write(obj.courseId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.videoUrl)
      ..writeByte(5)
      ..write(obj.localPath)
      ..writeByte(6)
      ..write(obj.thumbnailPath)
      ..writeByte(7)
      ..write(obj.fileSize)
      ..writeByte(8)
      ..write(obj.downloadedAt)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.progress)
      ..writeByte(11)
      ..write(obj.errorMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadedLessonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadStatusAdapter extends TypeAdapter<DownloadStatus> {
  @override
  final int typeId = 0;

  @override
  DownloadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DownloadStatus.notDownloaded;
      case 1:
        return DownloadStatus.downloading;
      case 2:
        return DownloadStatus.downloaded;
      case 3:
        return DownloadStatus.failed;
      case 4:
        return DownloadStatus.paused;
      case 5:
        return DownloadStatus.cancelled;
      default:
        return DownloadStatus.notDownloaded;
    }
  }

  @override
  void write(BinaryWriter writer, DownloadStatus obj) {
    switch (obj) {
      case DownloadStatus.notDownloaded:
        writer.writeByte(0);
        break;
      case DownloadStatus.downloading:
        writer.writeByte(1);
        break;
      case DownloadStatus.downloaded:
        writer.writeByte(2);
        break;
      case DownloadStatus.failed:
        writer.writeByte(3);
        break;
      case DownloadStatus.paused:
        writer.writeByte(4);
        break;
      case DownloadStatus.cancelled:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
