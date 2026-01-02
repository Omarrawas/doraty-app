// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_lesson.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineLessonAdapter extends TypeAdapter<OfflineLesson> {
  @override
  final int typeId = 3;

  @override
  OfflineLesson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineLesson(
      id: fields[0] as String,
      courseId: fields[1] as String,
      title: fields[2] as String,
      videoPath: fields[3] as String?,
      content: fields[4] as String?,
      isDownloaded: fields[5] as bool,
      duration: fields[6] as int,
      orderIndex: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineLesson obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.videoPath)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.isDownloaded)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.orderIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineLessonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
