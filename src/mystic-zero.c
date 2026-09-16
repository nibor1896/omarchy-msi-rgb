#define _DEFAULT_SOURCE
#include <hidapi/hidapi.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  hid_device *h = hid_open_path("/dev/hidraw2");
  if (!h) { fprintf(stderr, "open failed\n"); return 1; }
  unsigned char buf[761];
  int ids[5] = {0x51, 0xB0, 0xB1, 0xB2, 0xB3};
  for (int i = 0; i < 5; i++) {
    int len = ids[i] == 0x51 ? 727 : 761;
    memset(buf, 0, sizeof buf);
    buf[0] = ids[i];
    printf("zero 0x%02X: %d\n", ids[i], hid_send_feature_report(h, buf, len));
  }
  hid_close(h);
  return 0;
}
