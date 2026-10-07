// Ask AppKit directly what a wxWindow's backing NSView carries, and whether a
// tooltip window actually appears when the cursor rests on it.
#import <Cocoa/Cocoa.h>
#include <wx/wx.h>
#include <string>

// A plain executable is a background process on macOS, and a background app's
// windows do not take part in normal tooltip tracking. Make it a regular app so
// the probe measures tooltips and not activation policy.
void become_foreground_app()
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
}

std::string native_tooltip(wxWindow *w)
{
    NSView *view = (NSView *) w->GetHandle();
    if (view == nil)
        return "(no NSView)";
    NSString *tip = [view toolTip];
    return tip == nil ? std::string() : std::string([tip UTF8String]);
}

// Park the cursor over the widget and look for a window our process owns that is
// neither the frame nor the panel: a displayed tooltip is its own window.
// CGWarpMouseCursorPosition needs no accessibility grant, which matters on a CI
// runner where nothing can click "Allow".
std::string hover_probe(wxWindow *w)
{
    NSView *view = (NSView *) w->GetHandle();
    if (view == nil || [view window] == nil)
        return "no view";

    const NSRect  in_window = [view convertRect:[view bounds] toView:nil];
    const NSRect  on_screen = [[view window] convertRectToScreen:in_window];
    const CGFloat height    = NSMaxY([[NSScreen screens][0] frame]);
    const CGPoint centre    = CGPointMake(NSMidX(on_screen), height - NSMidY(on_screen));

    const size_t before = [(__bridge NSArray *) CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID) count];

    CGWarpMouseCursorPosition(centre);
    CGAssociateMouseAndMouseCursorPosition(true);
    for (int i = 0; i < 40; ++i) {      // up to 4 s, the system tooltip delay plus slack
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        NSArray *now = (__bridge_transfer NSArray *) CGWindowListCopyWindowInfo(
            kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
        if ([now count] > before)
            return "tooltip window appeared";
    }
    return "no tooltip window";
}
