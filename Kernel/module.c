// SPDX-License-Identifier: GPL-2.0-only
/* ABI smoke-test bridge only: no ANE registers, DMA, IRQs, or device binding. */
#include <linux/errno.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/of.h>

#include "ane_core.h"

static int __init swift_ane_probe_init(void)
{
	if (!of_machine_is_compatible("apple,t8103"))
		return -ENODEV;

	if (swift_ane_abi_version() != 1 ||
	    swift_ane_is_m1_chip(0x8103) != 1 ||
	    swift_ane_is_m1_chip(0) != 0)
		return -EINVAL;

	pr_info("swift_ane_probe: Embedded Swift ABI verified; ANE hardware untouched\n");
	return 0;
}

static void __exit swift_ane_probe_exit(void)
{
	pr_info("swift_ane_probe: unloaded\n");
}

module_init(swift_ane_probe_init);
module_exit(swift_ane_probe_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Experimental Embedded Swift ABI probe, not an ANE driver");
