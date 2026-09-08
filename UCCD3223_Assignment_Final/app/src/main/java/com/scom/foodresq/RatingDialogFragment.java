package com.scom.foodresq;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.RatingBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.DialogFragment;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FirebaseFirestore;

import java.util.HashMap;
import java.util.Map;

public class RatingDialogFragment extends DialogFragment {

    private static final String ARG_VENDOR_ID = "vendor_id";
    private static final String ARG_FOOD_NAME = "food_name";
    private static final String ARG_RESERVATION_ID = "reservation_id";
    private static final String ARG_FOOD_ID = "food_id";

    private RatingBar ratingBar;
    private EditText commentInput;
    private Button submitButton;
    private TextView foodNameText;
    private FirebaseFirestore db;

    public static RatingDialogFragment newInstance(String vendorId, String foodName,
                                                   String reservationId, String foodId) {
        RatingDialogFragment fragment = new RatingDialogFragment();
        Bundle args = new Bundle();
        args.putString(ARG_VENDOR_ID, vendorId);
        args.putString(ARG_FOOD_NAME, foodName);
        args.putString(ARG_RESERVATION_ID, reservationId);
        args.putString(ARG_FOOD_ID, foodId);
        fragment.setArguments(args);
        return fragment;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.dialog_rating, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        ratingBar = view.findViewById(R.id.ratingBar);
        commentInput = view.findViewById(R.id.commentInput);
        submitButton = view.findViewById(R.id.submitButton);
        foodNameText = view.findViewById(R.id.foodNameText);
        db = FirebaseFirestore.getInstance();

        Bundle args = getArguments();
        if (args != null) {
            String foodName = args.getString(ARG_FOOD_NAME);
            foodNameText.setText("How was your " + foodName + "?");
        }

        setCancelable(false);

        submitButton.setOnClickListener(v -> submitRating());
    }

    private void submitRating() {
        Bundle args = getArguments();
        if (args == null) return;

        String vendorId = args.getString(ARG_VENDOR_ID);
        String foodName = args.getString(ARG_FOOD_NAME);
        String reservationId = args.getString(ARG_RESERVATION_ID);
        String foodId = args.getString(ARG_FOOD_ID);

        String studentId = FirebaseAuth.getInstance().getCurrentUser().getUid();

        int stars = (int) ratingBar.getRating();
        String comment = commentInput.getText().toString().trim();

        if (stars == 0) {
            Toast.makeText(getContext(), "Please select a rating", Toast.LENGTH_SHORT).show();
            return;
        }

        Rating rating = new Rating(
                studentId, "student",
                vendorId, "vendor",
                reservationId, foodId,
                stars, comment, "food_quality"
        );

        submitButton.setEnabled(false);
        submitButton.setText("Submitting...");

        db.collection("ratings")
                .add(rating)
                .addOnSuccessListener(docRef -> {
                    updateVendorAverageRating(vendorId);
                    clearRatingTrigger(reservationId);
                    Toast.makeText(getContext(), "Thank you for your feedback!", Toast.LENGTH_SHORT).show();
                    dismiss();
                    navigateToMainPage();
                })
                .addOnFailureListener(e -> {
                    submitButton.setEnabled(true);
                    submitButton.setText("Submit Rating");
                    Toast.makeText(getContext(), "Error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                });
    }

    private void navigateToMainPage() {
        if (getActivity() != null) {
            Intent intent = new Intent(getActivity(), StudentHomeActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
            getActivity().startActivity(intent);
            getActivity().finish();
        }
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

                    Map<String, Object> updates = new HashMap<>();
                    updates.put("averageRating", avg);
                    updates.put("ratingCount", count);

                    db.collection("users").document(vendorId).update(updates);
                });
    }

    private void clearRatingTrigger(String reservationId) {
        db.collection("ratingTriggers").document(reservationId)
                .update("needsRating", false)
                .addOnFailureListener(e -> {});
    }

    @Override
    public void onStart() {
        super.onStart();
        if (getDialog() != null && getDialog().getWindow() != null) {
            getDialog().getWindow().setLayout(ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT);
        }
    }
}