package com.scom.foodresq;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FirebaseFirestore;
import com.journeyapps.barcodescanner.ScanContract;
import com.journeyapps.barcodescanner.ScanOptions;

import java.util.HashMap;
import java.util.Map;

public class QRScannerActivity extends AppCompatActivity {

    private ReservationRepository reservationRepo;
    private String currentVendorId;
    private boolean isAwaitingResult = false;
    private ActivityResultLauncher<ScanOptions> scanLauncher;
    private FirebaseFirestore db;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        reservationRepo = new ReservationRepository();
        db = FirebaseFirestore.getInstance();

        if (FirebaseAuth.getInstance().getCurrentUser() == null) {
            Toast.makeText(this, "Please login first", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        currentVendorId = FirebaseAuth.getInstance().getCurrentUser().getUid();

        scanLauncher = registerForActivityResult(new ScanContract(), result -> {
            isAwaitingResult = false;

            if (result.getContents() == null) {
                Toast.makeText(this, "Scan cancelled", Toast.LENGTH_SHORT).show();
                finish();
            } else {
                processQRCode(result.getContents());
            }
        });

        startScanning();
    }

    private void startScanning() {
        isAwaitingResult = true;
        ScanOptions options = new ScanOptions();
        options.setPrompt("Scan student's pickup QR code");
        options.setBeepEnabled(true);
        options.setOrientationLocked(false);
        options.setDesiredBarcodeFormats(ScanOptions.QR_CODE);
        scanLauncher.launch(options);
    }

    private void processQRCode(String qrCode) {
        reservationRepo.verifyQRCode(qrCode, currentVendorId,
                new ReservationRepository.VerificationCallback() {
                    @Override
                    public void onSuccess(Reservation reservation) {
                        updateReservationAndTriggerRating(reservation);

                        new Handler(Looper.getMainLooper()).post(() -> {
                            new MaterialAlertDialogBuilder(QRScannerActivity.this)
                                    .setTitle("✅ Pickup Verified")
                                    .setMessage(String.format(
                                            "Food: %s\nStudent: %s\n\nPickup completed successfully!",
                                            reservation.getFoodName(),
                                            reservation.getStudentEmail()))
                                    .setPositiveButton("Scan Another", (d, w) -> {
                                        startScanning();
                                    })
                                    .setNegativeButton("Exit", (d, w) -> {
                                        finish();
                                    })
                                    .setCancelable(false)
                                    .show();
                        });
                    }

                    @Override
                    public void onFailure(String error) {
                        new Handler(Looper.getMainLooper()).post(() -> {
                            new MaterialAlertDialogBuilder(QRScannerActivity.this)
                                    .setTitle("❌ Verification Failed")
                                    .setMessage(error)
                                    .setPositiveButton("Try Again", (d, w) -> {
                                        startScanning();
                                    })
                                    .setNegativeButton("Cancel", (d, w) -> {
                                        finish();
                                    })
                                    .setCancelable(false)
                                    .show();
                        });
                    }
                });
    }

    private void updateReservationAndTriggerRating(Reservation reservation) {
        Map<String, Object> updates = new HashMap<>();
        updates.put("status", "completed");
        updates.put("completedAt", System.currentTimeMillis());

        db.collection("reservations").document(reservation.getReservationId())
                .update(updates)
                .addOnSuccessListener(aVoid -> {
                    createRatingTrigger(reservation);
                });
    }

    private void createRatingTrigger(Reservation reservation) {
        Map<String, Object> trigger = new HashMap<>();
        trigger.put("reservationId", reservation.getReservationId());
        trigger.put("foodId", reservation.getFoodId());
        trigger.put("foodName", reservation.getFoodName());
        trigger.put("vendorId", reservation.getVendorId());
        trigger.put("studentId", reservation.getStudentId());
        trigger.put("needsRating", true);
        trigger.put("createdAt", System.currentTimeMillis());

        db.collection("ratingTriggers")
                .document(reservation.getReservationId())
                .set(trigger);
    }

    @Override
    protected void onStop() {
        super.onStop();
        isAwaitingResult = false;
    }
}