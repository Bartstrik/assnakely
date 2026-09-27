#include "stdio.h"
#include <stdint.h>
#include <stdbool.h>

const int64_t batoi(const char* str);

int main(int argc, char** argv) {
	if (argc != 3) return 1;
	
	int64_t ret = batoi(argv[1]);
	ret += batoi(argv[2]);
	printf("%ld\n", ret); 
	return 0;
}

// only works with int64
const int64_t batoi(const char* str) {
	int64_t ret = 0;
	int8_t sign = 1;
	uint8_t count = 0;
	uint8_t str_len = 0;

	// set sign multiplier to -1 if str starts with '-'
	if (*str == 45) {
		sign = -1;
		str += sizeof(char);
	}

	// finding str_len
	while (*str != '\0') {
		str_len++;
		str += sizeof(char);
	}

	str -= sizeof(char);

	// int64 max is 9223372036854775807 = 19 chars, beware that if '9' * 19 is inserted it will not return -1 but overflow ret.
	if (str_len > 19) return 0;
	
	while (count < str_len) {
		if (*str < 48 || *str > 57) return 0; // incorrect string check (48 = '0', 45 = '9')
		int64_t add = sign * (*str - 48);
		for (uint8_t i = 0; i < count; i++) { add *= 10; } //Simple 10**count
		ret += add;
		count++;
		str -= sizeof(char);
	}
	
	return ret;
}
