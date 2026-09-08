package com.scom.foodresq;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.pm.PackageManager;
import android.location.Location;
import android.os.Bundle;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.firebase.auth.FirebaseAuth;

public class VendorPostFoodActivity extends AppCompatActivity {

    private static final int LOCATION_PERMISSION_CODE = 101;

    // ── Views ─────────────────────────────────────────────────────────────
    private EditText etName, etOriginalPrice, etPrice, etQty, etExpiry;
    private Spinner  spinnerCategory;
    private Button   btnPost;
    private TextView tvLocationStatus;

    // ── Dependencies ──────────────────────────────────────────────────────
    private FoodRepository              repository;
    private FirebaseAuth                auth;
    private FusedLocationProviderClient fusedClient;

    private double currentLat = 0.0;
    private double currentLng = 0.0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_vendor_post_food);

        repository  = new FoodRepository(this);
        auth        = FirebaseAuth.getInstance();
        fusedClient = LocationServices.getFusedLocationProviderClient(this);

        // Bind views
        etName          = findViewById(R.id.etName);
        etOriginalPrice = findViewById(R.id.etOriginalPrice);   // NEW
        etPrice         = findViewById(R.id.etPrice);
        etQty           = findViewById(R.id.etQty);
        etExpiry        = findViewById(R.id.etExpiry);
        spinnerCategory = findViewById(R.id.spinnerCategory);
        btnPost         = findViewById(R.id.btnPost);
        tvLocationStatus = findViewById(R.id.tvLocationStatus);

        ArrayAdapter<String> catAdapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_dropdown_item,
                FoodCategory.VENDOR_CATEGORIES
        );
        spinnerCategory.setAdapter(catAdapter);

        String editId = getIntent().getStringExtra("firestoreId");
        if (editId != null) prefillForEdit();

        btnPost.setOnClickListener(v -> requestLocationThenSubmit());

        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main), (v, insets) -> {
            Insets sb = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            v.setPadding(sb.left, sb.top, sb.right, sb.bottom);
            return insets;
        });
    }

    // ── GPS flow ──────────────────────────────────────────────────────────

    private void requestLocationThenSubmit() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                    this,
                    new String[]{Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION},
                    LOCATION_PERMISSION_CODE);
        } else {
            fetchLocationAndSubmit();
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOCATION_PERMISSION_CODE) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                fetchLocationAndSubmit();
            } else {
                Toast.makeText(this,
                        "Location permission denied — listing posted without map pin.",
                        Toast.LENGTH_LONG).show();
                submitListing();
            }
        }
    }

    @SuppressLint("MissingPermission")
    private void fetchLocationAndSubmit() {
        tvLocationStatus.setText("📍 Getting your location…");
        btnPost.setEnabled(false);

        fusedClient.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                .addOnSuccessListener(location -> {
                    if (location != null) {
                        currentLat = location.getLatitude();
                        currentLng = location.getLongitude();
                        tvLocationStatus.setText(String.format(
                                "📍 Location: %.5f, %.5f", currentLat, currentLng));
                    } else {
                        fusedClient.getLastLocation().addOnSuccessListener(last -> {
                            if (last != null) {
                                currentLat = last.getLatitude();
                                currentLng = last.getLongitude();
                                tvLocationStatus.setText(String.format(
                                        "📍 Location (cached): %.5f, %.5f",
                                        currentLat, currentLng));
                            } else {
                                tvLocationStatus.setText("⚠️ Location unavailable");
                            }
                            submitListing();
                        });
                        return;
                    }
                    submitListing();
                })
                .addOnFailureListener(e -> {
                    tvLocationStatus.setText("⚠️ Location error — posting without pin");
                    submitListing();
                });
    }

    // ── Form submission ───────────────────────────────────────────────────

    private void submitListing() {
        btnPost.setEnabled(false);

        if (auth.getCurrentUser() == null) {
            Toast.makeText(this, "Not logged in", Toast.LENGTH_SHORT).show();
            btnPost.setEnabled(true);
            return;
        }

        String name          = etName.getText().toString().trim();
        String originalPrice = etOriginalPrice.getText().toString().trim(); // NEW
        String price         = etPrice.getText().toString().trim();
        String qty           = etQty.getText().toString().trim();
        String expiry        = etExpiry.getText().toString().trim();
        String category      = spinnerCategory.getSelectedItem().toString();

        if (name.isEmpty() || price.isEmpty() || qty.isEmpty() || expiry.isEmpty()) {
            Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show();
            btnPost.setEnabled(true);
            return;
        }

        // If vendor didn't fill originalPrice, default it to the discounted price
        if (originalPrice.isEmpty()) {
            originalPrice = price;
        }

        // Validate: originalPrice should not be less than discounted price
        try {
            double orig = Double.parseDouble(originalPrice);
            double disc = Double.parseDouble(price);
            if (orig < disc) {
                Toast.makeText(this,
                        "Original price can't be less than discounted price",
                        Toast.LENGTH_SHORT).show();
                btnPost.setEnabled(true);
                return;
            }
        } catch (NumberFormatException e) {
            Toast.makeText(this, "Please enter valid prices", Toast.LENGTH_SHORT).show();
            btnPost.setEnabled(true);
            return;
        }

        String uid  = auth.getCurrentUser().getUid();
        // NEW: pass originalPrice into Food constructor
        Food food = new Food(name, originalPrice, price, qty, expiry, uid, category,
                currentLat, currentLng);

        String editId = getIntent().getStringExtra("firestoreId");

        if (editId != null) {
            food.setFirestoreId(editId);
            repository.updateFood(food, new FoodRepository.WriteCallback() {
                @Override public void onSuccess(String id) {
                    Toast.makeText(VendorPostFoodActivity.this,
                            "Listing updated!", Toast.LENGTH_SHORT).show();
                    finish();
                }
                @Override public void onFailure(String error) {
                    Toast.makeText(VendorPostFoodActivity.this,
                            "Error: " + error, Toast.LENGTH_LONG).show();
                    btnPost.setEnabled(true);
                }
            });
        } else {
            repository.addFood(food, new FoodRepository.WriteCallback() {
                @Override public void onSuccess(String id) {
                    Toast.makeText(VendorPostFoodActivity.this,
                            "Listing posted!", Toast.LENGTH_SHORT).show();
                    clearFields();
                    btnPost.setEnabled(true);
                }
                @Override public void onFailure(String error) {
                    Toast.makeText(VendorPostFoodActivity.this,
                            "Error: " + error, Toast.LENGTH_LONG).show();
                    btnPost.setEnabled(true);
                }
            });
        }
    }

    // ── Edit mode prefill ─────────────────────────────────────────────────

    private void prefillForEdit() {
        etName.setText(getIntent().getStringExtra("name"));
        // prefill originalPrice if available, else fall back to price
        String origPrice = getIntent().getStringExtra("originalPrice");
        etOriginalPrice.setText(origPrice != null ? origPrice :
                getIntent().getStringExtra("price"));
        etPrice.setText(getIntent().getStringExtra("price"));
        etQty.setText(getIntent().getStringExtra("quantity"));
        etExpiry.setText(getIntent().getStringExtra("expiry"));

        String cat = getIntent().getStringExtra("category");
        if (cat != null) {
            for (int i = 0; i < FoodCategory.VENDOR_CATEGORIES.size(); i++) {
                if (FoodCategory.VENDOR_CATEGORIES.get(i).equals(cat)) {
                    spinnerCategory.setSelection(i);
                    break;
                }
            }
        }
        btnPost.setText("Update Listing");
    }

    private void clearFields() {
        etName.setText("");
        etOriginalPrice.setText("");
        etPrice.setText("");
        etQty.setText("");
        etExpiry.setText("");
        spinnerCategory.setSelection(0);
        currentLat = 0.0;
        currentLng = 0.0;
        tvLocationStatus.setText("📍 Location will be captured on submit");
    }
}
