package my.edu.utar.passwordmanager;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.List;

public class PasswordAdapter extends RecyclerView.Adapter<PasswordAdapter.PasswordViewHolder> {

    private List<PasswordEntry> passwordList;
    private OnItemClickListener listener;

    public interface OnItemClickListener {
        void onItemClick(PasswordEntry entry);
    }

    public PasswordAdapter(List<PasswordEntry> passwordList, OnItemClickListener listener) {
        this.passwordList = passwordList;
        this.listener = listener;
    }

    public void setPasswords(List<PasswordEntry> passwords) {
        this.passwordList = passwords;
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public PasswordViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_password, parent, false);
        return new PasswordViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull PasswordViewHolder holder, int position) {
        PasswordEntry currentEntry = passwordList.get(position);

        holder.tvSiteName.setText(currentEntry.siteName);
        holder.tvUsername.setText(currentEntry.username);

        holder.itemView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (listener != null) {
                    listener.onItemClick(currentEntry);
                }
            }
        });
    }

    @Override
    public int getItemCount() {
        return passwordList != null ? passwordList.size() : 0;
    }

    public PasswordEntry getPasswordAt(int position) {
        return passwordList.get(position);
    }

    class PasswordViewHolder extends RecyclerView.ViewHolder {
        private TextView tvSiteName;
        private TextView tvUsername;

        public PasswordViewHolder(@NonNull View itemView) {
            super(itemView);
            tvSiteName = itemView.findViewById(R.id.tvSiteName);
            tvUsername = itemView.findViewById(R.id.tvUsername);
        }
    }
}