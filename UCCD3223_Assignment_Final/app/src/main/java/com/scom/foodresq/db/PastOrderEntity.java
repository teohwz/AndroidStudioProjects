package com.scom.foodresq.db;

import androidx.room.Entity;
import androidx.room.Ignore;
import androidx.room.PrimaryKey;

@Entity(tableName = "past_orders")
public class PastOrderEntity {

    @PrimaryKey(autoGenerate = true)
    public int id;

    public String firestoreFoodId;
    public String foodName;
    public String foodCategory;
    public String originalFoodPrice;  // NEW: original price (before discount)
    public String foodPrice;          // discounted price actually paid

    public String vendorId;
    public String studentUid;
    public int    quantityOrdered;
    public long   orderedAt;

    public PastOrderEntity() {}

    @Ignore
    public PastOrderEntity(String firestoreFoodId,
                           String foodName,
                           String foodCategory,
                           String originalFoodPrice,
                           String foodPrice,
                           String vendorId,
                           String studentUid,
                           int    quantityOrdered) {
        this.firestoreFoodId   = firestoreFoodId;
        this.foodName          = foodName;
        this.foodCategory      = foodCategory;
        this.originalFoodPrice = originalFoodPrice;
        this.foodPrice         = foodPrice;
        this.vendorId          = vendorId;
        this.studentUid        = studentUid;
        this.quantityOrdered   = quantityOrdered;
        this.orderedAt         = System.currentTimeMillis();
    }
}
