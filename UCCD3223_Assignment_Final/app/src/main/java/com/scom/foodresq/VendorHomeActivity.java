package com.scom.foodresq;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.Observer;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.firebase.auth.FirebaseAuth;
import com.scom.foodresq.db.FoodEntity;

import java.util.List;

/**
 * Vendor Home — shows the vendor's own listings from Room cache.
 *
 * Features
 * ────────
 * • RecyclerView of this vendor's food listings (Room LiveData).
 * • FAB → VendorPostFoodActivity (post a new listing).
 * • Long-press a listing → Edit / Delete dialog.
 * • On launch, syncs listings from Firestore into Room.
 */
public class VendorHomeActivity extends AppCompatActivity {

    private RecyclerView   recyclerView;
    private FoodAdapter    adapter;
    private FoodRepository repository;

    private ReservationRepository reservationRepo;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_vendor_home);

        repository   = new FoodRepository(this);

        repository.cleanupExpiredFoods();

        reservationRepo = new ReservationRepository();
        reservationRepo.releaseExpiredReservations();

        recyclerView = findViewById(R.id.recyclerView);

        adapter = new FoodAdapter();
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        recyclerView.setAdapter(adapter);

        adapter.setOnItemClickListener(new FoodAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(FoodEntity food) {
                // Tap = quick view; long-press = edit/delete
                Toast.makeText(VendorHomeActivity.this,
                        food.name + " — tap & hold to edit/delete", Toast.LENGTH_SHORT).show();
            }
            @Override
            public void onItemLongClick(FoodEntity food) {
                showEditDeleteDialog(food);
            }
        });

        // FAB to post a new listing
        FloatingActionButton fab = findViewById(R.id.fabAddFood);
        if (fab != null) {
            fab.setOnClickListener(v ->
                    startActivity(new Intent(this, VendorPostFoodActivity.class)));
        }

        // QR Scan Button
        Button btnScanQR = findViewById(R.id.btnScanQR);
        if (btnScanQR != null) {
            btnScanQR.setOnClickListener(v -> {
                Intent intent = new Intent(VendorHomeActivity.this, QRScannerActivity.class);
                startActivity(intent);
            });
        }

        loadVendorListings();
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Refresh after returning from VendorPostFoodActivity
        repository.syncFoodsFromFirestore(null);
    }

    private void loadVendorListings() {
        String uid = FirebaseAuth.getInstance().getCurrentUser() != null
                ? FirebaseAuth.getInstance().getCurrentUser().getUid()
                : "";

        repository.getFoodsByVendor(uid).observe(this, foods -> adapter.submitList(foods));

        // Pull fresh data from Firestore in background
        repository.syncFoodsFromFirestore(new FoodRepository.SyncCallback() {
            @Override public void onSuccess() {}
            @Override public void onFailure(String error) {
                Toast.makeText(VendorHomeActivity.this,
                        "Offline — showing cached listings", Toast.LENGTH_SHORT).show();
            }
        });
    }

    // ── Edit / Delete ─────────────────────────────────────────────────────

    private void showEditDeleteDialog(FoodEntity food) {
        new AlertDialog.Builder(this)
                .setTitle(food.name)
                .setItems(new String[]{"Edit", "Delete"}, (dialog, which) -> {
                    if (which == 0) openEditDialog(food);
                    else            confirmDelete(food);
                })
                .show();
    }

    private void openEditDialog(FoodEntity food) {
        // Pass firestoreId to VendorPostFoodActivity via Intent extras for edit mode
        Intent intent = new Intent(this, VendorPostFoodActivity.class);
        intent.putExtra("firestoreId",  food.firestoreId);
        intent.putExtra("name",         food.name);
        intent.putExtra("price",        food.price);
        intent.putExtra("quantity",     food.quantity);
        intent.putExtra("expiry",       food.expiry);
        intent.putExtra("category",     food.category);
        startActivity(intent);
    }

    private void confirmDelete(FoodEntity food) {
        new AlertDialog.Builder(this)
                .setTitle("Delete " + food.name + "?")
                .setMessage("This cannot be undone.")
                .setPositiveButton("Delete", (d, w) ->
                        repository.deleteFood(food.firestoreId, new FoodRepository.WriteCallback() {
                            @Override
                            public void onSuccess(String id) {
                                Toast.makeText(VendorHomeActivity.this,
                                        "Deleted", Toast.LENGTH_SHORT).show();
                            }
                            @Override
                            public void onFailure(String error) {
                                Toast.makeText(VendorHomeActivity.this,
                                        "Error: " + error, Toast.LENGTH_LONG).show();
                            }
                        }))
                .setNegativeButton("Cancel", null)
                .show();
    }
}
