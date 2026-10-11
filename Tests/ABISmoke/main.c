/* Execute the actual Embedded Swift object in userspace, never in the kernel. */
#include <stdint.h>
#include <stdio.h>

extern uint32_t swift_ane_abi_version(void);
extern int32_t swift_ane_is_m1_chip(uint32_t chip_id);

int main(void)
{
	if (swift_ane_abi_version() != 1 ||
	    swift_ane_is_m1_chip(0x8103) != 1 ||
	    swift_ane_is_m1_chip(0) != 0 ||
	    swift_ane_is_m1_chip(UINT32_MAX) != 0) {
		fputs("Embedded Swift C ABI smoke test failed\n", stderr);
		return 1;
	}
	puts("Embedded Swift C ABI smoke test passed (userspace only)");
	return 0;
}
