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
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import java.util.Random;

public class AddEditPasswordActivity extends AppCompatActivity {

    private EditText etSiteName, etUsername, etPassword;
    private ImageButton btnToggleVisibility, btnCopy;
    private Button btnGenerate, btnSave;
    private boolean isPasswordVisible = false;
    private int existingId = -1;
    private TextView tvHeaderTitle;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_add_edit_password);

        tvHeaderTitle = findViewById(R.id.tvHeaderTitle);
        etSiteName = findViewById(R.id.etSiteName);
        etUsername = findViewById(R.id.etUsername);
        etPassword = findViewById(R.id.etPassword);
        btnToggleVisibility = findViewById(R.id.btnToggleVisibility);
        btnCopy = findViewById(R.id.btnCopy);
        btnGenerate = findViewById(R.id.btnGenerate);
        btnSave = findViewById(R.id.btnSave);

        Intent intent = getIntent();
        if (intent.hasExtra("ENTRY_ID")) {
            existingId = intent.getIntExtra("ENTRY_ID", -1);

            etSiteName.setText(intent.getStringExtra("SITE_NAME"));
            etUsername.setText(intent.getStringExtra("USERNAME"));
            etPassword.setText(intent.getStringExtra("PASSWORD"));

            btnSave.setText("Update Password");
            tvHeaderTitle.setText("Update Password");
        }

        btnToggleVisibility.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (isPasswordVisible) {
                    etPassword.setTransformationMethod(PasswordTransformationMethod.getInstance());
                    isPasswordVisible = false;
                } else {
                    etPassword.setTransformationMethod(HideReturnsTransformationMethod.getInstance());
                    isPasswordVisible = true;
                }
                etPassword.setSelection(etPassword.getText().length());
            }
        });

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

        btnGenerate.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String newSecurePassword = generateRandomPassword();
                etPassword.setText(newSecurePassword);
                etPassword.setTransformationMethod(HideReturnsTransformationMethod.getInstance());
                isPasswordVisible = true;
            }
        });

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
                    String encryptedPassword = EncryptionUtils.encrypt(pass);

                    PasswordEntry newEntry = new PasswordEntry();
                    newEntry.siteName = site;
                    newEntry.username = user;
                    newEntry.encryptedPassword = encryptedPassword;

                    AppDatabase db = AppDatabase.getDatabase(AddEditPasswordActivity.this);
                    if (existingId == -1) {
                        db.passwordDao().insert(newEntry);
                        Toast.makeText(AddEditPasswordActivity.this, "Password saved!", Toast.LENGTH_SHORT).show();
                    } else {
                        newEntry.id = existingId;
                        db.passwordDao().update(newEntry);
                        Toast.makeText(AddEditPasswordActivity.this, "Password updated!", Toast.LENGTH_SHORT).show();
                    }

                    finish();

                } catch (Exception e) {
                    e.printStackTrace();
                    Toast.makeText(AddEditPasswordActivity.this, "Error saving: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            }
        });
    }


    private String generateRandomPassword() {
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*";
        StringBuilder sb = new StringBuilder();
        Random random = new Random();
        for (int i = 0; i < 16; i++) {
            int index = random.nextInt(chars.length());
            sb.append(chars.charAt(index));
        }
        return sb.toString();
    }
}