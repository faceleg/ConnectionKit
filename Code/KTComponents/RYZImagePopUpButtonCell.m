// http://iratescotsman.com/products/source/
// Eric Wang's reimplementation of my PopUpImage class (see above), using a subclass of NSPopUpButton.

////////////////////////////////////////////////////////////////////////////////
//  NB: This file incorporates many bugfixes by TJT, 2004-5, do not replace!  //
////////////////////////////////////////////////////////////////////////////////

#import "RYZImagePopUpButtonCell.h"

#import "NSImage+KTExtensions.h"


@implementation RYZImagePopUpButtonCell

// -----------------------------------------
//	Initialization and termination
// -----------------------------------------

- (id) init
{
    if (self = [super init])
    {
		_buttonCell = [[NSButtonCell alloc] initTextCell:@""];
		[_buttonCell setBordered:NO];
		[_buttonCell setHighlightsBy:NSContentsCellMask];
		[_buttonCell setImagePosition:NSImageLeft];
		
		_iconSize = NSMakeSize(32, 32);
		_showsMenuWhenIconClicked = NO;
		
		[self setIconImage: [NSImage imageNamed:@"NSApplicationIcon"]];	
		[self setArrowImage:[NSImage imageInBundleForClass:[self class] named:@"ArrowPointingDown.png"]];
		
		_toolbar = nil; // this needs to be explicitly set if used
    }
    
    return self;
}

- (void) dealloc
{
    [self setToolbar:nil];
    
    [_buttonCell release];
    [_iconImage release];
    [_arrowImage release];
    [super dealloc];
}

// TJT added NSCoding support
- (void)encodeWithCoder:(NSCoder *)encoder
{
    if ( [encoder allowsKeyedCoding] )
	{
        [encoder encodeObject:_buttonCell forKey:@"RYZButtonCell"];
        [encoder encodeSize:_iconSize forKey:@"RYZIconSize"];
        [encoder encodeBool:_showsMenuWhenIconClicked forKey:@"RYZShowsMenuWhenIconClicked"];
        [encoder encodeObject:_iconImage forKey:@"RYZIconImage"];
        [encoder encodeObject:_arrowImage forKey:@"RYZArrowImage"];
    }
    else 
	{
        NSLog(@"%@: unable to encode using keyed archiving.", [self className]);
    }
    
    return;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    
    if ( [decoder allowsKeyedCoding] ) 
	{
        _buttonCell = [[decoder decodeObjectForKey:@"RYZButtonCell"] retain];
        _iconSize = [decoder decodeSizeForKey:@"RYZIconSize"];
        _showsMenuWhenIconClicked = [decoder decodeBoolForKey:@"RYZShowsMenuWhenIconClicked"];
        _iconImage = [[decoder decodeObjectForKey:@"RYZIconImage"] retain];
        _arrowImage = [[decoder decodeObjectForKey:@"RYZArrowImage"] retain];
        
    }
    else 
	{
        NSLog(@"%@: unable to decode using keyed archiving.", [self className]);
    }    
	
    return self;
}

- (void)setToolbar:(NSToolbar *)toolbar		// DON'T retain, this creates a retain cycle.
{
    _toolbar = toolbar;
}

// --------------------------------------------
//	Getting and setting the icon size
// --------------------------------------------

- (NSSize)iconSize
{
    return _iconSize;
}

- (void)setIconSize:(NSSize)iconSize
{
    _iconSize = iconSize;
}

- (NSSize)arrowSize
{
	return _arrowImage ? [_arrowImage size] : NSZeroSize;
}

- (float)padding
{
	return _arrowImage ? 1.0 : 0;
}

- (float)toolbarIconWidth
{
	return [[self iconImage] size].width+([self padding]*2+[self arrowSize].width)*2;
}

// ---------------------------------------------------------------------------------
//	Getting and setting whether the menu is shown when the icon is clicked
// ---------------------------------------------------------------------------------

- (BOOL)showsMenuWhenIconClicked
{
    return _showsMenuWhenIconClicked;
}

- (void)setShowsMenuWhenIconClicked:(BOOL)showsMenuWhenIconClicked
{
    _showsMenuWhenIconClicked = showsMenuWhenIconClicked;
}

// ---------------------------------------------
//      Getting and setting the icon image
// ---------------------------------------------

- (NSImage *)iconImage
{
    return _iconImage;
}

- (void)setIconImage:(NSImage *)iconImage
{
    [iconImage retain];
    [_iconImage release];
    _iconImage = iconImage;
}

// ----------------------------------------------
//      Getting and setting the arrow image
// ----------------------------------------------

- (NSImage *)arrowImage
{
    return _arrowImage;
}

- (void)setArrowImage:(NSImage *)arrowImage
{
    [arrowImage retain];
    [_arrowImage release];
    _arrowImage = arrowImage;
}

// -----------------------------------------
//	Handling mouse/keyboard events
// -----------------------------------------

- (BOOL) trackMouse:(NSEvent *)event
			 inRect:(NSRect)cellFrame
			 ofView:(NSView *)controlView
       untilMouseUp:(BOOL)untilMouseUp
{
    BOOL trackingResult = YES;
    
    if ([event type] == NSKeyDown) 
	{
        unichar upAndDownArrowCharacters[2];
        upAndDownArrowCharacters[0] = NSUpArrowFunctionKey;
        upAndDownArrowCharacters[1] = NSDownArrowFunctionKey;
        NSString *upAndDownArrowString = [NSString stringWithCharacters: upAndDownArrowCharacters  length: 2];
        NSCharacterSet *upAndDownArrowCharacterSet = [NSCharacterSet characterSetWithCharactersInString: upAndDownArrowString];
        
        if ([self showsMenuWhenIconClicked] == YES || [[event characters] rangeOfCharacterFromSet: upAndDownArrowCharacterSet].location != NSNotFound)
        {
            NSEvent *newEvent = [NSEvent keyEventWithType: [event type]
                                                 location: NSMakePoint([controlView frame].origin.x, [controlView frame].origin.y - 4)
                                            modifierFlags: [event modifierFlags]
                                                timestamp: [event timestamp]
                                             windowNumber: [event windowNumber]
                                                  context: [event context]
                                               characters: [event characters]
                              charactersIgnoringModifiers: [event charactersIgnoringModifiers]
                                                isARepeat: [event isARepeat]
                                                  keyCode: [event keyCode]];
            
            [NSMenu popUpContextMenu: [self menu]  withEvent: newEvent  forView: controlView];
// FIXME: A flaw of using this method is that it thinks it's a context menu, so CM plugins tend to add stuff here!
        }
        else if ([[event characters] rangeOfString: @" "].location != NSNotFound)
        {
            [self performClick: controlView];
        }
    }
    else 
	{
        NSPoint mouseLocation = [controlView convertPoint:[event locationInWindow]  fromView:nil];
        
        NSSize iconSize = [self iconSize];
        NSSize arrowSize = [self arrowSize];
        NSRect arrowRect = NSMakeRect(cellFrame.origin.x + iconSize.width + 1,
                                      cellFrame.origin.y,
                                      arrowSize.width,
                                      arrowSize.height);
        
        // TJT: convert to window coordinates when processing the event
        NSRect controlViewFrame = [controlView convertRect:[controlView bounds] toView:nil];
        
        if ([controlView isFlipped])
        {
            arrowRect.origin.y += iconSize.height;
            arrowRect.origin.y -= arrowSize.height;
        }
		
        if ([event type] == NSLeftMouseDown && ([self showsMenuWhenIconClicked] == YES || [controlView mouse:mouseLocation  inRect:arrowRect]))
        {
            NSEvent *newEvent = [NSEvent mouseEventWithType:[event type]
												   location:NSMakePoint(controlViewFrame.origin.x, controlViewFrame.origin.y - 4)
                                              modifierFlags:[event modifierFlags]
                                                  timestamp:[event timestamp]
                                               windowNumber:[event windowNumber]
                                                    context:[event context]
                                                eventNumber:[event eventNumber]
                                                 clickCount:[event clickCount]
                                                   pressure:[event pressure]];
            
            [NSMenu popUpContextMenu:[self menu]  withEvent:newEvent  forView:controlView];
        }
        else
        {
            trackingResult = [_buttonCell trackMouse:event
                                              inRect:cellFrame
                                              ofView:controlView
                                        untilMouseUp:[[_buttonCell class] prefersTrackingUntilMouseUp]];  // NO for NSButton
            
            if (trackingResult == YES)
            {
                NSMenuItem *selectedItem = [self selectedItem];
                [[NSApplication sharedApplication] sendAction:[selectedItem action]  to:[selectedItem target]  from:selectedItem];
            }
        }
    }
    
    //NSLog(@"trackingResult: %d", trackingResult);
    
    return trackingResult;
}


- (void)performClick:(id)sender
{
    //NSLog(@"performClick:");
    [_buttonCell performClick: sender];
    [super performClick: sender];
}


// -----------------------------------
//	Drawing and highlighting
// -----------------------------------

- (NSSize)minimumSize
{
	if ( nil != _toolbar )
	{
		if ( NSToolbarSizeModeSmall == [_toolbar sizeMode] ) 
		{
			return NSMakeSize([self toolbarIconWidth], 24);
		}
		else
		{
			return NSMakeSize([self toolbarIconWidth], 32);
		}
	}
	else
	{
		return NSMakeSize([self iconSize].width + [self padding] + [self arrowSize].width, [self iconSize].height);
	}
}

- (NSSize)maximumSize
{
	return [self minimumSize];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSImage *arrowImage = [self arrowImage];
    NSSize arrowSize = [self arrowSize];

    NSImage *iconImage;
    if ([self usesItemFromMenu] == NO) 
	{
        iconImage = [[[self iconImage] copy] autorelease];
    }
    else 
	{
        iconImage = [[[[self selectedItem] image] copy] autorelease];
    }	
	
    NSSize iconSize;
	NSSize popUpSize;
	if ( nil != _toolbar )
	{
		if ( NSToolbarSizeModeSmall == [_toolbar sizeMode] ) 
		{
			[iconImage setScalesWhenResized:YES];
			[iconImage setSize:NSMakeSize(24, 24)];
		}
		iconSize = [iconImage size];
		popUpSize = NSMakeSize([self toolbarIconWidth], [iconImage size].height);
	}
	else
	{
		iconSize = [iconImage size];
		popUpSize = NSMakeSize(iconSize.width + [self padding] + arrowSize.width,iconSize.height);
	}
	
	if (0 == popUpSize.height || 0 == popUpSize.height)
	{
		NSLog(@"Warning: RYZImagePopUpButtonCell popUpSize is empty");
	}
	
	NSImage *popUpImage = [[NSImage alloc] initWithSize:popUpSize];
    
    NSRect iconRect = NSMakeRect(0, 0, iconSize.width, iconSize.height);
    NSRect arrowRect = NSMakeRect(0, 0, arrowSize.width, arrowSize.height);
        
    [popUpImage lockFocus];
    [iconImage drawAtPoint:NSMakePoint((popUpSize.width-iconSize.width)/2.0, 0.0) fromRect:iconRect operation:NSCompositeSourceOver fraction:1.0];
	if (arrowImage)
	{
		// don't use [self toolbarIconWidth]; doesn't work for non toolbar popups
		// float arrowX = [self toolbarIconWidth] - arrowSize.width - arrowSize.width/2.0; // hand-tuned, could be better
		float arrowX = popUpSize.width - arrowSize.width;
		[arrowImage drawAtPoint:NSMakePoint(arrowX, arrowSize.height) fromRect:arrowRect operation:NSCompositeSourceOver fraction:1.0];
	}
	[popUpImage unlockFocus];
    
    [popUpImage normalizeSize];
    [_buttonCell setImage:popUpImage];
    
    [popUpImage release];
    
    if ([[controlView window] firstResponder] == controlView &&
        [controlView respondsToSelector:@selector(selectedCell)] &&
        [controlView performSelector:@selector(selectedCell)] == self)
	{
        [_buttonCell setShowsFirstResponder: YES];
    }
    else 
	{
        [_buttonCell setShowsFirstResponder: NO];
    }
    
    //NSLog(@"cellFrame: %@  selectedItem: %@", NSStringFromRect(cellFrame), [[self selectedItem] title]);
    
    [_buttonCell drawWithFrame:cellFrame inView:controlView];
}

- (void)highlight:(BOOL) flag withFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    //NSLog(@"highlight: %d", flag);
    [_buttonCell highlight:flag withFrame:cellFrame inView:controlView];
    [super highlight:flag withFrame:cellFrame inView:controlView];
}

@end
