package com.scom.foodresq.db;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Delete;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Update;

import java.util.List;

/**
 * DAO for all local CRUD operations on cached food listings.
 *
 * Naming conventions
 * ──────────────────
 * getAll*          → LiveData queries (UI-observable, run on IO thread)
 * insert / update  → Room does the threading via executor
 * delete*          → same
 */
@Dao
public interface FoodDao {

    // ── INSERT / UPSERT ─────────────────────────────────────────────────────

    /** Insert or replace a single listing (used when syncing from Firestore). */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insert(FoodEntity food);

    /** Bulk upsert — used after a full Firestore fetch. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertAll(List<FoodEntity> foods);

    // ── READ ─────────────────────────────────────────────────────────────────

    /** All listings, newest cache first — used for the student browse screen. */
    @Query("SELECT * FROM food_listings ORDER BY cachedAt DESC")
    LiveData<List<FoodEntity>> getAllFoods();

    /**
     * Filter by category (case-insensitive) OR return everything when
     * category is "All".  The LIKE trick handles both branches in one query.
     */
    @Query("SELECT * FROM food_listings " +
           "WHERE :category = 'All' OR LOWER(category) = LOWER(:category) " +
           "ORDER BY cachedAt DESC")
    LiveData<List<FoodEntity>> getFoodsByCategory(String category);

    /**
     * Full-text search across name and category.
     * The caller passes "%" + term + "%" for the LIKE parameter.
     */
    @Query("SELECT * FROM food_listings " +
           "WHERE (name LIKE :query OR category LIKE :query) " +
           "ORDER BY cachedAt DESC")
    LiveData<List<FoodEntity>> searchFoods(String query);

    /**
     * Combined search + category filter.
     */
    @Query("SELECT * FROM food_listings " +
           "WHERE (:category = 'All' OR LOWER(category) = LOWER(:category)) " +
           "  AND (name LIKE :query OR category LIKE :query) " +
           "ORDER BY cachedAt DESC")
    LiveData<List<FoodEntity>> searchFoodsByCategory(String query, String category);

    /** All listings belonging to a specific vendor (vendor's own dashboard). */
    @Query("SELECT * FROM food_listings WHERE vendorId = :vendorId ORDER BY cachedAt DESC")
    LiveData<List<FoodEntity>> getFoodsByVendor(String vendorId);

    // ── UPDATE ───────────────────────────────────────────────────────────────

    @Update
    void update(FoodEntity food);

    // ── DELETE ───────────────────────────────────────────────────────────────

    @Delete
    void delete(FoodEntity food);

    /** Remove a listing by its Firestore document ID. */
    @Query("DELETE FROM food_listings WHERE firestoreId = :firestoreId")
    void deleteById(String firestoreId);

    /** Wipe the entire cache — call before a full re-sync. */
    @Query("DELETE FROM food_listings")
    void deleteAll();

    // ── PAST ORDERS ──────────────────────────────────────────────────────────
    // Past orders are stored in a separate table (PastOrderEntity / PastOrderDao).
    // See PastOrderDao.java.
}
