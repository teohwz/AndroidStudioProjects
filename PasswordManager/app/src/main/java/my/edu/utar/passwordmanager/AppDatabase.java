package my.edu.utar.passwordmanager;

import android.content.Context;
import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;

import my.edu.utar.passwordmanager.PasswordDao;
import my.edu.utar.passwordmanager.PasswordEntry;

@Database(entities = {PasswordEntry.class}, version = 1)
public abstract class AppDatabase extends RoomDatabase {
    public abstract PasswordDao passwordDao();

    private static volatile AppDatabase INSTANCE;

    public static AppDatabase getDatabase(final Context context) {
        if (INSTANCE == null) {
            synchronized (AppDatabase.class) {
                if (INSTANCE == null) {
                    INSTANCE = Room.databaseBuilder(context.getApplicationContext(),
                                    AppDatabase.class, "password_manager_db")
                            .allowMainThreadQueries() // Note: For production, run DB calls on background threads!
                            .build();
                }
            }
        }
        return INSTANCE;
    }
}