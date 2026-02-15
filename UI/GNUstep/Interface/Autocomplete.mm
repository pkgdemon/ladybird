/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Interface/Autocomplete.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static NSString* const AUTOCOMPLETE_IDENTIFIER = @"Autocomplete";
static constexpr auto MAX_NUMBER_OF_ROWS = 8uz;
static constexpr auto PANEL_PADDING = 6uz;

@interface Autocomplete ()
{
    Vector<String> m_suggestions;
}

@property (nonatomic, weak) id<AutocompleteObserver> observer;
@property (nonatomic, weak) NSToolbarItem* toolbar_item;
@property (nonatomic, strong) NSTableView* table_view;
@property (nonatomic, strong) NSScrollView* scroll_view;
@property (nonatomic, assign) BOOL isShown;

@end

@implementation Autocomplete

- (instancetype)init:(id<AutocompleteObserver>)observer
     withToolbarItem:(NSToolbarItem*)toolbar_item
{
    // Create panel with no title bar (popup style)
    static constexpr auto style_mask = NSWindowStyleMaskBorderless;

    if (self = [super initWithContentRect:NSZeroRect
                                styleMask:style_mask
                                  backing:NSBackingStoreBuffered
                                    defer:YES]) {
        self.observer = observer;
        self.toolbar_item = toolbar_item;
        self.isShown = NO;

        // Configure panel appearance
        [self setOpaque:NO];
        [self setBackgroundColor:[NSColor colorWithCalibratedWhite:0.97 alpha:0.98]];
        [self setHasShadow:YES];
        [self setLevel:NSPopUpMenuWindowLevel];

        // Create table column
        auto* column = [[NSTableColumn alloc] initWithIdentifier:AUTOCOMPLETE_IDENTIFIER];
        [column setEditable:NO];

        // Create table view
        self.table_view = [[NSTableView alloc] init];
        [self.table_view setAction:@selector(selectSuggestion:)];
        [self.table_view setBackgroundColor:[NSColor clearColor]];
        [self.table_view setIntercellSpacing:NSMakeSize(0, 5)];
        [self.table_view setHeaderView:nil];
        [self.table_view setRefusesFirstResponder:YES];
        [self.table_view addTableColumn:column];
        [self.table_view setDataSource:self];
        [self.table_view setDelegate:self];
        [self.table_view setTarget:self];

        // Create scroll view
        self.scroll_view = [[NSScrollView alloc] init];
        [self.scroll_view setHasVerticalScroller:YES];
        [self.scroll_view setDocumentView:self.table_view];
        [self.scroll_view setDrawsBackground:NO];

        [[self contentView] addSubview:self.scroll_view];
    }

    return self;
}

#pragma mark - Public methods

- (void)showWithSuggestions:(Vector<String>)suggestions
{
    m_suggestions = move(suggestions);
    [self.table_view reloadData];

    if (m_suggestions.is_empty()) {
        [self close];
    } else {
        [self show];
    }
}

- (BOOL)close
{
    if (!self.isShown)
        return NO;

    [self orderOut:nil];
    self.isShown = NO;
    return YES;
}

- (Optional<String>)selectedSuggestion
{
    if (!self.isShown || self.table_view.numberOfRows == 0)
        return {};

    auto row = [self.table_view selectedRow];
    if (row < 0)
        return {};

    return m_suggestions[row];
}

- (BOOL)selectNextSuggestion
{
    if (self.table_view.numberOfRows == 0)
        return NO;

    if (!self.isShown) {
        [self show];
        return YES;
    }

    [self selectRow:[self.table_view selectedRow] + 1];
    return YES;
}

- (BOOL)selectPreviousSuggestion
{
    if (self.table_view.numberOfRows == 0)
        return NO;

    if (!self.isShown) {
        [self show];
        return YES;
    }

    [self selectRow:[self.table_view selectedRow] - 1];
    return YES;
}

- (void)selectSuggestion:(id)sender
{
    if (auto suggestion = [self selectedSuggestion]; suggestion.has_value())
        [self.observer onSelectedSuggestion:suggestion.release_value()];
}

#pragma mark - Private methods

- (void)show
{
    auto row_height = self.table_view.rowHeight + self.table_view.intercellSpacing.height;
    auto visible_rows = min(self.table_view.numberOfRows, (NSInteger)MAX_NUMBER_OF_ROWS);
    auto height = row_height * visible_rows + PANEL_PADDING * 2;

    // Get the toolbar item's view frame in screen coordinates
    NSView* toolbar_view = [self.toolbar_item view];
    if (!toolbar_view) {
        return;
    }

    NSRect view_frame = [toolbar_view frame];
    NSRect screen_frame = [[toolbar_view window] convertRectToScreen:
        [toolbar_view convertRect:view_frame toView:nil]];

    // Position panel below the toolbar item
    NSRect panel_frame = NSMakeRect(
        screen_frame.origin.x,
        screen_frame.origin.y - height,
        view_frame.size.width,
        height);

    [self setFrame:panel_frame display:YES];

    // Configure scroll view to fill the content
    NSRect scroll_frame = NSMakeRect(0, PANEL_PADDING, view_frame.size.width, height - PANEL_PADDING * 2);
    [self.scroll_view setFrame:scroll_frame];

    [self.table_view deselectAll:nil];
    [self.table_view scrollRowToVisible:0];

    [self orderFront:nil];
    self.isShown = YES;

    // Keep focus on the original window
    auto* window = [self.toolbar_item.view window];
    auto* first_responder = [window firstResponder];
    if (first_responder)
        [window makeFirstResponder:first_responder];
}

- (void)selectRow:(NSInteger)row
{
    if (row < 0)
        row = self.table_view.numberOfRows - 1;
    else if (row >= self.table_view.numberOfRows)
        row = 0;

    [self.table_view selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self.table_view scrollRowToVisible:[self.table_view selectedRow]];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView
{
    return static_cast<NSInteger>(m_suggestions.size());
}

#pragma mark - NSTableViewDelegate

- (NSView*)tableView:(NSTableView*)table_view
    viewForTableColumn:(NSTableColumn*)table_column
                   row:(NSInteger)row
{
    NSTableCellView* view = (NSTableCellView*)[table_view makeViewWithIdentifier:AUTOCOMPLETE_IDENTIFIER owner:self];

    if (view == nil) {
        view = [[NSTableCellView alloc] initWithFrame:NSZeroRect];

        NSTextField* text_field = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [text_field setBezeled:NO];
        [text_field setDrawsBackground:NO];
        [text_field setEditable:NO];
        [text_field setSelectable:NO];

        [view addSubview:text_field];
        [view setTextField:text_field];
        [view setIdentifier:AUTOCOMPLETE_IDENTIFIER];
    }

    [view.textField setStringValue:Ladybird::string_to_ns_string(m_suggestions[row])];
    return view;
}

@end
