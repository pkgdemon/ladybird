/*
 * Copyright (c) 2023-2025, Tim Flynn <trflynn89@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <LibWebView/Application.h>
#include <LibWebView/Autocomplete.h>
#include <LibWebView/URL.h>
#include <LibWebView/ViewImplementation.h>

#import <Platform.h>
#import <Application/ApplicationDelegate.h>
#import <Interface/Autocomplete.h>
#import <Interface/LadybirdWebView.h>
#import <Interface/Menu.h>
#import <Interface/Tab.h>
#import <Interface/TabController.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static NSString* const TOOLBAR_IDENTIFIER = @"Toolbar";
static NSString* const TOOLBAR_NAVIGATE_BACK_IDENTIFIER = @"ToolbarNavigateBackIdentifier";
static NSString* const TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER = @"ToolbarNavigateForwardIdentifier";
static NSString* const TOOLBAR_RELOAD_IDENTIFIER = @"ToolbarReloadIdentifier";
static NSString* const TOOLBAR_LOCATION_IDENTIFIER = @"ToolbarLocationIdentifier";
static NSString* const TOOLBAR_ZOOM_IDENTIFIER = @"ToolbarZoomIdentifier";
static NSString* const TOOLBAR_NEW_TAB_IDENTIFIER = @"ToolbarNewTabIdentifier";
static NSString* const TOOLBAR_TAB_OVERVIEW_IDENTIFIER = @"ToolbarTabOverviewIdentifier";

@interface LocationSearchField : NSSearchField

- (BOOL)becomeFirstResponder;

@end

@implementation LocationSearchField

- (BOOL)becomeFirstResponder
{
    BOOL result = [super becomeFirstResponder];
    if (result)
        [self performSelector:@selector(selectText:) withObject:self afterDelay:0];
    return result;
}

@end

#if LADYBIRD_APPLE
@interface TabController () <NSToolbarDelegate, NSSearchFieldDelegate, AutocompleteObserver>
#else
@interface TabController () <NSToolbarDelegate, NSTextFieldDelegate, AutocompleteObserver>
#endif
{
    u64 m_page_index;

    OwnPtr<WebView::Autocomplete> m_autocomplete;
}

@property (nonatomic, strong) Tab* parent;

@property (nonatomic, strong) NSToolbar* toolbar;
@property (nonatomic, strong) NSArray* toolbar_identifiers;

@property (nonatomic, strong) NSToolbarItem* navigate_back_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* navigate_forward_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* reload_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* location_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* zoom_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* new_tab_toolbar_item;
@property (nonatomic, strong) NSToolbarItem* tab_overview_toolbar_item;

@property (nonatomic, strong) Autocomplete* autocomplete;

@property (nonatomic, assign) NSLayoutConstraint* location_toolbar_item_width;

#if !LADYBIRD_APPLE
@property (nonatomic, strong) NSTextField* gnustep_location_field;
#endif

@end

@implementation TabController

@synthesize toolbar_identifiers = _toolbar_identifiers;
@synthesize navigate_back_toolbar_item = _navigate_back_toolbar_item;
@synthesize navigate_forward_toolbar_item = _navigate_forward_toolbar_item;
@synthesize reload_toolbar_item = _reload_toolbar_item;
@synthesize location_toolbar_item = _location_toolbar_item;
@synthesize zoom_toolbar_item = _zoom_toolbar_item;
@synthesize new_tab_toolbar_item = _new_tab_toolbar_item;
@synthesize tab_overview_toolbar_item = _tab_overview_toolbar_item;

- (instancetype)init
{
#if !LADYBIRD_APPLE
    NSLog(@"TabController init: starting");
    fflush(stderr);
#endif
    if (self = [super init]) {
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: super init done");
        fflush(stderr);
#endif
        __weak TabController* weak_self = self;

#if !LADYBIRD_APPLE
        NSLog(@"TabController init: creating toolbar");
        fflush(stderr);
#endif
        self.toolbar = [[NSToolbar alloc] initWithIdentifier:TOOLBAR_IDENTIFIER];
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: toolbar alloc done");
        fflush(stderr);
        // GNUstep: Defer setting delegate until showWindow: to avoid
        // accessing [self tab] before the window exists
#else
        [self.toolbar setDelegate:self];
#endif
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: delegate handling done");
        fflush(stderr);
#endif
        [self.toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: setDisplayMode done");
        fflush(stderr);
#endif
        if (@available(macOS 15, *)) {
            if ([self.toolbar respondsToSelector:@selector(setAllowsDisplayModeCustomization:)]) {
                [self.toolbar performSelector:@selector(setAllowsDisplayModeCustomization:) withObject:nil];
            }
        }
        [self.toolbar setAllowsUserCustomization:NO];
        [self.toolbar setSizeMode:NSToolbarSizeModeRegular];
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: toolbar created");
        fflush(stderr);
#endif

        m_page_index = 0;

#if !LADYBIRD_APPLE
        NSLog(@"TabController init: creating autocomplete");
        fflush(stderr);
#endif
        self.autocomplete = [[Autocomplete alloc] init:self withToolbarItem:self.location_toolbar_item];
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: autocomplete created, creating m_autocomplete");
        fflush(stderr);
#endif
        m_autocomplete = make<WebView::Autocomplete>();
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: m_autocomplete created");
        fflush(stderr);
#endif

        m_autocomplete->on_autocomplete_query_complete = [weak_self](auto suggestions) {
            TabController* self = weak_self;
            if (self == nil) {
                return;
            }

            [self.autocomplete showWithSuggestions:move(suggestions)];
        };
#if !LADYBIRD_APPLE
        NSLog(@"TabController init: complete");
        fflush(stderr);
#endif
    }

    return self;
}

- (instancetype)initAsChild:(Tab*)parent
                  pageIndex:(u64)page_index
{
    if (self = [self init]) {
        self.parent = parent;
        m_page_index = page_index;
    }

    return self;
}

#pragma mark - Public methods

- (void)loadURL:(URL::URL const&)url
{
    [[self tab].web_view loadURL:url];
}

- (void)onLoadStart:(URL::URL const&)url isRedirect:(BOOL)isRedirect
{
    [self setLocationFieldText:url.serialize()];
}

- (void)onURLChange:(URL::URL const&)url
{
    [self setLocationFieldText:url.serialize()];

    // Don't steal focus from the location bar when loading the new tab page
    if (url != WebView::Application::settings().new_tab_page_url()) {
        [self.window makeFirstResponder:[self tab].web_view];
    }
}

- (void)clearHistory
{
    // FIXME: Reimplement clearing history using WebContent's history.
}

- (void)focusLocationToolbarItem
{
#if LADYBIRD_APPLE
    [self.window makeFirstResponder:self.location_toolbar_item.view];
#else
    if (self.gnustep_location_field) {
        [self.window makeFirstResponder:self.gnustep_location_field];
    }
#endif
}

#pragma mark - Private methods

- (Tab*)tab
{
    return (Tab*)[self window];
}

#if !LADYBIRD_APPLE
- (void)setupGNUstepLocationBar
{
    // Create a simple location bar at the top of the window
    static constexpr CGFloat LOCATION_BAR_HEIGHT = 30;

    NSView* contentView = [self.window contentView];
    NSRect contentFrame = [contentView frame];

    // Create container for location bar
    NSRect locationBarFrame = NSMakeRect(0, contentFrame.size.height - LOCATION_BAR_HEIGHT,
                                         contentFrame.size.width, LOCATION_BAR_HEIGHT);
    NSView* locationBar = [[NSView alloc] initWithFrame:locationBarFrame];
    [locationBar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

    // Create the text field
    NSRect textFieldFrame = NSMakeRect(5, 3, contentFrame.size.width - 10, LOCATION_BAR_HEIGHT - 6);
    self.gnustep_location_field = [[NSTextField alloc] initWithFrame:textFieldFrame];
    [self.gnustep_location_field setAutoresizingMask:NSViewWidthSizable];
    [self.gnustep_location_field setPlaceholderString:@"Enter web address"];
    [self.gnustep_location_field setDelegate:self];
    [self.gnustep_location_field setEditable:YES];
    [self.gnustep_location_field setBezeled:YES];
    [self.gnustep_location_field setBezelStyle:NSTextFieldSquareBezel];

    // GNUstep: Set target/action for Enter key handling (doCommandBySelector: not called)
    [self.gnustep_location_field setTarget:self];
    [self.gnustep_location_field setAction:@selector(gnustepLocationFieldAction:)];

    [locationBar addSubview:self.gnustep_location_field];

    // Add location bar to window
    [contentView addSubview:locationBar];

    // Adjust existing content view children to make room
    for (NSView* subview in [contentView subviews]) {
        if (subview != locationBar) {
            NSRect frame = [subview frame];
            frame.size.height = contentFrame.size.height - LOCATION_BAR_HEIGHT;
            [subview setFrame:frame];
        }
    }
}

- (void)gnustepLocationFieldAction:(id)sender
{
    NSLog(@"gnustepLocationFieldAction: Enter pressed");
    fflush(stderr);

    auto location = Ladybird::ns_string_to_string([self.gnustep_location_field stringValue]);
    NSLog(@"gnustepLocationFieldAction: navigating to: %s", location.to_byte_string().characters());
    fflush(stderr);

    [self navigateToLocation:move(location)];
}
#endif

- (void)createNewTab:(id)sender
{
    auto* delegate = (ApplicationDelegate*)[NSApp delegate];

#if LADYBIRD_APPLE
    self.tab.titlebarAppearsTransparent = NO;
#endif

    [delegate createNewTab:WebView::Application::settings().new_tab_page_url()
                   fromTab:[self tab]
               activateTab:Web::HTML::ActivateTab::Yes];

#if LADYBIRD_APPLE
    self.tab.titlebarAppearsTransparent = YES;
#endif
}

- (void)setLocationFieldText:(StringView)url
{
    NSMutableAttributedString* attributed_url;

    auto* dark_attributes = @{
        NSForegroundColorAttributeName : [NSColor systemGrayColor],
    };
    auto* highlight_attributes = @{
        NSForegroundColorAttributeName : [NSColor textColor],
    };

    if (auto url_parts = WebView::break_url_into_parts(url); url_parts.has_value()) {
        attributed_url = [[NSMutableAttributedString alloc] init];

        auto* attributed_scheme_and_subdomain = [[NSAttributedString alloc]
            initWithString:Ladybird::string_to_ns_string(url_parts->scheme_and_subdomain)
                attributes:dark_attributes];

        auto* attributed_effective_tld_plus_one = [[NSAttributedString alloc]
            initWithString:Ladybird::string_to_ns_string(url_parts->effective_tld_plus_one)
                attributes:highlight_attributes];

        auto* attributed_remainder = [[NSAttributedString alloc]
            initWithString:Ladybird::string_to_ns_string(url_parts->remainder)
                attributes:dark_attributes];

        [attributed_url appendAttributedString:attributed_scheme_and_subdomain];
        [attributed_url appendAttributedString:attributed_effective_tld_plus_one];
        [attributed_url appendAttributedString:attributed_remainder];
    } else {
        attributed_url = [[NSMutableAttributedString alloc]
            initWithString:Ladybird::string_to_ns_string(url)
                attributes:highlight_attributes];
    }

    auto* location_search_field = (LocationSearchField*)[self.location_toolbar_item view];
    [location_search_field setAttributedStringValue:attributed_url];
}

- (BOOL)navigateToLocation:(String)location
{
    if (auto url = WebView::sanitize_url(location, WebView::Application::settings().search_engine()); url.has_value()) {
        [self loadURL:*url];
    }

    [self.window makeFirstResponder:nil];
    [self.autocomplete close];

    return YES;
}

- (void)showTabOverview:(id)sender
{
#if LADYBIRD_APPLE
    self.tab.titlebarAppearsTransparent = NO;
    [self.window toggleTabOverview:sender];
    self.tab.titlebarAppearsTransparent = YES;
#else
    // GNUstep: Tab overview not available
    (void)sender;
#endif
}

#pragma mark - Properties

#if LADYBIRD_APPLE
- (NSButton*)create_button:(NSImageName)image
#else
- (NSButton*)create_button:(NSString*)image
#endif
               with_action:(nonnull SEL)action
              with_tooltip:(NSString*)tooltip
{
#if LADYBIRD_APPLE
    auto* button = [NSButton buttonWithImage:[NSImage imageNamed:image]
                                      target:self
                                      action:action];
#else
    NSButton* button = [[NSButton alloc] init];
    [button setImage:[NSImage imageNamed:image]];
    [button setTarget:self];
    [button setAction:action];
    [button setBordered:NO];
#endif
    if (tooltip) {
        [button setToolTip:tooltip];
    }

    [button setBordered:YES];

    return button;
}

- (NSToolbarItem*)navigate_back_toolbar_item
{
    if (!_navigate_back_toolbar_item) {
        auto* button = Ladybird::create_application_button([[[self tab] web_view] view].navigate_back_action());

        _navigate_back_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NAVIGATE_BACK_IDENTIFIER];
        [_navigate_back_toolbar_item setView:button];
    }

    return _navigate_back_toolbar_item;
}

- (NSToolbarItem*)navigate_forward_toolbar_item
{
    if (!_navigate_forward_toolbar_item) {
        auto* button = Ladybird::create_application_button([[[self tab] web_view] view].navigate_forward_action());

        _navigate_forward_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER];
        [_navigate_forward_toolbar_item setView:button];
    }

    return _navigate_forward_toolbar_item;
}

- (NSToolbarItem*)reload_toolbar_item
{
    if (!_reload_toolbar_item) {
        auto* button = Ladybird::create_application_button(WebView::Application::the().reload_action());

        _reload_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_RELOAD_IDENTIFIER];
        [_reload_toolbar_item setView:button];
    }

    return _reload_toolbar_item;
}

- (NSToolbarItem*)location_toolbar_item
{
    if (!_location_toolbar_item) {
        auto* location_search_field = [[LocationSearchField alloc] init];
        [location_search_field setPlaceholderString:@"Enter web address"];
        [location_search_field setTextColor:[NSColor textColor]];
        [location_search_field setDelegate:self];

        if (@available(macOS 26, *)) {
            [location_search_field setBordered:YES];
        }

        _location_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_LOCATION_IDENTIFIER];
        [_location_toolbar_item setView:location_search_field];
    }

    return _location_toolbar_item;
}

- (NSToolbarItem*)zoom_toolbar_item
{
    if (!_zoom_toolbar_item) {
        auto* button = Ladybird::create_application_button([[[self tab] web_view] view].reset_zoom_action());

        _zoom_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_ZOOM_IDENTIFIER];
        [_zoom_toolbar_item setView:button];
    }

    return _zoom_toolbar_item;
}

- (NSToolbarItem*)new_tab_toolbar_item
{
    if (!_new_tab_toolbar_item) {
#if LADYBIRD_APPLE
        auto* button = [self create_button:NSImageNameAddTemplate
                               with_action:@selector(createNewTab:)
                              with_tooltip:@"New tab"];
#else
        // GNUstep: Use text button since NSImageNameAddTemplate not available
        NSButton* button = [[NSButton alloc] init];
        [button setTitle:@"+"];
        [button setTarget:self];
        [button setAction:@selector(createNewTab:)];
        [button setToolTip:@"New tab"];
        [button setBordered:YES];
#endif

        _new_tab_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NEW_TAB_IDENTIFIER];
        [_new_tab_toolbar_item setView:button];
    }

    return _new_tab_toolbar_item;
}

- (NSToolbarItem*)tab_overview_toolbar_item
{
    if (!_tab_overview_toolbar_item) {
#if LADYBIRD_APPLE
        auto* button = [self create_button:NSImageNameIconViewTemplate
                               with_action:@selector(showTabOverview:)
                              with_tooltip:@"Show all tabs"];
#else
        // GNUstep: Use text button since NSImageNameIconViewTemplate not available
        NSButton* button = [[NSButton alloc] init];
        [button setTitle:@"Tabs"];
        [button setTarget:self];
        [button setAction:@selector(showTabOverview:)];
        [button setToolTip:@"Show all tabs"];
        [button setBordered:YES];
#endif

        _tab_overview_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_TAB_OVERVIEW_IDENTIFIER];
        [_tab_overview_toolbar_item setView:button];
    }

    return _tab_overview_toolbar_item;
}

- (NSArray*)toolbar_identifiers
{
    if (!_toolbar_identifiers) {
#if LADYBIRD_APPLE
        _toolbar_identifiers = @[
            TOOLBAR_NAVIGATE_BACK_IDENTIFIER,
            TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER,
            NSToolbarFlexibleSpaceItemIdentifier,
            TOOLBAR_RELOAD_IDENTIFIER,
            TOOLBAR_LOCATION_IDENTIFIER,
            TOOLBAR_ZOOM_IDENTIFIER,
            NSToolbarFlexibleSpaceItemIdentifier,
            TOOLBAR_NEW_TAB_IDENTIFIER,
            TOOLBAR_TAB_OVERVIEW_IDENTIFIER,
        ];
#else
        // GNUstep: Use minimal toolbar to avoid hangs
        _toolbar_identifiers = @[
            TOOLBAR_LOCATION_IDENTIFIER,
        ];
#endif
    }

    return _toolbar_identifiers;
}

#pragma mark - NSWindowController

- (IBAction)showWindow:(id)sender
{
#if !LADYBIRD_APPLE
    NSLog(@"showWindow: starting");
    fflush(stderr);
#endif
    self.window = self.parent
        ? [[Tab alloc] initAsChild:self.parent pageIndex:m_page_index]
        : [[Tab alloc] init];
#if !LADYBIRD_APPLE
    NSLog(@"showWindow: Tab created, retaining immediately");
    fflush(stderr);
    // GNUstep: Immediately add to ApplicationDelegate's managed_windows to prevent ARC deallocation
    auto* appDelegate = (ApplicationDelegate*)[NSApp delegate];
    [[appDelegate valueForKey:@"managed_windows"] addObject:self.window];
#endif

    [self.window setDelegate:self];
#if !LADYBIRD_APPLE
    NSLog(@"showWindow: window delegate set");
    fflush(stderr);
#endif

#if LADYBIRD_APPLE
    [self.window setToolbar:self.toolbar];
    [self.window setToolbarStyle:NSWindowToolbarStyleUnified];
#else
    // GNUstep: NSToolbar causes hangs, use a custom location bar instead
    NSLog(@"showWindow: creating custom location bar for GNUstep");
    fflush(stderr);
    [self setupGNUstepLocationBar];
    NSLog(@"showWindow: custom location bar created");
    fflush(stderr);
#endif

    [self.window makeKeyAndOrderFront:sender];
#if !LADYBIRD_APPLE
    NSLog(@"showWindow: after makeKeyAndOrderFront, window=%p isVisible=%d", self.window, [self.window isVisible]);
    fflush(stderr);
#endif

    [self focusLocationToolbarItem];
#if !LADYBIRD_APPLE
    NSLog(@"showWindow: after focusLocationToolbarItem, window isVisible=%d", [self.window isVisible]);
    fflush(stderr);
#endif

    auto* delegate = (ApplicationDelegate*)[NSApp delegate];
    [delegate setActiveTab:[self tab]];
}

#pragma mark - NSWindowDelegate

- (void)windowDidBecomeMain:(NSNotification*)notification
{
    auto* delegate = (ApplicationDelegate*)[NSApp delegate];
    [delegate setActiveTab:[self tab]];
}

- (void)windowWillClose:(NSNotification*)notification
{
#if !LADYBIRD_APPLE
    NSLog(@"windowWillClose: called");
    fflush(stderr);
#endif
    auto* delegate = (ApplicationDelegate*)[NSApp delegate];
    [delegate removeTab:self];
}

- (void)windowDidMove:(NSNotification*)notification
{
    auto position = Ladybird::ns_point_to_gfx_point([[self tab] frame].origin);
    [[[self tab] web_view] setWindowPosition:position];
}

- (void)windowDidResize:(NSNotification*)notification
{
#if LADYBIRD_APPLE
    if (self.location_toolbar_item_width != nil) {
        self.location_toolbar_item_width.active = NO;
    }

    auto width = [self window].frame.size.width * 0.6;
    self.location_toolbar_item_width = [[[self.location_toolbar_item view] widthAnchor] constraintEqualToConstant:width];
    self.location_toolbar_item_width.active = YES;
#endif

    [[[self tab] web_view] handleResize];
}

- (void)windowDidChangeBackingProperties:(NSNotification*)notification
{
    [[[self tab] web_view] handleDevicePixelRatioChange];
}

- (void)windowDidChangeScreen:(NSNotification*)notification
{
    [[[self tab] web_view] handleDisplayRefreshRateChange];
}

#pragma mark - NSToolbarDelegate

- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
        itemForItemIdentifier:(NSString*)identifier
    willBeInsertedIntoToolbar:(BOOL)flag
{
#if !LADYBIRD_APPLE
    NSLog(@"toolbar:itemForItemIdentifier: %@", identifier);
    fflush(stderr);
#endif
    if ([identifier isEqual:TOOLBAR_NAVIGATE_BACK_IDENTIFIER]) {
#if !LADYBIRD_APPLE
        NSLog(@"  returning navigate_back_toolbar_item");
        fflush(stderr);
#endif
        return self.navigate_back_toolbar_item;
    }
    if ([identifier isEqual:TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER]) {
#if !LADYBIRD_APPLE
        NSLog(@"  returning navigate_forward_toolbar_item");
        fflush(stderr);
#endif
        return self.navigate_forward_toolbar_item;
    }
    if ([identifier isEqual:TOOLBAR_RELOAD_IDENTIFIER]) {
#if !LADYBIRD_APPLE
        NSLog(@"  returning reload_toolbar_item");
        fflush(stderr);
#endif
        return self.reload_toolbar_item;
    }
    if ([identifier isEqual:TOOLBAR_LOCATION_IDENTIFIER]) {
#if !LADYBIRD_APPLE
        NSLog(@"  returning location_toolbar_item");
        fflush(stderr);
#endif
        return self.location_toolbar_item;
    }
    if ([identifier isEqual:TOOLBAR_ZOOM_IDENTIFIER]) {
#if !LADYBIRD_APPLE
        NSLog(@"  returning zoom_toolbar_item");
        fflush(stderr);
#endif
        return self.zoom_toolbar_item;
    }
    if ([identifier isEqual:TOOLBAR_NEW_TAB_IDENTIFIER]) {
#if !LADYBIRD_APPLE
        NSLog(@"  returning new_tab_toolbar_item");
        fflush(stderr);
#endif
        return self.new_tab_toolbar_item;
    }
    if ([identifier isEqual:TOOLBAR_TAB_OVERVIEW_IDENTIFIER]) {
#if !LADYBIRD_APPLE
        NSLog(@"  returning tab_overview_toolbar_item");
        fflush(stderr);
#endif
        return self.tab_overview_toolbar_item;
    }

    return nil;
}

- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return self.toolbar_identifiers;
}

- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return self.toolbar_identifiers;
}

#pragma mark - NSSearchFieldDelegate

- (BOOL)control:(NSControl*)control
               textView:(NSTextView*)text_view
    doCommandBySelector:(SEL)selector
{
#if !LADYBIRD_APPLE
    NSLog(@"doCommandBySelector: %@", NSStringFromSelector(selector));
    fflush(stderr);
#endif

    if (selector == @selector(cancelOperation:)) {
        if ([self.autocomplete close])
            return YES;
    }

    if (selector == @selector(moveDown:)) {
        if ([self.autocomplete selectNextSuggestion])
            return YES;
    }

    if (selector == @selector(moveUp:)) {
        if ([self.autocomplete selectPreviousSuggestion])
            return YES;
    }

    if (selector != @selector(insertNewline:)) {
        return NO;
    }

#if !LADYBIRD_APPLE
    NSLog(@"doCommandBySelector: handling insertNewline, navigating to URL");
    fflush(stderr);
#endif

    auto location = [self.autocomplete selectedSuggestion].value_or_lazy_evaluated([&]() {
#if LADYBIRD_APPLE
        return Ladybird::ns_string_to_string([[text_view textStorage] string]);
#else
        return Ladybird::ns_string_to_string([self.gnustep_location_field stringValue]);
#endif
    });

#if !LADYBIRD_APPLE
    NSLog(@"doCommandBySelector: navigating to: %s", location.to_byte_string().characters());
    fflush(stderr);
#endif

    [self navigateToLocation:move(location)];
    return YES;
}

- (void)controlTextDidEndEditing:(NSNotification*)notification
{
#if LADYBIRD_APPLE
    auto* location_search_field = (LocationSearchField*)[self.location_toolbar_item view];
    auto url_string = Ladybird::ns_string_to_string([location_search_field stringValue]);
#else
    auto url_string = Ladybird::ns_string_to_string([self.gnustep_location_field stringValue]);
#endif
    [self setLocationFieldText:url_string];
}

- (void)controlTextDidChange:(NSNotification*)notification
{
#if LADYBIRD_APPLE
    auto* location_search_field = (LocationSearchField*)[self.location_toolbar_item view];
    auto url_string = Ladybird::ns_string_to_string([location_search_field stringValue]);
#else
    auto url_string = Ladybird::ns_string_to_string([self.gnustep_location_field stringValue]);
#endif
    m_autocomplete->query_autocomplete_engine(move(url_string));
}

#pragma mark - AutocompleteObserver

- (void)onSelectedSuggestion:(String)suggestion
{
    [self navigateToLocation:move(suggestion)];
}

@end
