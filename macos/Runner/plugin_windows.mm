#import "plugin_windows.h"
#include "../../rust/karbeat-host/include/digidaw_native_host.h"
#include <dlfcn.h>

@interface DigidawPluginWindow : NSObject <NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic) BOOL closed;
@property(nonatomic) BOOL resized;
@end
@implementation DigidawPluginWindow
- (BOOL)windowShouldClose:(NSWindow *)sender {
  self.closed = YES;
  return NO;
}
- (void)windowDidResize:(NSNotification *)notification {
  self.resized = YES;
}
@end

namespace {
__weak NSWindow *app_window;
uintptr_t create_window(const char *title, uint32_t width, uint32_t height,
                        uintptr_t *parent) {
  DigidawPluginWindow *host = [DigidawPluginWindow new];
  host.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, width, height)
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
      backing:NSBackingStoreBuffered defer:NO];
  host.window.releasedWhenClosed = NO;
  host.window.title = [NSString stringWithUTF8String:title];
  host.window.delegate = host;
  [host.window center];
  if (app_window) [app_window addChildWindow:host.window ordered:NSWindowAbove];
  *parent = reinterpret_cast<uintptr_t>((__bridge void *)host.window.contentView);
  return reinterpret_cast<uintptr_t>((__bridge_retained void *)host);
}
void destroy_window(uintptr_t token) {
  DigidawPluginWindow *host = CFBridgingRelease(reinterpret_cast<void *>(token));
  host.window.delegate = nil;
  [host.window.parentWindow removeChildWindow:host.window];
  [host.window close];
}
void focus_window(uintptr_t token) {
  DigidawPluginWindow *host = (__bridge DigidawPluginWindow *)reinterpret_cast<void *>(token);
  [host.window makeKeyAndOrderFront:nil];
}
bool resize_window(uintptr_t token, uint32_t width, uint32_t height) {
  if (!width || !height || width > 16384 || height > 16384) return false;
  DigidawPluginWindow *host = (__bridge DigidawPluginWindow *)reinterpret_cast<void *>(token);
  [host.window setContentSize:NSMakeSize(width, height)];
  return true;
}
uint32_t poll_window(uintptr_t token, uint32_t *width, uint32_t *height) {
  DigidawPluginWindow *host = (__bridge DigidawPluginWindow *)reinterpret_cast<void *>(token);
  *width = host.window.contentView.bounds.size.width;
  *height = host.window.contentView.bounds.size.height;
  uint32_t flags = (host.closed ? 1 : 0) | (host.resized ? 2 : 0);
  host.resized = NO;
  return flags;
}
bool set_title(uintptr_t token, const char *title) {
  DigidawPluginWindow *host = (__bridge DigidawPluginWindow *)reinterpret_cast<void *>(token);
  NSString *name = [NSString stringWithUTF8String:title];
  if (!name) return false;
  host.window.title = name;
  return true;
}
bool set_resizable(uintptr_t token, bool resizable) {
  DigidawPluginWindow *host = (__bridge DigidawPluginWindow *)reinterpret_cast<void *>(token);
  const NSSize content_size = host.window.contentView.bounds.size;
  if (resizable) host.window.styleMask |= NSWindowStyleMaskResizable;
  else host.window.styleMask &= ~NSWindowStyleMaskResizable;
  [host.window setContentSize:content_size];
  [host.window standardWindowButton:NSWindowZoomButton].enabled = resizable;
  return true;
}
const DigidawNativeWindowApi api = {
    2, 3, create_window, destroy_window, focus_window, resize_window, poll_window,
    set_title, set_resizable};
}  // namespace

void digidaw_native_host_start(NSWindow *owner) {
  app_window = owner;
  NSTimer *timer = [NSTimer timerWithTimeInterval:0.016 repeats:YES block:^(NSTimer *) {
    auto poll = reinterpret_cast<DigidawNativeHostPoll>(dlsym(RTLD_DEFAULT, "digidaw_native_host_poll"));
    if (poll) poll(&api);
  }];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}
