package com.scom.foodresq;

import android.os.Bundle;
import android.widget.Button;
import android.widget.RatingBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FirebaseFirestore;

public class RateVendorActivity extends AppCompatActivity {

    private RatingBar ratingBar;
    private Button submitButton;
    private TextView foodNameText, vendorNameText;
    private FirebaseFirestore db;

    private String vendorId;
    private String foodName;
    private String reservationId;
    private String foodId;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_rate_vendor);

        ratingBar = findViewById(R.id.ratingBar);
        submitButton = findViewById(R.id.submitButton);
        foodNameText = findViewById(R.id.foodNameText);
        vendorNameText = findViewById(R.id.vendorNameText);

        db = FirebaseFirestore.getInstance();

        vendorId = getIntent().getStringExtra("vendor_id");
        foodName = getIntent().getStringExtra("food_name");
        reservationId = getIntent().getStringExtra("reservation_id");
        foodId = getIntent().getStringExtra("food_id");

        foodNameText.setText(foodName);

        loadVendorName();

        submitButton.setOnClickListener(v -> submitRating());
    }

    private void loadVendorName() {
        db.collection("users").document(vendorId)
                .get()
                .addOnSuccessListener(doc -> {
                    if (doc.exists()) {
                        String email = doc.getString("email");
                        String name = email != null ? email.split("@")[0] : "Vendor";
                        vendorNameText.setText(name);
                    } else {
                        vendorNameText.setText("Vendor");
                    }
                })
                .addOnFailureListener(e -> {
                    vendorNameText.setText("Vendor");
                });
    }

    private void submitRating() {
        int stars = (int) ratingBar.getRating();

        if (stars == 0) {
            Toast.makeText(this, "Please select a rating", Toast.LENGTH_SHORT).show();
            return;
        }

        String studentId = FirebaseAuth.getInstance().getCurrentUser().getUid();

        Rating rating = new Rating(
                studentId, "student",
                vendorId, "vendor",
                reservationId, foodId,
                stars, "", "food_quality"
        );

        db.collection("ratings")
                .add(rating)
                .addOnSuccessListener(docRef -> {
                    updateVendorAverageRating(vendorId);
                    Toast.makeText(RateVendorActivity.this, "Thank you for your rating!", Toast.LENGTH_SHORT).show();
                    finish();
                })
                .addOnFailureListener(e -> {
                    Toast.makeText(RateVendorActivity.this, "Error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                });
    }

    private void updateVendorAverageRating(String vendorId) {
        db.collection("ratings")
                .whereEqualTo("toUserId", vendorId)
                .get()
                .addOnSuccessListener(snapshots -> {
                    double total = 0;
                    int count = 0;
                    for (com.google.firebase.firestore.DocumentSnapshot doc : snapshots.getDocuments()) {
                        Rating r = doc.toObject(Rating.class);
                        if (r != null) {
                            total += r.getScore();
                            count++;
                        }
                    }
                    double avg = count > 0 ? total / count : 0;

                    java.util.Map<String, Object> updates = new java.util.HashMap<>();
                    updates.put("averageRating", avg);
                    updates.put("ratingCount", count);

                    db.collection("users").document(vendorId).update(updates);
                });
    }
}