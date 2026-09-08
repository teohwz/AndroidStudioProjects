package my.edu.utar.passwordmanager;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.text.method.HideReturnsTransformationMethod;
import android.text.method.PasswordTransformationMethod;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import java.util.Random;

public class AddEditPasswordActivity extends AppCompatActivity {

    private EditText etSiteName, etUsername, etPassword;
    private ImageButton btnToggleVisibility, btnCopy;
    private Button btnGenerate, btnSave;
    private boolean isPasswordVisible = false;
    private int existingId = -1; // -1 means we are adding a NEW password. Any other number means EDIT.

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_add_edit_password);

        // 1. Initialize all views
        etSiteName = findViewById(R.id.etSiteName);
        etUsername = findViewById(R.id.etUsername);
        etPassword = findViewById(R.id.etPassword);
        btnToggleVisibility = findViewById(R.id.btnToggleVisibility);
        btnCopy = findViewById(R.id.btnCopy);
        btnGenerate = findViewById(R.id.btnGenerate);
        btnSave = findViewById(R.id.btnSave);

        // --- EDIT LOGIC CHECK ---
        Intent intent = getIntent();
        if (intent.hasExtra("ENTRY_ID")) {
            // We are in EDIT mode!
            existingId = intent.getIntExtra("ENTRY_ID", -1);

            // Pre-fill the text boxes with the existing data
            etSiteName.setText(intent.getStringExtra("SITE_NAME"));
            etUsername.setText(intent.getStringExtra("USERNAME"));
            etPassword.setText(intent.getStringExtra("PASSWORD"));

            // Change the button text
            btnSave.setText("Update Password");
        }

        // 2. UX Feature: Password Masking Toggle
        btnToggleVisibility.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (isPasswordVisible) {
                    // Hide password
                    etPassword.setTransformationMethod(PasswordTransformationMethod.getInstance());
                    isPasswordVisible = false;
                } else {
                    // Show password
                    etPassword.setTransformationMethod(HideReturnsTransformationMethod.getInstance());
                    isPasswordVisible = true;
                }
                // Move cursor to the end of the text
                etPassword.setSelection(etPassword.getText().length());
            }
        });

        // 3. UX Feature: Copy to Clipboard
        btnCopy.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String currentPassword = etPassword.getText().toString();
                if (!currentPassword.isEmpty()) {
                    ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                    ClipData clip = ClipData.newPlainText("Password", currentPassword);
                    clipboard.setPrimaryClip(clip);
                    Toast.makeText(AddEditPasswordActivity.this, "Password copied to clipboard", Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(AddEditPasswordActivity.this, "Nothing to copy", Toast.LENGTH_SHORT).show();
                }
            }
        });

        // 4. UX Feature: Secure Password Generator
        btnGenerate.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String newSecurePassword = generateRandomPassword();
                etPassword.setText(newSecurePassword);
                // Automatically show the generated password so the user can see it
                etPassword.setTransformationMethod(HideReturnsTransformationMethod.getInstance());
                isPasswordVisible = true;
            }
        });

        // 5. Save Button (Encrypts and Inserts into Room Database)
        btnSave.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String site = etSiteName.getText().toString().trim();
                String user = etUsername.getText().toString().trim();
                String pass = etPassword.getText().toString().trim();

                if(site.isEmpty() || user.isEmpty() || pass.isEmpty()){
                    Toast.makeText(AddEditPasswordActivity.this, "Please fill all fields", Toast.LENGTH_SHORT).show();
                    return;
                }

                try {
                    // 1. Encrypt the password using our utility class
                    String encryptedPassword = EncryptionUtils.encrypt(pass);

                    // 2. Create a new data model object
                    PasswordEntry newEntry = new PasswordEntry();
                    newEntry.siteName = site;
                    newEntry.username = user;
                    newEntry.encryptedPassword = encryptedPassword;

                    // 3. Get the database instance and insert the data
                    AppDatabase db = AppDatabase.getDatabase(AddEditPasswordActivity.this);
                    // Check if we are inserting or updating!
                    if (existingId == -1) {
                        // Adding a new entry
                        db.passwordDao().insert(newEntry);
                        Toast.makeText(AddEditPasswordActivity.this, "Password saved!", Toast.LENGTH_SHORT).show();
                    } else {
                        // Updating an existing entry
                        newEntry.id = existingId; // MUST provide the ID so Room knows which row to update
                        db.passwordDao().update(newEntry);
                        Toast.makeText(AddEditPasswordActivity.this, "Password updated!", Toast.LENGTH_SHORT).show();
                    }

                    finish();

                } catch (Exception e) {
                    // If encryption or database saving fails, catch the error so the app doesn't crash
                    e.printStackTrace();
                    Toast.makeText(AddEditPasswordActivity.this, "Error saving: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            }
        });
    }

    // The Password Generator Method
    private String generateRandomPassword() {
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*";
        StringBuilder sb = new StringBuilder();
        Random random = new Random();
        for (int i = 0; i < 16; i++) { // 16 character password
            int index = random.nextInt(chars.length());
            sb.append(chars.charAt(index));
        }
        return sb.toString();
    }
}