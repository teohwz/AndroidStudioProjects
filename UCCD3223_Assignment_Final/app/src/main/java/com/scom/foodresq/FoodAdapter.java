package com.scom.foodresq;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import com.scom.foodresq.db.FoodEntity;

/**
 * RecyclerView adapter for food listings.
 *
 * Uses ListAdapter + DiffUtil for efficient partial updates — no more
 * blanket notifyDataSetChanged() calls.
 *
 * Works with FoodEntity (Room) objects so the UI always reflects local cache.
 */
public class FoodAdapter extends ListAdapter<FoodEntity, FoodAdapter.FoodViewHolder> {

    // ── Click callback ────────────────────────────────────────────────────

    public interface OnItemClickListener {
        void onItemClick(FoodEntity food);
        void onItemLongClick(FoodEntity food); // vendor: edit / delete
    }

    private OnItemClickListener listener;

    public void setOnItemClickListener(OnItemClickListener listener) {
        this.listener = listener;
    }

    // ── DiffUtil ──────────────────────────────────────────────────────────

    private static final DiffUtil.ItemCallback<FoodEntity> DIFF_CALLBACK =
            new DiffUtil.ItemCallback<FoodEntity>() {
                @Override
                public boolean areItemsTheSame(@NonNull FoodEntity a, @NonNull FoodEntity b) {
                    return a.firestoreId.equals(b.firestoreId);
                }
                @Override
                public boolean areContentsTheSame(@NonNull FoodEntity a, @NonNull FoodEntity b) {
                    return a.name.equals(b.name)
                        && a.price.equals(b.price)
                        && a.quantity.equals(b.quantity)
                        && a.category != null && a.category.equals(b.category);
                }
            };

    public FoodAdapter() {
        super(DIFF_CALLBACK);
    }

    // ── ViewHolder ────────────────────────────────────────────────────────

    public static class FoodViewHolder extends RecyclerView.ViewHolder {
        TextView txtName, txtPrice, txtQty, txtExpiry, txtCategory;

        public FoodViewHolder(@NonNull View itemView) {
            super(itemView);
            txtName     = itemView.findViewById(R.id.txtName);
            txtPrice    = itemView.findViewById(R.id.txtPrice);
            txtQty      = itemView.findViewById(R.id.txtQty);
            txtExpiry   = itemView.findViewById(R.id.txtExpiry);
            txtCategory = itemView.findViewById(R.id.txtCategory);
        }
    }

    @NonNull
    @Override
    public FoodViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.food_item, parent, false);
        return new FoodViewHolder(v);
    }

    @Override
    public void onBindViewHolder(@NonNull FoodViewHolder holder, int position) {
        FoodEntity food = getItem(position);

        holder.txtName.setText(food.name);
        holder.txtPrice.setText("RM " + food.price);
        holder.txtQty.setText("Qty: " + food.quantity);
        holder.txtExpiry.setText("Exp: " + food.expiry);
        holder.txtCategory.setText(food.category != null ? food.category : "—");

        holder.itemView.setOnClickListener(v -> {
            if (listener != null) listener.onItemClick(food);
        });
        holder.itemView.setOnLongClickListener(v -> {
            if (listener != null) listener.onItemLongClick(food);
            return true;
        });
    }
}
