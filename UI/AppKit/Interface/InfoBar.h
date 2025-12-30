/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#import <Cocoa/Cocoa.h>
#import <Platform.h>

@class Tab;

using InfoBarDismissed = void (^)(void);

#if LADYBIRD_HAS_STACKVIEW
@interface InfoBar : NSStackView
#else
@interface InfoBar : NSView
#endif

- (void)showWithMessage:(NSString*)message
      dismissButtonTitle:(NSString*)title
    dismissButtonClicked:(InfoBarDismissed)on_dismissed
               activeTab:(Tab*)tab;
- (void)hide;

- (void)tabBecameActive:(Tab*)tab;

@end
