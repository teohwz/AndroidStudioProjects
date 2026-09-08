package com.scom.foodresq;

import android.graphics.Bitmap;
import android.os.Bundle;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.google.firebase.firestore.FirebaseFirestore;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.MultiFormatWriter;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.journeyapps.barcodescanner.BarcodeEncoder;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class QRCodeDisplayActivity extends AppCompatActivity {

    private String reservationId;
    private String foodId;
    private String foodName;
    private String vendorId;
    private String vendorName;
    private String expiryTime;
    private FirebaseFirestore db;
    private com.google.firebase.firestore.ListenerRegistration triggerListener;
    private boolean ratingShown = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_qr_display);

        db = FirebaseFirestore.getInstance();

        String qrCode = getIntent().getStringExtra("qr_code");
        foodName = getIntent().getStringExtra("food_name");
        vendorId = getIntent().getStringExtra("vendor_id");
        reservationId = getIntent().getStringExtra("reservation_id");
        foodId = getIntent().getStringExtra("food_id");
        vendorName = getIntent().getStringExtra("vendor_name");
        expiryTime = getIntent().getStringExtra("expiry_time");

        TextView foodNameText = findViewById(R.id.foodNameText);
        ImageView qrImage = findViewById(R.id.qrImage);
        Button btnDone = findViewById(R.id.btnDone);

        TextView detailFoodName = findViewById(R.id.detailFoodName);
        TextView detailVendor = findViewById(R.id.detailVendor);
        TextView detailExpiry = findViewById(R.id.detailExpiry);

        foodNameText.setText("Show to vendor for: " + foodName);

        if (detailFoodName != null) {
            detailFoodName.setText(foodName);
        }

        if (detailVendor != null) {
            if (vendorName != null && !vendorName.isEmpty()) {
                detailVendor.setText(vendorName);
            } else {
                loadVendorName(detailVendor);
            }
        }

        if (detailExpiry != null) {
            if (expiryTime != null && !expiryTime.isEmpty()) {
                detailExpiry.setText(expiryTime);
            } else {
                String expiryDisplay = "5 minutes";
                detailExpiry.setText(expiryDisplay);
            }
        }

        try {
            MultiFormatWriter writer = new MultiFormatWriter();
            BitMatrix matrix = writer.encode(qrCode, BarcodeFormat.QR_CODE, 500, 500);
            BarcodeEncoder encoder = new BarcodeEncoder();
            Bitmap bitmap = encoder.createBitmap(matrix);
            qrImage.setImageBitmap(bitmap);
        } catch (WriterException e) {
            e.printStackTrace();
        }

        btnDone.setOnClickListener(v -> {
            if (triggerListener != null) {
                triggerListener.remove();
            }
            finish();
        });

        listenForRatingTrigger();
    }

    private void loadVendorName(TextView detailVendor) {
        db.collection("users").document(vendorId)
                .get()
                .addOnSuccessListener(doc -> {
                    if (doc.exists()) {
                        String email = doc.getString("email");
                        String name = email != null ? email.split("@")[0] : "Vendor";
                        detailVendor.setText(name);
                    } else {
                        detailVendor.setText("Vendor");
                    }
                })
                .addOnFailureListener(e -> {
                    detailVendor.setText("Vendor");
                });
    }

    private void listenForRatingTrigger() {
        triggerListener = db.collection("ratingTriggers")
                .document(reservationId)
                .addSnapshotListener((snapshot, error) -> {
                    if (error != null) {
                        return;
                    }
                    if (snapshot != null && snapshot.exists() && !ratingShown) {
                        Boolean needsRating = snapshot.getBoolean("needsRating");
                        if (needsRating != null && needsRating) {
                            ratingShown = true;
                            showRatingDialog();
                        }
                    }
                });
    }

    private void showRatingDialog() {
        RatingDialogFragment.newInstance(vendorId, foodName, reservationId, foodId)
                .show(getSupportFragmentManager(), "rating_dialog");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (triggerListener != null) {
            triggerListener.remove();
        }
    }
}