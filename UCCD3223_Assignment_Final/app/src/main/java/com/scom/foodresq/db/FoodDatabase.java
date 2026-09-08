package com.scom.foodresq.db;

import android.content.Context;

import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

@Database(
    entities     = { FoodEntity.class, PastOrderEntity.class },
    version      = 3,
    exportSchema = false
)
public abstract class FoodDatabase extends RoomDatabase {

    private static volatile FoodDatabase INSTANCE;

    public abstract FoodDao      foodDao();
    public abstract PastOrderDao pastOrderDao();

    /** Migration 1 → 2: add latitude and longitude to food_listings. */
    static final Migration MIGRATION_1_2 = new Migration(1, 2) {
        @Override
        public void migrate(SupportSQLiteDatabase db) {
            db.execSQL("ALTER TABLE food_listings ADD COLUMN latitude  REAL NOT NULL DEFAULT 0.0");
            db.execSQL("ALTER TABLE food_listings ADD COLUMN longitude REAL NOT NULL DEFAULT 0.0");
        }
    };

    /** Migration 2 → 3: add originalPrice to food_listings and past_orders. */
    static final Migration MIGRATION_2_3 = new Migration(2, 3) {
        @Override
        public void migrate(SupportSQLiteDatabase db) {
            // food_listings: originalPrice defaults to the existing price value
            db.execSQL("ALTER TABLE food_listings ADD COLUMN originalPrice TEXT NOT NULL DEFAULT ''");
            // past_orders: store original price at time of order for savings calc
            db.execSQL("ALTER TABLE past_orders ADD COLUMN originalFoodPrice TEXT NOT NULL DEFAULT ''");
        }
    };

    public static FoodDatabase getInstance(Context context) {
        if (INSTANCE == null) {
            synchronized (FoodDatabase.class) {
                if (INSTANCE == null) {
                    INSTANCE = Room.databaseBuilder(
                                    context.getApplicationContext(),
                                    FoodDatabase.class,
                                    "foodresq_db"
                               )
                               .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                               .fallbackToDestructiveMigration()
                               .build();
                }
            }
        }
        return INSTANCE;
    }
}
