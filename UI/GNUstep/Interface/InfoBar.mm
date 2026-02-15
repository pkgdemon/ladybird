/*
 * Copyright (c) 2024, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Interface/GNUstepBrowserWindow.h>
#import <Interface/InfoBar.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static constexpr CGFloat INFO_BAR_HEIGHT = 30.0;
static constexpr CGFloat PADDING = 8.0;
static constexpr CGFloat BUTTON_WIDTH = 80.0;

@interface InfoBar ()

@property (nonatomic, copy) void (^dismissButtonClicked)(void);
@property (nonatomic, strong) NSTextField* messageLabel;
@property (nonatomic, strong) NSButton* dismissButton;
@property (nonatomic, weak) GNUstepBrowserWindow* currentWindow;

@end

@implementation InfoBar

- (instancetype)init
{
    if (self = [super initWithFrame:NSZeroRect]) {
        // Create message label
        self.messageLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [self.messageLabel setEditable:NO];
        [self.messageLabel setBordered:NO];
        [self.messageLabel setBackgroundColor:[NSColor clearColor]];
        [self.messageLabel setAlignment:NSTextAlignmentLeft];
        [self addSubview:self.messageLabel];

        // Create dismiss button
        self.dismissButton = [[NSButton alloc] initWithFrame:NSZeroRect];
        [self.dismissButton setTarget:self];
        [self.dismissButton setAction:@selector(dismissButtonAction:)];
        [self.dismissButton setBezelStyle:NSRoundedBezelStyle];
        [self addSubview:self.dismissButton];
    }
    return self;
}

- (void)layout
{
    [super layout];

    NSRect bounds = [self bounds];

    // Position dismiss button on the right
    CGFloat buttonX = NSMaxX(bounds) - BUTTON_WIDTH - PADDING;
    CGFloat buttonY = (NSHeight(bounds) - 20) / 2;
    [self.dismissButton setFrame:NSMakeRect(buttonX, buttonY, BUTTON_WIDTH, 20)];

    // Position message label to fill the rest
    CGFloat labelWidth = buttonX - PADDING * 2;
    CGFloat labelY = (NSHeight(bounds) - 20) / 2;
    [self.messageLabel setFrame:NSMakeRect(PADDING, labelY, labelWidth, 20)];
}

- (void)showWithMessage:(NSString*)message
     dismissButtonTitle:(NSString*)dismiss_button_title
   dismissButtonClicked:(void (^)(void))dismiss_button_clicked
              activeTab:(GNUstepBrowserWindow*)window
{
    [self.messageLabel setStringValue:message];
    [self.dismissButton setTitle:dismiss_button_title];
    self.dismissButtonClicked = dismiss_button_clicked;
    self.currentWindow = window;

    if (!window) {
        return;
    }

    // Calculate frame for info bar
    NSRect contentBounds = [[window contentView] bounds];
    NSRect infoBarFrame = NSMakeRect(0,
                                     NSMaxY(contentBounds) - INFO_BAR_HEIGHT,
                                     NSWidth(contentBounds),
                                     INFO_BAR_HEIGHT);
    [self setFrame:infoBarFrame];
    [self setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

    // Add to window content view
    [[window contentView] addSubview:self positioned:NSWindowAbove relativeTo:nil];
    [self setNeedsLayout:YES];
}

- (void)hide
{
    [self removeFromSuperview];
    self.currentWindow = nil;
}

- (void)dismissButtonAction:(id)sender
{
    if (self.dismissButtonClicked) {
        self.dismissButtonClicked();
    }
}

@end
