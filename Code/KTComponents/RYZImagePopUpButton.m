// http://iratescotsman.com/products/source/
// Eric Wang's reimplementation of my PopUpImage class (see above), using a subclass of NSPopUpButton.

#import "RYZImagePopUpButton.h"
#import "RYZImagePopUpButtonCell.h"


@implementation RYZImagePopUpButton

// TJT added NSCoding support, necessary for use of button in a toolbar
- (void)encodeWithCoder:(NSCoder *)encoder
{
    [super encodeWithCoder:encoder];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    
    return self;
}

// -----------------------------------------
//	Initialization and termination
// -----------------------------------------

+ (Class) cellClass
{
    return [RYZImagePopUpButtonCell class];
}

- (void)awakeFromNib
{
	[self setCell:[[[[[self class] cellClass] alloc] init] autorelease]];
}



// --------------------------------------------
//      Getting and setting the icon size
// --------------------------------------------

- (NSSize)iconSize
{
    return [[self cell] iconSize];
}


- (void)setIconSize:(NSSize)iconSize
{
    [[self cell] setIconSize:iconSize];
}


// ---------------------------------------------------------------------------------
//      Getting and setting whether the menu is shown when the icon is clicked
// ---------------------------------------------------------------------------------

- (BOOL)showsMenuWhenIconClicked
{
    return [[self cell] showsMenuWhenIconClicked];
}


- (void)setShowsMenuWhenIconClicked:(BOOL)showsMenuWhenIconClicked
{
    [[self cell] setShowsMenuWhenIconClicked:showsMenuWhenIconClicked];
}


// ---------------------------------------------
//      Getting and setting the icon image
// ---------------------------------------------

- (NSImage *)iconImage
{
    return [[self cell] iconImage];
}


- (void)setIconImage:(NSImage *)iconImage
{
    [[self cell] setIconImage:iconImage];
}


// ----------------------------------------------
//      Getting and setting the arrow image
// ----------------------------------------------

- (NSImage *)arrowImage
{
    return [[self cell] arrowImage];
}


- (void)setArrowImage:(NSImage *)arrowImage
{
    [[self cell] setArrowImage:arrowImage];
}

@end
