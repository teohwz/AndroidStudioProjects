package my.edu.utar.passwordmanager;

import androidx.room.Dao;
import androidx.room.Delete;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;
import java.util.List;

@Dao
public interface PasswordDao {
    @Insert
    void insert(PasswordEntry entry);

    @Update
    void update(PasswordEntry entry);

    @Delete
    void delete(PasswordEntry entry);

    @Query("SELECT * FROM password_entries ORDER BY siteName ASC")
    List<PasswordEntry> getAllEntries();
}