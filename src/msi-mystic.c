// msi-mystic — direct control for the MSI Mystic Light USB RGB hub
// (1462:921b) found in MSI desktops (MEG Vision X AI era). Talks HID feature
// reports straight to the controller, so it works even where OpenRGB has no
// device support yet.
//
// Protocol (reverse engineered 2026-09-16 on a MEG Vision X AI):
//   Feature report 0x50, 290 bytes:
//     [0]            0x50
//     [1 + ch*16]    channel entry, 16 bytes:
//       [0]  mode      (observed: 0x0a default rainbow-ish, 0x01 static,
//                       0x00 off — remaining values follow the classic
//                       Mystic Light enum, pass raw numbers to try more)
//       [1-3]  RGB #1
//       [4-6]  RGB #2
//       [7-9]  RGB #3
//       [10-12] ff ff ff (speed/brightness flags, untouched)
//       [13-14] 03 15    (marker, untouched)
//       [15]   LED count (read-only: channels present when count > 0)
//   Firmware ping: output report 0x01 with 01 B0 CC.. → answers 01 vv vv.
//
// Build: gcc -O2 -o msi-mystic msi-mystic.c -lhidapi-hidraw
// License: MIT
#define _DEFAULT_SOURCE
#include <hidapi/hidapi.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#define VID 0x1462
#define PID 0x921B
#define REPORT_LEN 290
#define ENTRY_SIZE 16
#define MAX_CHANNELS 6

static hid_device *dev = NULL;

static int open_dev(const char *path) {
  if (path) {
    dev = hid_open_path(path);
    return dev ? 0 : -1;
  }
  struct hid_device_info *list = hid_enumerate(VID, PID);
  if (!list) return -1;
  dev = hid_open_path(list->path);
  hid_free_enumeration(list);
  return dev ? 0 : -1;
}

static int read_table(unsigned char buf[REPORT_LEN]) {
  memset(buf, 0, REPORT_LEN);
  buf[0] = 0x50;
  return hid_get_feature_report(dev, buf, REPORT_LEN);
}

static int write_table(unsigned char buf[REPORT_LEN]) {
  return hid_send_feature_report(dev, buf, REPORT_LEN);
}

static int channel_present(const unsigned char buf[REPORT_LEN], int ch) {
  return buf[1 + ch * ENTRY_SIZE + 15] > 0;
}

static void print_channels(const unsigned char buf[REPORT_LEN]) {
  for (int ch = 0; ch < MAX_CHANNELS; ch++) {
    const unsigned char *e = buf + 1 + ch * ENTRY_SIZE;
    printf("%d\tleds=%d\tmode=0x%02x\tcolors=%02x%02x%02x,%02x%02x%02x,%02x%02x%02x\n",
           ch, e[15], e[0], e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9]);
  }
}

static int mode_from_name(const char *s) {
  struct { const char *name; int mode; } map[] = {
    {"off", 0x00}, {"static", 0x01}, {"breathing", 0x02},
    {"flashing", 0x03}, {"rainbow", 0x0a},
  };
  for (unsigned i = 0; i < sizeof map / sizeof map[0]; i++)
    if (!strcmp(map[i].name, s)) return map[i].mode;
  return (int)strtol(s, NULL, 0);  // raw number (0x.. accepted)
}

static void usage(void) {
  fputs(
    "usage: msi-mystic [--device /dev/hidrawN] <command>\n"
    "\n"
    "commands:\n"
    "  ping                    firmware ping, verifies the controller answers\n"
    "  channels                list RGB channels (led count, mode, colors)\n"
    "  set <ch|all> <mode> <rrggbb>\n"
    "        mode: off|static|breathing|flashing|rainbow or raw number (0x..)\n"
    "        example: msi-mystic set all static ff6a00\n",
    stderr);
}

int main(int argc, char **argv) {
  const char *path = NULL;
  int i = 1;
  if (i < argc && !strcmp(argv[i], "--device")) { path = argv[i + 1]; i += 2; }
  if (i >= argc) { usage(); return 2; }

  if (open_dev(path)) {
    fprintf(stderr, "msi-mystic: Mystic Light controller (1462:921b) not found\n");
    return 1;
  }

  int rc = 0;
  if (!strcmp(argv[i], "ping")) {
    unsigned char out[65], in[64];
    memset(out, 0, sizeof out);
    out[0] = 0x01; out[1] = 0xB0;
    memset(out + 2, 0xCC, sizeof out - 2);
    hid_write(dev, out, sizeof out);
    int n = hid_read_timeout(dev, in, sizeof in, 500);
    if (n > 0) printf("firmware %02x %02x\n", in[1], in[2]);
    else { fprintf(stderr, "no response\n"); rc = 1; }
  } else if (!strcmp(argv[i], "channels")) {
    unsigned char buf[REPORT_LEN];
    if (read_table(buf) < 0) { fprintf(stderr, "read failed\n"); rc = 1; }
    else print_channels(buf);
  } else if (!strcmp(argv[i], "set") && i + 3 < argc) {
    unsigned char buf[REPORT_LEN];
    if (read_table(buf) < 0) { fprintf(stderr, "read failed\n"); rc = 1; }
    else {
      int mode = mode_from_name(argv[i + 2]);
      char *end;
      long color = strtol(argv[i + 3], &end, 16);
      if (end == argv[i + 3] || strlen(argv[i + 3]) != 6) {
        fprintf(stderr, "color must be rrggbb hex\n"); rc = 2;
      } else {
        unsigned r = (color >> 16) & 0xff, g = (color >> 8) & 0xff, b = color & 0xff;
        int touched = 0;
        for (int ch = 0; ch < MAX_CHANNELS; ch++) {
          if (!channel_present(buf, ch)) continue;
          if (strcmp(argv[i + 1], "all") && atoi(argv[i + 1]) != ch) continue;
          unsigned char *e = buf + 1 + ch * ENTRY_SIZE;
          e[0] = mode;
          e[1] = r; e[2] = g; e[3] = b;
          e[4] = 0; e[5] = 0; e[6] = 0;
          e[7] = 0; e[8] = 0; e[9] = 0;
          touched++;
        }
        if (!touched) { fprintf(stderr, "no such channel\n"); rc = 1; }
        else {
          write_table(buf);
          usleep(50000);
          unsigned char chk[REPORT_LEN];
          read_table(chk);
          printf("applied to %d channel(s)\n", touched);
        }
      }
    }
  } else {
    usage(); rc = 2;
  }

  hid_close(dev);
  hid_exit();
  return rc;
}
