//
//  MyDocument.m
//  NumberRenderer
//
//  Created by Dan Wood on 4/16/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "MyDocument.h"
#import "NSImage+KTExtensions.h"

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	NSString *destDir = @"/Users/dwood/Desktop/FontImages/";
	
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	
	NSEnumerator *theEnum = [[[NSFontManager sharedFontManager] availableFonts] objectEnumerator];
	NSString *aName;
	int fontCounter = 0;
	
	NSMutableString *buf = [NSMutableString stringWithString:@"<html><body>\n"];
	
	while (nil != (aName = [theEnum nextObject]) )
	{
		if (fontCounter++ > 999) break;			/// stop before I get too many
		[buf appendFormat:@"<p>%@:<br />\n",aName];
		NSLog(@"Font %@", aName);
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSFont *font = [NSFont fontWithName:aName size:30.0];
		
		NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
		[aShadow setShadowOffset:NSMakeSize(0,-2)];
		[aShadow setShadowBlurRadius:2.0];
		[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.35]];

	
#define BACKGROUND [NSColor colorWithCalibratedWhite:0.0 alpha:1.0]
//#define FOREGROUND [NSColor colorWithCalibratedRed:0.75 green:0.55 blue:0.5 alpha:1.0]
#define BORDER		[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]

		
		float r = (float)random() / (float) LONG_MAX;
		float g = (float)random() / (float) LONG_MAX;
		float b = (float)random() / (float) LONG_MAX;
#define FOREGROUND [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0]
		
		
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName,
			FOREGROUND, NSForegroundColorAttributeName,
		aShadow, NSShadowAttributeName,
			nil];
		int i;
		for (i = '0'; i <= '9' ; i++)
		{
			NSArray *colors = [NSArray arrayWithObjects:
				[NSColor blueColor],
				[NSColor brownColor],
				[NSColor colorWithCalibratedRed:1.0 green:0.6 blue:0.8 alpha:1.0],	// pink
				[NSColor colorWithCalibratedRed:0.5 green:0.0 blue:0.5 alpha:1.0],	// plum
				[NSColor redColor],
				[NSColor colorWithCalibratedRed:0.0 green:0.5 blue:0.25 alpha:1.0],
				[NSColor magentaColor],
				[NSColor orangeColor],
				[NSColor colorWithCalibratedRed:0.4 green:1.0 blue:0.4 alpha:1.0],	// lighter-green
				[NSColor colorWithCalibratedRed:1.0 green:0.85 blue:0.0 alpha:1.0],	// deeper yellow
				nil];
			
			
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				font, NSFontAttributeName,
				[colors objectAtIndex:i-'0'], NSForegroundColorAttributeName,
				aShadow, NSShadowAttributeName,
				nil];
			
			
			
			
			
			
			
			
			
			
			NSString *s = [NSString stringWithFormat:@"%c", i];
			NSAttributedString *as = [[[NSAttributedString alloc] initWithString:s attributes:attributes] autorelease];
			NSSize size = [as size];
			
#define OFF_THE_TOP 0
#define SIDE_PADDING 2
#define BOTTOM_OFFSET 1
			
			size.height -= OFF_THE_TOP;	// to subtract from height
			size.height += BOTTOM_OFFSET;
			size.width += SIDE_PADDING * 2;
			

			NSImage *im = [[[NSImage alloc] initWithSize:size] autorelease];
			
			[im lockFocus];
		
//			[BACKGROUND set];
//			[NSBezierPath fillRect:NSMakeRect(0,0,size.width, size.height)];
			[as drawAtPoint:NSMakePoint(SIDE_PADDING, BOTTOM_OFFSET)];

//			[BORDER set];
//			NSRect borderRect = NSMakeRect(0,0,size.width-0.5, size.height);
//			borderRect = NSInsetRect(borderRect,1.5,1.5);
//			[NSBezierPath strokeRect:borderRect];

			[im unlockFocus];
			
			NSData *pngdata = [im PNGRepresentation];
			NSString *fileName = [NSString stringWithFormat:@"%@-%@.png", aName, s];
			NSString *filePath = [NSString stringWithFormat:@"%@/%@", destDir, fileName];
			[[NSFileManager defaultManager] removeFileAtPath:filePath handler:nil];
			[pngdata writeToFile:filePath atomically:NO];
			
			[buf appendFormat:@"<img src=\"%@\" alt=\"%@\" />",fileName, s];
		}
		[pool release];
		
		[buf appendString:@"\n</p>\n"];
	}
	[buf appendString:@"</body></html>"];
	NSData *data = [buf dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *indexPath = [NSString stringWithFormat:@"%@/index.html", destDir];
	[[NSFileManager defaultManager] removeFileAtPath:indexPath handler:nil];
	[data writeToFile:indexPath atomically:NO];
	
	[NSApp terminate:nil];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    // Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
    
    // For applications targeted for Tiger or later systems, you should use the new Tiger API -dataOfType:error:.  In this case you can also choose to override -writeToURL:ofType:error:, -fileWrapperOfType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    return nil;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    // Insert code here to read your document from the given data.  You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.
    
    // For applications targeted for Tiger or later systems, you should use the new Tiger API readFromData:ofType:error:.  In this case you can also choose to override -readFromURL:ofType:error: or -readFromFileWrapper:ofType:error: instead.
    
    return YES;
}

@end
