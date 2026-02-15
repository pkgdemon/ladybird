/*
 * Copyright (c) 2023-2025, Tim Flynn <trflynn89@ladybird.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/Optional.h>
#include <Interface/LadybirdWebViewBridge.h>
#include <LibURL/URL.h>
#include <LibWeb/HTML/SelectedFile.h>

#import <Application/ApplicationDelegate.h>
#import <Interface/Event.h>
#import <Interface/LadybirdWebView.h>
#import <Interface/Menu.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

// Calls to [NSCursor hide] and [NSCursor unhide] must be balanced.
struct HideCursor {
    HideCursor()
    {
        [NSCursor hide];
    }

    ~HideCursor()
    {
        [NSCursor unhide];
    }
};

@interface LadybirdWebView ()
{
    OwnPtr<Ladybird::WebViewBridge> m_web_view_bridge;

    Optional<HideCursor> m_hidden_cursor;

    NSEventModifierFlags m_modifier_flags;
}

@property (nonatomic, weak) id<LadybirdWebViewObserver> observer;
@property (nonatomic, strong) NSMenu* page_context_menu;
@property (nonatomic, strong) NSMenu* link_context_menu;
@property (nonatomic, strong) NSMenu* image_context_menu;
@property (nonatomic, strong) NSMenu* media_context_menu;
@property (nonatomic, strong) NSMenu* select_dropdown;
@property (nonatomic, strong) NSTextField* status_label;
@property (nonatomic, strong) NSAlert* dialog;

@property (nonatomic, strong) NSEvent* event_being_redispatched;
@property (nonatomic, strong) NSEvent* current_key_down_event;

@end

@implementation LadybirdWebView

@synthesize status_label = _status_label;

- (instancetype)init:(id<LadybirdWebViewObserver>)observer
{
    if (self = [self initWebView:observer]) {
        m_web_view_bridge->initialize_client();
    }

    return self;
}

- (instancetype)initAsChild:(id<LadybirdWebViewObserver>)observer
                     parent:(LadybirdWebView*)parent
                  pageIndex:(u64)page_index
{
    if (self = [self initWebView:observer]) {
        m_web_view_bridge->initialize_client_as_child(*parent->m_web_view_bridge, page_index);
    }

    return self;
}

- (instancetype)initWebView:(id<LadybirdWebViewObserver>)observer
{
    if (self = [super init]) {
        self.observer = observer;

        auto* screens = [NSScreen screens];

        Vector<Web::DevicePixelRect> screen_rects;
        screen_rects.ensure_capacity([screens count]);

        for (id screen in screens) {
            auto screen_rect = Ladybird::ns_rect_to_gfx_rect([screen frame]).to_type<Web::DevicePixels>();
            screen_rects.unchecked_append(screen_rect);
        }

        double device_pixel_ratio = 1.0;
        u64 maximum_frames_per_second = 60;

        m_web_view_bridge = MUST(Ladybird::WebViewBridge::create(move(screen_rects), device_pixel_ratio, maximum_frames_per_second));
        [self setWebViewCallbacks];

        self.page_context_menu = Ladybird::create_context_menu(self, [self view].page_context_menu());
        self.link_context_menu = Ladybird::create_context_menu(self, [self view].link_context_menu());
        self.image_context_menu = Ladybird::create_context_menu(self, [self view].image_context_menu());
        self.media_context_menu = Ladybird::create_context_menu(self, [self view].media_context_menu());

        [self registerForDraggedTypes:@[ NSFilenamesPboardType ]];

        m_modifier_flags = 0;
    }

    return self;
}

#pragma mark - Public methods

- (void)loadURL:(URL::URL const&)url
{
    m_web_view_bridge->load(url);
}

- (WebView::ViewImplementation&)view
{
    return *m_web_view_bridge;
}

- (String const&)handle
{
    return m_web_view_bridge->handle();
}

- (void)setWindowPosition:(Gfx::IntPoint)position
{
    m_web_view_bridge->set_window_position(Ladybird::compute_origin_relative_to_window([self window], position));
}

- (void)setWindowSize:(Gfx::IntSize)size
{
    m_web_view_bridge->set_window_size(size);
}

- (void)handleResize
{
    auto size = Ladybird::ns_size_to_gfx_size([[self window] frame].size);
    [self setWindowSize:size];

    [self updateViewportRect];
    [self updateStatusLabelPosition];
}

- (void)handleDevicePixelRatioChange
{
    m_web_view_bridge->set_device_pixel_ratio(1.0);
    [self updateViewportRect];
    [self updateStatusLabelPosition];
}

- (void)handleDisplayRefreshRateChange
{
    m_web_view_bridge->set_maximum_frames_per_second(60);
}

- (void)handleVisibility:(BOOL)is_visible
{
    m_web_view_bridge->set_system_visibility_state(is_visible
            ? Web::HTML::VisibilityState::Visible
            : Web::HTML::VisibilityState::Hidden);
}

- (void)findInPage:(NSString*)query
    caseSensitivity:(CaseSensitivity)case_sensitivity
{
    m_web_view_bridge->find_in_page(Ladybird::ns_string_to_string(query), case_sensitivity);
}

- (void)findInPageNextMatch
{
    m_web_view_bridge->find_in_page_next_match();
}

- (void)findInPagePreviousMatch
{
    m_web_view_bridge->find_in_page_previous_match();
}

#pragma mark - Private methods

- (void)updateViewportRect
{
    auto viewport_rect = Ladybird::ns_rect_to_gfx_rect([self frame]);
    m_web_view_bridge->set_viewport_rect(viewport_rect);
}

- (void)updateStatusLabelPosition
{
    static constexpr CGFloat LABEL_INSET = 10;

    if (_status_label == nil || [[self status_label] isHidden]) {
        return;
    }

    auto visible_rect = [self visibleRect];
    auto status_label_rect = [self.status_label frame];

    auto position = NSMakePoint(LABEL_INSET, visible_rect.origin.y + visible_rect.size.height - status_label_rect.size.height - LABEL_INSET);
    [self.status_label setFrameOrigin:position];
}

- (void)setWebViewCallbacks
{
    __weak LadybirdWebView* weak_self = self;

    m_web_view_bridge->on_ready_to_paint = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self setNeedsDisplay:YES];
    };

    m_web_view_bridge->on_new_web_view = [weak_self](auto activate_tab, auto, auto page_index) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return String {};
        }

        if (page_index.has_value()) {
            return [self.observer onCreateChildTab:{}
                                       activateTab:activate_tab
                                         pageIndex:*page_index];
        }

        return [self.observer onCreateNewTab:{} activateTab:activate_tab];
    };

    m_web_view_bridge->on_activate_tab = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [[self window] orderFront:nil];
    };

    m_web_view_bridge->on_close = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [[self window] close];
    };

    m_web_view_bridge->on_load_start = [weak_self](auto const& url, bool is_redirect) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.observer onLoadStart:url isRedirect:is_redirect];

        if (_status_label != nil) {
            [self.status_label setHidden:YES];
        }
    };

    m_web_view_bridge->on_load_finish = [weak_self](auto const& url) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.observer onLoadFinish:url];
    };

    m_web_view_bridge->on_url_change = [weak_self](auto const& url) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.observer onURLChange:url];
    };

    m_web_view_bridge->on_title_change = [weak_self](auto const& title) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.observer onTitleChange:title];
    };

    m_web_view_bridge->on_favicon_change = [weak_self](auto const& bitmap) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.observer onFaviconChange:bitmap];
    };

    m_web_view_bridge->on_finish_handling_key_event = [weak_self](auto const& key_event) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        auto* event = Ladybird::key_event_to_ns_event(key_event);

        self.event_being_redispatched = event;
        [NSApp sendEvent:event];
        self.event_being_redispatched = nil;
    };

    m_web_view_bridge->on_finish_handling_drag_event = [weak_self](auto const& event) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }

        if (event.type != Web::DragEvent::Type::Drop) {
            return;
        }

        if (auto urls = Ladybird::drag_event_url_list(event); !urls.is_empty()) {
            [self loadURL:urls[0]];

            for (size_t i = 1; i < urls.size(); ++i) {
                [self.observer onCreateNewTab:urls[i] activateTab:Web::HTML::ActivateTab::No];
            }
        }
    };

    m_web_view_bridge->on_cursor_change = [weak_self](auto cursor) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        cursor.visit(
            [](Gfx::ImageCursor const& image_cursor) {
                auto* cursor_image = Ladybird::gfx_bitmap_to_ns_image(*image_cursor.bitmap.bitmap());
                auto hotspot = Ladybird::gfx_point_to_ns_point(image_cursor.hotspot);

                [[[NSCursor alloc] initWithImage:cursor_image hotSpot:hotspot] set];
            },
            [&self](Gfx::StandardCursor standard_cursor) {
                if (standard_cursor == Gfx::StandardCursor::Hidden) {
                    if (!m_hidden_cursor.has_value()) {
                        m_hidden_cursor.emplace();
                    }

                    return;
                }

                m_hidden_cursor.clear();

                switch (standard_cursor) {
                case Gfx::StandardCursor::Arrow:
                    [[NSCursor arrowCursor] set];
                    break;
                case Gfx::StandardCursor::Crosshair:
                    [[NSCursor crosshairCursor] set];
                    break;
                case Gfx::StandardCursor::IBeam:
                    [[NSCursor IBeamCursor] set];
                    break;
                case Gfx::StandardCursor::ResizeHorizontal:
                    [[NSCursor resizeLeftRightCursor] set];
                    break;
                case Gfx::StandardCursor::ResizeVertical:
                    [[NSCursor resizeUpDownCursor] set];
                    break;
                case Gfx::StandardCursor::ResizeDiagonalTLBR:
                case Gfx::StandardCursor::ResizeDiagonalBLTR:
                    [[NSCursor arrowCursor] set];
                    break;
                case Gfx::StandardCursor::ResizeColumn:
                    [[NSCursor resizeLeftRightCursor] set];
                    break;
                case Gfx::StandardCursor::ResizeRow:
                    [[NSCursor resizeUpDownCursor] set];
                    break;
                case Gfx::StandardCursor::Hand:
                    [[NSCursor pointingHandCursor] set];
                    break;
                case Gfx::StandardCursor::Help:
                    [[NSCursor arrowCursor] set];
                    break;
                case Gfx::StandardCursor::OpenHand:
                    [[NSCursor openHandCursor] set];
                    break;
                case Gfx::StandardCursor::Drag:
                    [[NSCursor closedHandCursor] set];
                    break;
                case Gfx::StandardCursor::DragCopy:
                    [[NSCursor dragCopyCursor] set];
                    break;
                case Gfx::StandardCursor::Move:
                    [[NSCursor closedHandCursor] set];
                    break;
                case Gfx::StandardCursor::Wait:
                case Gfx::StandardCursor::Disallowed:
                case Gfx::StandardCursor::Eyedropper:
                case Gfx::StandardCursor::Zoom:
                    [[NSCursor arrowCursor] set];
                    break;
                default:
                    break;
                }
            });
    };

    m_web_view_bridge->on_zoom_level_changed = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self updateViewportRect];
    };

    m_web_view_bridge->on_request_tooltip_override = [weak_self](auto, auto const& tooltip) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        self.toolTip = Ladybird::string_to_ns_string(tooltip);
    };

    m_web_view_bridge->on_stop_tooltip_override = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        self.toolTip = nil;
    };

    m_web_view_bridge->on_enter_tooltip_area = [weak_self](auto const& tooltip) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        self.toolTip = Ladybird::string_to_ns_string(tooltip);
    };

    m_web_view_bridge->on_leave_tooltip_area = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        self.toolTip = nil;
    };

    m_web_view_bridge->on_link_hover = [weak_self](auto const& url) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        auto* url_string = Ladybird::string_to_ns_string(url.serialize());
        [self.status_label setStringValue:url_string];
        [self.status_label sizeToFit];
        [self.status_label setHidden:NO];

        [self updateStatusLabelPosition];
    };

    m_web_view_bridge->on_link_unhover = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.status_label setHidden:YES];
    };

    m_web_view_bridge->on_request_alert = [weak_self](auto const& message) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        auto* ns_message = Ladybird::string_to_ns_string(message);

        self.dialog = [[NSAlert alloc] init];
        [self.dialog setMessageText:ns_message];

        [self.dialog beginSheetModalForWindow:[self window]
                            completionHandler:^(NSModalResponse) {
                                m_web_view_bridge->alert_closed();
                                self.dialog = nil;
                            }];
    };

    m_web_view_bridge->on_request_confirm = [weak_self](auto const& message) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        auto* ns_message = Ladybird::string_to_ns_string(message);

        self.dialog = [[NSAlert alloc] init];
        [[self.dialog addButtonWithTitle:@"OK"] setTag:NSModalResponseOK];
        [[self.dialog addButtonWithTitle:@"Cancel"] setTag:NSModalResponseCancel];
        [self.dialog setMessageText:ns_message];

        [self.dialog beginSheetModalForWindow:[self window]
                            completionHandler:^(NSModalResponse response) {
                                m_web_view_bridge->confirm_closed(response == NSModalResponseOK);
                                self.dialog = nil;
                            }];
    };

    m_web_view_bridge->on_request_prompt = [weak_self](auto const& message, auto const& default_) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        auto* ns_message = Ladybird::string_to_ns_string(message);
        auto* ns_default = Ladybird::string_to_ns_string(default_);

        __block auto* input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        [input setStringValue:ns_default];

        self.dialog = [[NSAlert alloc] init];
        [[self.dialog addButtonWithTitle:@"OK"] setTag:NSModalResponseOK];
        [[self.dialog addButtonWithTitle:@"Cancel"] setTag:NSModalResponseCancel];
        [self.dialog setMessageText:ns_message];

        NSView* alert_content = [[self.dialog window] contentView];
        NSRect content_bounds = [alert_content bounds];
        [input setFrame:NSMakeRect(20, 10, content_bounds.size.width - 40, 24)];
        [alert_content addSubview:input];

        [self.dialog beginSheetModalForWindow:[self window]
                            completionHandler:^(NSModalResponse response) {
                                Optional<String> text;

                                if (response == NSModalResponseOK) {
                                    text = Ladybird::ns_string_to_string([input stringValue]);
                                }

                                m_web_view_bridge->prompt_closed(move(text));
                                self.dialog = nil;
                            }];
    };

    m_web_view_bridge->on_request_set_prompt_text = [weak_self](String const& message) {
        LadybirdWebView* self = weak_self;
        if (self == nil || self.dialog == nil) {
            return;
        }

        NSView* alert_content = [[self.dialog window] contentView];
        for (NSView* subview in [alert_content subviews]) {
            if ([subview isKindOfClass:[NSTextField class]] && [(NSTextField*)subview isEditable]) {
                auto* ns_message = Ladybird::string_to_ns_string(message);
                [(NSTextField*)subview setStringValue:ns_message];
                break;
            }
        }
    };

    m_web_view_bridge->on_request_accept_dialog = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil || self.dialog == nil) {
            return;
        }

        [NSApp endSheet:[[self dialog] window]
             returnCode:NSModalResponseOK];
    };

    m_web_view_bridge->on_request_dismiss_dialog = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil || self.dialog == nil) {
            return;
        }

        [NSApp endSheet:[[self dialog] window]
             returnCode:NSModalResponseCancel];
    };

    m_web_view_bridge->on_request_color_picker = [weak_self](Color current_color) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        auto* panel = [NSColorPanel sharedColorPanel];
        [panel setColor:Ladybird::gfx_color_to_ns_color(current_color)];
        [panel setShowsAlpha:NO];
        [panel setTarget:self];
        [panel setAction:@selector(colorPickerUpdate:)];

        NSNotificationCenter* notification_center = [NSNotificationCenter defaultCenter];
        [notification_center addObserver:self
                                selector:@selector(colorPickerClosed:)
                                    name:NSWindowWillCloseNotification
                                  object:panel];

        [panel makeKeyAndOrderFront:nil];
    };

    m_web_view_bridge->on_request_file_picker = [weak_self](auto const& accepted_file_types, auto allow_multiple_files) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        auto* panel = [NSOpenPanel openPanel];
        [panel setCanChooseFiles:YES];
        [panel setCanChooseDirectories:NO];

        if (allow_multiple_files == Web::HTML::AllowMultipleFiles::Yes) {
            [panel setAllowsMultipleSelection:YES];
            [panel setMessage:@"Select files"];
        } else {
            [panel setAllowsMultipleSelection:NO];
            [panel setMessage:@"Select file"];
        }

        NSMutableArray<NSString*>* allowed_extensions = [NSMutableArray array];

        for (auto const& filter : accepted_file_types.filters) {
            filter.visit(
                [&](Web::HTML::FileFilter::FileType type) {
                    switch (type) {
                    case Web::HTML::FileFilter::FileType::Audio:
                        [allowed_extensions addObjectsFromArray:@[ @"mp3", @"wav", @"ogg", @"flac", @"aac", @"m4a" ]];
                        break;
                    case Web::HTML::FileFilter::FileType::Image:
                        [allowed_extensions addObjectsFromArray:@[ @"png", @"jpg", @"jpeg", @"gif", @"bmp", @"webp", @"svg" ]];
                        break;
                    case Web::HTML::FileFilter::FileType::Video:
                        [allowed_extensions addObjectsFromArray:@[ @"mp4", @"webm", @"avi", @"mov", @"mkv" ]];
                        break;
                    }
                },
                [&](Web::HTML::FileFilter::MimeType const&) {
                },
                [&](Web::HTML::FileFilter::Extension const& filter) {
                    auto* ns_extension = Ladybird::string_to_ns_string(filter.value);
                    [allowed_extensions addObject:ns_extension];
                });
        }

        if ([allowed_extensions count] > 0) {
            [panel setAllowedFileTypes:allowed_extensions];
        }

        [panel beginSheetModalForWindow:[self window]
                      completionHandler:^(NSInteger result) {
                          Vector<Web::HTML::SelectedFile> selected_files;

                          auto create_selected_file = [&](NSString* ns_file_path) {
                              auto file_path = Ladybird::ns_string_to_byte_string(ns_file_path);

                              if (auto file = Web::HTML::SelectedFile::from_file_path(file_path); file.is_error())
                                  warnln("Unable to open file {}: {}", file_path, file.error());
                              else
                                  selected_files.append(file.release_value());
                          };

                          if (result == NSModalResponseOK) {
                              for (NSURL* url : [panel URLs]) {
                                  create_selected_file([url path]);
                              }
                          }

                          m_web_view_bridge->file_picker_closed(move(selected_files));
                      }];
    };

    self.select_dropdown = [[NSMenu alloc] initWithTitle:@"Select Dropdown"];
    [self.select_dropdown setDelegate:self];

    m_web_view_bridge->on_request_select_dropdown = [weak_self](Gfx::IntPoint content_position, i32 minimum_width, Vector<Web::HTML::SelectItem> items) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.select_dropdown removeAllItems];

        auto add_menu_item = [self](Web::HTML::SelectItemOption const& item_option, bool in_option_group) {
            NSMenuItem* menuItem = [[NSMenuItem alloc]
                initWithTitle:Ladybird::string_to_ns_string(in_option_group ? MUST(String::formatted("    {}", item_option.label)) : item_option.label)
                       action:item_option.disabled ? nil : @selector(selectDropdownAction:)
                keyEquivalent:@""];
            menuItem.representedObject = [NSNumber numberWithUnsignedInt:item_option.id];
            menuItem.state = item_option.selected ? NSOnState : NSOffState;
            [self.select_dropdown addItem:menuItem];
        };

        for (auto const& item : items) {
            if (item.has<Web::HTML::SelectItemOptionGroup>()) {
                auto const& item_option_group = item.get<Web::HTML::SelectItemOptionGroup>();
                NSMenuItem* subtitle = [[NSMenuItem alloc]
                    initWithTitle:Ladybird::string_to_ns_string(item_option_group.label)
                           action:nil
                    keyEquivalent:@""];
                [self.select_dropdown addItem:subtitle];

                for (auto const& item_option : item_option_group.items)
                    add_menu_item(item_option, true);
            }

            if (item.has<Web::HTML::SelectItemOption>())
                add_menu_item(item.get<Web::HTML::SelectItemOption>(), false);

            if (item.has<Web::HTML::SelectItemSeparator>())
                [self.select_dropdown addItem:[NSMenuItem separatorItem]];
        }

        auto* event = Ladybird::create_context_menu_mouse_event(self, content_position);
        [NSMenu popUpContextMenu:self.select_dropdown withEvent:event forView:self];
    };

    m_web_view_bridge->on_restore_window = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [[self window] deminiaturize:nil];
        [[self window] orderFront:nil];
    };

    m_web_view_bridge->on_reposition_window = [weak_self](auto position) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }

        position = Ladybird::compute_origin_relative_to_window([self window], position);
        [[self window] setFrameOrigin:Ladybird::gfx_point_to_ns_point(position)];

        m_web_view_bridge->did_update_window_rect();
    };

    m_web_view_bridge->on_resize_window = [weak_self](auto size) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }

        auto frame = [[self window] frame];
        frame.size = Ladybird::gfx_size_to_ns_size(size);
        [[self window] setFrame:frame display:YES];

        m_web_view_bridge->did_update_window_rect();
    };

    m_web_view_bridge->on_maximize_window = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }

        auto frame = [[[self window] screen] frame];
        [[self window] setFrame:frame display:YES];

        m_web_view_bridge->did_update_window_rect();
    };

    m_web_view_bridge->on_minimize_window = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }

        [[self window] miniaturize:nil];
    };

    m_web_view_bridge->on_fullscreen_window = [weak_self]() {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }

        auto frame = [[[self window] screen] frame];
        [[self window] setFrame:frame display:YES];

        m_web_view_bridge->did_update_window_rect();
    };

    m_web_view_bridge->on_theme_color_change = [weak_self](auto color) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self setNeedsDisplay:YES];
    };

    m_web_view_bridge->on_find_in_page = [weak_self](auto current_match_index, auto const& total_match_count) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.observer onFindInPageResult:current_match_index + 1
                          totalMatchCount:total_match_count];
    };

    m_web_view_bridge->on_audio_play_state_changed = [weak_self](auto play_state) {
        LadybirdWebView* self = weak_self;
        if (self == nil) {
            return;
        }
        [self.observer onAudioPlayStateChange:play_state];
    };
}

- (void)handleCurrentKeyDownEvent
{
    if (!self.current_key_down_event)
        return;

    auto key_event = Ladybird::ns_event_to_key_event(Web::KeyEvent::Type::KeyDown, self.current_key_down_event);
    m_web_view_bridge->enqueue_input_event(move(key_event));

    self.current_key_down_event = nil;
}

- (void)selectDropdownAction:(NSMenuItem*)menuItem
{
    NSNumber* data = [menuItem representedObject];
    m_web_view_bridge->select_dropdown_closed([data unsignedIntValue]);
}

- (void)menuWillOpen:(NSMenu*)menu
{
}

- (void)menu:(NSMenu*)menu willHighlightItem:(NSMenuItem*)item
{
}

- (NSRect)confinementRectForMenu:(NSMenu*)menu onScreen:(NSScreen*)screen
{
    return NSZeroRect;
}

- (void)menuDidClose:(NSMenu*)menu
{
    id<NSMenuView> menu_rep = [menu menuRepresentation];
    if (menu_rep && [menu_rep highlightedItemIndex] < 0)
        m_web_view_bridge->select_dropdown_closed({});
}

- (void)colorPickerUpdate:(NSColorPanel*)colorPanel
{
    m_web_view_bridge->color_picker_update(Ladybird::ns_color_to_gfx_color(colorPanel.color), Web::HTML::ColorPickerUpdateState::Update);
}

- (void)colorPickerClosed:(NSNotification*)notification
{
    m_web_view_bridge->color_picker_update(Ladybird::ns_color_to_gfx_color([NSColorPanel sharedColorPanel].color), Web::HTML::ColorPickerUpdateState::Closed);
}

#pragma mark - Properties

- (NSTextField*)status_label
{
    if (!_status_label) {
        _status_label = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [_status_label setStringValue:@""];
        [_status_label setEditable:NO];
        [_status_label setSelectable:NO];
        [_status_label setBezeled:NO];
        [_status_label setDrawsBackground:YES];
        [_status_label setBordered:YES];
        [_status_label setHidden:YES];

        [self addSubview:_status_label];
    }

    return _status_label;
}

#pragma mark - NSView

- (void)drawRect:(NSRect)rect
{
    auto paintable = m_web_view_bridge->paintable();
    if (!paintable.has_value()) {
        [super drawRect:rect];
        return;
    }

    auto [bitmap, bitmap_size] = *paintable;
    VERIFY(bitmap.format() == Gfx::BitmapFormat::BGRA8888);

    auto* image_rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:nil
                      pixelsWide:bitmap_size.width()
                      pixelsHigh:bitmap_size.height()
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                    bitmapFormat:(NSBitmapFormat)(NSBitmapFormatAlphaFirst | NSBitmapFormatThirtyTwoBitLittleEndian)
                     bytesPerRow:bitmap.pitch()
                    bitsPerPixel:32];

    // Copy bitmap data
    memcpy([image_rep bitmapData], bitmap.scanline_u8(0), bitmap.size_in_bytes());

    auto* image = [[NSImage alloc] initWithSize:NSMakeSize(bitmap_size.width(), bitmap_size.height())];
    [image addRepresentation:image_rep];

    // Draw the image
    auto inverse_device_pixel_ratio = m_web_view_bridge->inverse_device_pixel_ratio();

    NSRect image_rect = NSMakeRect(
        rect.origin.x,
        rect.origin.y,
        bitmap_size.width() * inverse_device_pixel_ratio,
        bitmap_size.height() * inverse_device_pixel_ratio);

    [image drawInRect:image_rect];

    [super drawRect:rect];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self handleResize];

    auto window = Ladybird::ns_rect_to_gfx_rect([[self window] frame]);
    [self setWindowPosition:window.location()];
    [self setWindowSize:window.size()];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
    [super resizeWithOldSuperviewSize:oldSize];
    [self handleResize];
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)mouseMoved:(NSEvent*)event
{
    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseMove, event, self, Web::UIEvents::MouseButton::None);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)scrollWheel:(NSEvent*)event
{
    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseWheel, event, self, Web::UIEvents::MouseButton::Middle);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)mouseDown:(NSEvent*)event
{
    [[self window] makeFirstResponder:self];

    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseDown, event, self, Web::UIEvents::MouseButton::Primary);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)mouseUp:(NSEvent*)event
{
    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseUp, event, self, Web::UIEvents::MouseButton::Primary);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)mouseDragged:(NSEvent*)event
{
    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseMove, event, self, Web::UIEvents::MouseButton::Primary);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)rightMouseDown:(NSEvent*)event
{
    [[self window] makeFirstResponder:self];

    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseDown, event, self, Web::UIEvents::MouseButton::Secondary);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)rightMouseUp:(NSEvent*)event
{
    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseUp, event, self, Web::UIEvents::MouseButton::Secondary);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)rightMouseDragged:(NSEvent*)event
{
    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseMove, event, self, Web::UIEvents::MouseButton::Secondary);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)otherMouseDown:(NSEvent*)event
{
    if (event.buttonNumber != 2)
        return;

    [[self window] makeFirstResponder:self];

    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseDown, event, self, Web::UIEvents::MouseButton::Middle);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)otherMouseUp:(NSEvent*)event
{
    if (event.buttonNumber != 2)
        return;

    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseUp, event, self, Web::UIEvents::MouseButton::Middle);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (void)otherMouseDragged:(NSEvent*)event
{
    if (event.buttonNumber != 2)
        return;

    auto mouse_event = Ladybird::ns_event_to_mouse_event(Web::MouseEvent::Type::MouseMove, event, self, Web::UIEvents::MouseButton::Middle);
    m_web_view_bridge->enqueue_input_event(move(mouse_event));
}

- (BOOL)performKeyEquivalent:(NSEvent*)event
{
    if ([event window] != [self window]) {
        return NO;
    }
    if ([[self window] firstResponder] != self) {
        return NO;
    }
    if (self.event_being_redispatched == event) {
        return NO;
    }

    [self keyDown:event];
    return YES;
}

- (void)keyDown:(NSEvent*)event
{
    if (self.event_being_redispatched == event) {
        return;
    }

    self.current_key_down_event = event;
    [self interpretKeyEvents:@[ event ]];
}

- (void)keyUp:(NSEvent*)event
{
    if (self.event_being_redispatched == event) {
        return;
    }

    auto key_event = Ladybird::ns_event_to_key_event(Web::KeyEvent::Type::KeyUp, event);
    m_web_view_bridge->enqueue_input_event(move(key_event));
}

- (void)flagsChanged:(NSEvent*)event
{
    if (self.event_being_redispatched == event) {
        return;
    }

    auto enqueue_event_if_needed = [&](auto flag) {
        auto is_flag_set = [&](auto flags) { return (flags & flag) != 0; };
        Web::KeyEvent::Type type;

        if (is_flag_set(event.modifierFlags) && !is_flag_set(m_modifier_flags)) {
            type = Web::KeyEvent::Type::KeyDown;
        } else if (!is_flag_set(event.modifierFlags) && is_flag_set(m_modifier_flags)) {
            type = Web::KeyEvent::Type::KeyUp;
        } else {
            return;
        }

        auto key_event = Ladybird::ns_event_to_key_event(type, event);
        m_web_view_bridge->enqueue_input_event(move(key_event));
    };

    enqueue_event_if_needed(NSEventModifierFlagShift);
    enqueue_event_if_needed(NSEventModifierFlagControl);
    enqueue_event_if_needed(NSEventModifierFlagOption);
    enqueue_event_if_needed(NSEventModifierFlagCommand);

    m_modifier_flags = event.modifierFlags;
}

- (BOOL)canBecomeKeyView
{
    return YES;
}

#pragma mark - NSResponder

- (BOOL)acceptsFirstResponder
{
    return YES;
}

#pragma mark - NSTextInputClient

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange
{
    [self handleCurrentKeyDownEvent];
}

- (void)doCommandBySelector:(SEL)selector
{
    [self handleCurrentKeyDownEvent];
}

- (BOOL)hasMarkedText
{
    return NO;
}

- (NSRange)markedRange
{
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange)selectedRange
{
    return NSMakeRange(NSNotFound, 0);
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange
{
}

- (void)unmarkText
{
}

- (NSArray<NSAttributedStringKey>*)validAttributesForMarkedText
{
    return @[];
}

- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    return nil;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point
{
    return NSNotFound;
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    return NSZeroRect;
}

#pragma mark - NSDraggingDestination

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)event
{
    auto drag_event = Ladybird::ns_event_to_drag_event(Web::DragEvent::Type::DragStart, event, self);
    m_web_view_bridge->enqueue_input_event(move(drag_event));

    return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)event
{
    auto drag_event = Ladybird::ns_event_to_drag_event(Web::DragEvent::Type::DragMove, event, self);
    m_web_view_bridge->enqueue_input_event(move(drag_event));

    return NSDragOperationCopy;
}

- (void)draggingExited:(id<NSDraggingInfo>)event
{
    auto drag_event = Ladybird::ns_event_to_drag_event(Web::DragEvent::Type::DragEnd, event, self);
    m_web_view_bridge->enqueue_input_event(move(drag_event));
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)event
{
    auto drag_event = Ladybird::ns_event_to_drag_event(Web::DragEvent::Type::Drop, event, self);
    m_web_view_bridge->enqueue_input_event(move(drag_event));

    return YES;
}

- (BOOL)wantsPeriodicDraggingUpdates
{
    return NO;
}

@end
