//
//  SVFlash.m
//  Sandvox
//
//  Created by Dan Wood on 9/9/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

/*
 SVFlash is a MediaGraphic, similar to SVVideo and SVAudio, but much simpler.
 
 We try to guess the dimensions of the flash file by parsing the file.
 One drawback about the fact that we won't know the dimensions of a movie until we have been able
 to load it on a page is that it's possible that one could create a bunch of "movie pages" and never
 load them into Sandvox to give them a chance to calculate their dimensions. I don't think that
 this is very likely; as soon as the site author has gone to a page to even see what the size is,
 Sandvox will be fetching the size.
  
 Icon source: http://sharealogo.com/computer/adobe-flash-8-vector-logo-download/ modified with Opacity
 
 // Example: http://mindymcadams.com/photos/flowers/slideshow.swf
 // Flash ref: http://kb2.adobe.com/cps/415/tn_4150.html http://kb2.adobe.com/cps/127/tn_12701.html
 
 */

#import "SVFlash.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "KSSimpleURLConnection.h"
#include <zlib.h>
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "KSThreadProxy.h"
#import "NSImage+KTExtensions.h"
#import "SVMediaGraphicInspector.h"

@interface SVFlash ()
- (void)loadMovie;
- (void)setOriginalSizeFromData:(NSData *)aData;
@end


@implementation SVFlash 

@synthesize showMenu = _showMenu;
@synthesize flashvars = _flashvars;



@synthesize dimensionCalculationConnection = _dimensionCalculationConnection;


//	NSLocalizedString(@"This is a placeholder for Flash. The full Flash video will appear on your published site, or view it in Sandvox by enabling 'Load data from the Internet' in Preferences.", "Live data feeds disabled message.")

//	NSLocalizedString(@"Please use the Inspector to enter the URL of a Flash.", "URL has not been specified - placeholder message")

#pragma mark -
#pragma mark Lifetime

- (void)awakeFromNew;
{
	self.autoplay = NO;
	self.loop = NO;
	self.showMenu = YES;
	self.flashvars = @"";
	
    // Show caption
    if ([[[self.container textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}

+ (NSArray *)plugInKeys;
{
    return [[super plugInKeys] arrayByAddingObjectsFromArray:
			[NSArray arrayWithObjects:
			 @"flashvars",
			 @"showMenu",
			 nil]];
}


#pragma mark -
#pragma mark General

+ (NSArray *) allowedFileTypes
{
	return [NSArray arrayWithObjects:@"com.adobe.shockwave-flash",
			@"com.macromedia.shockwave-flash",	// annoying to have to check both, but somehow I got the macromedia UTI....
			nil];
	
	// com.macromedia.shockwave-flash ???
}

- (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
	return @"com.karelia.sandvox.SVFlash";
}

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = nil;
    result = [[[SVMediaGraphicInspector alloc] initWithNibName:@"SVFlashInspector" bundle:nil] autorelease];
    return result;
}




- (id <SVMedia>)thumbnail
{
	return nil;		// can't determine thumbnail;
}


#pragma mark -
#pragma mark Media

- (void)_mediaChanged;
{
	NSLog(@"SVFlash Media set.");
	
	// Flash changed - clear out the known width/height so we can recalculate
	[self setNaturalWidth:nil height:nil];
	
	// Load the movie to figure out the media size
	[self loadMovie];
}

- (void)didSetSource;
{
    [super didSetSource];
	[self _mediaChanged];

    /*if ([self.container constrainProportions])    // generally true
    {
        // Resize image to fit in space
        NSUInteger width = self.width;
        [self.container makeOriginalSize];
        if (self.width > width) self.width = width;
    }*/
}

#pragma mark -
#pragma mark Writing Tag


- (NSString *)writeFlash:(SVHTMLContext *)context
		  flashSourceURL:(NSURL *)flashSourceURL;
{
	NSString *flashSourcePath  = flashSourceURL ? [context relativeStringFromURL:flashSourceURL] : @"";
	
	[context pushAttribute:@"classid" value:@"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"];	// Proper value?
	[context pushAttribute:@"codebase" value:@"http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,40,0"];
	// align?  It was in Sandvox 1.x.  Doesn't seem to be officially supported though.
	
	[context buildAttributesForResizableElement:@"object" object:self DOMControllerClass:nil sizeDelta:NSZeroSize options:0];

	// ID on <object> apparently required for IE8
	NSString *elementID = [context startElement:@"object" preferredIdName:@"flash" className:nil attributes:nil];	// class, attributes already pushed
	
	[context writeParamElementWithName:@"movie" value:flashSourcePath];
	[context writeParamElementWithName:@"quality" value:@"autohigh"];	// or autohigh
	[context writeParamElementWithName:@"scale" value:@"showall"];

	
	[context writeParamElementWithName:@"play" value:self.autoplay ? @"true" : @"false"];
	[context writeParamElementWithName:@"menu" value:self.showMenu ? @"true" : @"false"];
	[context writeParamElementWithName:@"loop" value:self.loop ? @"true" : @"false"];
	[context writeParamElementWithName:@"scale" value:@"default"];
	[context writeParamElementWithName:@"type" value:@"application/x-shockwave-flash"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://www.macromedia.com/go/getflashplayer"];	
	
	/*
	// We may as well do nested <embed> tag though are there really any browsers that need it?
	
	[context pushAttribute:@"src" value:flashSourcePath];
	// Align middle? In 1.x
	[context pushAttribute:@"quality" value:@"autohigh"];
	[context pushAttribute:@"scale" value:@"default"];
	[context pushAttribute:@"play" value:self.autoplay ? @"true" : @"false"];
	[context pushAttribute:@"menu" value:self.showMenu ? @"true" : @"false"];
	[context pushAttribute:@"loop" value:self.loop ? @"true" : @"false"];
	[context pushAttribute:@"type" value:@"application/x-shockwave-flash"];
	[context pushAttribute:@"pluginspage" value:@"http://www.macromedia.com/go/getflashplayer"];
	
	if (self.flashvars && ![self.flashvars isEqualToString:@""])
	{
		[context pushAttribute:@"flashvars" value:self.flashvars];
	}

	// Not going to use buildAttributesForElement:bindSizeToObject: for this element since it's hidden from Sandvox anyhow, just a fallback.
	[context startElement:@"embed"];
	
	[context endElement];
	*/
	
	
	[context endElement];
	
	return elementID;	// ID of outer object tag
}


- (void)writeHTML:(SVHTMLContext *)context;
{
	// Prepare Media
	
	SVMedia *media = [self media];
	//[context addDependencyOnObject:self keyPath:@"media"];    // don't need, graphic does for us
	
	NSURL *flashSourceURL = [self externalSourceURL];
    if (media)
    {
	    flashSourceURL = [context addMedia:media];
	}
		
	[self writeFlash:context flashSourceURL:flashSourceURL]; 
}


// Caches the flash from data.


#pragma mark -
#pragma mark Flash

/*
 A flash 8 file that's 0x65EE4F bytes long
 
 00000000  46 57 53 08 4f ee 65 00  78 00 06 0e 00 00 12 c0  |FWS.O.e.x.......|
 00000010  00 00 1e 22 0c 43 02 00  00 00 84 04 0b 2b df 02  |...".C.......+..|
 00000020  3f 03 14 00 00 00 96 09  00 00 57 46 5f 44 4f 4e  |?.........WF_DON|
 00000030  45 00 96 03 00 00 30 00  1d 00 0a 0f 01 00 21 0c  |E.....0.......!.|
 
 Nbits     	     nBits = UB[5]     	     Bits used for each subsequent field     
 Xmin     	     SB[nBits]     	     X minimum position for rectangle in twips     
 Xmax     	     SB[nBits]     	     X maximum position for rectangle in twips     
 Ymin     	     SB[nBits]     	     Y minimum position for rectangle in twips     
 Ymax     	     SB[nBits]     	     Y maximum position for rectangle in twips     
 };
 
 Here's a CWF -- compressed flash file, file size 0x7A849E
 
 00000000  43 57 53 06 88 be 7d 00  78 da e4 ba 07 58 13 db  |CWS...}.x....X..|
 00000010  b6 00 bc 33 24 90 d0 a4  77 14 29 91 2e 45 82 0a  |...3$...w.)..E..|
 00000020  62 04 94 8e 48 2f 4a 4d  42 0b 01 01 11 44 3d 51  |b...H/JMB....D=Q|
 00000030  b1 60 05 85 08 44 14 15  50 54 7a 2f 62 6c 08 08  |.`...D..PTz/bl..|
 
 After deflating starting at byte 8, you get:
 78 9C 00 07 40 F8 BF 78 DA E4 BA 07 58 13 DB B6 | x...@..x....X...
 00 BC 33 24 90 D0 A4 77 14 29 91 2E 45 82 0A 62 | ..3$...w.)..E..b
 04 94 8E 48 2F 4A 4D 42 0B 01 01 11 44 3D 51 B1 | ...H/JMB....D=Q.
 
 */ 

// based loosely on swfparse.c from http://www.fontimages.org.uk/
- (int)getBits:(int)numberOfBits
{
	int result = 0;
	int i, shift;
	for(i = 0 ; i < numberOfBits ; i += shift)
	{	
		if (!myBitOffset)
		{	
			myCurrentByte = *myBytePointer++;	// to next byte
			myBitOffset = 8;
		}
		shift = numberOfBits - i;
		if(shift > myBitOffset)	shift = myBitOffset;
		result <<= shift;
		result |= (myCurrentByte >> (myBitOffset -= shift)) & ((1 << shift) - 1);
	}
	return result;
}

- (BOOL)attemptToGetSize:(NSSize *)outSize fromSWFData:(NSData *)data
{
	BOOL result = NO;
	myBytePointer = (char *) [data bytes];
	
	@synchronized (self)	// since we store temporary stuff in ivars
	{
		BOOL isCompressed = NO;
		if ( [data length] > 20
			&& (myBytePointer[0] == 'F' || (isCompressed = myBytePointer[0] == 'C')  ) 
			&& myBytePointer[1] == 'W'
			&& myBytePointer[2] == 'S' )	// verify flash format
		{
			// Initialize ivars for the scanning
			myBitOffset = 0;
			myCurrentByte = 0;
			myBytePointer += 4;					// point to the 4th byte where the size data are
			int dataLength = NSSwapLittleIntToHost(*((int*)myBytePointer));
			
			myBytePointer += 4;					// point to the 8th byte where the rectangle data are
			
			if (isCompressed)
			{
				NSMutableData *outputData = [NSMutableData dataWithLength: dataLength - 8];
				
				z_stream z = {0};
				z.next_in = (Bytef*)myBytePointer;
				z.avail_in = [data length] - 8;
				z.next_out = (Bytef *)[outputData bytes];
				z.avail_out = dataLength - 8;
				
				(void) inflateInit((z_streamp)&z);
				(void) inflate(&z, Z_FINISH);
				(void) inflateEnd((z_streamp)&z);
				
				myBytePointer = (char *)[outputData bytes];
			}
			
			int numBits = [self getBits:5];
			int xx1		= [self getBits:numBits] / 20.0;
			int xx2		= [self getBits:numBits] / 20.0;
			int yy1		= [self getBits:numBits] / 20.0;
			int yy2		= [self getBits:numBits] / 20.0;
			
			if (nil != outSize)
			{
				*outSize = NSMakeSize(xx2-xx1, yy2-yy1);
			}
			result = YES;
		}
	}
	myBytePointer = nil;	// clean up, no sense hanging onto pointer
	return result;
}

- (void)setOriginalSizeFromData:(NSData *)aData;
{
	NSSize aSize = NSZeroSize;
	if ([self attemptToGetSize:&aSize fromSWFData:aData] && aSize.width && aSize.height)
	{
		[self setNaturalWidth:[NSNumber numberWithFloat:aSize.width] height:[NSNumber numberWithFloat:aSize.height]];
	}
	
}

- (void)loadMovie;
{
	SVMedia *media = [self media];
	if (media)
	{
		NSData *newData = [NSData newDataWithContentsOfMedia:media];
		[self setOriginalSizeFromData:newData];
		[newData release];
	}
	else	// Load the data asynchronously and check that way.
	{
		NSURL *flashSourceURL = [self externalSourceURL];
		if (flashSourceURL)
		{
			self.dimensionCalculationConnection = [[[KSSimpleURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:flashSourceURL] delegate:self] autorelease];
			self.dimensionCalculationConnection.bytesNeeded = 1024;	// Let's just get the first 1K ... should be enough.
		}
	}
}

// Asynchronous load returned -- try to set the dimensions.
- (void)connection:(KSSimpleURLConnection *)connection didFinishLoadingData:(NSData *)data response:(NSURLResponse *)response;
{
	[self setOriginalSizeFromData:data];
	self.dimensionCalculationConnection = nil;
}

- (void)connection:(KSSimpleURLConnection *)connection didFailWithError:(NSError *)error;
{
	NSLog(@"SVFlash error:%@ connection:%@", error, connection);
	// do nothing with the error, but clear out the connection.
	self.dimensionCalculationConnection = nil;
}


@end
