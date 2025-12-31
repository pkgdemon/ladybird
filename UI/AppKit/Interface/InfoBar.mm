/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Interface/InfoBar.h>
#import <Interface/Tab.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static constexpr CGFloat const INFO_BAR_HEIGHT = 40;
static constexpr CGFloat const INFO_BAR_PADDING = 8;

@interface InfoBar ()

@property (nonatomic, strong) NSTextField* text_label;
@property (nonatomic, strong) NSButton* dismiss_button;
@property (nonatomic, copy) InfoBarDismissed on_dismissed;

@end

@implementation InfoBar

- (instancetype)init
{
    if (self = [super init]) {
#if LADYBIRD_APPLE
        self.text_label = [NSTextField labelWithString:@""];
        self.dismiss_button = [NSButton buttonWithTitle:@""
                                                 target:self
                                                 action:@selector(dismiss:)];
#else
        // GNUstep: Create label manually
        self.text_label = [[NSTextField alloc] init];
        [self.text_label setStringValue:@""];
        [self.text_label setBezeled:NO];
        [self.text_label setDrawsBackground:NO];
        [self.text_label setEditable:NO];
        [self.text_label setSelectable:NO];

        // GNUstep: Create button manually
        self.dismiss_button = [[NSButton alloc] init];
        [self.dismiss_button setTitle:@""];
        [self.dismiss_button setTarget:self];
        [self.dismiss_button setAction:@selector(dismiss:)];
#endif
        [self.dismiss_button setBezelStyle:NSBezelStyleAccessoryBarAction];

#if LADYBIRD_HAS_STACKVIEW
        [self addView:self.text_label inGravity:NSStackViewGravityLeading];
        [self addView:self.dismiss_button inGravity:NSStackViewGravityTrailing];

        [self setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
        [self setEdgeInsets:NSEdgeInsets { 0, 8, 0, 8 }];

        [[self heightAnchor] constraintEqualToConstant:INFO_BAR_HEIGHT].active = YES;
#else
        [self addSubview:self.text_label];
        [self addSubview:self.dismiss_button];
        [self setAutoresizingMask:NSViewWidthSizable];
#endif
    }

    return self;
}

#if !LADYBIRD_HAS_STACKVIEW
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
    [super resizeSubviewsWithOldSize:oldSize];
    [self layoutSubviews];
}

- (void)layoutSubviews
{
    auto bounds = [self bounds];
    auto button_size = [self.dismiss_button intrinsicContentSize];

    // Position text label on the left with padding
    auto label_width = bounds.size.width - button_size.width - INFO_BAR_PADDING * 3;
    [self.text_label setFrame:NSMakeRect(INFO_BAR_PADDING, (bounds.size.height - 20) / 2, label_width, 20)];

    // Position button on the right with padding
    [self.dismiss_button setFrame:NSMakeRect(bounds.size.width - button_size.width - INFO_BAR_PADDING,
                                             (bounds.size.height - button_size.height) / 2,
                                             button_size.width, button_size.height)];
}
#endif

- (void)showWithMessage:(NSString*)message
      dismissButtonTitle:(NSString*)title
    dismissButtonClicked:(InfoBarDismissed)on_dismissed
               activeTab:(Tab*)tab
{
    [self.text_label setStringValue:message];

    self.dismiss_button.title = title;
    self.on_dismissed = on_dismissed;

    if (tab) {
        [self attachToTab:tab];
    }

    [self setHidden:NO];
}

- (void)dismiss:(id)sender
{
    if (self.on_dismissed) {
        self.on_dismissed();
    }

    [self hide];
}

- (void)hide
{
    [self removeFromSuperview];
    [self setHidden:YES];
}

- (void)tabBecameActive:(Tab*)tab
{
    if (![self isHidden]) {
        [self attachToTab:tab];
    }
}

- (void)attachToTab:(Tab*)tab
{
    [self removeFromSuperview];

#if LADYBIRD_HAS_STACKVIEW
    [tab.contentView addView:self inGravity:NSStackViewGravityTrailing];
    [[self leadingAnchor] constraintEqualToAnchor:[tab.contentView leadingAnchor]].active = YES;
#else
    // GNUstep: Manually position at top of content view
    auto content_bounds = [tab.contentView bounds];
    auto frame = NSMakeRect(0, content_bounds.size.height - INFO_BAR_HEIGHT,
                            content_bounds.size.width, INFO_BAR_HEIGHT);
    [self setFrame:frame];
    [tab.contentView addSubview:self];
    [self layoutSubviews];
#endif
}

@end
