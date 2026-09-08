package com.scom.foodresq;

import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.Toast;
import android.widget.ArrayAdapter;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import android.content.Intent;

import java.util.HashMap;
import java.util.Map;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FirebaseFirestore;

public class MainActivity extends AppCompatActivity {

    EditText email, password;
    Button btnLogin, btnRegister;
    FirebaseAuth auth;
    FirebaseFirestore db;
    Spinner roleSpinner;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_main);

        email = findViewById(R.id.email);
        password = findViewById(R.id.password);
        btnLogin = findViewById(R.id.btnLogin);
        btnRegister = findViewById(R.id.btnRegister);
        roleSpinner = findViewById(R.id.roleSpinner);

        auth = FirebaseAuth.getInstance();
        db = FirebaseFirestore.getInstance();

        // SPINNER
        String[] roles = {"student", "vendor"};

        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_dropdown_item,
                roles
        );

        roleSpinner.setAdapter(adapter);

        // LOGIN
        btnLogin.setOnClickListener(v -> {

            String em = email.getText().toString().trim();
            String pw = password.getText().toString().trim();

            if (em.isEmpty() || pw.isEmpty()) {
                Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show();
                return;
            }

            auth.signInWithEmailAndPassword(em, pw)
                    .addOnSuccessListener(authResult -> {


                        String uid = auth.getCurrentUser().getUid();

                        db.collection("users").document(uid)
                                .get()
                                .addOnSuccessListener(document -> {

                                    String role = document.getString("role");

                                    if ("vendor".equals(role)) {
                                        Toast.makeText(this, "Welcome Vendor", Toast.LENGTH_SHORT).show();
                                        startActivity(new Intent(MainActivity.this, VendorHomeActivity.class));
                                        finish();
                                    } else {
                                        Toast.makeText(this, "Welcome Student", Toast.LENGTH_SHORT).show();
                                        startActivity(new Intent(MainActivity.this, StudentHomeActivity.class));
                                        finish();
                                    }
                                });
                    })
                    .addOnFailureListener(e ->
                            Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG).show()
                    );
        });

        //REGISTER
        btnRegister.setOnClickListener(v -> {

            String em = email.getText().toString().trim();
            String pw = password.getText().toString().trim();

            if (em.isEmpty() || pw.isEmpty()) {
                Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show();
                return;
            }

            if (pw.length() < 6) {
                Toast.makeText(this, "Password must be at least 6 characters", Toast.LENGTH_SHORT).show();
                return;
            }

            auth.createUserWithEmailAndPassword(em, pw)
                    .addOnSuccessListener(authResult -> {

                        String uid = auth.getCurrentUser().getUid();

                        String role = roleSpinner.getSelectedItem().toString();

                        Map<String, Object> user = new HashMap<>();
                        user.put("email", em);
                        user.put("role", role);
                        user.put("uid", uid);
                        user.put("createdAt", System.currentTimeMillis());

                        db.collection("users")
                                .document(uid)
                                .set(user)
                                .addOnSuccessListener(aVoid ->
                                        Toast.makeText(this, "Register Success + Role saved", Toast.LENGTH_SHORT).show()
                                )
                                .addOnFailureListener(e ->
                                        Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG).show()
                                );
                    })
                    .addOnFailureListener(e ->
                            Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG).show()
                    );
        });

        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main), (v, insets) -> {
            Insets systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom);
            return insets;
        });
    }
}