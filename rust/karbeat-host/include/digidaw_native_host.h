#ifndef DIGIDAW_NATIVE_HOST_H
#define DIGIDAW_NATIVE_HOST_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DigidawNativeWindowApi {
  uint32_t version;
  uint32_t parent_kind;
  uintptr_t (*create)(const char *title, uint32_t width, uint32_t height,
                      uintptr_t *parent);
  void (*destroy)(uintptr_t token);
  void (*focus)(uintptr_t token);
  bool (*resize)(uintptr_t token, uint32_t width, uint32_t height);
  uint32_t (*poll)(uintptr_t token, uint32_t *width, uint32_t *height);
  bool (*set_title)(uintptr_t token, const char *title);
  bool (*set_resizable)(uintptr_t token, bool resizable);
} DigidawNativeWindowApi;

typedef void (*DigidawNativeHostPoll)(const DigidawNativeWindowApi *api);

#ifdef __cplusplus
}
#endif
#endif
