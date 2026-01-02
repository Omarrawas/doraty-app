// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_course.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineCourseAdapter extends TypeAdapter<OfflineCourse> {
  @override
  final int typeId = 2;

  @override
  OfflineCourse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineCourse(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      thumbnailPath: fields[3] as String?,
      lessonIds: (fields[4] as List).cast<String>(),
      downloadedAt: fields[5] as DateTime,
      lastSyncAt: fields[6] as DateTime,
      totalSize: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineCourse obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.thumbnailPath)
      ..writeByte(4)
      ..write(obj.lessonIds)
      ..writeByte(5)
      ..write(obj.downloadedAt)
      ..writeByte(6)
      ..write(obj.lastSyncAt)
      ..writeByte(7)
      ..write(obj.totalSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineCourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
