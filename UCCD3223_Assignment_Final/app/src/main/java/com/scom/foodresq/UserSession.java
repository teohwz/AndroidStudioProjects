package com.scom.foodresq;

import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.auth.FirebaseAuth;

public class UserSession {

    FirebaseFirestore db = FirebaseFirestore.getInstance();
    FirebaseAuth auth = FirebaseAuth.getInstance();

    public interface RoleCallback {
        void onRoleReceived(String role);
        void onError(String error);
    }

    public void getUserRole(RoleCallback callback) {

        if (auth.getCurrentUser() == null) {
            callback.onError("User not logged in");
            return;
        }

        String uid = auth.getCurrentUser().getUid();

        db.collection("users").document(uid)
                .get()
                .addOnSuccessListener(doc -> {

                    if (doc.exists()) {

                        String role = doc.getString("role");

                        if (role == null) {
                            role = "student";
                        }

                        callback.onRoleReceived(role);

                    } else {
                        callback.onError("User data not found");
                    }

                })
                .addOnFailureListener(e ->
                        callback.onError(e.getMessage())
                );
    }
}