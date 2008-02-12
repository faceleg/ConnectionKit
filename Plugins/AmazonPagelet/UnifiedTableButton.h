/* UnifiedTableButton */
//
//	An NSButton that draws a special border to fit in with the "unified" style
//	in which Inspector table views are being drawn.
//	If a menu is attached to the button, clicking will open it.


#import <Cocoa/Cocoa.h>


@interface UnifiedTableButton : NSButton
{
}

- (void)openMenu;

@end
