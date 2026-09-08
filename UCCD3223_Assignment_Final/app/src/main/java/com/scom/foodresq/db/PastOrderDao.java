package com.scom.foodresq.db;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;

import java.util.List;

@Dao
public interface PastOrderDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insert(PastOrderEntity order);

    /** All orders for this student, most recent first. */
    @Query("SELECT * FROM past_orders WHERE studentUid = :uid ORDER BY orderedAt DESC")
    LiveData<List<PastOrderEntity>> getOrdersByStudent(String uid);

    /** Most recent N orders — for the dashboard preview list. */
    @Query("SELECT * FROM past_orders WHERE studentUid = :uid ORDER BY orderedAt DESC LIMIT :limit")
    LiveData<List<PastOrderEntity>> getRecentOrders(String uid, int limit);

    /** Total number of orders placed by this student. */
    @Query("SELECT COUNT(*) FROM past_orders WHERE studentUid = :uid")
    LiveData<Integer> getLiveOrderCount(String uid);

    /** Sum of discounted prices paid. */
    @Query("SELECT COALESCE(SUM(CAST(foodPrice AS REAL) * quantityOrdered), 0.0) " +
           "FROM past_orders WHERE studentUid = :uid")
    LiveData<Double> getTotalSpent(String uid);

    /** Total quantity of food items rescued. */
    @Query("SELECT COALESCE(SUM(quantityOrdered), 0) FROM past_orders WHERE studentUid = :uid")
    LiveData<Integer> getTotalMealsRescued(String uid);

    /**
     * Total savings = sum of (originalPrice - discountedPrice) * quantity.
     * If originalFoodPrice is empty/missing, savings for that row = 0.
     */
    @Query("SELECT COALESCE(SUM(" +
           "  (CAST(CASE WHEN originalFoodPrice = '' THEN foodPrice ELSE originalFoodPrice END AS REAL)" +
           "   - CAST(foodPrice AS REAL)) * quantityOrdered" +
           "), 0.0) FROM past_orders WHERE studentUid = :uid")
    LiveData<Double> getTotalSavings(String uid);

    /** Quick summary count — non-LiveData, for badges etc. */
    @Query("SELECT COUNT(*) FROM past_orders WHERE studentUid = :uid")
    int getOrderCount(String uid);

    @Query("DELETE FROM past_orders")
    void deleteAll();
}
