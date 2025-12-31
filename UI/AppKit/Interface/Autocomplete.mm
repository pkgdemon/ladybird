/*
 * Copyright (c) 2025, Tim Flynn <trflynn89@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Interface/Autocomplete.h>
#import <Utilities/Conversions.h>

static NSString* const AUTOCOMPLETE_IDENTIFIER = @"Autocomplete";
static constexpr auto MAX_NUMBER_OF_ROWS = 8uz;
static constexpr auto POPOVER_PADDING = 6uz;

@interface Autocomplete () <NSTableViewDataSource, NSTableViewDelegate>
{
    Vector<String> m_suggestions;
}

@property (nonatomic, weak) id<AutocompleteObserver> observer;
@property (nonatomic, weak) NSToolbarItem* toolbar_item;

@property (nonatomic, strong) NSTableView* table_view;
#if !LADYBIRD_HAS_POPOVER
@property (nonatomic, strong) NSView* content_view;
#endif

@end

@implementation Autocomplete

- (instancetype)init:(id<AutocompleteObserver>)observer
     withToolbarItem:(NSToolbarItem*)toolbar_item
{
#if LADYBIRD_HAS_POPOVER
    if (self = [super init]) {
#else
    auto initial_frame = NSMakeRect(0, 0, 200, 200);
    if (self = [super initWithContentRect:initial_frame
                                styleMask:NSWindowStyleMaskBorderless
                                  backing:NSBackingStoreBuffered
                                    defer:YES]) {
        [self setFloatingPanel:YES];
        [self setBecomesKeyOnlyIfNeeded:YES];
        [self setHidesOnDeactivate:YES];
#endif
        self.observer = observer;
        self.toolbar_item = toolbar_item;

        auto* column = [[NSTableColumn alloc] init];
        [column setEditable:NO];

        self.table_view = [[NSTableView alloc] init];
        [self.table_view setAction:@selector(selectSuggestion:)];
        [self.table_view setBackgroundColor:[NSColor clearColor]];
        [self.table_view setIntercellSpacing:NSMakeSize(0, 5)];
        [self.table_view setHeaderView:nil];
        [self.table_view setRefusesFirstResponder:YES];
#if LADYBIRD_APPLE
        [self.table_view setRowSizeStyle:NSTableViewRowSizeStyleDefault];
#endif
        [self.table_view addTableColumn:column];
        [self.table_view setDataSource:self];
        [self.table_view setDelegate:self];
        [self.table_view setTarget:self];

        auto* scroll_view = [[NSScrollView alloc] init];
        [scroll_view setHasVerticalScroller:YES];
        [scroll_view setDocumentView:self.table_view];
        [scroll_view setDrawsBackground:NO];

#if LADYBIRD_HAS_POPOVER
        auto* content_view = [[NSView alloc] init];
        [content_view addSubview:scroll_view];

        auto* controller = [[NSViewController alloc] init];
        [controller setView:content_view];

        [self setAnimates:NO];
        [self setBehavior:NSPopoverBehaviorTransient];
        [self setContentViewController:controller];
        [self setValue:[NSNumber numberWithBool:YES] forKeyPath:@"shouldHideAnchor"];
#else
        self.content_view = [[NSView alloc] initWithFrame:initial_frame];
        [self.content_view addSubview:scroll_view];
        [self setContentView:self.content_view];
#endif
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
#if LADYBIRD_HAS_POPOVER
    if (!self.isShown)
        return NO;
    [super close];
#else
    if (![self isVisible])
        return NO;
    [self orderOut:nil];
#endif
    return YES;
}

- (BOOL)isCurrentlyShown
{
#if LADYBIRD_HAS_POPOVER
    return self.isShown;
#else
    return [self isVisible];
#endif
}

- (Optional<String>)selectedSuggestion
{
    if (![self isCurrentlyShown] || self.table_view.numberOfRows == 0)
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

    if (![self isCurrentlyShown]) {
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

    if (![self isCurrentlyShown]) {
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
    auto height = (self.table_view.rowHeight + self.table_view.intercellSpacing.height) * min(self.table_view.numberOfRows, MAX_NUMBER_OF_ROWS);
    auto frame = NSMakeRect(0, 0, [[self.toolbar_item view] frame].size.width, height);

    [self.table_view.enclosingScrollView setFrame:NSInsetRect(frame, 0, POPOVER_PADDING)];

    [self.table_view deselectAll:nil];
    [self.table_view scrollRowToVisible:0];

    auto* window = [self.toolbar_item.view window];
    auto* first_responder = [window firstResponder];

#if LADYBIRD_HAS_POPOVER
    [self setContentSize:frame.size];
    [self showRelativeToToolbarItem:self.toolbar_item];
    [self showRelativeToRect:self.toolbar_item.view.frame
                      ofView:self.toolbar_item.view
               preferredEdge:NSRectEdgeMaxY];
#else
    // GNUstep: Position the panel below the toolbar item
    auto toolbar_frame = [[self.toolbar_item view] convertRect:[[self.toolbar_item view] bounds] toView:nil];
    auto screen_origin = [window convertRectToScreen:toolbar_frame].origin;
    auto panel_frame = NSMakeRect(screen_origin.x, screen_origin.y - frame.size.height, frame.size.width, frame.size.height);
    [self setFrame:panel_frame display:YES];
    [self.content_view setFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
    [self orderFront:nil];
#endif

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
