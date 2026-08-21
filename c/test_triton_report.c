/* Unit test for triton_report.h (Phase 0, Task 4). Numbered-report framing. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "triton_report.h"

int main(void)
{
    unsigned char buf[TRITON_WIRE_MAX];

    /* USB-id variant: wire length = 1 + 53, report id 0x42, moving stick axis. */
    memset(buf, 0xAA, sizeof buf);
    int n = triton_fill_canned_report(buf, sizeof buf, TRITON_REPORT_ID_USB, 0);
    assert(n == 1 + TRITON_PAYLOAD_USB);          /* 54 bytes on the wire */
    assert(buf[0] == 0x42);

    short lsx0;
    memcpy(&lsx0, buf + TRITON_LSX_OFFSET, 2);
    triton_fill_canned_report(buf, sizeof buf, TRITON_REPORT_ID_USB, 128);
    short lsx1;
    memcpy(&lsx1, buf + TRITON_LSX_OFFSET, 2);
    assert(lsx0 != lsx1);                         /* left-stick X must move with tick */

    /* BLE-id variant: wire length = 1 + 45, report id 0x45. */
    n = triton_fill_canned_report(buf, sizeof buf, TRITON_REPORT_ID_BLE, 0);
    assert(n == 1 + TRITON_PAYLOAD_BLE);          /* 46 bytes on the wire */
    assert(buf[0] == 0x45);

    /* sLeftStickX must sit fully inside the smaller (0x45) payload. */
    assert(TRITON_LSX_OFFSET + 2 <= 1 + TRITON_PAYLOAD_BLE);

    /* Too-small buffer is rejected. */
    unsigned char tiny[8];
    assert(triton_fill_canned_report(tiny, sizeof tiny, TRITON_REPORT_ID_USB, 0) == 0);

    printf("PASS\n");
    return 0;
}
