//
//  PageCounterPagelet.m
//  PageCounterPagelet
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//



 /*
  
  DROP TABLE IF EXISTS PageCounts;
  CREATE TABLE  `PageCounts` (
							  `urlID` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
							  `url` VARCHAR(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL ,
							  `count` BIGINT NOT NULL default '0',
							  PRIMARY KEY(urlID)
							  ) ENGINE = innodb CHARACTER SET utf8 COLLATE utf8_unicode_ci;
  
  ALTER TABLE PageCounts ADD INDEX(url);
  
  
  
  */
 

#import "PageCounterPagelet.h"
#import "PageCounterInspector.h"

#import "SandvoxPlugin.h"


NSString *PCThemeKey = @"theme";
NSString *PCTypeKey = @"type";		
NSString *PCWidthKey = @"width";
NSString *PCHeightKey = @"height";
NSString *PCImagesPathKey = @"path";
NSString *PCSampleImageKey = @"sampleImage";



@implementation PageCounterPagelet

@synthesize selectedTheme = _selectedTheme;

#pragma mark -
#pragma mark Initialization

+ (NSArray *)themes
{
	static NSArray *sThemes;
	
	if (!sThemes)
	{
		NSMutableArray *themes = [NSMutableArray array];
		NSMutableDictionary *d;
		
		d = [NSMutableDictionary dictionary];
		[d setObject:LocalizedStringInThisBundle(@"Text", @"Text style of page counter") forKey:PCThemeKey];
		[d setObject:[NSNumber numberWithInt:PC_TEXT] forKey:PCTypeKey];
		[themes addObject:d];
		
		d = [NSMutableDictionary dictionary];
		[d setObject:LocalizedStringInThisBundle(@"Invisible", @"Invisible style of page counter; outputs no number") forKey:PCThemeKey];
		[d setObject:[NSNumber numberWithInt:PC_INVISIBLE] forKey:PCTypeKey];
		[themes addObject:d];
		
		NSString *resourcePath = [[NSBundle bundleForClass:[PageCounterPagelet class]] resourcePath];
		resourcePath = [resourcePath stringByAppendingPathComponent:@"digits"];
		NSString *fileName;
		NSDirectoryEnumerator *dirEnum =
		[[NSFileManager defaultManager] enumeratorAtPath:resourcePath];
		
		while (fileName = [dirEnum nextObject])
		{
			// Look for all "0" digits to represent the whole group.
			// MUST END WITH .png
			unsigned int whereZeroPng = [fileName rangeOfString:@"-0.png"].location;
			if (NSNotFound != whereZeroPng)
			{
				NSString *path = [resourcePath stringByAppendingPathComponent:fileName];
				
				// Determine image size
				NSSize size = NSMakeSize(0,0);
				NSURL *url = [NSURL fileURLWithPath:path];
				CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
				if (source)
				{
					NSDictionary *props = (NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
					
					size = NSMakeSize([[props objectForKey:(NSString *)kCGImagePropertyPixelWidth] intValue],
									  [[props objectForKey:(NSString *)kCGImagePropertyPixelHeight] intValue]);
					CFRelease(source);
					[props release];
					
					if (!NSEqualSizes(size, NSZeroSize))
					{
						// Get the other properties into a dictionary
						NSString *baseName = [fileName substringToIndex:whereZeroPng];
						d = [NSMutableDictionary dictionary];
						[d setObject:[NSNumber numberWithInt:PC_GRAPHICS] forKey:PCTypeKey];
						[d setObject:baseName forKey:PCThemeKey];	// Used internally not for display
						[d setObject:[NSNumber numberWithInt:(int)size.width] forKey:PCWidthKey];
						[d setObject:[NSNumber numberWithInt:(int)size.height] forKey:PCHeightKey];
						[themes addObject:d];
						
	#define MAX_SAMPLE_WIDTH 148	// best width for a 250 pixel inspector; depends on nib width!
						
						int maxDigits = MAX_SAMPLE_WIDTH / (int) size.width;
						
						NSRect digitRect = NSMakeRect(0,0,size.width, size.height);
						NSImage *sampleImage = [[[NSImage alloc] initWithSize:NSMakeSize(size.width * maxDigits, size.height)] autorelease];
						[sampleImage lockFocus];
						int i;
						for (i = 0 ; i < maxDigits ; i++)
						{
							NSString *digitFilePath = [resourcePath stringByAppendingPathComponent:
								[NSString stringWithFormat:@"%@-%d.png", baseName, i]];
							NSImage *digitImage = [[[NSImage alloc] initWithContentsOfFile:digitFilePath] autorelease];
							[digitImage drawAtPoint:NSMakePoint(size.width * i, 0) fromRect:digitRect operation:NSCompositeSourceOver fraction:1.0];
						}
								
						[sampleImage unlockFocus];
						[d setObject:sampleImage forKey:PCSampleImageKey];
					}
				}
			}
		}
		
		// Add any from user defaults  (NOT SURE HOW THIS WOULD REALLY WORK...
		NSArray *ud = [[NSUserDefaults standardUserDefaults] objectForKey:@"PageCounterThemes"];
		if (ud)
		{ 
			[themes addObjectsFromArray:ud];
		}
		
		
		// Store the themes
		sThemes = [[NSArray alloc] initWithArray:themes];
	}
	
	return sThemes;
}



+ (NSSet *)plugInKeys
{
	return [NSSet setWithObjects:@"selectedTheme", 
			nil];
}
+ (Class)inspectorViewControllerClass;
{
	return [PageCounterInspector class];
}


#pragma mark -
#pragma mark Accessors

- (NSDictionary *)currentThemeDict
{
	int index = self.selectedTheme;
	if (index >= [[[self class] themes] count]) index = 0;
	NSDictionary *result = [[[self class] themes] objectAtIndex:index];
	return result;
}

- (int)type
{ 
	return [[[self currentThemeDict] objectForKey:PCTypeKey] intValue];
}

- (NSString *)theme
{
	return [[self currentThemeDict] objectForKey:PCThemeKey];
}

- (id)width
{
	return [[self currentThemeDict] objectForKey:PCWidthKey];
}

- (id)height
{
	return [[self currentThemeDict] objectForKey:PCHeightKey];
}

- (NSArray *)themes
{
	return [[self class] themes];
}

#pragma mark -
#pragma mark Resources

- (NSURL *)previewResourceDirectory
{
	NSString *path = [[[self bundle] resourcePath] stringByAppendingPathComponent:@"digits"];
	return [NSURL fileURLWithPath:path];
}

- (void)writeHTML:(id <SVPlugInContext>)context;
{
    // Include resources for each digit if needed
    if (PC_GRAPHICS == [self type])
	{
		NSString *theme = [self theme];
		NSBundle *b = [self bundle];
		NSString *imagePath = [[self currentThemeDict] objectForKey:PCImagesPathKey];	// from default
		
		unsigned i;
		
		for (i = 0; i < 10; i++)
		{
			NSString *format = [NSString stringWithFormat:@"%@-%d.png", theme, i];
			if (imagePath)
			{
				[context addResource:
                 [NSURL fileURLWithPath:[imagePath stringByAppendingPathComponent:format]]];
			}
			else
			{
				NSString *resource = [b pathForResource:[format stringByDeletingPathExtension]
                                                 ofType:[format pathExtension] 
                                            inDirectory:@"digits"];
                OBASSERT(resource);
                [context addResource:[NSURL fileURLWithPath:resource]];
			}
		}
	}
    
    
    // Carry on
    [super writeHTML:context];
}

//LocalizedStringInThisBundle("page views",@" preceeded by a number to show how many times a page has been viewed over the web");

@end
