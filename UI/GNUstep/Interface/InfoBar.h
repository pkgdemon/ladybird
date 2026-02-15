/*
 * Copyright (c) 2024, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class GNUstepBrowserWindow;

@interface InfoBar : NSView

- (void)showWithMessage:(NSString*)message
     dismissButtonTitle:(NSString*)dismiss_button_title
   dismissButtonClicked:(void (^)(void))dismiss_button_clicked
              activeTab:(GNUstepBrowserWindow*)window;

- (void)hide;

@end
