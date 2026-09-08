package com.scom.foodresq;

import android.content.Context;
import android.util.Log;

import androidx.lifecycle.LiveData;

import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QueryDocumentSnapshot;
import com.scom.foodresq.db.FoodDao;
import com.scom.foodresq.db.FoodDatabase;
import com.scom.foodresq.db.FoodEntity;
import com.scom.foodresq.db.PastOrderDao;
import com.scom.foodresq.db.PastOrderEntity;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class FoodRepository {

    private static final String TAG = "FoodRepository";

    private final FoodDao         foodDao;
    private final PastOrderDao    pastOrderDao;
    private final FirebaseFirestore db;
    private final ExecutorService  executor;

    public FoodRepository(Context context) {
        FoodDatabase database = FoodDatabase.getInstance(context);
        foodDao      = database.foodDao();
        pastOrderDao = database.pastOrderDao();
        db           = FirebaseFirestore.getInstance();
        executor     = Executors.newSingleThreadExecutor();
    }

    // ── OBSERVE (Room LiveData) ────────────────────────────────────────────

    public LiveData<List<FoodEntity>> getAllFoods() {
        return foodDao.getAllFoods();
    }

    public LiveData<List<FoodEntity>> getFoodsByCategory(String category) {
        return foodDao.getFoodsByCategory(category);
    }

    public LiveData<List<FoodEntity>> searchFoods(String searchTerm, String category) {
        String likeQuery = "%" + (searchTerm == null ? "" : searchTerm.trim()) + "%";
        boolean hasSearch   = searchTerm != null && !searchTerm.trim().isEmpty();
        boolean hasCategory = category   != null && !category.equals(FoodCategory.ALL);

        if (hasSearch && hasCategory) {
            return foodDao.searchFoodsByCategory(likeQuery, category);
        } else if (hasSearch) {
            return foodDao.searchFoods(likeQuery);
        } else if (hasCategory) {
            return foodDao.getFoodsByCategory(category);
        } else {
            return foodDao.getAllFoods();
        }
    }

    public LiveData<List<FoodEntity>> getFoodsByVendor(String vendorId) {
        return foodDao.getFoodsByVendor(vendorId);
    }

    public LiveData<List<PastOrderEntity>> getPastOrders(String studentUid) {
        return pastOrderDao.getOrdersByStudent(studentUid);
    }

    // ── SYNC FROM FIRESTORE ────────────────────────────────────────────────

    public void syncFoodsFromFirestore(SyncCallback callback) {
        db.collection("foodListings")
                .get()
                .addOnSuccessListener(snapshots -> {
                    executor.execute(() -> {
                        List<FoodEntity> entities = new ArrayList<>();
                        for (QueryDocumentSnapshot doc : snapshots) {
                            Food food = doc.toObject(Food.class);
                            food.setFirestoreId(doc.getId());

                            // Read originalPrice from Firestore; fall back to price if missing
                            String origPrice = doc.getString("originalPrice");
                            if (origPrice == null || origPrice.isEmpty()) {
                                origPrice = food.getPrice();
                            }
                            food.setOriginalPrice(origPrice);

                            entities.add(food.toEntity());
                        }

                        foodDao.deleteAll();
                        foodDao.insertAll(entities);
                        Log.d(TAG, "Synced " + entities.size() + " listings to Room.");

                        if (callback != null) {
                            new android.os.Handler(android.os.Looper.getMainLooper())
                                    .post(callback::onSuccess);
                        }
                    });
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Firestore sync failed: " + e.getMessage());
                    if (callback != null) callback.onFailure(e.getMessage());
                });
    }

    // ── WRITE (Firestore + Room) ───────────────────────────────────────────

    public void addFood(Food food, WriteCallback callback) {
        java.util.Map<String, Object> map = new java.util.HashMap<>();
        map.put("name",          food.getName());
        map.put("originalPrice", food.getOriginalPrice() != null
                ? food.getOriginalPrice() : food.getPrice()); // NEW
        map.put("price",         food.getPrice());
        map.put("quantity",      food.getQuantity());
        map.put("expiry",        food.getExpiry());
        map.put("vendorId",      food.getVendorId());
        map.put("category",      food.getCategory());
        map.put("latitude",      food.getLatitude());
        map.put("longitude",     food.getLongitude());

        db.collection("foodListings")
                .add(map)
                .addOnSuccessListener(docRef -> {
                    food.setFirestoreId(docRef.getId());
                    executor.execute(() -> foodDao.insert(food.toEntity()));
                    if (callback != null) callback.onSuccess(docRef.getId());
                })
                .addOnFailureListener(e -> {
                    if (callback != null) callback.onFailure(e.getMessage());
                });
    }

    public void updateFood(Food food, WriteCallback callback) {
        java.util.Map<String, Object> map = new java.util.HashMap<>();
        map.put("name",          food.getName());
        map.put("originalPrice", food.getOriginalPrice() != null
                ? food.getOriginalPrice() : food.getPrice()); // NEW
        map.put("price",         food.getPrice());
        map.put("quantity",      food.getQuantity());
        map.put("expiry",        food.getExpiry());
        map.put("category",      food.getCategory());

        db.collection("foodListings")
                .document(food.getFirestoreId())
                .update(map)
                .addOnSuccessListener(aVoid -> {
                    executor.execute(() -> foodDao.update(food.toEntity()));
                    if (callback != null) callback.onSuccess(food.getFirestoreId());
                })
                .addOnFailureListener(e -> {
                    if (callback != null) callback.onFailure(e.getMessage());
                });
    }

    public void deleteFood(String firestoreId, WriteCallback callback) {
        db.collection("foodListings")
                .document(firestoreId)
                .delete()
                .addOnSuccessListener(aVoid -> {
                    executor.execute(() -> foodDao.deleteById(firestoreId));
                    if (callback != null) callback.onSuccess(firestoreId);
                })
                .addOnFailureListener(e -> {
                    if (callback != null) callback.onFailure(e.getMessage());
                });
    }

    // ── PAST ORDERS ────────────────────────────────────────────────────────

    public void savePastOrder(PastOrderEntity order) {
        executor.execute(() -> pastOrderDao.insert(order));
    }

    // ── DASHBOARD QUERIES ──────────────────────────────────────────────────

    public LiveData<Integer> getTotalMealsRescued(String studentUid) {
        return pastOrderDao.getTotalMealsRescued(studentUid);
    }

    public LiveData<Double> getTotalSpent(String studentUid) {
        return pastOrderDao.getTotalSpent(studentUid);
    }

    /** Total money saved = sum of (originalPrice - discountedPrice) * qty */
    public LiveData<Double> getTotalSavings(String studentUid) {
        return pastOrderDao.getTotalSavings(studentUid);
    }

    public LiveData<Integer> getLiveOrderCount(String studentUid) {
        return pastOrderDao.getLiveOrderCount(studentUid);
    }

    public LiveData<List<PastOrderEntity>> getRecentOrders(String studentUid, int limit) {
        return pastOrderDao.getRecentOrders(studentUid, limit);
    }

    // ── CLEANUP EXPIRED FOODS ─────────────────────────────────────────────

    public void cleanupExpiredFoods() {
        db.collection("foodListings")
                .get()
                .addOnSuccessListener(snapshots -> {
                    java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat(
                            "dd/MM/yyyy", java.util.Locale.getDefault());
                    long currentTime = System.currentTimeMillis();

                    for (QueryDocumentSnapshot doc : snapshots) {
                        String expiryStr = doc.getString("expiry");
                        if (expiryStr != null && !expiryStr.isEmpty()) {
                            try {
                                java.util.Date expiryDate = sdf.parse(expiryStr);
                                if (expiryDate != null && expiryDate.getTime() < currentTime) {
                                    String docId = doc.getId();
                                    db.collection("foodListings").document(docId).delete()
                                            .addOnSuccessListener(aVoid ->
                                                    Log.d(TAG, "Deleted expired food: " + docId));
                                    executor.execute(() -> foodDao.deleteById(docId));
                                }
                            } catch (Exception e) {
                                Log.e(TAG, "Failed to parse expiry date: " + expiryStr);
                            }
                        }
                    }
                });
    }

    // ── CALLBACKS ─────────────────────────────────────────────────────────

    public interface SyncCallback {
        void onSuccess();
        void onFailure(String error);
    }

    public interface WriteCallback {
        void onSuccess(String id);
        void onFailure(String error);
    }
}
