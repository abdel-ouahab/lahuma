# Release (R8) keep rules. Flutter's Gradle plugin adds this file to the
# release build automatically.

# WorkManager (adhan reschedule) starts with the app and creates its Room
# database, WorkDatabase_Impl, through its no-arg constructor by reflection.
# Room 2.6.x only ships `-keep class * extends androidx.room.RoomDatabase`,
# which under AGP 9's strict R8 full mode keeps the class but not its
# constructors: every release build then crashed on launch with
# NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> [].
-keep class * extends androidx.room.RoomDatabase { <init>(); }
