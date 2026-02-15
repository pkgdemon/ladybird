/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 * Copyright (c) 2025, Joe Maloney <jpm820@proton.me>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/ByteString.h>
#include <LibCore/Resource.h>
#include <LibGfx/Palette.h>
#include <LibGfx/SystemTheme.h>

#import <AppKit/AppKit.h>
#import <Interface/Palette.h>
#import <Utilities/Conversions.h>

namespace Ladybird {

bool is_using_dark_system_theme()
{
    // Check environment variable first
    const char* theme = getenv("GNUSTEP_THEME");
    if (theme && strcasestr(theme, "dark") != nullptr) {
        return true;
    }

    // Check user defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* gnustep_theme = [defaults stringForKey:@"GSTheme"];
    if (gnustep_theme && [[gnustep_theme lowercaseString] containsString:@"dark"]) {
        return true;
    }

    // Default to light theme
    return false;
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

    palette.set_color(Gfx::ColorRole::Accent, ns_color_to_gfx_color([NSColor controlColor]));

    return theme;
}

}
