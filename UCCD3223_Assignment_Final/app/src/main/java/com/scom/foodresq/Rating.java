package com.scom.foodresq;

public class Rating {
    private String ratingId;
    private String fromUserId;
    private String fromUserRole;
    private String toUserId;
    private String toUserRole;
    private String reservationId;
    private String foodId;
    private int score;
    private String comment;
    private String type;
    private long createdAt;

    public Rating() {}

    public Rating(String fromUserId, String fromUserRole, String toUserId,
                  String toUserRole, String reservationId, String foodId,
                  int score, String comment, String type) {
        this.fromUserId = fromUserId;
        this.fromUserRole = fromUserRole;
        this.toUserId = toUserId;
        this.toUserRole = toUserRole;
        this.reservationId = reservationId;
        this.foodId = foodId;
        this.score = score;
        this.comment = comment;
        this.type = type;
        this.createdAt = System.currentTimeMillis();
    }

    public String getRatingId() { return ratingId; }
    public void setRatingId(String ratingId) { this.ratingId = ratingId; }
    public String getFromUserId() { return fromUserId; }
    public void setFromUserId(String fromUserId) { this.fromUserId = fromUserId; }
    public String getFromUserRole() { return fromUserRole; }
    public void setFromUserRole(String fromUserRole) { this.fromUserRole = fromUserRole; }
    public String getToUserId() { return toUserId; }
    public void setToUserId(String toUserId) { this.toUserId = toUserId; }
    public String getToUserRole() { return toUserRole; }
    public void setToUserRole(String toUserRole) { this.toUserRole = toUserRole; }
    public String getReservationId() { return reservationId; }
    public void setReservationId(String reservationId) { this.reservationId = reservationId; }
    public String getFoodId() { return foodId; }
    public void setFoodId(String foodId) { this.foodId = foodId; }
    public int getScore() { return score; }
    public void setScore(int score) { this.score = score; }
    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }
}