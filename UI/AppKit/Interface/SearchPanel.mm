/*
 * Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <Interface/LadybirdWebViewBridge.h>

#import <Platform.h>
#import <Interface/LadybirdWebView.h>
#import <Interface/SearchPanel.h>
#import <Interface/Tab.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

#if LADYBIRD_HAS_STACKVIEW
static constexpr CGFloat const SEARCH_FIELD_HEIGHT = 30;
#endif
static constexpr CGFloat const SEARCH_FIELD_WIDTH = 300;
static constexpr CGFloat const SEARCH_PANEL_PADDING = 8;

#if LADYBIRD_APPLE
@interface SearchPanel () <NSSearchFieldDelegate>
#else
@interface SearchPanel () <NSTextFieldDelegate>
#endif
{
    CaseSensitivity m_case_sensitivity;
}

@property (nonatomic, strong) NSSearchField* search_field;
@property (nonatomic, strong) NSButton* search_previous;
@property (nonatomic, strong) NSButton* search_next;
@property (nonatomic, strong) NSButton* search_match_case;
@property (nonatomic, strong) NSTextField* result_label;
@property (nonatomic, strong) NSButton* search_done;

@end

@implementation SearchPanel

- (instancetype)init
{
    if (self = [super init]) {
        self.search_field = [[NSSearchField alloc] init];
        [self.search_field setPlaceholderString:@"Search"];
        [self.search_field setDelegate:self];

#if LADYBIRD_APPLE
        self.search_previous = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameGoLeftTemplate]
                                                  target:self
                                                  action:@selector(findPreviousMatch:)];
#else
        self.search_previous = [[NSButton alloc] init];
        [self.search_previous setTitle:@"<"];
        [self.search_previous setTarget:self];
        [self.search_previous setAction:@selector(findPreviousMatch:)];
#endif
        [self.search_previous setToolTip:@"Find Previous Match"];
        [self.search_previous setBordered:NO];

#if LADYBIRD_APPLE
        self.search_next = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameGoRightTemplate]
                                              target:self
                                              action:@selector(findNextMatch:)];
#else
        self.search_next = [[NSButton alloc] init];
        [self.search_next setTitle:@">"];
        [self.search_next setTarget:self];
        [self.search_next setAction:@selector(findNextMatch:)];
#endif
        [self.search_next setToolTip:@"Find Next Match"];
        [self.search_next setBordered:NO];

#if LADYBIRD_APPLE
        self.search_match_case = [NSButton checkboxWithTitle:@"Match Case"
                                                      target:self
                                                      action:@selector(find:)];
#else
        self.search_match_case = [[NSButton alloc] init];
        [self.search_match_case setButtonType:NSSwitchButton];
        [self.search_match_case setTitle:@"Match Case"];
        [self.search_match_case setTarget:self];
        [self.search_match_case setAction:@selector(find:)];
#endif
        [self.search_match_case setState:NSControlStateValueOff];
        m_case_sensitivity = CaseSensitivity::CaseInsensitive;

#if LADYBIRD_APPLE
        self.result_label = [NSTextField labelWithString:@""];
#else
        self.result_label = [[NSTextField alloc] init];
        [self.result_label setStringValue:@""];
        [self.result_label setEditable:NO];
        [self.result_label setSelectable:NO];
        [self.result_label setBezeled:NO];
        [self.result_label setDrawsBackground:NO];
#endif
        [self.result_label setHidden:YES];

#if LADYBIRD_APPLE
        self.search_done = [NSButton buttonWithTitle:@"Done"
                                              target:self
                                              action:@selector(cancelSearch:)];
#else
        self.search_done = [[NSButton alloc] init];
        [self.search_done setTitle:@"Done"];
        [self.search_done setTarget:self];
        [self.search_done setAction:@selector(cancelSearch:)];
#endif
        [self.search_done setToolTip:@"Close Search Bar"];
        [self.search_done setBezelStyle:NSBezelStyleAccessoryBarAction];

#if LADYBIRD_HAS_STACKVIEW
        [self addView:self.search_field inGravity:NSStackViewGravityLeading];
        [self addView:self.search_previous inGravity:NSStackViewGravityLeading];
        [self addView:self.search_next inGravity:NSStackViewGravityLeading];
        [self addView:self.search_match_case inGravity:NSStackViewGravityLeading];
        [self addView:self.result_label inGravity:NSStackViewGravityLeading];
        [self addView:self.search_done inGravity:NSStackViewGravityTrailing];

        [self setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
        [self setEdgeInsets:NSEdgeInsets { 0, 8, 0, 8 }];

        [[self heightAnchor] constraintEqualToConstant:SEARCH_FIELD_HEIGHT].active = YES;
        [[self.search_field widthAnchor] constraintEqualToConstant:SEARCH_FIELD_WIDTH].active = YES;
#else
        [self addSubview:self.search_field];
        [self addSubview:self.search_previous];
        [self addSubview:self.search_next];
        [self addSubview:self.search_match_case];
        [self addSubview:self.result_label];
        [self addSubview:self.search_done];
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
    CGFloat x = SEARCH_PANEL_PADDING;
    CGFloat center_y = (bounds.size.height - 20) / 2;

    // Search field
    [self.search_field setFrame:NSMakeRect(x, center_y - 2, SEARCH_FIELD_WIDTH, 24)];
    x += SEARCH_FIELD_WIDTH + SEARCH_PANEL_PADDING;

    // Previous button
    auto prev_size = [self.search_previous intrinsicContentSize];
    [self.search_previous setFrame:NSMakeRect(x, center_y, prev_size.width, prev_size.height)];
    x += prev_size.width + 4;

    // Next button
    auto next_size = [self.search_next intrinsicContentSize];
    [self.search_next setFrame:NSMakeRect(x, center_y, next_size.width, next_size.height)];
    x += next_size.width + SEARCH_PANEL_PADDING;

    // Match case checkbox
    auto match_size = [self.search_match_case intrinsicContentSize];
    [self.search_match_case setFrame:NSMakeRect(x, center_y, match_size.width, match_size.height)];
    x += match_size.width + SEARCH_PANEL_PADDING;

    // Result label
    if (![self.result_label isHidden]) {
        [self.result_label sizeToFit];
        auto label_size = [self.result_label frame].size;
        [self.result_label setFrame:NSMakeRect(x, center_y, label_size.width, label_size.height)];
    }

    // Done button (right-aligned)
    auto done_size = [self.search_done intrinsicContentSize];
    [self.search_done setFrame:NSMakeRect(bounds.size.width - done_size.width - SEARCH_PANEL_PADDING,
                                          center_y, done_size.width, done_size.height)];
}
#endif

#pragma mark - Public methods

- (void)find:(id)sender
{
    [self setHidden:NO];
    [self setSearchTextFromPasteBoard];

    [self.window makeFirstResponder:self.search_field];
}

- (void)findNextMatch:(id)sender
{
    if ([self setSearchTextFromPasteBoard]) {
        return;
    }

    [[[self tab] web_view] findInPageNextMatch];
}

- (void)findPreviousMatch:(id)sender
{
    if ([self setSearchTextFromPasteBoard]) {
        return;
    }

    [[[self tab] web_view] findInPagePreviousMatch];
}

- (void)useSelectionForFind:(id)sender
{
    auto selected_text = [[[self tab] web_view] view].selected_text();
    auto* query = Ladybird::string_to_ns_string(selected_text);

    [self setPasteBoardContents:query];

    if (![self isHidden]) {
        [self.search_field setStringValue:query];
        [[[self tab] web_view] findInPage:query caseSensitivity:m_case_sensitivity];

        [self.window makeFirstResponder:self.search_field];
    }
}

- (void)onFindInPageResult:(size_t)current_match_index
           totalMatchCount:(Optional<size_t> const&)total_match_count
{
    if (total_match_count.has_value()) {
        auto* label_text = *total_match_count > 0
            ? [NSString stringWithFormat:@"%zu of %zu matches", current_match_index, *total_match_count]
            : @"Phrase not found";

        auto* label_attributes = @{
            NSFontAttributeName : [NSFont boldSystemFontOfSize:12.0f],
        };

        auto* label_attribute = [[NSAttributedString alloc] initWithString:label_text
                                                                attributes:label_attributes];

        [self.result_label setAttributedStringValue:label_attribute];
        [self.result_label setHidden:NO];
    } else {
        [self.result_label setHidden:YES];
    }
}

#pragma mark - Private methods

- (Tab*)tab
{
    return (Tab*)[self window];
}

- (void)setPasteBoardContents:(NSString*)query
{
#if LADYBIRD_APPLE
    auto* paste_board = [NSPasteboard pasteboardWithName:NSPasteboardNameFind];
    [paste_board clearContents];
    [paste_board setString:query forType:NSPasteboardTypeString];
#else
    auto* paste_board = [NSPasteboard pasteboardWithName:NSFindPboard];
    [paste_board declareTypes:@[ NSPasteboardTypeString ] owner:nil];
    [paste_board setString:query forType:NSPasteboardTypeString];
#endif
}

- (BOOL)setSearchTextFromPasteBoard
{
#if LADYBIRD_APPLE
    auto* paste_board = [NSPasteboard pasteboardWithName:NSPasteboardNameFind];
#else
    auto* paste_board = [NSPasteboard pasteboardWithName:NSFindPboard];
#endif
    auto* query = [paste_board stringForType:NSPasteboardTypeString];

    if (query) {
        auto case_sensitivity = [self.search_match_case state] == NSControlStateValueOff
            ? CaseSensitivity::CaseInsensitive
            : CaseSensitivity::CaseSensitive;

        if (case_sensitivity != m_case_sensitivity || ![[self.search_field stringValue] isEqual:query]) {
            [self.search_field setStringValue:query];
            m_case_sensitivity = case_sensitivity;

            [[[self tab] web_view] findInPage:query caseSensitivity:m_case_sensitivity];
            return YES;
        }
    }

    return NO;
}

- (void)cancelSearch:(id)sender
{
    [self setHidden:YES];
}

#pragma mark - NSSearchFieldDelegate

- (void)controlTextDidChange:(NSNotification*)notification
{
    auto* query = [self.search_field stringValue];
    [[[self tab] web_view] findInPage:query caseSensitivity:m_case_sensitivity];

    [self setPasteBoardContents:query];
}

- (BOOL)control:(NSControl*)control
               textView:(NSTextView*)text_view
    doCommandBySelector:(SEL)selector
{
    if (selector == @selector(insertNewline:)) {
        NSEvent* event = [[self tab] currentEvent];

        if ((event.modifierFlags & NSEventModifierFlagShift) == 0) {
            [self findNextMatch:nil];
        } else {
            [self findPreviousMatch:nil];
        }

        return YES;
    }

    if (selector == @selector(cancelOperation:)) {
        [self cancelSearch:nil];
        return YES;
    }

    return NO;
}

@end
