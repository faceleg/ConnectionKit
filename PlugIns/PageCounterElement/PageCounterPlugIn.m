//
//  PageCounterPlugIn.m
//  PageCounterElement
//
//  Copyright 2006-2011 Karelia Software. All rights reserved.
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
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//


#import "PageCounterPlugIn.h"

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
 


NSString *PCThemeKey = @"theme";
NSString *PCTypeKey = @"type";		
NSString *PCWidthKey = @"width";
NSString *PCHeightKey = @"height";
NSString *PCImagesPathKey = @"path";
NSString *PCSampleImageKey = @"sampleImage";
NSString *PCFilenameKey = @"filename";


@interface PageCounterPlugIn ()
- (NSURL *)resourcesURL:(id <SVPlugInContext>)context;
@end



@implementation PageCounterPlugIn


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"selectedThemeIndex", 
            nil];
}


- (void)awakeFromNew;
{
    [super awakeFromNew];
    self.selectedThemeIndex = 0;
    self.showsTitle = NO;
}    


#pragma mark Initialization

+ (NSMutableDictionary *)themeImages
{
    static NSMutableDictionary *sThemeImages = nil;
    if ( ! sThemeImages )
    {
        sThemeImages = [[NSMutableDictionary alloc] initWithCapacity:10];
    }
    
    return sThemeImages;
}

+ (NSImage *)sampleImageForFilename:(NSString *)filename
{
    NSMutableDictionary *themeImage = [[self themeImages] objectForKey:filename];
    if ( !themeImage )
    {
        // if we don't have one, we need to make one
		NSString *resourcePath = [[NSBundle bundleForClass:[PageCounterPlugIn class]] resourcePath];
		resourcePath = [resourcePath stringByAppendingPathComponent:@"digits"];
        NSString *path = [resourcePath stringByAppendingPathComponent:filename];
        
        // Determine image size
        NSURL *url = [NSURL fileURLWithPath:path];
        CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
        if (source)
        {
            NSDictionary *props = (NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
            
            NSSize size = NSMakeSize([[props objectForKey:(NSString *)kCGImagePropertyPixelWidth] integerValue],
                                     [[props objectForKey:(NSString *)kCGImagePropertyPixelHeight] integerValue]);
            CFRelease(source);
            [props release];
            
            if (!NSEqualSizes(size, NSZeroSize))
            {              
                unsigned int whereZeroPng = [filename rangeOfString:@"-0.png"].location;
                NSString *baseName = [filename substringToIndex:whereZeroPng];

                // make a new themeImage

                themeImage = [NSMutableDictionary dictionary];
                [themeImage setObject:[NSNumber numberWithInteger:(NSInteger)size.width] forKey:PCWidthKey];
                [themeImage setObject:[NSNumber numberWithInteger:(NSInteger)size.height] forKey:PCHeightKey];
                
#define MAX_SAMPLE_WIDTH 180	// best width for a 230 pixel inspector; depends on nib width!
                
                int maxDigits = MAX_SAMPLE_WIDTH / (NSInteger)size.width;
                
                NSRect digitRect = NSMakeRect(0,0,size.width, size.height);
                NSImage *sampleImage = [[[NSImage alloc] initWithSize:NSMakeSize(size.width * maxDigits, size.height)] autorelease];
                [sampleImage lockFocus];
                for (NSUInteger i = 0 ; i < maxDigits ; i++)
                {
                    NSString *digitFilePath = [resourcePath stringByAppendingPathComponent:
                                               [NSString stringWithFormat:@"%@-%d.png", baseName, i]];
                    NSImage *digitImage = [[[NSImage alloc] initWithContentsOfFile:digitFilePath] autorelease];
                    [digitImage drawAtPoint:NSMakePoint(size.width * i, 0) fromRect:digitRect operation:NSCompositeSourceOver fraction:1.0];
                }
                
                [sampleImage unlockFocus];
                [themeImage setObject:sampleImage forKey:PCSampleImageKey];
            }
        }
    }
    
    id result = [themeImage objectForKey:PCSampleImageKey];
    return result;
}

+ (NSNumber *)widthOfSampleImageForFilename:(NSString *)filename
{
    NSMutableDictionary *themeImage = [[self themeImages] objectForKey:filename];
    return [themeImage objectForKey:PCWidthKey];
}

+ (NSNumber *)heightOfSampleImageForFilename:(NSString *)filename
{
    NSMutableDictionary *themeImage = [[self themeImages] objectForKey:filename];
    return [themeImage objectForKey:PCHeightKey];
}

// returns dictionaries with keys PCThemeKey, PCTypeKey, PCFilenameKey
+ (NSArray *)themes
{
	static NSArray *sThemes;
	
	if (!sThemes)
	{
		NSMutableArray *themes = [NSMutableArray array];
		NSMutableDictionary *d;
		
		d = [NSMutableDictionary dictionary];
		[d setObject:SVLocalizedString(@"Text", @"Text style of page counter") forKey:PCThemeKey];
		[d setObject:[NSNumber numberWithUnsignedInteger:PC_TEXT] forKey:PCTypeKey];
		[themes addObject:d];
		
		d = [NSMutableDictionary dictionary];
		[d setObject:SVLocalizedString(@"Invisible", @"Invisible style of page counter; outputs no number") forKey:PCThemeKey];
		[d setObject:[NSNumber numberWithUnsignedInteger:PC_INVISIBLE] forKey:PCTypeKey];
		[themes addObject:d];
        
        d = [NSMutableDictionary dictionary]; // empty dictionary to account for separator item in menu
		[themes addObject:d];
		
		NSString *resourcePath = [[NSBundle bundleForClass:[PageCounterPlugIn class]] resourcePath];
		resourcePath = [resourcePath stringByAppendingPathComponent:@"digits"];
		NSString *filename;
		NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:resourcePath];
		
		while (filename = [dirEnum nextObject])
		{

			// Look for all "0" digits to represent the whole group.
			// MUST END WITH .png
			unsigned int whereZeroPng = [filename rangeOfString:@"-0.png"].location;
			if (NSNotFound != whereZeroPng)
			{
                d = [NSMutableDictionary dictionary];
                [d setObject:[NSNumber numberWithUnsignedInteger:PC_GRAPHICS] forKey:PCTypeKey];
                NSString *baseName = [filename substringToIndex:whereZeroPng];
                [d setObject:baseName forKey:PCThemeKey];	// Used internally not for display
                [d setObject:filename forKey:PCFilenameKey]; // used to fetch image, when needed
                [themes addObject:d];
			}
		}
				
		// Store the themes
		sThemes = [[NSArray alloc] initWithArray:themes];
	}
	
	return sThemes;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // write replaceable div
    NSDictionary *attrs = [NSDictionary dictionaryWithObject:@"text-align: center;" forKey:@"style"];
    NSString *divID = [context startElement:@"div"
                            preferredIdName:@"pc"
                                  className:@"page_counter"
                                 attributes:attrs];
    [context endElement]; // </div>
    
    // write appropriate scripts to endBody
    [context addMarkupToEndOfBody:@"<!-- pagecounter scripts -->\n"];

    // [[=%&parser.currentPage.URL]]
    NSURL *currentPageURL = [context baseURL];

    NSString *countScript = nil;
    if ( [context isForEditing] )
    {
        countScript = @"<script type=\"text/javascript\">var svxPageCount = \"1234\";</script>\n";
    }
    else 
    {
        countScript = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"http://service.karelia.com/ctr/count.js?u=%@\"></script>\n", currentPageURL];
    }
    [context addMarkupToEndOfBody:countScript];
    
    switch ( self.themeType ) 
    {
        case 0: // invisible
        {
            if ( [context isForEditing] )
            {
                [context writePlaceholderWithText:SVLocalizedString(@"Page Counter", "placeholder for invisible page counter") options:SVPlaceholderInvisible];
            }
            NSString *script = [NSString stringWithFormat:
                                @"<script type=\"text/javascript\">\n"
                                @"    var commentNode = document.createComment(svxPageCount);\n"
                                @"    document.getElementById(\"%@\").appendChild(commentNode);\n"
                                @"</script>\n",
                                divID];
            [context addMarkupToEndOfBody:script];
        }
            break;
            
        case 1: // text-only
        {
            NSString *script = [NSString stringWithFormat:
                                @"<script type=\"text/javascript\">\n"
                                @"    var paragraph = document.createElement(\"p\");\n"
                                @"    var text = document.createTextNode(svxPageCount);\n"
                                @"    paragraph.appendChild(text);\n"
                                @"    document.getElementById(\"%@\").appendChild(paragraph);\n"
                                @"</script>\n",
                                divID];
            [context addMarkupToEndOfBody:script];
        }
            break;
            
        case 2: // graphical
        {
            NSString *script = [NSString stringWithFormat:
                                @"<script type=\"text/javascript\">\n"
                                @"    var resourceDir = \"%@\";\n"                                  // resourcesURL
                                @"    var theme = \"%@\";\n"                                        // themeTitle
                                @"    var countRequest = false;\n"
                                @"    var pcWidth = \"%@\";\n"                                      // themeWidth
                                @"    var pcHeight = \"%@\";\n"                                     // themeHeight
                                @"\n"
                                @"    function showCount(countStr)\n"
                                @"    {\n"
                                @"        var pagelet = document.getElementById(\"%@\");\n"         // divID
                                @"        var i, c = countStr.length;\n"
                                @"        for (i = 0; i < c; i++)\n"
                                @"        {\n"
                                @"            var image = document.createElement(\"img\");\n"
                                @"            image.setAttribute(\"style\", \"padding:0px; margin:0px;\");\n"
                                @"            image.setAttribute(\"src\", resourceDir+\"/\"+theme+\"-\"+countStr.charAt(i)+\".png\");\n"
                                @"            image.setAttribute(\"width\", pcWidth);\n"
                                @"            image.setAttribute(\"height\", pcHeight);\n"
                                @"            image.setAttribute(\"alt\", "" + countStr.charAt(i));\n"
                                @"            pagelet.appendChild(image);\n"
                                @"        }\n"
                                @"    }\n"
                                @"    showCount(svxPageCount);\n"
                                @"</script>\n",
                                [[self resourcesURL:context] absoluteString], [self themeTitle], [self themeWidth], [self themeHeight], divID];
            [context addMarkupToEndOfBody:script];
        }
            break;
        default:
            break;
    }
    
    if ( ![context isForEditing] )
    {
        NSString *noscriptScript  = nil;
        if ( self.themeType > 0 )
        {
            noscriptScript = [NSString stringWithFormat:
                              @"<noscript>\n"
                              @"    <!-- tickle pagecounter by loading a small image -->\n"
                              @"    <p><img src=\"http://service.karelia.com/ctr/noscript.gif?u=%@\" alt=\"\" /></p>\n"
                              @"</noscript>\n",
                              currentPageURL];
        }
        else 
        {
            noscriptScript = [NSString stringWithFormat:
                              @"<noscript>\n"
                              @"    <!-- tickle pagecounter by loading a small image -->\n"
                              @"    <div><img src=\"http://service.karelia.com/ctr/1x1.gif?u=%@\" alt=\"\" height=\"1\" width=\"1\" /></div>\n"
                              @"</noscript>\n",
                              currentPageURL];
        }
        [context addMarkupToEndOfBody:noscriptScript];
    }
    
    [context addMarkupToEndOfBody:@"<!-- /pagecounter scripts -->\n"];

    // add dependencies
    [context addDependencyForKeyPath:@"selectedThemeIndex" ofObject:self];
}

- (NSURL *)resourcesURL:(id <SVPlugInContext>)context
{
    // add resources to context and return base _Resources URL
    NSURL *result = nil;
    
	if (PC_GRAPHICS == self.themeType)
	{
		NSString *theme = self.themeTitle;
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *imagePath = [self.selectedTheme objectForKey:PCImagesPathKey];	// from default
        
        NSURL *contextResourceURL = nil;
		for (NSUInteger i = 0; i < 10; i++)
		{
			NSString *format = [NSString stringWithFormat:@"%@-%d.png", theme, i];
			if (imagePath)
			{
                NSURL *imageURL = [NSURL fileURLWithPath:[imagePath stringByAppendingPathComponent:format]];
                contextResourceURL = [context addResourceWithURL:imageURL];
			}
			else
			{
				NSString *resource = [b pathForResource:[format stringByDeletingPathExtension]
                                                 ofType:[format pathExtension] 
                                            inDirectory:@"digits"];
                NSAssert((nil != resource), @"resource cannot be nil");
                NSURL *resourceURL = [NSURL fileURLWithPath:resource];
                contextResourceURL = [context addResourceWithURL:resourceURL];
			}
		}
        
        if ( contextResourceURL )
        {
            CFURLRef pathURL = CFURLCreateCopyDeletingLastPathComponent(
                                                                        kCFAllocatorDefault,
                                                                        (CFURLRef)contextResourceURL
                                                                        );
            result = [[(NSURL *)pathURL retain] autorelease];
            CFRelease(pathURL);
        }        
	}
    
    return result;
}


#pragma mark Properties

@synthesize selectedThemeIndex = _selectedThemeIndex;

- (NSArray *)themes
{
	return [[self class] themes];
}

- (NSDictionary *)selectedTheme
{
    NSUInteger index = self.selectedThemeIndex;
    if ( index >= self.themes.count ) index = 0; //FIXME: is this guard really necessary?
    return [self.themes objectAtIndex:index];
}

- (NSString *)themeTitle
{
	return [self.selectedTheme objectForKey:PCThemeKey];
}

- (id)themeWidth
{
	//return [self.selectedTheme objectForKey:PCWidthKey];
    NSDictionary *themeInfo = [self selectedTheme];
    NSString *filename = [themeInfo objectForKey:PCFilenameKey];
    return [[self class] widthOfSampleImageForFilename:filename];
}

- (id)themeHeight
{
	//return [self.selectedTheme objectForKey:PCHeightKey];
    NSDictionary *themeInfo = [self selectedTheme];
    NSString *filename = [themeInfo objectForKey:PCFilenameKey];
    return [[self class] heightOfSampleImageForFilename:filename];    
}

- (NSUInteger)themeType
{ 
	return [[self.selectedTheme objectForKey:PCTypeKey] unsignedIntegerValue];
}

@end
