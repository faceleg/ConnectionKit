
#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>
#import "KTUtilitiesForQuickLook.h"

#import "NSCharacterSet+QuickLook.h"
#import "NSString+QuickLook.h"


/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, 
							   CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options) 
{ 
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; 

	NSString *docPath = [((NSURL *)url) path];
	//NSString *sitePath = [docPath stringByAppendingPathComponent:@"Site"];
	
	NSString *previewPath = [[docPath stringByAppendingPathComponent:@"QuickLook"] stringByAppendingPathComponent:@"preview.html"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:previewPath])
	{
        return noErr; 
	}
    // Before proceeding make sure the user didn't cancel the request 
    if (QLPreviewRequestIsCancelled(preview)) 
	{
		return noErr; 
	}
	NSData *htmlData = [NSData dataWithContentsOfFile:previewPath];
	NSString *htmlString = [NSString stringWithHTMLData:htmlData];
	NSMutableString *buffer = [NSMutableString stringWithCapacity:[htmlString length]];
	
	/*
	NSString *basePathString = [NSString stringWithFormat:@"<head><base href=\"%@\" />", 
								[[NSURL fileURLWithPath:sitePath] absoluteString]];
	(void) [buffer replaceOccurrencesOfString:@"<head>" withString:basePathString options:NSCaseInsensitiveSearch range:NSMakeRange(0, [buffer length])];
	*/
	
	
	// Search for <!svxdata> pseudo-tags
	NSScanner *scanner = [[NSScanner alloc] initWithString:htmlString];
	NSString *aString;
	NSString *aURIScheme;	NSString *aURIPath;
	NSCharacterSet *tagEndCharactersSet = [NSCharacterSet svxDataPseudoTagEndCharacterSet];
	
	while (![scanner isAtEnd])
	{
		// Look for the tag
		[scanner scanUpToString:@"<!svxdata" intoString:&aString];
		[buffer appendString:aString];
		
		if ([scanner isAtEnd]) break;
		
		// Scan up to the URL information
		[scanner scanString:@"<!svxdata" intoString:NULL];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
		
		// Scan the URI info
		[scanner scanUpToString:@":" intoString:&aURIScheme];
		[scanner setScanLocation:([scanner scanLocation] + 1)];
		[scanner scanUpToCharactersFromSet:tagEndCharactersSet intoString:&aURIPath];
		
		// Process the URI
		if ([aURIScheme isEqualToString:@"design"])
		{
			NSArray *pathComponents = [aURIPath pathComponents];
			
			NSString *designIdentifier = [pathComponents objectAtIndex:0];
			NSBundle *designBundle = [NSBundle bundleWithIdentifier:designIdentifier];
			if (designBundle)
			{
				NSArray *subPathComponents = [pathComponents subarrayWithRange:NSMakeRange(1, [pathComponents count] - 1)];
				NSString *subPath = [NSString pathWithComponents:subPathComponents];
				
				NSString *path = [[designBundle bundlePath] stringByAppendingPathComponent:subPath];
				[buffer appendString:[NSURL fileURLWithPath:path]];
			}
		}
		
		// Make sure we're ready to go round the loop again
		[scanner scanUpToString:@">" intoString:NULL];
		[scanner scanString:@">" intoString:NULL];
	}
	
	[scanner release];
	
	
	/*
	// To show the substituted banner, we're going to have to write out the CSS to uplooad, and use that instead of the generic CSS.
	// We can probably still use the generic CSS resources, but we're not going to get 
	
	// Intercept CSS paths and try to find the right design
	// e.g. <link rel="stylesheet" type="text/css" href="sandvox_EarthandSky/main.css" title="Earth &amp; Sky" />
	NSRange whereStyle = [buffer rangeBetweenString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"" andString:@"/"];
	if (NSNotFound != whereStyle.location)
	{
		NSString *styleSheetCondensed = [buffer substringWithRange:whereStyle];
		NSLog(@"style sheet = '%@'", styleSheetCondensed);

		NSDictionary *designBundles = [KTUtilitiesForQuickLook pluginsWithExtension:@"svxDesign" sisterDirectory:@"Designs"];
		
		NSEnumerator *enumerator = [designBundles keyEnumerator];
		NSString *key;
		
		while ( key = [enumerator nextObject] )
		{
			NSBundle *designBundle = [designBundles objectForKey:key];
			NSString *bundleIdentifier = [designBundle bundleIdentifier];
			NSString *version = [designBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

			// convert into the format we would be seeing in the HTML

			NSMutableString *condensed = [NSMutableString stringWithString:[bundleIdentifier removeWhiteSpace]];
			if ((version != nil) 
				&& ![version isEqualToString:@""] 
				&& ![version isEqualToString:@"APP_VERSION"] 
				&& ([version floatVersion] > 1.0))
			{
				[condensed appendFormat:@".%@", version];
			}
			
			[condensed replaceOccurrencesOfString:@"." withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [condensed length])];

			if ([condensed isEqualToString:styleSheetCondensed])
			{
				[buffer replaceCharactersInRange:whereStyle withString:[designBundle bundlePath]];
				
				break;		// found it -- done
			}
		}
	}
	*/
	
	// Intercept remote images and ... replace with a gray image or something?
	buffer = (NSMutableString *) [buffer replaceAllTextBetweenString:@"src=\"http://" andString:@"\"" fromDictionary:[NSDictionary dictionary]];
	[buffer replaceOccurrencesOfString:@"src=\"http://" withString:@"src=\"cid:gray.gif" options:NSLiteralSearch range:NSMakeRange(0, [buffer length])];
	
	
	// Intercept media that doesn't exist, and find the real deals?
	
	
	// Put a sticky note on there for metadata
	NSString *stickyHTML =
	@"<div style='z-index:999; background:#fef49c; position: fixed; top:50px; right:50px; padding:10px; border:1px solid #CCC; -webkit-box-shadow: 5px 5px 5px rgba(0, 0, 0, 0.5); width:200px; height:100px;'>Published at <a href='http://www.karelia.com/'>http://www.karelia.com/</a>.<br />Pages: 34</div></body>";
	
	// I think what we need to do is to use dojo to create a sticky note.  I'll have to research that!
	
	
	[buffer replaceOccurrencesOfString:@"</body>" withString:stickyHTML options:NSLiteralSearch range:NSMakeRange(0, [buffer length])];
	
	// Intercept Resources.... FOR NOW EMPTY OUT
	// TO DO -- MAYBE FIGURE OUT BETTER WAY TO ACTUALLY FIND THE RESOURCES?
	buffer = (NSMutableString *) [buffer replaceAllTextBetweenString:@"src=\"_Resources/" andString:@"\"" fromDictionary:[NSDictionary dictionary]];
	[buffer replaceOccurrencesOfString:@"src=\"_Resources/" withString:@"src=\"cid:gray.gif" options:NSLiteralSearch range:NSMakeRange(0, [buffer length])];


	NSMutableDictionary *props=[[[NSMutableDictionary alloc] init] autorelease]; 
	[props setObject:@"UTF-8" forKey:(NSString 
									  *)kQLPreviewPropertyTextEncodingNameKey]; 
	[props setObject:@"text/html" forKey:(NSString 
										  *)kQLPreviewPropertyMIMETypeKey]; 

	// Set up a "gray.gif" placeholder 
	unsigned char gifBytes[35] = 
	{ 0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x90, 0x00, 0x00,
		0xbf, 0xbf, 0xbf,	// R G B
	0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x04, 0x01, 0x00, 0x3b };
	NSData *imageData = [NSData dataWithBytes:gifBytes length:35];
		
	NSMutableDictionary *imgProps=[[[NSMutableDictionary alloc] init] autorelease]; 
	[imgProps setObject:@"image/gif" forKey:(NSString *)kQLPreviewPropertyMIMETypeKey]; 
	[imgProps setObject:imageData forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey]; 
	[props setObject:[NSDictionary dictionaryWithObject:imgProps 
		forKey:@"gray.gif"] forKey:(NSString *)kQLPreviewPropertyAttachmentsKey]; 

	htmlData = [buffer dataUsingEncoding:NSUTF8StringEncoding];
	
	QLPreviewRequestSetDataRepresentation(preview,(CFDataRef)htmlData,kUTTypeHTML,(CFDictionaryRef)props); 

    [pool release]; 
    return noErr; 
} 

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}

