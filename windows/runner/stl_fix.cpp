#include <cstdint>
#include <cstring>

// Fix for missing STL symbols when linking newer Firebase SDK with older VS toolsets.
// These symbols are internal to the Microsoft STL and are used for vectorized operations.
// They are missing in Visual Studio 2019 but referenced by newer Firebase SDKs (built with VS 2022+).

extern "C" {
    void* __std_find_trivial_1(const void* first, const void* last, uint8_t value) {
        if (first == last) return (void*)last;
        size_t cnt = (const uint8_t*)last - (const uint8_t*)first;
        void* res = (void*)memchr(first, value, cnt);
        return res ? res : (void*)last;
    }

    void* __std_find_trivial_8(const void* first, const void* last, uint64_t value) {
        const uint64_t* f = (const uint64_t*)first;
        const uint64_t* l = (const uint64_t*)last;
        for (; f != l; ++f) { if (*f == value) return (void*)f; }
        return (void*)l;
    }

    void* __std_find_last_trivial_1(const void* first, const void* last, uint8_t value) {
        if (first == last) return (void*)last;
        const uint8_t* f = (const uint8_t*)first;
        const uint8_t* l = (const uint8_t*)last;
        const uint8_t* p = l;
        while (p != f) {
            if (*--p == value) return (void*)p;
        }
        return (void*)l;
    }

    void* __std_find_first_of_trivial_1(const void* first1, const void* last1, const void* first2, const void* last2) {
        const uint8_t* f1 = (const uint8_t*)first1;
        const uint8_t* l1 = (const uint8_t*)last1;
        const uint8_t* f2 = (const uint8_t*)first2;
        const uint8_t* l2 = (const uint8_t*)last2;
        for (; f1 != l1; ++f1) {
            for (const uint8_t* p = f2; p != l2; ++p) {
                if (*f1 == *p) return (void*)f1;
            }
        }
        return (void*)l1;
    }

    void* __std_remove_8(void* first, void* last, uint64_t value) {
        uint64_t* f = (uint64_t*)first;
        uint64_t* l = (uint64_t*)last;
        f = (uint64_t*)__std_find_trivial_8(f, l, value);
        if (f != l) {
            uint64_t* i = f;
            for (++i; i != l; ++i) {
                if (!(*i == value)) {
                    *f = *i;
                    ++f;
                }
            }
        }
        return (void*)f;
    }

    uint64_t __std_find_last_of_trivial_pos_1(const void* first1, size_t size1, const void* first2, size_t size2) {
        const uint8_t* f1 = (const uint8_t*)first1;
        const uint8_t* f2 = (const uint8_t*)first2;
        if (size1 == 0 || size2 == 0) return (uint64_t)-1;
        for (size_t i = size1; i > 0; --i) {
            uint8_t c = f1[i - 1];
            for (size_t j = 0; j < size2; ++j) {
                if (c == f2[j]) return (uint64_t)(i - 1);
            }
        }
        return (uint64_t)-1;
    }
}
