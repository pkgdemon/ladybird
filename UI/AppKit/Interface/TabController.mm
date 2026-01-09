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

#if LADYBIRD_APPLE
@interface LocationSearchField : NSSearchField
#else
// GNUstep: Use NSTextField instead of NSSearchField to avoid Eau theme crash
// The Eau theme's NSSearchFieldCell+Eau.m has infinite recursion bug
@interface LocationSearchField : NSTextField
#endif

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
    [self.window makeFirstResponder:self.location_toolbar_item.view];
}

#pragma mark - Private methods

- (Tab*)tab
{
    return (Tab*)[self window];
}


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
        _navigate_back_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NAVIGATE_BACK_IDENTIFIER];
#if LADYBIRD_APPLE
        auto* button = Ladybird::create_application_button([[[self tab] web_view] view].navigate_back_action());
        [_navigate_back_toolbar_item setView:button];
#else
        // GNUstep: Use NSToolbarItem's native image support instead of custom view
        [_navigate_back_toolbar_item setImage:[NSImage imageNamed:@"common_ArrowLeft"]];
        [_navigate_back_toolbar_item setLabel:@"Back"];
        [_navigate_back_toolbar_item setTarget:self];
        [_navigate_back_toolbar_item setAction:@selector(navigateBack:)];
#endif
    }

    return _navigate_back_toolbar_item;
}

- (NSToolbarItem*)navigate_forward_toolbar_item
{
    if (!_navigate_forward_toolbar_item) {
        _navigate_forward_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER];
#if LADYBIRD_APPLE
        auto* button = Ladybird::create_application_button([[[self tab] web_view] view].navigate_forward_action());
        [_navigate_forward_toolbar_item setView:button];
#else
        // GNUstep: Use NSToolbarItem's native image support instead of custom view
        [_navigate_forward_toolbar_item setImage:[NSImage imageNamed:@"common_ArrowRight"]];
        [_navigate_forward_toolbar_item setLabel:@"Forward"];
        [_navigate_forward_toolbar_item setTarget:self];
        [_navigate_forward_toolbar_item setAction:@selector(navigateForward:)];
#endif
    }

    return _navigate_forward_toolbar_item;
}

- (NSToolbarItem*)reload_toolbar_item
{
    if (!_reload_toolbar_item) {
        _reload_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_RELOAD_IDENTIFIER];
#if LADYBIRD_APPLE
        auto* button = Ladybird::create_application_button(WebView::Application::the().reload_action());
        [_reload_toolbar_item setView:button];
#else
        // GNUstep: Use text button to avoid Eau theme NSButtonCell infinite recursion
        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
        [button setTitle:@"\u21BB"];  // ↻ Unicode clockwise arrow
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(reload:)];
        [_reload_toolbar_item setView:button];
        [_reload_toolbar_item setMinSize:NSMakeSize(24.0, 24.0)];
        [_reload_toolbar_item setMaxSize:NSMakeSize(24.0, 24.0)];
#endif
    }

    return _reload_toolbar_item;
}

- (NSToolbarItem*)location_toolbar_item
{
    if (!_location_toolbar_item) {
#if LADYBIRD_APPLE
        auto* location_search_field = [[LocationSearchField alloc] init];
#else
        // GNUstep: Use initWithFrame: with smaller width to leave room for other toolbar items
        auto* location_search_field = [[LocationSearchField alloc] initWithFrame:NSMakeRect(0, 0, 300, 22)];
#endif
        [location_search_field setPlaceholderString:@"Enter web address"];
        [location_search_field setTextColor:[NSColor textColor]];
        [location_search_field setDelegate:self];

        if (@available(macOS 26, *)) {
            [location_search_field setBordered:YES];
        }

        _location_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_LOCATION_IDENTIFIER];
        [_location_toolbar_item setView:location_search_field];
#if !LADYBIRD_APPLE
        // GNUstep: Set min/max size for toolbar item with custom view (required by GNUstep)
        [_location_toolbar_item setMinSize:NSMakeSize(100.0, 22.0)];
        [_location_toolbar_item setMaxSize:NSMakeSize(600.0, 22.0)];
#endif
    }

    return _location_toolbar_item;
}

- (NSToolbarItem*)zoom_toolbar_item
{
    if (!_zoom_toolbar_item) {
        _zoom_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_ZOOM_IDENTIFIER];
#if LADYBIRD_APPLE
        auto* button = Ladybird::create_application_button([[[self tab] web_view] view].reset_zoom_action());
        [_zoom_toolbar_item setView:button];
#else
        // GNUstep: Use label-based toolbar item
        [_zoom_toolbar_item setLabel:@"100%"];
        [_zoom_toolbar_item setTarget:self];
        [_zoom_toolbar_item setAction:@selector(resetZoom:)];
#endif
    }

    return _zoom_toolbar_item;
}

- (NSToolbarItem*)new_tab_toolbar_item
{
    if (!_new_tab_toolbar_item) {
        _new_tab_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_NEW_TAB_IDENTIFIER];
#if LADYBIRD_APPLE
        auto* button = [self create_button:NSImageNameAddTemplate
                               with_action:@selector(createNewTab:)
                              with_tooltip:@"New tab"];
        [_new_tab_toolbar_item setView:button];
#else
        // GNUstep: Use text button to avoid Eau theme NSButtonCell infinite recursion
        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
        [button setTitle:@"+"];
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(createNewTab:)];
        [_new_tab_toolbar_item setView:button];
        [_new_tab_toolbar_item setMinSize:NSMakeSize(24.0, 24.0)];
        [_new_tab_toolbar_item setMaxSize:NSMakeSize(24.0, 24.0)];
#endif
    }

    return _new_tab_toolbar_item;
}

- (NSToolbarItem*)tab_overview_toolbar_item
{
    if (!_tab_overview_toolbar_item) {
        _tab_overview_toolbar_item = [[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_TAB_OVERVIEW_IDENTIFIER];
#if LADYBIRD_APPLE
        auto* button = [self create_button:NSImageNameIconViewTemplate
                               with_action:@selector(showTabOverview:)
                              with_tooltip:@"Show all tabs"];
        [_tab_overview_toolbar_item setView:button];
#else
        // GNUstep: Use text button to avoid Eau theme NSButtonCell infinite recursion
        auto* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 36, 24)];
        [button setTitle:@"\u2630"];  // ☰ Unicode hamburger menu / trigram for heaven
        [button setBordered:YES];
        [button setTarget:self];
        [button setAction:@selector(showTabOverview:)];
        [_tab_overview_toolbar_item setView:button];
        [_tab_overview_toolbar_item setMinSize:NSMakeSize(36.0, 24.0)];
        [_tab_overview_toolbar_item setMaxSize:NSMakeSize(36.0, 24.0)];
#endif
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
        // GNUstep: Layout without flexible spaces
        // Left: Back, Forward, Reload | Location | Right: New Tab, Tabs
        _toolbar_identifiers = @[
            TOOLBAR_NAVIGATE_BACK_IDENTIFIER,
            TOOLBAR_NAVIGATE_FORWARD_IDENTIFIER,
            TOOLBAR_RELOAD_IDENTIFIER,
            TOOLBAR_LOCATION_IDENTIFIER,
            TOOLBAR_NEW_TAB_IDENTIFIER,
            TOOLBAR_TAB_OVERVIEW_IDENTIFIER,
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
    [self.window makeKeyAndOrderFront:sender];
#else
    // GNUstep: Follow FlexiSheet's pattern for toolbar setup
    // 1. Set delegate (toolbar is already visible by default in GNUstep)
    // 2. Attach toolbar to window
    // 3. Then make window visible
    [self.toolbar setDelegate:self];
    [self.window setToolbar:self.toolbar];

    NSLog(@"showWindow: toolbar attached, isVisible=%d", [self.toolbar isVisible]);
    fflush(stderr);

    // Make the window visible
    [self.window makeKeyAndOrderFront:sender];

    NSLog(@"showWindow: window visible, content frame=%@",
          NSStringFromRect([[self.window contentView] frame]));
    fflush(stderr);
#endif

    [self focusLocationToolbarItem];

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
    // Auto Layout constraints - not supported on GNUstep
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

#if !LADYBIRD_APPLE
#pragma mark - GNUstep Navigation Actions

- (void)navigateBack:(id)sender
{
    [[[self tab] web_view] view].navigate_back_action().activate();
}

- (void)navigateForward:(id)sender
{
    [[[self tab] web_view] view].navigate_forward_action().activate();
}

- (void)reload:(id)sender
{
    WebView::Application::the().reload_action().activate();
}

- (void)resetZoom:(id)sender
{
    [[[self tab] web_view] view].reset_zoom_action().activate();
}
#endif

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
        auto const& url = [[[self tab] web_view] view].url();
        [self setLocationFieldText:url.serialize()];
        [self.window makeFirstResponder:nil];
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
        auto* location_search_field = (LocationSearchField*)[self.location_toolbar_item view];
        return Ladybird::ns_string_to_string([location_search_field stringValue]);
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
    auto* location_search_field = (LocationSearchField*)[self.location_toolbar_item view];
    auto url_string = Ladybird::ns_string_to_string([location_search_field stringValue]);
    [self setLocationFieldText:url_string];
}

- (void)controlTextDidChange:(NSNotification*)notification
{
    auto* location_search_field = (LocationSearchField*)[self.location_toolbar_item view];
    auto url_string = Ladybird::ns_string_to_string([location_search_field stringValue]);
    m_autocomplete->query_autocomplete_engine(move(url_string));
}

#pragma mark - AutocompleteObserver

- (void)onSelectedSuggestion:(String)suggestion
{
    [self navigateToLocation:move(suggestion)];
}

@end
