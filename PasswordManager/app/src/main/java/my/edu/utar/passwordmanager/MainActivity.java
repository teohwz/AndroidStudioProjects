package my.edu.utar.passwordmanager;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import androidx.activity.EdgeToEdge;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.recyclerview.widget.ItemTouchHelper;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import java.util.ArrayList;
import java.util.List;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.widget.Toast;
import androidx.appcompat.app.AlertDialog;

public class MainActivity extends AppCompatActivity {

    private RecyclerView recyclerView;
    private PasswordAdapter adapter;
    private TextView tvEmptyState;
    private AppDatabase db;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_main);

        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main), (v, insets) -> {
            Insets systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom);
            return insets;
        });

        // 1. Initialize Views and Database
        recyclerView = findViewById(R.id.recyclerViewPasswords);
        tvEmptyState = findViewById(R.id.tvEmptyState);
        db = AppDatabase.getDatabase(this);

        // 2. Set up the RecyclerView
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        // Set up the Adapter with the Click Listener
        adapter = new PasswordAdapter(new ArrayList<>(), new PasswordAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(PasswordEntry entry) {
                // When a row is clicked, trigger the dialog method
                showPasswordDialog(entry);
            }
        });
        recyclerView.setAdapter(adapter);

        // 3. Initialize the Swipe Logic
        setupSwipeToDelete();

        // 4. Set up the Add Button (Moved out of the setup method)
        FloatingActionButton fabAddPassword = findViewById(R.id.fabAddPassword);
        fabAddPassword.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Intent intent = new Intent(MainActivity.this, AddEditPasswordActivity.class);
                startActivity(intent);
            }
        });
    }

    private void setupSwipeToDelete() {
        ItemTouchHelper.SimpleCallback simpleItemTouchCallback = new ItemTouchHelper.SimpleCallback(0, ItemTouchHelper.LEFT | ItemTouchHelper.RIGHT) {

            @Override
            public boolean onMove(@NonNull RecyclerView recyclerView, @NonNull RecyclerView.ViewHolder viewHolder, @NonNull RecyclerView.ViewHolder target) {
                return false; // We aren't implementing drag-and-drop reordering
            }

            @Override
            public void onSwiped(@NonNull RecyclerView.ViewHolder viewHolder, int swipeDir) {
                int position = viewHolder.getAdapterPosition();
                PasswordEntry entryToDelete = adapter.getPasswordAt(position);

                // Delete from DB
                db.passwordDao().delete(entryToDelete);
                loadPasswords();

                // Show Snackbar with Undo
                com.google.android.material.snackbar.Snackbar.make(recyclerView, "Entry deleted", com.google.android.material.snackbar.Snackbar.LENGTH_LONG)
                        .setAction("UNDO", v -> {
                            // Re-insert if they click Undo
                            db.passwordDao().insert(entryToDelete);
                            loadPasswords();
                        }).show();
            }
        };

        // Attach the helper to your RecyclerView
        ItemTouchHelper itemTouchHelper = new ItemTouchHelper(simpleItemTouchCallback);
        itemTouchHelper.attachToRecyclerView(recyclerView);

        // 3. Set up the Add Button
        FloatingActionButton fabAddPassword = findViewById(R.id.fabAddPassword);
        fabAddPassword.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Intent intent = new Intent(MainActivity.this, AddEditPasswordActivity.class);
                startActivity(intent);
            }
        });
    }

    // This runs every time the activity comes into view
    @Override
    protected void onResume() {
        super.onResume();
        loadPasswords();
    }

    private void loadPasswords() {
        // Fetch all passwords from the database
        List<PasswordEntry> passwords = db.passwordDao().getAllEntries();

        // Update the adapter with the new data
        adapter.setPasswords(passwords);

        // Toggle the empty state message visibility
        if (passwords.isEmpty()) {
            tvEmptyState.setVisibility(View.VISIBLE);
            recyclerView.setVisibility(View.GONE);
        } else {
            tvEmptyState.setVisibility(View.GONE);
            recyclerView.setVisibility(View.VISIBLE);
        }
    }

    private void showPasswordDialog(PasswordEntry entry) {
        try {
            // 1. Decrypt the password!
            String decryptedPassword = EncryptionUtils.decrypt(entry.encryptedPassword);

            // 2. Build the Alert Dialog
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setTitle(entry.siteName);

            // Format the text nicely
            String message = "Username: " + entry.username + "\n\n" +
                    "Password: " + decryptedPassword;
            builder.setMessage(message);

            // 3. Add a "Copy Password" button for convenience
            builder.setPositiveButton("Copy Password", (dialog, which) -> {
                ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                ClipData clip = ClipData.newPlainText("Password", decryptedPassword);
                clipboard.setPrimaryClip(clip);
                Toast.makeText(MainActivity.this, "Password copied to clipboard!", Toast.LENGTH_SHORT).show();
            });

            // 4. Add a "Close" button
            builder.setNegativeButton("Close", (dialog, which) -> {
                dialog.dismiss();
            });

            // 5. Add a "Edit" button
            builder.setNeutralButton("Edit", (dialog, which) -> {
                // Create an intent to open the AddEdit screen
                Intent editIntent = new Intent(MainActivity.this, AddEditPasswordActivity.class);

                // Pass all the current data to the next screen so it can fill the text boxes
                editIntent.putExtra("ENTRY_ID", entry.id);
                editIntent.putExtra("SITE_NAME", entry.siteName);
                editIntent.putExtra("USERNAME", entry.username);
                editIntent.putExtra("PASSWORD", decryptedPassword); // Pass the decrypted version so they can edit it

                startActivity(editIntent);
            });

            // 6. Show it to the user
            builder.show();

        } catch (Exception e) {
            e.printStackTrace();
            Toast.makeText(this, "Error decrypting password!", Toast.LENGTH_SHORT).show();
        }
    }

}