package my.edu.utar.passwordmanager;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

@Entity(tableName = "password_entries")
public class PasswordEntry {

    @PrimaryKey(autoGenerate = true)
    public int id;

    public String siteName;
    public String username;
    public String encryptedPassword;


    public String pinNumber;
    public String securityQuestion;
    public String securityAnswer;

}