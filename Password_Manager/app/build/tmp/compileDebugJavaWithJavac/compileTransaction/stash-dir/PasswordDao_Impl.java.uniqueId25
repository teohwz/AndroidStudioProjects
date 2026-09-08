package my.edu.utar.passwordmanager;

import android.database.Cursor;
import androidx.annotation.NonNull;
import androidx.room.EntityDeletionOrUpdateAdapter;
import androidx.room.EntityInsertionAdapter;
import androidx.room.RoomDatabase;
import androidx.room.RoomSQLiteQuery;
import androidx.room.util.CursorUtil;
import androidx.room.util.DBUtil;
import androidx.sqlite.db.SupportSQLiteStatement;
import java.lang.Class;
import java.lang.Override;
import java.lang.String;
import java.lang.SuppressWarnings;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import javax.annotation.processing.Generated;

@Generated("androidx.room.RoomProcessor")
@SuppressWarnings({"unchecked", "deprecation"})
public final class PasswordDao_Impl implements PasswordDao {
  private final RoomDatabase __db;

  private final EntityInsertionAdapter<PasswordEntry> __insertionAdapterOfPasswordEntry;

  private final EntityDeletionOrUpdateAdapter<PasswordEntry> __deletionAdapterOfPasswordEntry;

  private final EntityDeletionOrUpdateAdapter<PasswordEntry> __updateAdapterOfPasswordEntry;

  public PasswordDao_Impl(@NonNull final RoomDatabase __db) {
    this.__db = __db;
    this.__insertionAdapterOfPasswordEntry = new EntityInsertionAdapter<PasswordEntry>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR ABORT INTO `password_entries` (`id`,`siteName`,`username`,`encryptedPassword`,`pinNumber`,`securityQuestion`,`securityAnswer`) VALUES (nullif(?, 0),?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          final PasswordEntry entity) {
        statement.bindLong(1, entity.id);
        if (entity.siteName == null) {
          statement.bindNull(2);
        } else {
          statement.bindString(2, entity.siteName);
        }
        if (entity.username == null) {
          statement.bindNull(3);
        } else {
          statement.bindString(3, entity.username);
        }
        if (entity.encryptedPassword == null) {
          statement.bindNull(4);
        } else {
          statement.bindString(4, entity.encryptedPassword);
        }
        if (entity.pinNumber == null) {
          statement.bindNull(5);
        } else {
          statement.bindString(5, entity.pinNumber);
        }
        if (entity.securityQuestion == null) {
          statement.bindNull(6);
        } else {
          statement.bindString(6, entity.securityQuestion);
        }
        if (entity.securityAnswer == null) {
          statement.bindNull(7);
        } else {
          statement.bindString(7, entity.securityAnswer);
        }
      }
    };
    this.__deletionAdapterOfPasswordEntry = new EntityDeletionOrUpdateAdapter<PasswordEntry>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "DELETE FROM `password_entries` WHERE `id` = ?";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          final PasswordEntry entity) {
        statement.bindLong(1, entity.id);
      }
    };
    this.__updateAdapterOfPasswordEntry = new EntityDeletionOrUpdateAdapter<PasswordEntry>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "UPDATE OR ABORT `password_entries` SET `id` = ?,`siteName` = ?,`username` = ?,`encryptedPassword` = ?,`pinNumber` = ?,`securityQuestion` = ?,`securityAnswer` = ? WHERE `id` = ?";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          final PasswordEntry entity) {
        statement.bindLong(1, entity.id);
        if (entity.siteName == null) {
          statement.bindNull(2);
        } else {
          statement.bindString(2, entity.siteName);
        }
        if (entity.username == null) {
          statement.bindNull(3);
        } else {
          statement.bindString(3, entity.username);
        }
        if (entity.encryptedPassword == null) {
          statement.bindNull(4);
        } else {
          statement.bindString(4, entity.encryptedPassword);
        }
        if (entity.pinNumber == null) {
          statement.bindNull(5);
        } else {
          statement.bindString(5, entity.pinNumber);
        }
        if (entity.securityQuestion == null) {
          statement.bindNull(6);
        } else {
          statement.bindString(6, entity.securityQuestion);
        }
        if (entity.securityAnswer == null) {
          statement.bindNull(7);
        } else {
          statement.bindString(7, entity.securityAnswer);
        }
        statement.bindLong(8, entity.id);
      }
    };
  }

  @Override
  public void insert(final PasswordEntry entry) {
    __db.assertNotSuspendingTransaction();
    __db.beginTransaction();
    try {
      __insertionAdapterOfPasswordEntry.insert(entry);
      __db.setTransactionSuccessful();
    } finally {
      __db.endTransaction();
    }
  }

  @Override
  public void delete(final PasswordEntry entry) {
    __db.assertNotSuspendingTransaction();
    __db.beginTransaction();
    try {
      __deletionAdapterOfPasswordEntry.handle(entry);
      __db.setTransactionSuccessful();
    } finally {
      __db.endTransaction();
    }
  }

  @Override
  public void update(final PasswordEntry entry) {
    __db.assertNotSuspendingTransaction();
    __db.beginTransaction();
    try {
      __updateAdapterOfPasswordEntry.handle(entry);
      __db.setTransactionSuccessful();
    } finally {
      __db.endTransaction();
    }
  }

  @Override
  public List<PasswordEntry> getAllEntries() {
    final String _sql = "SELECT * FROM password_entries ORDER BY siteName ASC";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    __db.assertNotSuspendingTransaction();
    final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
    try {
      final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
      final int _cursorIndexOfSiteName = CursorUtil.getColumnIndexOrThrow(_cursor, "siteName");
      final int _cursorIndexOfUsername = CursorUtil.getColumnIndexOrThrow(_cursor, "username");
      final int _cursorIndexOfEncryptedPassword = CursorUtil.getColumnIndexOrThrow(_cursor, "encryptedPassword");
      final int _cursorIndexOfPinNumber = CursorUtil.getColumnIndexOrThrow(_cursor, "pinNumber");
      final int _cursorIndexOfSecurityQuestion = CursorUtil.getColumnIndexOrThrow(_cursor, "securityQuestion");
      final int _cursorIndexOfSecurityAnswer = CursorUtil.getColumnIndexOrThrow(_cursor, "securityAnswer");
      final List<PasswordEntry> _result = new ArrayList<PasswordEntry>(_cursor.getCount());
      while (_cursor.moveToNext()) {
        final PasswordEntry _item;
        _item = new PasswordEntry();
        _item.id = _cursor.getInt(_cursorIndexOfId);
        if (_cursor.isNull(_cursorIndexOfSiteName)) {
          _item.siteName = null;
        } else {
          _item.siteName = _cursor.getString(_cursorIndexOfSiteName);
        }
        if (_cursor.isNull(_cursorIndexOfUsername)) {
          _item.username = null;
        } else {
          _item.username = _cursor.getString(_cursorIndexOfUsername);
        }
        if (_cursor.isNull(_cursorIndexOfEncryptedPassword)) {
          _item.encryptedPassword = null;
        } else {
          _item.encryptedPassword = _cursor.getString(_cursorIndexOfEncryptedPassword);
        }
        if (_cursor.isNull(_cursorIndexOfPinNumber)) {
          _item.pinNumber = null;
        } else {
          _item.pinNumber = _cursor.getString(_cursorIndexOfPinNumber);
        }
        if (_cursor.isNull(_cursorIndexOfSecurityQuestion)) {
          _item.securityQuestion = null;
        } else {
          _item.securityQuestion = _cursor.getString(_cursorIndexOfSecurityQuestion);
        }
        if (_cursor.isNull(_cursorIndexOfSecurityAnswer)) {
          _item.securityAnswer = null;
        } else {
          _item.securityAnswer = _cursor.getString(_cursorIndexOfSecurityAnswer);
        }
        _result.add(_item);
      }
      return _result;
    } finally {
      _cursor.close();
      _statement.release();
    }
  }

  @NonNull
  public static List<Class<?>> getRequiredConverters() {
    return Collections.emptyList();
  }
}
