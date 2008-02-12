/* Controller */

#import <Cocoa/Cocoa.h>

@class HSAController;

@interface Controller : NSObject
{
    IBOutlet NSTextView *oTextView;
	IBOutlet NSWindow	*oWindow;
	NSDictionary		*myProperties;
	
	HSAController		*myAssistant;
}
- (IBAction)launchHSA:(id)sender;

@end
