package com.scom.foodresq;

import java.util.Arrays;
import java.util.List;

/**
 * Centralised list of food categories used across the app.
 *
 * Add / remove entries here — the spinner in VendorPostFoodActivity and
 * the chip filter bar in StudentHomeActivity both read from this list.
 */
public final class FoodCategory {

    private FoodCategory() {}

    public static final String ALL       = "All";
    public static final String RICE      = "Rice";
    public static final String NOODLES   = "Noodles";
    public static final String BREAD     = "Bread";
    public static final String DESSERT   = "Dessert";
    public static final String DRINKS    = "Drinks";
    public static final String SNACKS    = "Snacks";
    public static final String VEGETARIAN = "Vegetarian";
    public static final String OTHERS    = "Others";

    /** Full list — first entry is "All" so it acts as a default filter. */
    public static final List<String> ALL_CATEGORIES = Arrays.asList(
            ALL, RICE, NOODLES, BREAD, DESSERT, DRINKS, SNACKS, VEGETARIAN, OTHERS
    );

    /** Categories excluding "All" — used in the vendor post form spinner. */
    public static final List<String> VENDOR_CATEGORIES = Arrays.asList(
            RICE, NOODLES, BREAD, DESSERT, DRINKS, SNACKS, VEGETARIAN, OTHERS
    );
}
