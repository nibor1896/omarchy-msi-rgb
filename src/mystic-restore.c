#define _DEFAULT_SOURCE
#include <hidapi/hidapi.h>
#include <stdio.h>
#include <string.h>

// Restore report 0x50 to the factory dump: channels 0-5 rainbow default
// with led counts 23/18/11/8/0/0, empty slots zero, trailing entry at 272.
int main(void) {
  hid_device *h = hid_open_path("/dev/hidraw2");
  if (!h) { fprintf(stderr, "open failed\n"); return 1; }
  unsigned char buf[290];
  memset(buf, 0, sizeof buf);
  buf[0] = 0x50;
  int counts[6] = {0x17, 0x12, 0x0b, 0x08, 0x00, 0x00};
  for (int k = 0; k < 6; k++) {
    unsigned char *e = buf + 1 + 16 * k;
    e[0] = 0x0a;
    e[1] = 0xff; e[2] = 0x00; e[3] = 0x00;
    e[4] = 0x00; e[5] = 0xff; e[6] = 0x00;
    e[7] = 0x00; e[8] = 0x00; e[9] = 0xff;
    e[10] = e[11] = e[12] = 0xff;
    e[13] = 0x03; e[14] = 0x15; e[15] = counts[k];
  }
  unsigned char *t = buf + 272;
  t[0] = 0x0a;
  t[1] = 0xff; t[2] = 0; t[3] = 0;
  t[4] = 0; t[5] = 0xff; t[6] = 0;
  t[7] = 0; t[8] = 0; t[9] = 0xff;
  t[10] = t[11] = t[12] = 0xff;
  t[13] = 0x03; t[14] = 0x15;
  printf("restore write=%d\n", hid_send_feature_report(h, buf, sizeof buf));
  hid_close(h);
  return 0;
}
