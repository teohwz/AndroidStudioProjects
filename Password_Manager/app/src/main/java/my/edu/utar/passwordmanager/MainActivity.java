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

        recyclerView = findViewById(R.id.recyclerViewPasswords);
        tvEmptyState = findViewById(R.id.tvEmptyState);
        db = AppDatabase.getDatabase(this);

        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        adapter = new PasswordAdapter(new ArrayList<>(), new PasswordAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(PasswordEntry entry) {
                showPasswordDialog(entry);
            }
        });
        recyclerView.setAdapter(adapter);

        setupSwipeToDelete();

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
                return false;
            }

            @Override
            public void onSwiped(@NonNull RecyclerView.ViewHolder viewHolder, int swipeDir) {
                int position = viewHolder.getAdapterPosition();
                PasswordEntry entryToDelete = adapter.getPasswordAt(position);

                db.passwordDao().delete(entryToDelete);
                loadPasswords();

                com.google.android.material.snackbar.Snackbar.make(recyclerView, "Entry deleted", com.google.android.material.snackbar.Snackbar.LENGTH_LONG)
                        .setAction("UNDO", v -> {
                            db.passwordDao().insert(entryToDelete);
                            loadPasswords();
                        }).show();
            }
        };

        ItemTouchHelper itemTouchHelper = new ItemTouchHelper(simpleItemTouchCallback);
        itemTouchHelper.attachToRecyclerView(recyclerView);

        FloatingActionButton fabAddPassword = findViewById(R.id.fabAddPassword);
        fabAddPassword.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Intent intent = new Intent(MainActivity.this, AddEditPasswordActivity.class);
                startActivity(intent);
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        loadPasswords();
    }

    private void loadPasswords() {
        List<PasswordEntry> passwords = db.passwordDao().getAllEntries();

        adapter.setPasswords(passwords);

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
            String decryptedPassword = EncryptionUtils.decrypt(entry.encryptedPassword);

            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setTitle(entry.siteName);

            String message = "Username: " + entry.username + "\n\n" +
                    "Password: " + decryptedPassword;
            builder.setMessage(message);

            builder.setPositiveButton("Copy Password", (dialog, which) -> {
                ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                ClipData clip = ClipData.newPlainText("Password", decryptedPassword);
                clipboard.setPrimaryClip(clip);
                Toast.makeText(MainActivity.this, "Password copied to clipboard!", Toast.LENGTH_SHORT).show();
            });

            builder.setNegativeButton("Close", (dialog, which) -> {
                dialog.dismiss();
            });

            builder.setNeutralButton("Edit", (dialog, which) -> {
                Intent editIntent = new Intent(MainActivity.this, AddEditPasswordActivity.class);

                editIntent.putExtra("ENTRY_ID", entry.id);
                editIntent.putExtra("SITE_NAME", entry.siteName);
                editIntent.putExtra("USERNAME", entry.username);
                editIntent.putExtra("PASSWORD", decryptedPassword);

                startActivity(editIntent);
            });

            builder.show();

        } catch (Exception e) {
            e.printStackTrace();
            Toast.makeText(this, "Error decrypting password!", Toast.LENGTH_SHORT).show();
        }
    }

}