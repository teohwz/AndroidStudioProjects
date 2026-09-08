package com.scom.foodresq;

import android.content.Intent;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.LatLngBounds;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.material.chip.Chip;
import com.google.android.material.chip.ChipGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.firebase.auth.FirebaseAuth;
import com.scom.foodresq.db.FoodEntity;
import com.scom.foodresq.db.PastOrderEntity;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Student home screen with 3 tabs:
 *  1. Browse  — RecyclerView + search + category chips
 *  2. Dashboard — impact stats + recent orders
 *  3. Map  — Google Map with food markers; tap a pin to order
 */
public class StudentHomeActivity extends AppCompatActivity implements OnMapReadyCallback {

    // ── Browse ────────────────────────────────────────────────────────────
    private RecyclerView   recyclerView;
    private FoodAdapter    adapter;
    private EditText       searchBar;
    private ChipGroup      chipGroup;
    private FoodRepository repository;
    private String         activeCategory = FoodCategory.ALL;

    // ── Reservation timer ─────────────────────────────────────────────────
    private ReservationRepository reservationRepo;
    private View          timerBanner;
    private TextView      timerText;
    private CountDownTimer countDownTimer;
    private Reservation   activeReservation;

    // ── Tabs ──────────────────────────────────────────────────────────────
    private LinearLayout layoutList;
    private ScrollView   layoutDashboard;
    private FrameLayout  layoutMap;
    private Button       tabBrowse, tabDashboard, tabMap;

    // ── Dashboard ─────────────────────────────────────────────────────────
    private TextView tvTotalMeals, tvTotalSavings, tvCO2, tvTotalOrders;
    private RecyclerView rvRecentOrders;
    private RecentOrderAdapter recentOrderAdapter;
    private static final double CO2_PER_MEAL_KG = 2.5;

    // ── Map ───────────────────────────────────────────────────────────────
    private GoogleMap  googleMap;
    private boolean    mapReady      = false;
    private boolean    mapInitialized = false;
    private List<FoodEntity> latestFoods = new ArrayList<>();

    // Marker → FoodEntity lookup
    private final Map<Marker, FoodEntity> markerFoodMap = new HashMap<>();

    // Selected food (for the bottom info card)
    private FoodEntity selectedFood;

    // Map info card views
    private View     cardMapInfo;
    private TextView tvMapFoodName, tvMapFoodDetails;
    private Button   btnMapOrder;

    // ─────────────────────────────────────────────────────────────────────

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_student_home);

        repository      = new FoodRepository(this);
        reservationRepo = new ReservationRepository();

        repository.cleanupExpiredFoods();
        repository.syncFoodsFromFirestore(null);
        reservationRepo.releaseExpiredReservations();

        // Timer banner
        timerBanner = findViewById(R.id.timerBanner);

        Button btnShowQR = findViewById(R.id.btnShowQR);
        btnShowQR.setOnClickListener(v -> {
            if (activeReservation != null) {
                Intent intent = new Intent(this, QRCodeDisplayActivity.class);
                intent.putExtra("qr_code", activeReservation.getQrCode());
                intent.putExtra("food_name", activeReservation.getFoodName());
                startActivity(intent);
            }
        });

        timerText   = findViewById(R.id.timerText);
        checkActiveReservation();

        // Tab panels
        layoutList      = findViewById(R.id.layoutList);
        layoutDashboard = findViewById(R.id.layoutDashboard);
        layoutMap       = findViewById(R.id.layoutMap);
        tabBrowse       = findViewById(R.id.tabBrowse);
        tabDashboard    = findViewById(R.id.tabDashboard);
        tabMap          = findViewById(R.id.tabMap);

        tabBrowse.setOnClickListener(v -> showTab(0));
        tabDashboard.setOnClickListener(v -> showTab(1));
        tabMap.setOnClickListener(v -> showTab(2));

        // ── Browse setup ──────────────────────────────────────────────────
        recyclerView = findViewById(R.id.recyclerView);
        adapter      = new FoodAdapter();
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        recyclerView.setAdapter(adapter);

        adapter.setOnItemClickListener(new FoodAdapter.OnItemClickListener() {
            @Override public void onItemClick(FoodEntity food)     { showOrderDialog(food); }
            @Override public void onItemLongClick(FoodEntity food) {}
        });

        searchBar = findViewById(R.id.searchBar);
        chipGroup = findViewById(R.id.chipGroup);
        buildCategoryChips();
        searchBar.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int i, int i1, int i2) {}
            @Override public void onTextChanged(CharSequence s, int i, int i1, int i2) { observeFoods(); }
            @Override public void afterTextChanged(Editable e) {}
        });
        observeFoods();

        repository.syncFoodsFromFirestore(new FoodRepository.SyncCallback() {
            @Override public void onSuccess() {}
            @Override public void onFailure(String e) {
                Toast.makeText(StudentHomeActivity.this,
                        "Offline — showing cached data", Toast.LENGTH_SHORT).show();
            }
        });

        // ── Dashboard setup ───────────────────────────────────────────────
        tvTotalMeals   = findViewById(R.id.tvTotalMeals);
        tvTotalSavings = findViewById(R.id.tvTotalSavings);
        tvCO2          = findViewById(R.id.tvCO2);
        tvTotalOrders  = findViewById(R.id.tvTotalOrders);
        rvRecentOrders = findViewById(R.id.rvRecentOrders);

        recentOrderAdapter = new RecentOrderAdapter();
        rvRecentOrders.setLayoutManager(new LinearLayoutManager(this));
        rvRecentOrders.setAdapter(recentOrderAdapter);
        rvRecentOrders.setNestedScrollingEnabled(false);
        observeDashboard();

        // ── Map setup ─────────────────────────────────────────────────────
        cardMapInfo     = findViewById(R.id.cardMapInfo);
        tvMapFoodName   = findViewById(R.id.tvMapFoodName);
        tvMapFoodDetails= findViewById(R.id.tvMapFoodDetails);
        btnMapOrder     = findViewById(R.id.btnMapOrder);
        btnMapOrder.setOnClickListener(v -> {
            if (selectedFood != null) showOrderDialog(selectedFood);
        });

        SupportMapFragment mapFragment =
                (SupportMapFragment) getSupportFragmentManager().findFragmentById(R.id.mapFragment);
        if (mapFragment != null) mapFragment.getMapAsync(this);

        // Keep a copy of latest foods for map markers
        repository.getAllFoods().observe(this, foods -> {
            latestFoods = foods != null ? foods : new ArrayList<>();
            if (mapReady) refreshMapMarkers();
        });
    }

    // ─────────────────────────────────────────────────────────────────────
    // Tab switching
    // ─────────────────────────────────────────────────────────────────────

    private void showTab(int tab) {
        layoutList.setVisibility(tab == 0 ? View.VISIBLE : View.GONE);
        layoutDashboard.setVisibility(tab == 1 ? View.VISIBLE : View.GONE);
        layoutMap.setVisibility(tab == 2 ? View.VISIBLE : View.GONE);

        int active   = getResources().getColor(android.R.color.holo_green_dark, null);
        int inactive = getResources().getColor(android.R.color.darker_gray, null);

        tabBrowse.setTextColor(tab == 0 ? active : inactive);
        tabDashboard.setTextColor(tab == 1 ? active : inactive);
        tabMap.setTextColor(tab == 2 ? active : inactive);

        // Initialise map camera once map is first shown
        if (tab == 2 && mapReady && !mapInitialized) {
            initMapCamera();
            mapInitialized = true;
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Google Maps
    // ─────────────────────────────────────────────────────────────────────

    @Override
    public void onMapReady(GoogleMap map) {
        googleMap = map;
        mapReady  = true;

        googleMap.getUiSettings().setZoomControlsEnabled(true);
        googleMap.getUiSettings().setMyLocationButtonEnabled(false);

        googleMap.setOnMarkerClickListener(marker -> {
            FoodEntity food = markerFoodMap.get(marker);
            if (food != null) showMapInfoCard(food);
            return true;
        });

        googleMap.setOnMapClickListener(latLng -> {
            cardMapInfo.setVisibility(View.GONE);
            selectedFood = null;
        });

        refreshMapMarkers();

        // If map tab is currently visible, initialise camera now
        if (layoutMap.getVisibility() == View.VISIBLE && !mapInitialized) {
            initMapCamera();
            mapInitialized = true;
        }
    }

    private void refreshMapMarkers() {
        if (googleMap == null) return;
        googleMap.clear();
        markerFoodMap.clear();

        for (FoodEntity food : latestFoods) {
            if (food.latitude == 0.0 && food.longitude == 0.0) continue;

            LatLng pos = new LatLng(food.latitude, food.longitude);
            Marker marker = googleMap.addMarker(new MarkerOptions()
                    .position(pos)
                    .title(food.name)
                    .snippet("RM " + food.price + " · Qty: " + food.quantity)
                    .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN)));

            if (marker != null) markerFoodMap.put(marker, food);
        }
    }

    /** Zoom camera to fit all markers, or default to Malaysia if none. */
    private void initMapCamera() {
        if (latestFoods.isEmpty()) {
            // Default: Malaysia
            googleMap.moveCamera(CameraUpdateFactory.newLatLngZoom(
                    new LatLng(4.2105, 101.9758), 6f));
            return;
        }

        LatLngBounds.Builder builder = new LatLngBounds.Builder();
        boolean anyPin = false;
        for (FoodEntity f : latestFoods) {
            if (f.latitude != 0.0 || f.longitude != 0.0) {
                builder.include(new LatLng(f.latitude, f.longitude));
                anyPin = true;
            }
        }

        if (anyPin) {
            try {
                googleMap.animateCamera(
                        CameraUpdateFactory.newLatLngBounds(builder.build(), 150));
            } catch (Exception e) {
                googleMap.moveCamera(CameraUpdateFactory.newLatLngZoom(
                        new LatLng(4.2105, 101.9758), 12f));
            }
        } else {
            googleMap.moveCamera(CameraUpdateFactory.newLatLngZoom(
                    new LatLng(4.2105, 101.9758), 6f));
        }
    }

    private void showMapInfoCard(FoodEntity food) {
        selectedFood = food;
        tvMapFoodName.setText(food.name);
        tvMapFoodDetails.setText(
                food.category + " · RM " + food.price + " · Qty: " + food.quantity);
        cardMapInfo.setVisibility(View.VISIBLE);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Dashboard
    // ─────────────────────────────────────────────────────────────────────

    private void observeDashboard() {
        String uid = currentUid();
        if (uid == null) return;

        repository.getTotalMealsRescued(uid).observe(this, meals -> {
            int m = meals != null ? meals : 0;
            tvTotalMeals.setText(String.valueOf(m));
            tvCO2.setText(String.format(Locale.getDefault(), "%.2f kg", m * CO2_PER_MEAL_KG));
        });

        repository.getTotalSavings(uid).observe(this, savings -> {
            double s = savings != null ? savings : 0.0;
            tvTotalSavings.setText(String.format(Locale.getDefault(), "RM %.2f", s));
        });

        repository.getLiveOrderCount(uid).observe(this, count ->
                tvTotalOrders.setText(String.valueOf(count != null ? count : 0)));

        repository.getRecentOrders(uid, 10).observe(this,
                orders -> recentOrderAdapter.submitList(orders));
    }

    // ─────────────────────────────────────────────────────────────────────
    // Browse
    // ─────────────────────────────────────────────────────────────────────

    private void observeFoods() {
        String term = searchBar != null ? searchBar.getText().toString() : "";
        repository.searchFoods(term, activeCategory)
                  .observe(this, foods -> adapter.submitList(foods));
    }

    private void buildCategoryChips() {
        for (String cat : FoodCategory.ALL_CATEGORIES) {
            Chip chip = new Chip(this);
            chip.setText(cat);
            chip.setCheckable(true);
            chip.setChecked(cat.equals(FoodCategory.ALL));
            chip.setOnCheckedChangeListener((btn, checked) -> {
                if (checked) { activeCategory = cat; observeFoods(); }
            });
            chipGroup.addView(chip);
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Order dialog
    // ─────────────────────────────────────────────────────────────────────

    private void showOrderDialog(FoodEntity food) {
        new AlertDialog.Builder(this)
                .setTitle("Order: " + food.name)
                .setMessage("Price: RM " + food.price
                        + "\nCategory: " + food.category
                        + "\nAvailable qty: " + food.quantity
                        + "\n\nConfirm order (qty: 1)?")
                .setPositiveButton("Order", (d, w) -> placeOrder(food))
                .setNegativeButton("Cancel", null)
                .show();
    }

    private void placeOrder(FoodEntity food) {
        String uid   = currentUid();
        String email = FirebaseAuth.getInstance().getCurrentUser() != null
                ? FirebaseAuth.getInstance().getCurrentUser().getEmail() : "";

        recyclerView.setEnabled(false);
        cardMapInfo.setVisibility(View.GONE);

        reservationRepo.createReservation(food, uid, email,
                new ReservationRepository.ReservationCallback() {
                    @Override
                    public void onSuccess(Reservation reservation) {
                        runOnUiThread(() -> {
                            recyclerView.setEnabled(true);
                            activeReservation = reservation;
                            startCountdownTimer(reservation);

                            String origPrice = (food.originalPrice != null && !food.originalPrice.isEmpty())
                                    ? food.originalPrice
                                    : food.price;

                            PastOrderEntity order = new PastOrderEntity(
                                    food.firestoreId,
                                    food.name,
                                    food.category,
                                    origPrice,       // originalFoodPrice
                                    food.price,      // foodPrice (discounted)
                                    food.vendorId,
                                    uid,
                                    1);

                            new FoodRepository(StudentHomeActivity.this).savePastOrder(order);

                            showQRCodeDialog(reservation);
                        });
                    }
                    @Override
                    public void onFailure(String error) {
                        runOnUiThread(() -> {
                            recyclerView.setEnabled(true);
                            Toast.makeText(StudentHomeActivity.this,
                                    error, Toast.LENGTH_LONG).show();
                        });
                    }
                });
    }

    // ─────────────────────────────────────────────────────────────────────
    // Reservation timer
    // ─────────────────────────────────────────────────────────────────────

    private void checkActiveReservation() {
        String uid = currentUid();
        if (uid == null) return;
        reservationRepo.getActiveReservation(uid).observe(this, reservation -> {
            if (reservation != null && "active".equals(reservation.getStatus())) {
                activeReservation = reservation;
                startCountdownTimer(reservation);
                timerBanner.setVisibility(View.VISIBLE);
            } else {
                timerBanner.setVisibility(View.GONE);
                if (countDownTimer != null) countDownTimer.cancel();
            }
        });
    }

    private void startCountdownTimer(Reservation reservation) {
        if (countDownTimer != null) countDownTimer.cancel();
        long remainingMs = reservation.getTimeRemainingMs();
        if (remainingMs <= 0) return;
        timerBanner.setVisibility(View.VISIBLE);
        countDownTimer = new CountDownTimer(remainingMs, 1000) {
            @Override public void onTick(long ms) {
                timerText.setText(String.format(Locale.getDefault(),
                        "%02d:%02d", ms / 60000, (ms % 60000) / 1000));
            }
            @Override public void onFinish() {
                timerBanner.setVisibility(View.GONE);
                Toast.makeText(StudentHomeActivity.this,
                        "Reservation expired! The food is now available again.",
                        Toast.LENGTH_LONG).show();
            }
        }.start();
    }

    private void showQRCodeDialog(Reservation reservation) {
        new MaterialAlertDialogBuilder(this)
                .setTitle("✓ Food Reserved!")
                .setMessage("Food: " + reservation.getFoodName()
                        + "\nExpires in: 5 minutes\n\nShow this QR code to the vendor for pickup.\n\nAfter vendor scans, you can rate them.")
                .setPositiveButton("Show QR", (d, w) -> {
                    Intent intent = new Intent(this, QRCodeDisplayActivity.class);
                    intent.putExtra("qr_code", reservation.getQrCode());
                    intent.putExtra("food_name", reservation.getFoodName());
                    intent.putExtra("vendor_id", reservation.getVendorId());
                    intent.putExtra("reservation_id", reservation.getReservationId());
                    intent.putExtra("food_id", reservation.getFoodId());

                    String expiryTime = new SimpleDateFormat("HH:mm", Locale.getDefault())
                            .format(new Date(reservation.getExpiresAt()));
                    intent.putExtra("expiry_time", expiryTime);

                    startActivity(intent);
                })
                .setNegativeButton("Cancel", null)
                .show();
    }

    private String currentUid() {
        return FirebaseAuth.getInstance().getCurrentUser() != null
                ? FirebaseAuth.getInstance().getCurrentUser().getUid() : null;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Inner adapter: recent orders list in Dashboard
    // ─────────────────────────────────────────────────────────────────────

    private static class RecentOrderAdapter
            extends androidx.recyclerview.widget.ListAdapter<PastOrderEntity,
                                                             RecentOrderAdapter.VH> {

        private static final androidx.recyclerview.widget.DiffUtil.ItemCallback<PastOrderEntity> DIFF =
                new androidx.recyclerview.widget.DiffUtil.ItemCallback<PastOrderEntity>() {
                    @Override public boolean areItemsTheSame(PastOrderEntity a, PastOrderEntity b) { return a.id == b.id; }
                    @Override public boolean areContentsTheSame(PastOrderEntity a, PastOrderEntity b) { return a.id == b.id && a.orderedAt == b.orderedAt; }
                };

        RecentOrderAdapter() { super(DIFF); }

        @Override
        public VH onCreateViewHolder(android.view.ViewGroup parent, int viewType) {
            LinearLayout row = new LinearLayout(parent.getContext());
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(16, 14, 16, 14);
            row.setBackgroundColor(android.graphics.Color.WHITE);
            LinearLayout.LayoutParams lp =
                    new LinearLayout.LayoutParams(
                            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                            android.view.ViewGroup.LayoutParams.WRAP_CONTENT);
            lp.setMargins(0, 0, 0, 4);
            row.setLayoutParams(lp);

            LinearLayout left = new LinearLayout(parent.getContext());
            left.setOrientation(LinearLayout.VERTICAL);
            left.setLayoutParams(new LinearLayout.LayoutParams(
                    0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

            TextView tvName = new TextView(parent.getContext());
            tvName.setTextSize(14); tvName.setTypeface(null, android.graphics.Typeface.BOLD);
            tvName.setTextColor(android.graphics.Color.parseColor("#212121")); tvName.setTag("name");

            TextView tvCat = new TextView(parent.getContext());
            tvCat.setTextSize(12); tvCat.setTextColor(android.graphics.Color.parseColor("#757575")); tvCat.setTag("cat");

            TextView tvDate = new TextView(parent.getContext());
            tvDate.setTextSize(11); tvDate.setTextColor(android.graphics.Color.parseColor("#BDBDBD")); tvDate.setTag("date");

            left.addView(tvName); left.addView(tvCat); left.addView(tvDate);

            TextView tvPrice = new TextView(parent.getContext());
            tvPrice.setTextSize(14); tvPrice.setTypeface(null, android.graphics.Typeface.BOLD);
            tvPrice.setTextColor(android.graphics.Color.parseColor("#2E7D32"));
            tvPrice.setGravity(android.view.Gravity.END | android.view.Gravity.CENTER_VERTICAL);
            tvPrice.setTag("price");

            row.addView(left); row.addView(tvPrice);
            return new VH(row);
        }

        @Override
        public void onBindViewHolder(VH holder, int position) {
            PastOrderEntity o = getItem(position);
            SimpleDateFormat sdf = new SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault());
            ((TextView) holder.row.findViewWithTag("name")).setText(o.foodName);
            ((TextView) holder.row.findViewWithTag("cat")).setText(o.foodCategory);
            ((TextView) holder.row.findViewWithTag("date")).setText(sdf.format(new Date(o.orderedAt)));
            double p = 0; try { p = Double.parseDouble(o.foodPrice); } catch (Exception ignored) {}
            ((TextView) holder.row.findViewWithTag("price")).setText(
                    String.format(Locale.getDefault(), "RM %.2f", p * o.quantityOrdered));
        }

        static class VH extends RecyclerView.ViewHolder {
            final LinearLayout row;
            VH(LinearLayout v) { super(v); row = v; }
        }
    }
}
