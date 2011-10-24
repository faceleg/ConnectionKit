#import "NarrowPopUpButton.h"
#import "NarrowPopUpButtonCell.h"


@implementation NarrowPopUpButton

- (id)initWithCoder:(NSCoder *)decoder
{
	NSKeyedUnarchiver *unarchiver = nil;		// to stop initialization warning; we use it twice below.
	Class oldCellClass = nil;		// to stop initialization warning; we use it twice below.
	
	if ([decoder allowsKeyedCoding])
	{
		unarchiver = (NSKeyedUnarchiver *)decoder;
		oldCellClass = [unarchiver classForClassName: @"NSPopUpButtonCell"];
		
		[unarchiver setClass: [NarrowPopUpButtonCell class] forClassName: @"NSPopUpButtonCell"];
	}
	
	[super initWithCoder: decoder];
	
	if ([decoder allowsKeyedCoding]) {
		[unarchiver setClass: oldCellClass forClassName: @"NSPopUpButtonCell"];
	}
	
	return self;
}

@end
