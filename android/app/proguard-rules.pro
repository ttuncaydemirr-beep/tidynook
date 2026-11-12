# Tidy Nook R8 rules (ported from Arrowtile). Flutter, google_mobile_ads, UMP, in_app_purchase (Play Billing),
# flutter_local_notifications and Firebase bring their own consumer rules; these are the extras Arrowtile needed.
-keepattributes SourceFile,LineNumberTable

# google_mobile_ads -> play-services-ads -> WorkManager creates its Room database by reflection
# (WorkDatabase_Impl). Full-mode R8 removed the constructor and the app crashed at start in Arrowtile
# ("Failed to create an instance of androidx.work.impl.WorkDatabase").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** extends androidx.room.RoomDatabase { *; }

# flutter_local_notifications stores scheduled notifications with Gson (generic type signatures must survive).
-keepattributes Signature
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Crashlytics: keep exception class names readable.
-keep public class * extends java.lang.Exception
