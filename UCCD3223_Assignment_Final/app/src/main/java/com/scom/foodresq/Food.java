package com.scom.foodresq;

public class Food {

    String name;
    String originalPrice;   // NEW: vendor's original price (before discount)
    String price;           // discounted price student pays
    String quantity;
    String expiry;
    String vendorId;
    String category;
    double latitude;
    double longitude;

    String firestoreId;

    public Food() {}

    public Food(String name, String originalPrice, String price, String quantity,
                String expiry, String vendorId, String category) {
        this.name          = name;
        this.originalPrice = originalPrice;
        this.price         = price;
        this.quantity      = quantity;
        this.expiry        = expiry;
        this.vendorId      = vendorId;
        this.category      = category;
    }

    public Food(String name, String originalPrice, String price, String quantity,
                String expiry, String vendorId, String category,
                double latitude, double longitude) {
        this(name, originalPrice, price, quantity, expiry, vendorId, category);
        this.latitude  = latitude;
        this.longitude = longitude;
    }

    // ── Getters ──────────────────────────────────────────────────────────
    public String getName()          { return name; }
    public String getOriginalPrice() { return originalPrice; }
    public String getPrice()         { return price; }
    public String getQuantity()      { return quantity; }
    public String getExpiry()        { return expiry; }
    public String getVendorId()      { return vendorId; }
    public String getCategory()      { return category; }
    public String getFirestoreId()   { return firestoreId; }
    public double getLatitude()      { return latitude; }
    public double getLongitude()     { return longitude; }

    // ── Setters ──────────────────────────────────────────────────────────
    public void setName(String name)                   { this.name = name; }
    public void setOriginalPrice(String originalPrice) { this.originalPrice = originalPrice; }
    public void setPrice(String price)                 { this.price = price; }
    public void setQuantity(String quantity)           { this.quantity = quantity; }
    public void setExpiry(String expiry)               { this.expiry = expiry; }
    public void setVendorId(String vendorId)           { this.vendorId = vendorId; }
    public void setCategory(String category)           { this.category = category; }
    public void setFirestoreId(String id)              { this.firestoreId = id; }
    public void setLatitude(double lat)                { this.latitude = lat; }
    public void setLongitude(double lng)               { this.longitude = lng; }

    // ── Room conversion ───────────────────────────────────────────────────
    public com.scom.foodresq.db.FoodEntity toEntity() {
        return new com.scom.foodresq.db.FoodEntity(
                firestoreId != null ? firestoreId : "",
                name,
                originalPrice != null ? originalPrice : price,  // fallback if null
                price,
                quantity, expiry, vendorId,
                category != null ? category : FoodCategory.OTHERS,
                latitude, longitude
        );
    }

    public static Food fromEntity(com.scom.foodresq.db.FoodEntity e) {
        Food f = new Food(e.name, e.originalPrice, e.price, e.quantity, e.expiry,
                          e.vendorId, e.category, e.latitude, e.longitude);
        f.setFirestoreId(e.firestoreId);
        return f;
    }
}
