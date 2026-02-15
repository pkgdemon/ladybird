/*
 * Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/StringUtils.h>

#import <Interface/BrowserTab.h>
#import <Interface/LadybirdWebView.h>
#import <Interface/SearchPanel.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static constexpr CGFloat PANEL_HEIGHT = 30.0;
static constexpr CGFloat PADDING = 8.0;
static constexpr CGFloat BUTTON_WIDTH = 30.0;
static constexpr CGFloat SEARCH_FIELD_WIDTH = 200.0;
static constexpr CGFloat MATCH_LABEL_WIDTH = 100.0;

@interface SearchPanel ()

@property (nonatomic, strong) NSSearchField* search_field;
@property (nonatomic, strong) NSTextField* match_label;
@property (nonatomic, strong) NSButton* previous_button;
@property (nonatomic, strong) NSButton* next_button;
@property (nonatomic, strong) NSButton* done_button;

@end

@implementation SearchPanel

- (instancetype)init
{
    if (self = [super initWithFrame:NSMakeRect(0, 0, 500, PANEL_HEIGHT)]) {
        [self setAutoresizingMask:NSViewWidthSizable];

        // Create search field
        self.search_field = [[NSSearchField alloc] initWithFrame:NSZeroRect];
        [self.search_field setPlaceholderString:@"Find in page"];
        [self.search_field setDelegate:self];
        [self.search_field setTarget:self];
        [self.search_field setAction:@selector(searchFieldAction:)];
        [self addSubview:self.search_field];

        // Create match label
        self.match_label = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [self.match_label setEditable:NO];
        [self.match_label setBordered:NO];
        [self.match_label setBackgroundColor:[NSColor clearColor]];
        [self.match_label setAlignment:NSTextAlignmentCenter];
        [self.match_label setStringValue:@""];
        [self addSubview:self.match_label];

        // Create previous button
        self.previous_button = [[NSButton alloc] initWithFrame:NSZeroRect];
        [self.previous_button setTitle:@"\u25B2"]; // ▲
        [self.previous_button setBezelStyle:NSRoundedBezelStyle];
        [self.previous_button setTarget:self];
        [self.previous_button setAction:@selector(findPreviousMatch:)];
        [self.previous_button setToolTip:@"Previous match"];
        [self addSubview:self.previous_button];

        // Create next button
        self.next_button = [[NSButton alloc] initWithFrame:NSZeroRect];
        [self.next_button setTitle:@"\u25BC"]; // ▼
        [self.next_button setBezelStyle:NSRoundedBezelStyle];
        [self.next_button setTarget:self];
        [self.next_button setAction:@selector(findNextMatch:)];
        [self.next_button setToolTip:@"Next match"];
        [self addSubview:self.next_button];

        // Create done button
        self.done_button = [[NSButton alloc] initWithFrame:NSZeroRect];
        [self.done_button setTitle:@"Done"];
        [self.done_button setBezelStyle:NSRoundedBezelStyle];
        [self.done_button setTarget:self];
        [self.done_button setAction:@selector(hide:)];
        [self addSubview:self.done_button];
    }
    return self;
}

- (void)layout
{
    [super layout];

    NSRect bounds = [self bounds];
    CGFloat y = (NSHeight(bounds) - 22) / 2;
    CGFloat x = PADDING;

    // Search field
    [self.search_field setFrame:NSMakeRect(x, y, SEARCH_FIELD_WIDTH, 22)];
    x += SEARCH_FIELD_WIDTH + PADDING;

    // Match label
    [self.match_label setFrame:NSMakeRect(x, y, MATCH_LABEL_WIDTH, 22)];
    x += MATCH_LABEL_WIDTH + PADDING;

    // Previous button
    [self.previous_button setFrame:NSMakeRect(x, y, BUTTON_WIDTH, 22)];
    x += BUTTON_WIDTH + 4;

    // Next button
    [self.next_button setFrame:NSMakeRect(x, y, BUTTON_WIDTH, 22)];
    x += BUTTON_WIDTH + PADDING;

    // Done button on the right
    CGFloat done_width = 60;
    [self.done_button setFrame:NSMakeRect(NSMaxX(bounds) - done_width - PADDING, y, done_width, 22)];
}

#pragma mark - Public methods

- (void)find:(id)sender
{
    if ([self isHidden]) {
        [self setHidden:NO];
    }

    [[self window] makeFirstResponder:self.search_field];
}

- (void)findNextMatch:(id)sender
{
    if ([self isHidden]) {
        return;
    }

    auto* web_view = [self webView];
    if (web_view) {
        [web_view findInPageNextMatch];
    }
}

- (void)findPreviousMatch:(id)sender
{
    if ([self isHidden]) {
        return;
    }

    auto* web_view = [self webView];
    if (web_view) {
        [web_view findInPagePreviousMatch];
    }
}

- (void)useSelectionForFind:(id)sender
{
    // Get selection from web view and put in search field
    // For now, just focus the search panel
    [self find:sender];
}

- (void)onFindInPageResult:(size_t)current_match_index
           totalMatchCount:(Optional<size_t> const&)total_match_count
{
    NSString* message = nil;

    if (!total_match_count.has_value()) {
        message = @"";
    } else if (*total_match_count == 0) {
        message = @"No matches";
    } else {
        message = [NSString stringWithFormat:@"%zu of %zu", current_match_index, *total_match_count];
    }

    [self.match_label setStringValue:message];
}

#pragma mark - Private methods

- (LadybirdWebView*)webView
{
    // Navigate up to find the BrowserTab and get its web view
    NSView* superview = [self superview];
    while (superview) {
        if ([superview isKindOfClass:[LadybirdWebView class]]) {
            return (LadybirdWebView*)superview;
        }
        superview = [superview superview];
    }

    // Try to get from the window's tab view
    id window = [self window];
    if ([window respondsToSelector:@selector(activeTab)]) {
        BrowserTab* tab = [window performSelector:@selector(activeTab)];
        if (tab) {
            return [tab web_view];
        }
    }

    return nil;
}

- (void)searchFieldAction:(id)sender
{
    auto* web_view = [self webView];
    if (!web_view) {
        return;
    }

    NSString* query = [self.search_field stringValue];
    if ([query length] == 0) {
        [self.match_label setStringValue:@""];
        return;
    }

    [web_view findInPage:query caseSensitivity:CaseSensitivity::CaseInsensitive];
}

- (void)hide:(id)sender
{
    [self setHidden:YES];
    [self.search_field setStringValue:@""];
    [self.match_label setStringValue:@""];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification*)notification
{
    [self searchFieldAction:self.search_field];
}

@end
