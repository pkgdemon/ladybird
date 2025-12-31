/*
 * Copyright (c) 2024, Tim Flynn <trflynn89@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Platform.h>
#import <Interface/LadybirdWebView.h>
#import <Interface/LadybirdWebViewWindow.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

@interface LadybirdWebViewWindow ()
@end

@implementation LadybirdWebViewWindow

- (instancetype)initWithWebView:(LadybirdWebView*)web_view
                     windowRect:(NSRect)window_rect
{
    static constexpr auto style_mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

    self = [super initWithContentRect:window_rect
                            styleMask:style_mask
                              backing:NSBackingStoreBuffered
                                defer:NO];

    if (self) {
        self.web_view = web_view;

        if (self.web_view == nil)
            self.web_view = [[LadybirdWebView alloc] init:nil];

#if LADYBIRD_APPLE
        [self.web_view setClipsToBounds:YES];
#endif
    }

    return self;
}

#pragma mark - NSWindow

- (void)setIsVisible:(BOOL)flag
{
#if !LADYBIRD_APPLE
    NSLog(@"LadybirdWebViewWindow setIsVisible:%d", flag);
    fflush(stderr);
#endif
    [self.web_view handleVisibility:flag];
    [super setIsVisible:flag];
}

#if LADYBIRD_APPLE
- (void)setIsMiniaturized:(BOOL)flag
{
    [self.web_view handleVisibility:!flag];
    [super setIsMiniaturized:flag];
}
#endif

@end
