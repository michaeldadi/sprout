package com.michaeldadi.sprout.data.database

import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import android.content.Context
import com.michaeldadi.sprout.data.converters.DateConverter
import com.michaeldadi.sprout.data.converters.StringListConverter
import com.michaeldadi.sprout.data.dao.TransactionDao
import com.michaeldadi.sprout.data.entities.TransactionEntity

@Database(
    entities = [TransactionEntity::class],
    version = 1,
    exportSchema = false
)
@TypeConverters(DateConverter::class, StringListConverter::class)
abstract class SproutDatabase : RoomDatabase() {
    
    abstract fun transactionDao(): TransactionDao
    
    companion object {
        @Volatile
        private var INSTANCE: SproutDatabase? = null
        
        fun getDatabase(context: Context): SproutDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    SproutDatabase::class.java,
                    "sprout_database"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}