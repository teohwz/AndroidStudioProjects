package com.scom.foodresq;

import android.util.Log;

import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.DocumentReference;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.Query;
import com.google.firebase.firestore.SetOptions;
import com.scom.foodresq.db.FoodEntity;
import com.scom.foodresq.FoodRepository;

import java.util.HashMap;
import java.util.Map;

/**
 * Repository for managing reservations (5-minute holds), QR verification, and ratings.
 */
public class ReservationRepository {
    private static final String TAG = "ReservationRepo";
    private static final long RESERVATION_DURATION_MS = 5 * 60 * 1000; // 5 minutes

    private final FirebaseFirestore db;
    private final FoodRepository foodRepository;
    private final MutableLiveData<Reservation> activeReservation = new MutableLiveData<>();
    private final MutableLiveData<String> verificationResult = new MutableLiveData<>();

    public ReservationRepository() {
        this.db = FirebaseFirestore.getInstance();
        this.foodRepository = new FoodRepository(null); // Null context handled internally
    }

    /**
     * Create a 5-minute hold on a food item.
     * Returns true if reservation succeeded, false if already reserved.
     */
    /**
     * Create a 5-minute hold on a food item.
     * Checks:
     *  1. Food still has stock
     *  2. This student does NOT already have an active reservation
     */
    public void createReservation(FoodEntity food, String studentId, String studentEmail,
                                  ReservationCallback callback) {
        String foodId = food.firestoreId;

        int currentQuantity;
        try {
            currentQuantity = Integer.parseInt(food.quantity);
        } catch (NumberFormatException e) {
            currentQuantity = 0;
        }

        if (currentQuantity <= 0) {
            callback.onFailure("Sorry, this food is out of stock!");
            return;
        }

        // ── Step 1: check if this student already has an active reservation ──
        db.collection("reservations")
                .whereEqualTo("studentId", studentId)
                .whereEqualTo("status", "active")
                .get()
                .addOnSuccessListener(studentSnap -> {
                    long now = System.currentTimeMillis();

                    // Filter out truly expired ones (Firestore index may not have fired yet)
                    boolean hasActiveReservation = false;
                    for (com.google.firebase.firestore.DocumentSnapshot doc : studentSnap.getDocuments()) {
                        Long expiresAt = doc.getLong("expiresAt");
                        if (expiresAt != null && expiresAt > now) {
                            hasActiveReservation = true;
                            break;
                        } else {
                            // Clean up stale active reservation
                            doc.getReference().update("status", "expired");
                        }
                    }

                    if (hasActiveReservation) {
                        callback.onFailure("You already have an active reservation! " +
                                "Please complete or wait for it to expire first.");
                        return;
                    }

                    // ── Step 2: proceed to create the reservation ──
                    Reservation reservation = new Reservation(
                            foodId, food.name, studentId, studentEmail,
                            food.vendorId, getPickupLocationForVendor(food.vendorId)
                    );

                    db.collection("reservations")
                            .add(reservation)
                            .addOnSuccessListener(docRef -> {
                                reservation.setReservationId(docRef.getId());
                                activeReservation.setValue(reservation);
                                updateFoodQuantity(foodId, food.quantity);
                                callback.onSuccess(reservation);
                            })
                            .addOnFailureListener(e ->
                                    callback.onFailure("Failed to create reservation: " + e.getMessage()));
                })
                .addOnFailureListener(e -> callback.onFailure("Check failed: " + e.getMessage()));
    }

    private void updateFoodQuantity(String foodId, String currentQuantity) {
        int qty;
        try {
            qty = Integer.parseInt(currentQuantity);
            qty = Math.max(0, qty - 1);
        } catch (NumberFormatException e) {
            qty = 0;
        }

        Map<String, Object> updates = new HashMap<>();
        updates.put("quantity", String.valueOf(qty));

        db.collection("foodListings").document(foodId)
                .update(updates)
                .addOnSuccessListener(aVoid -> Log.d(TAG, "Food quantity updated"))
                .addOnFailureListener(e -> Log.e(TAG, "Failed to update quantity", e));
    }

    /**
     * Get active reservation for a student (for countdown timer)
     */
    public LiveData<Reservation> getActiveReservation(String studentId) {
        MutableLiveData<Reservation> result = new MutableLiveData<>();

        db.collection("reservations")
                .whereEqualTo("studentId", studentId)
                .whereEqualTo("status", "active")
                .limit(1)
                .addSnapshotListener((snapshots, error) -> {
                    if (error != null || snapshots == null || snapshots.isEmpty()) {
                        result.setValue(null);
                        return;
                    }
                    Reservation res = snapshots.getDocuments().get(0).toObject(Reservation.class);
                    res.setReservationId(snapshots.getDocuments().get(0).getId());
                    result.setValue(res);
                });

        return result;
    }

    /**
     * Verify QR code for pickup (used by Vendor)
     */
    public void verifyQRCode(String qrCode, String vendorId, VerificationCallback callback) {
        db.collection("reservations")
                .whereEqualTo("qrCode", qrCode)
                .whereEqualTo("vendorId", vendorId)
                .whereEqualTo("status", "active")
                .limit(1)
                .get()
                .addOnSuccessListener(querySnapshot -> {
                    if (querySnapshot.isEmpty()) {
                        callback.onFailure("Invalid or expired QR code");
                        return;
                    }

                    DocumentSnapshot doc = querySnapshot.getDocuments().get(0);
                    Reservation reservation = doc.toObject(Reservation.class);
                    reservation.setReservationId(doc.getId());

                    if (reservation.isExpired()) {
                        completeReservation(reservation.getReservationId(), "expired");
                        callback.onFailure("Reservation has expired!");
                        return;
                    }

                    // Mark as completed
                    completeReservation(reservation.getReservationId(), "completed");
                    callback.onSuccess(reservation);
                })
                .addOnFailureListener(e -> callback.onFailure("Verification failed: " + e.getMessage()));
    }

    private void completeReservation(String reservationId, String status) {
        Map<String, Object> updates = new HashMap<>();
        updates.put("status", status);
        updates.put("completedAt", System.currentTimeMillis());

        db.collection("reservations").document(reservationId)
                .update(updates)
                .addOnFailureListener(e -> Log.e(TAG, "Failed to complete reservation", e));
    }

    /**
     * Release an expired reservation (auto-called by background service)
     */
    public void releaseExpiredReservations() {
        long now = System.currentTimeMillis();

        db.collection("reservations")
                .whereEqualTo("status", "active")
                .whereLessThan("expiresAt", now)
                .get()
                .addOnSuccessListener(snapshots -> {
                    for (DocumentSnapshot doc : snapshots.getDocuments()) {
                        Map<String, Object> updates = new HashMap<>();
                        updates.put("status", "expired");
                        db.collection("reservations").document(doc.getId()).update(updates);
                    }
                });
    }

    /**
     * Submit a rating
     */
    public void submitRating(Rating rating, RatingCallback callback) {
        db.collection("ratings")
                .add(rating)
                .addOnSuccessListener(docRef -> {
                    rating.setRatingId(docRef.getId());
                    updateUserAverageRating(rating.getToUserId(), rating.getToUserRole());
                    callback.onSuccess(docRef.getId());
                })
                .addOnFailureListener(e -> callback.onFailure(e.getMessage()));
    }

    private void updateUserAverageRating(String userId, String role) {
        db.collection("ratings")
                .whereEqualTo("toUserId", userId)
                .get()
                .addOnSuccessListener(snapshots -> {
                    double total = 0;
                    int count = 0;
                    for (DocumentSnapshot doc : snapshots.getDocuments()) {
                        Rating r = doc.toObject(Rating.class);
                        if (r != null) {
                            total += r.getScore();
                            count++;
                        }
                    }
                    double avg = count > 0 ? total / count : 0;

                    Map<String, Object> updates = new HashMap<>();
                    updates.put("averageRating", avg);
                    updates.put("ratingCount", count);

                    db.collection("users").document(userId).update(updates);
                });
    }

    public LiveData<Double> getUserAverageRating(String userId) {
        MutableLiveData<Double> result = new MutableLiveData<>();
        db.collection("users").document(userId)
                .addSnapshotListener((doc, error) -> {
                    if (doc != null && doc.exists()) {
                        Double avg = doc.getDouble("averageRating");
                        result.setValue(avg != null ? avg : 0.0);
                    }
                });
        return result;
    }

    public LiveData<java.util.List<Rating>> getUserRatings(String userId) {
        MutableLiveData<java.util.List<Rating>> result = new MutableLiveData<>();
        db.collection("ratings")
                .whereEqualTo("toUserId", userId)
                .orderBy("createdAt", Query.Direction.DESCENDING)
                .addSnapshotListener((snapshots, error) -> {
                    if (snapshots != null) {
                        java.util.List<Rating> ratings = new java.util.ArrayList<>();
                        for (DocumentSnapshot doc : snapshots.getDocuments()) {
                            Rating r = doc.toObject(Rating.class);
                            if (r != null) {
                                r.setRatingId(doc.getId());
                                ratings.add(r);
                            }
                        }
                        result.setValue(ratings);
                    }
                });
        return result;
    }

    private String getPickupLocationForVendor(String vendorId) {
        // TODO: fetch from Firestore or return default
        return "Campus Food Court - Vendor Pickup Point";
    }

    // Callback interfaces
    public interface ReservationCallback {
        void onSuccess(Reservation reservation);
        void onFailure(String error);
    }

    public interface VerificationCallback {
        void onSuccess(Reservation reservation);
        void onFailure(String error);
    }

    public interface RatingCallback {
        void onSuccess(String ratingId);
        void onFailure(String error);
    }
}