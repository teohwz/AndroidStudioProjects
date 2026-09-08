package com.scom.foodresq.db;

import androidx.annotation.NonNull;
import androidx.room.Entity;
import androidx.room.Ignore;
import androidx.room.PrimaryKey;

@Entity(tableName = "food_listings")
public class FoodEntity {

    @PrimaryKey
    @NonNull
    public String firestoreId;

    public String name;
    public String originalPrice;   // NEW: vendor's original price
    public String price;           // discounted price student pays
    public String quantity;
    public String expiry;
    public String vendorId;
    public String category;
    public double latitude;
    public double longitude;
    public long   cachedAt;

    public FoodEntity() {}

    @Ignore
    public FoodEntity(String firestoreId, String name, String price,
                      String quantity,    String expiry, String vendorId,
                      String category) {
        this.firestoreId   = firestoreId;
        this.name          = name;
        this.originalPrice = price;   // default: originalPrice = price if not provided
        this.price         = price;
        this.quantity      = quantity;
        this.expiry        = expiry;
        this.vendorId      = vendorId;
        this.category      = category;
        this.latitude      = 0.0;
        this.longitude     = 0.0;
        this.cachedAt      = System.currentTimeMillis();
    }

    @Ignore
    public FoodEntity(String firestoreId, String name, String originalPrice, String price,
                      String quantity,    String expiry, String vendorId,
                      String category,   double latitude, double longitude) {
        this.firestoreId   = firestoreId;
        this.name          = name;
        this.originalPrice = originalPrice;
        this.price         = price;
        this.quantity      = quantity;
        this.expiry        = expiry;
        this.vendorId      = vendorId;
        this.category      = category;
        this.latitude      = latitude;
        this.longitude     = longitude;
        this.cachedAt      = System.currentTimeMillis();
    }
}
