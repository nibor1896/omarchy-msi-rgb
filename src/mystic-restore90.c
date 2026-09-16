#define _DEFAULT_SOURCE
#include <hidapi/hidapi.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// Restore reports 0x90-0x93 from a hex dump file (one report per section,
// header line "== feature 0x90 exact (302 bytes)").
int main(int argc, char **argv) {
  FILE *f = fopen(argv[1], "r");
  if (!f) { perror("dump"); return 1; }
  hid_device *h = hid_open_path("/dev/hidraw2");
  if (!h) { fprintf(stderr, "open failed\n"); return 1; }
  char line[512];
  int rid = 0, len = 0, idx = 0;
  static unsigned char buf[1024];
  while (fgets(line, sizeof line, f)) {
    if (strncmp(line, "== feature 0x", 12) == 0) {
      if (rid && idx == len) {
        printf("restore 0x%02X: %d\n", rid, hid_send_feature_report(h, buf, len));
      }
      sscanf(line, "== feature 0x%x exact (%d bytes)", &rid, &len);
      idx = 0;
      continue;
    }
    for (char *p = strtok(line, " \n"); p && idx < len; p = strtok(NULL, " \n"))
      buf[idx++] = (unsigned char)strtol(p, NULL, 16);
  }
  if (rid && idx == len) printf("restore 0x%02X: %d\n", rid, hid_send_feature_report(h, buf, len));
  hid_close(h);
  return 0;
}
