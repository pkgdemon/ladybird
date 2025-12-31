/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/ByteString.h>
#include <LibCore/Resource.h>
#include <LibGfx/Palette.h>
#include <LibGfx/SystemTheme.h>

#import <Platform.h>
#import <Cocoa/Cocoa.h>
#import <Interface/Palette.h>
#import <Utilities/Conversions.h>

namespace Ladybird {

bool is_using_dark_system_theme()
{
#if LADYBIRD_APPLE
    auto* appearance = [NSApp effectiveAppearance];

    auto* matched_appearance = [appearance bestMatchFromAppearancesWithNames:@[
        NSAppearanceNameAqua,
        NSAppearanceNameDarkAqua,
    ]];

    return [matched_appearance isEqualToString:NSAppearanceNameDarkAqua];
#else
    // GNUstep: effectiveAppearance not available, assume light theme
    return false;
#endif
}

Core::AnonymousBuffer create_system_palette()
{
    auto is_dark = is_using_dark_system_theme();

    auto theme_file = is_dark ? "Dark"sv : "Default"sv;
    auto theme_ini = MUST(Core::Resource::load_from_uri(MUST(String::formatted("resource://themes/{}.ini", theme_file))));
    auto theme = Gfx::load_system_theme(theme_ini->filesystem_path().to_byte_string()).release_value_but_fixme_should_propagate_errors();

    auto palette_impl = Gfx::PaletteImpl::create_with_anonymous_buffer(theme);
    auto palette = Gfx::Palette(move(palette_impl));
    palette.set_flag(Gfx::FlagRole::IsDark, is_dark);
#if LADYBIRD_APPLE
    palette.set_color(Gfx::ColorRole::Accent, ns_color_to_gfx_color([NSColor controlAccentColor]));
#else
    // GNUstep: controlAccentColor not available, use a default blue accent
    palette.set_color(Gfx::ColorRole::Accent, Gfx::Color(0, 122, 255)); // macOS default blue
#endif
    // FIXME: There are more system colors we currently don't use (https://developer.apple.com/documentation/appkit/nscolor/3000782-controlaccentcolor?language=objc)

    return theme;
}

}
