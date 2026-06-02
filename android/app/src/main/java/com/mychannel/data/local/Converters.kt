package com.mychannel.data.local

import androidx.room.TypeConverter
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * Room type converters for complex column types (lists and maps) stored as
 * JSON strings. Uses Gson, which is already a project dependency.
 */
class Converters {

    @TypeConverter
    fun fromStringList(value: List<String>?): String = gson.toJson(value ?: emptyList<String>())

    @TypeConverter
    fun toStringList(value: String?): List<String> {
        if (value.isNullOrBlank()) return emptyList()
        return runCatching {
            gson.fromJson<List<String>>(value, stringListType)
        }.getOrDefault(emptyList())
    }

    @TypeConverter
    fun fromStringMap(value: Map<String, String>?): String =
        gson.toJson(value ?: emptyMap<String, String>())

    @TypeConverter
    fun toStringMap(value: String?): Map<String, String> {
        if (value.isNullOrBlank()) return emptyMap()
        return runCatching {
            gson.fromJson<Map<String, String>>(value, stringMapType)
        }.getOrDefault(emptyMap())
    }

    private companion object {
        val gson = Gson()
        val stringListType = object : TypeToken<List<String>>() {}.type
        val stringMapType = object : TypeToken<Map<String, String>>() {}.type
    }
}
