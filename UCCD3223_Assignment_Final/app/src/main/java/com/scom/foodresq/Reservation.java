package com.scom.foodresq;

import java.util.Date;

/**
 * Firestore model for active reservations (5-minute hold system)
 */
public class Reservation {
    private String reservationId;
    private String foodId;          // Firestore ID of the food listing
    private String foodName;
    private String studentId;       // UID of student who reserved
    private String studentEmail;
    private String vendorId;
    private long reservedAt;        // Timestamp when reservation started (ms)
    private long expiresAt;         // Timestamp when reservation expires (ms)
    private String status;          // "active", "completed", "expired", "cancelled"
    private String qrCode;          // Unique QR code string for this reservation
    private String pickupLocation;


    // Required empty constructor for Firestore
    public Reservation() {}

    public Reservation(String foodId, String foodName, String studentId,
                       String studentEmail, String vendorId, String pickupLocation) {
        this.foodId = foodId;
        this.foodName = foodName;
        this.studentId = studentId;
        this.studentEmail = studentEmail;
        this.vendorId = vendorId;
        this.pickupLocation = pickupLocation;
        this.reservedAt = System.currentTimeMillis();
        this.expiresAt = System.currentTimeMillis() + (5 * 60 * 1000); // 5 minutes
        this.status = "active";
        this.qrCode = generateUniqueQRCode();
    }

    private String generateUniqueQRCode() {
        // Simple unique ID: timestamp + random + studentId suffix
        return "RQ" + System.currentTimeMillis() +
                (int)(Math.random() * 10000) +
                studentId.substring(0, Math.min(6, studentId.length()));
    }

    // Getters and Setters
    public String getReservationId() { return reservationId; }
    public void setReservationId(String reservationId) { this.reservationId = reservationId; }
    public String getFoodId() { return foodId; }
    public void setFoodId(String foodId) { this.foodId = foodId; }
    public String getFoodName() { return foodName; }
    public void setFoodName(String foodName) { this.foodName = foodName; }
    public String getStudentId() { return studentId; }
    public void setStudentId(String studentId) { this.studentId = studentId; }
    public String getStudentEmail() { return studentEmail; }
    public void setStudentEmail(String studentEmail) { this.studentEmail = studentEmail; }
    public String getVendorId() { return vendorId; }
    public void setVendorId(String vendorId) { this.vendorId = vendorId; }
    public long getReservedAt() { return reservedAt; }
    public void setReservedAt(long reservedAt) { this.reservedAt = reservedAt; }
    public long getExpiresAt() { return expiresAt; }
    public void setExpiresAt(long expiresAt) { this.expiresAt = expiresAt; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getQrCode() { return qrCode; }
    public void setQrCode(String qrCode) { this.qrCode = qrCode; }
    public String getPickupLocation() { return pickupLocation; }
    public void setPickupLocation(String pickupLocation) { this.pickupLocation = pickupLocation; }

    // Helper methods
    public boolean isExpired() {
        return System.currentTimeMillis() > expiresAt;
    }

    public long getTimeRemainingMs() {
        return Math.max(0, expiresAt - System.currentTimeMillis());
    }

    public String getFormattedTimeRemaining() {
        long remaining = getTimeRemainingMs();
        long minutes = remaining / 60000;
        long seconds = (remaining % 60000) / 1000;
        return String.format("%02d:%02d", minutes, seconds);
    }
}