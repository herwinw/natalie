#pragma once

#include <algorithm>
#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "tm/macros.hpp"
#include "tm/string.hpp"
#include "tm/string_view.hpp"

namespace TM {

template <typename KeyT>
struct HashKeyHandler {
};

template <typename Pointer>
struct HashKeyHandler<Pointer *> {
    /**
     * Returns a hash value for the given pointer as if it were
     * just a 64-bit number. The contents of the pointer are
     * not examined.
     *
     * ```
     * auto key1 = strdup("foo");
     * auto key2 = strdup("foo");
     * assert_neq(
     *   HashKeyHandler<char *>::hash(key1),
     *   HashKeyHandler<char *>::hash(key2)
     * );
     * assert_eq(
     *   HashKeyHandler<char *>::hash(key1),
     *   HashKeyHandler<char *>::hash(key1)
     * );
     * free(key1);
     * free(key2);
     * ```
     */
    static size_t hash(Pointer *ptr) {
        // https://stackoverflow.com/a/12996028/197498
        auto x = (size_t)ptr;
        x = (x ^ (x >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
        x = (x ^ (x >> 27)) * UINT64_C(0x94d049bb133111eb);
        x = x ^ (x >> 31);
        return x;
    }

    /**
     * Returns true if the two given pointers are the same.
     * The contents of the pointed-to object are not examined.
     * Null must be passed as the third argument.
     *
     * ```
     * auto key1 = strdup("foo");
     * auto key2 = strdup("foo");
     * assert_not(HashKeyHandler<char *>::compare(key1, key2, nullptr));
     * assert(HashKeyHandler<char *>::compare(key1, key1, nullptr));
     * free(key1);
     * free(key2);
     * ```
     */
    static bool compare(Pointer *a, Pointer *b, void *) {
        return a == b;
    }
};

template <>
struct HashKeyHandler<String> {
    /**
     * Returns a hash value for the given TM::String based on its contents.
     *
     * ```
     * String key1 { "foo" };
     * String key2 { "foo" };
     * String key3 { "bar" };
     * assert_eq(
     *   HashKeyHandler<String>::hash(key1),
     *   HashKeyHandler<String>::hash(key2)
     * );
     * assert_neq(
     *   HashKeyHandler<String>::hash(key1),
     *   HashKeyHandler<String>::hash(key3)
     * );
     * ```
     */
    static size_t hash(const String &str) {
        return djb2_hash(str.c_str(), str.size());
    }

    /**
     * Returns a hash value for the given TM::StringView based on its contents.
     * Return value should be the same as the equivalent TM::String
     *
     * ```
     * String key1 { "foo" };
     * StringView key2 { *key1 };
     * assert_eq(
     *   HashKeyHandler<String>::hash(key1),
     *   HashKeyHandler<String>::hash(key2)
     * );
     * ```
     */
    static size_t hash(StringView str) {
        return djb2_hash(str.dangerous_pointer_to_underlying_data(), str.length());
    }

    /**
     * Returns a hash value for the given char* based on its contents.
     * Return value should be the same as the equivalent TM::String
     *
     * ```
     * String key1 { "foo" };
     * const char key2 = "foo";
     * assert_eq(
     *   HashKeyHandler<String>::hash(key1),
     *   HashKeyHandler<String>::hash(key2)
     * );
     * ```
     */
    static size_t hash(const char *c) {
        return djb2_hash(c, strlen(c));
    }

    /**
     * Returns true if the two given TM:Strings have the same contents.
     * Null must be passed as the third argument.
     *
     * ```
     * auto key1 = String("foo");
     * auto key2 = String("foo");
     * auto key3 = String("bar");
     * assert(HashKeyHandler<String>::compare(key1, key2, nullptr));
     * assert_not(HashKeyHandler<String>::compare(key1, key3, nullptr));
     * ```
     */
    static bool compare(const String &a, const String &b, void *) {
        return a == b;
    }

    /**
     * Returns true if the two given arguments have the same contents.
     * Null must be passed as the third argument.
     *
     * ```
     * auto key1 = String("foo");
     * auto key2 = String("bar");
     * auto sv = StringView { *key1 };
     * assert(HashKeyHandler<String>::compare(sv, key1, nullptr));
     * assert_not(HashKeyHandler<String>::compare(sv, key1, nullptr));
     * ```
     */
    static bool compare(StringView a, const String &b, void *) {
        return a == b;
    }

    /**
     * Returns true if the two given arguments have the same contents.
     * Null must be passed as the third argument.
     *
     * ```
     * auto key1 = String("foo");
     * auto key2 = String("bar");
     * const char *charkey = "foo";
     * assert(HashKeyHandler<String>::compare(sv, key1, nullptr));
     * assert_not(HashKeyHandler<String>::compare(sv, key1, nullptr));
     * ```
     */
    static bool compare(const char *a, const String &b, void *) {
        return b == a;
    }

    /**
     * Returns hash value of this String.
     * This uses the 'djb2' hash algorithm by Dan Bernstein.
     *
     * ```
     * const char *str = "hello";
     * assert_eq(261238937, HashKeyHandler<String>::djb2_hash(str, strlen(str)));
     * ```
     */
    static uint32_t djb2_hash(const char *c, const size_t len) {
        size_t hash = 5381;
        for (size_t i = 0; i < len; ++i)
            hash = ((hash << 5) + hash) + c[i];
        return hash;
    }
};

template <typename KeyT, typename T = void *>
class Hashmap {
public:
    static constexpr size_t HASHMAP_MIN_LOAD_FACTOR = 25;
    static constexpr size_t HASHMAP_TARGET_LOAD_FACTOR = 50;
    static constexpr size_t HASHMAP_MAX_LOAD_FACTOR = 75;

    struct Item {
        KeyT key;
        T value;
        size_t hash;
        Item *next { nullptr };
    };

    /**
     * Constructs a Hashmap templated with key type and value type.
     * Optionally pass the initial capacity.
     *
     * ```
     * auto map = Hashmap<char *, Thing>();
     * auto key = strdup("foo");
     * map.put(key, Thing(1));
     * assert_eq(1, map.size());
     * free(key);
     * ```
     */
    Hashmap(size_t initial_capacity = 10)
        : m_capacity { calculate_map_size(initial_capacity) } { }

    /**
     * Copies the given Hashmap.
     *
     * ```
     * auto map1 = Hashmap<String, Thing>();
     * map1.put("foo", Thing(1));
     * auto map2 = Hashmap<String, Thing>(map1);
     * assert_eq(Thing(1), map2.get("foo"));
     * ```
     */
    Hashmap(const Hashmap &other)
        : m_capacity { other.m_capacity } {
        m_map = new Item *[m_capacity] {};
        copy_items_from(other);
    }

    /**
     * Creates a new Hashmap from another Hashmap, and clear the input
     *
     * ```
     * auto map1 = Hashmap<String, Thing>();
     * map1.put("foo", Thing(1));
     * auto map2 = Hashmap<String, Thing>(std::move(map1));
     * assert_eq(Thing(1), map2.get("foo"));
     * assert(map1.is_empty());
     * ```
     */
    Hashmap(Hashmap &&other) {
        m_size = other.m_size;
        m_capacity = other.m_capacity;
        m_map = other.m_map;
        other.m_size = 0;
        other.m_capacity = 0;
        other.m_map = nullptr;
    }

    /**
     * Overwrites this Hashmap with another.
     *
     * ```
     * auto map1 = Hashmap<String, Thing>();
     * map1.put("foo", Thing(1));
     * auto map2 = Hashmap<String, Thing>();
     * map2.put("foo", Thing(2));
     * map1 = map2;
     * assert_eq(Thing(2), map1.get("foo"));
     * ```
     */
    Hashmap &operator=(const Hashmap &other) {
        m_capacity = other.m_capacity;
        if (m_map) {
            clear();
            delete[] m_map;
        }
        m_map = new Item *[m_capacity] {};
        copy_items_from(other);
        return *this;
    }

    /**
     * Moves data from another Hashmap onto this one.
     *
     * ```
     * auto map1 = Hashmap<String, Thing>();
     * map1.put("foo", Thing(1));
     * auto map2 = Hashmap<String, Thing>();
     * map2.put("foo", Thing(2));
     * map1 = std::move(map2);
     * assert_eq(Thing(2), map1.get("foo"));
     * assert_eq(0, map2.size());
     * ```
     */
    Hashmap &operator=(Hashmap &&other) {
        if (m_map) {
            clear();
            delete[] m_map;
        }
        m_size = other.m_size;
        m_capacity = other.m_capacity;
        m_map = other.m_map;
        other.m_size = 0;
        other.m_capacity = 0;
        other.m_map = nullptr;
        return *this;
    }

    /**
     * Sets a cleanup function pointer to be called
     * whenever this Hashmap is deleted.
     *
     * NOTE: The cleanup function is not called if
     * the map was never initialized with any data.
     *
     * ```
     * // top-level ----
     * bool hm_cleanup_ran = false;
     * void hm_cleanup(Hashmap<String, Thing*> &map) {
     *     for (std::pair item : map) {
     *         delete item.second;
     *     }
     *     hm_cleanup_ran = true;
     * };
     * // end-top-level ----
     *
     * auto foo = new Thing(1);
     * {
     *     Hashmap<String, Thing*> map;
     *     map.set_cleanup_function(hm_cleanup);
     *     map.put("foo", foo);
     * }
     * assert_eq(true, hm_cleanup_ran);
     * ```
     */
    using CleanupFn = void(Hashmap<KeyT, T> &);
    void set_cleanup_function(CleanupFn fn) {
        m_cleanup_fn = fn;
    }

    ~Hashmap() {
        if (!m_map) return;
        if (m_cleanup_fn)
            m_cleanup_fn(*this);
        clear();
        delete[] m_map;
    }

    /**
     * Gets a value from the map stored under the given key.
     * Optionally pass an additional 'data' pointer if your
     * custom compare function requires the extra data
     * parameter. (The built-in compare function does not
     * use the data pointer.)
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * assert_eq(Thing(1), map.get("foo"));
     * ```
     *
     * If there is no value associated with the given key,
     * then a default-constructed object is returned.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * assert_eq(Thing(0), map.get("foo"));
     * ```
     *
     * If there is no value associated with the given key,
     * and your value type is a pointer type, then nullptr
     * is returned.
     *
     * ```
     * auto map = Hashmap<String, const char*>();
     * assert_eq(nullptr, map.get("foo"));
     * ```
     */
    template <typename KeyTArg>
    T get(KeyTArg &&key, void *data = nullptr) const {
        auto hash = HashKeyHandler<KeyT>::hash(std::forward<KeyTArg>(key));
        auto item = find_item(key, hash, data);
        if (item)
            return item->value;
        if constexpr (std::is_pointer_v<T>)
            return nullptr;
        else
            return {};
    }

    /**
     * Finds and returns an Item* (the internal container type
     * used by Hashmap) based on the given key and hash.
     * Optionally pass a third data pointer if your custom
     * compare function requires it.
     *
     * Use this method if you already have computed the hash value
     * and/or need to access the internal Item structure directly.
     *
     * ```
     * auto key = String("foo");
     * auto map = Hashmap<String, Thing>();
     * map.put(key, Thing(1));
     * auto hash = HashKeyHandler<String>::hash(key);
     * auto item = map.find_item(key, hash);
     * assert_eq(Thing(1), item->value);
     * ```
     *
     * If the item is not found, then null is returned.
     *
     * ```
     * auto key = String("foo");
     * auto map = Hashmap<String, Thing>();
     * auto hash = HashKeyHandler<String>::hash(key);
     * auto item = map.find_item(key, hash);
     * assert_eq(nullptr, item);
     * ```
     */
    template <typename KeyTArg>
    Item *find_item(KeyTArg &&key, size_t hash, void *data = nullptr) const {
        if (m_size == 0) return nullptr;
        assert(m_map);
        auto index = index_for_hash(hash);
        auto item = m_map[index];
        while (item) {
            if (hash == item->hash && HashKeyHandler<KeyT>::compare(std::forward<KeyTArg>(key), item->key, data))
                return item;
            item = item->next;
        }
        return nullptr;
    }

    /**
     * Sets a key in the Hashmap as if it were a hash set.
     * Use this if you don't care about storing/retrieving values.
     *
     * ```
     * auto map = Hashmap<String>();
     * map.set("foo");
     * assert(map.get("foo"));
     * assert_not(map.get("bar"));
     * ```
     */
    template <typename KeyTArg>
    void set(KeyTArg &&key) {
        put(std::forward<KeyTArg>(key), this); // we just put a placeholder value, a pointer to this Hashmap
    }

    /**
     * Puts the given value at the given key in the Hashmap.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * assert_eq(Thing(1), map.get("foo"));
     * map.put("foo", Thing(2));
     * assert_eq(Thing(2), map.get("foo"));
     * ```
     *
     * If your custom compare function requires the additional 'data'
     * pointer, then pass it as the third parameter.
     */
    template <typename KeyTArg>
    void put(KeyTArg &&key, T value, void *data = nullptr) {
        if (!m_map)
            m_map = new Item *[m_capacity] {};
        if (load_factor() > HASHMAP_MAX_LOAD_FACTOR)
            rehash();
        auto hash = HashKeyHandler<KeyT>::hash(std::forward<KeyTArg>(key));
        Item *item;
        if ((item = find_item(std::forward<KeyTArg>(key), hash, data))) {
            item->value = value;
            return;
        }
        auto index = index_for_hash(hash);
        auto new_item = new Item { std::forward<KeyTArg>(key), value, hash };
        insert_item(m_map, index, new_item);
        m_size++;
    }

    /**
     * Removes and returns the value at the given key.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * assert_eq(Thing(1), map.remove("foo"));
     * assert_eq(Thing(), map.remove("foo"));
     * ```
     *
     * If there is no value associated with the given key,
     * then a default-constructed object is returned.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * assert_eq(Thing(0), map.remove("foo"));
     * ```
     *
     * If there is no value associated with the given key,
     * and your value type is a pointer type, then nullptr
     * is returned.
     *
     * ```
     * auto map = Hashmap<String, const char*>();
     * assert_eq(nullptr, map.remove("foo"));
     * ```
     */
    template <typename KeyTArg>
    T remove(KeyTArg &&key, void *data = nullptr) {
        if (!m_map) {
            if constexpr (std::is_pointer_v<T>)
                return nullptr;
            else
                return {};
        }
        auto hash = HashKeyHandler<KeyT>::hash(std::forward<KeyTArg>(key));
        auto index = index_for_hash(hash);
        auto item = m_map[index];
        if (item) {
            // m_map[index] = [item] -> item -> item
            //                ^ this one
            if (hash == item->hash && HashKeyHandler<KeyT>::compare(std::forward<KeyTArg>(key), item->key, data)) {
                auto value = item->value;
                delete_item(index, item);
                return value;
            }
            auto chained_item = item->next;
            while (chained_item) {
                // m_map[index] = item -> [item] -> item
                //                        ^ this one
                if (hash == chained_item->hash && HashKeyHandler<KeyT>::compare(std::forward<KeyTArg>(key), chained_item->key, data)) {
                    auto value = chained_item->value;
                    delete_item(item, chained_item);
                    return value;
                }
                item = chained_item;
                chained_item = chained_item->next;
            }
        }
        if constexpr (std::is_pointer_v<T>)
            return nullptr;
        else
            return {};
    }

    /**
     * Removes all keys/values from the Hashmap.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * assert_eq(1, map.size());
     * map.clear();
     * assert_eq(0, map.size());
     * ```
     */
    void clear() {
        if (!m_map) return;
        for (size_t i = 0; i < m_capacity; i++) {
            auto item = m_map[i];
            m_map[i] = nullptr;
            while (item) {
                auto next_item = item->next;
                delete item;
                item = next_item;
            }
        }
        m_size = 0;
    }

    /**
     * Returns the number of values stored in the Hashmap.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * assert_eq(1, map.size());
     * ```
     */
    size_t size() const { return m_size; }

    /**
     * Returns the number of storage slots available.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * assert_eq(32, map.capacity());
     * ```
     */
    size_t capacity() const { return m_capacity; }

    /**
     * Returns true if there are zero values stored in the Hashmap.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * assert(map.is_empty());
     * map.put("foo", Thing(1));
     * assert_not(map.is_empty());
     * ```
     */
    bool is_empty() const { return m_size == 0; }

    template <typename H>
    class iterator {
    public:
        iterator(H &hashmap, size_t index, Item *item)
            : m_hashmap { hashmap }
            , m_index { index }
            , m_item { item } { }

        iterator &operator++() {
            assert(m_index < m_hashmap.m_capacity);
            if (m_item->next)
                m_item = m_item->next;
            else {
                do {
                    ++m_index;
                    if (m_index >= m_hashmap.m_capacity) {
                        m_item = nullptr;
                        return *this; // reached the end
                    }
                    m_item = m_hashmap.m_map[m_index];
                } while (!m_item);
            }
            return *this;
        }

        iterator operator++(int) {
            iterator i = *this;
            ++(*this);
            return i;
        }

        KeyT key() {
            if (m_item)
                return m_item->key;
            return nullptr;
        }

        T value() {
            if (m_item)
                return m_item->value;
            return nullptr;
        }

        std::pair<KeyT, T> operator*() {
            return std::pair<KeyT, T> { m_item->key, m_item->value };
        }

        friend bool operator==(const iterator &i1, const iterator &i2) {
            return i1.m_index == i2.m_index && i1.m_item == i2.m_item;
        }

        friend bool operator!=(const iterator &i1, const iterator &i2) {
            return i1.m_index != i2.m_index || i1.m_item != i2.m_item;
        }

        Item *item() { return m_item; }

    private:
        H &m_hashmap;
        size_t m_index { 0 };
        Hashmap::Item *m_item { nullptr };
    };

    /**
     * Returns an iterator over the Hashmap.
     * The iterator is dereferenced to a std::pair,
     * so you call .first and .second to get the key and
     * value, respectively.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * for (std::pair item : map) {
     *     assert_str_eq("foo", item.first);
     *     assert_eq(Thing(1), item.second);
     * }
     * ```
     */
    iterator<Hashmap> begin() {
        if (m_size == 0) return end();
        assert(m_map);
        Item *item = nullptr;
        size_t index;
        for (index = 0; index < m_capacity; ++index) {
            item = m_map[index];
            if (item)
                break;
        }
        return iterator<Hashmap> { *this, index, item };
    }

    /**
     * Returns a *const* iterator over the Hashmap.
     * Otherwise works the same as a non-const iterator.
     *
     * ```
     * auto map = Hashmap<String, Thing>();
     * map.put("foo", Thing(1));
     * const auto const_map = map;
     * for (std::pair item : const_map) {
     *     assert_str_eq("foo", item.first);
     *     assert_eq(Thing(1), item.second);
     * }
     * ```
     */
    iterator<const Hashmap> begin() const {
        if (m_size == 0) return end();
        assert(m_map);
        Item *item = nullptr;
        size_t index;
        for (index = 0; index < m_capacity; ++index) {
            item = m_map[index];
            if (item)
                break;
        }
        return iterator<const Hashmap> { *this, index, item };
    }

    iterator<Hashmap> end() {
        return iterator<Hashmap> { *this, m_capacity, nullptr };
    }

    iterator<const Hashmap> end() const {
        return iterator<const Hashmap> { *this, m_capacity, nullptr };
    }

private:
    // Returns an integer from 0-100
    size_t load_factor() { return m_size * 100 / m_capacity; }

    size_t index_for_hash(size_t hash) const {
        // This is an optimization for hash % capacity that is only possible
        // because capacity is always a power of two.
        assert((m_capacity & (m_capacity - 1)) == 0);
        return hash & (m_capacity - 1);
    }

    size_t calculate_map_size(size_t num_items) {
        size_t target_size = std::max<size_t>(4, num_items) * 100 / HASHMAP_TARGET_LOAD_FACTOR + 1;

        // Round up to the next power of two (if the value is not already a power of two)
        // TODO: This can be replaced by std::bit_ceil in C++20
        target_size--;
        for (size_t i = 1; i < sizeof(size_t) * 8; i *= 2) {
            target_size |= target_size >> i;
        }
        return ++target_size;
    }

    void rehash() {
        auto old_capacity = m_capacity;
        m_capacity = calculate_map_size(m_size);
        auto new_map = new Item *[m_capacity] {};
        for (size_t i = 0; i < old_capacity; i++) {
            auto item = m_map[i];
            while (item) {
                auto next_item = item->next;
                auto new_index = index_for_hash(item->hash);
                insert_item(new_map, new_index, item);
                item = next_item;
            }
        }
        auto old_map = m_map;
        m_map = new_map;
        delete[] old_map;
    }

    void insert_item(Item **map, size_t index, Item *item) {
        auto existing_item = map[index];
        if (existing_item) {
            while (existing_item && existing_item->next) {
                existing_item = existing_item->next;
            }
            existing_item->next = item;
        } else {
            map[index] = item;
        }
        item->next = nullptr;
    }

    void delete_item(size_t index, Item *item) {
        m_map[index] = item->next;
        delete item;
        m_size--;
        if (load_factor() < HASHMAP_MIN_LOAD_FACTOR)
            rehash();
    }

    void delete_item(Item *item_before, Item *item) {
        item_before->next = item->next;
        delete item;
        m_size--;
        if (load_factor() < HASHMAP_MIN_LOAD_FACTOR)
            rehash();
    }

    void copy_items_from(const Hashmap &other) {
        if (!other.m_map) return;
        for (size_t i = 0; i < m_capacity; i++) {
            auto item = other.m_map[i];
            if (item) {
                auto my_item = new Item { *item };
                my_item->key = item->key;
                m_map[i] = my_item;
                m_size++;
                while (item->next) {
                    item = item->next;
                    my_item->next = new Item { *item };
                    my_item->next->key = item->key;
                    my_item = my_item->next;
                    m_size++;
                }
            }
        }
    }

    size_t m_size { 0 };
    size_t m_capacity { 0 };
    Item **m_map { nullptr };

    CleanupFn *m_cleanup_fn { nullptr };
};
}
