/* NarrowPopUpButton */
//
//	For some reason, a bordless NSPopupButton will not draw correctly below
//	a certain width.
//	This class corrects the issue by using a custom cell, NarrowPopUpButtonCell.

#import <Cocoa/Cocoa.h>

@interface NarrowPopUpButton : NSPopUpButton
{
}
@end
