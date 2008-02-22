
#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>
#import "KTUtilitiesForQuickLook.h"

#import "BDAlias+QuickLook.h"
#import "NSBundle+QuickLook.h"
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
	NSString *mediaPath = [[docPath stringByAppendingPathComponent:@"Site"] stringByAppendingPathComponent:@"_Media"];
	
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
	NSString *htmlString = [NSString stringWithContentsOfFile:previewPath encoding:NSUTF8StringEncoding error:NULL];
	NSMutableString *buffer = [NSMutableString stringWithCapacity:[htmlString length]];
	
	
	// Search for <!svxdata> pseudo-tags
	NSScanner *scanner = [[NSScanner alloc] initWithString:htmlString];
	NSString *aString;
	NSString *aURIScheme;	NSString *aURIPath;
	
	while (![scanner isAtEnd] && !(QLPreviewRequestIsCancelled(preview)))
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
		
		[scanner scanUpToString:@">" intoString:&aURIPath];
		aURIPath = [aURIPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		
		// Process the URI
		if ([aURIScheme isEqualToString:@"bundle"])
		{
			NSArray *pathComponents = [aURIPath pathComponents];
			
			NSString *bundleIdentifier = [pathComponents objectAtIndex:0];
			NSBundle *bundle = [NSBundle quickLookBundleWithIdentifier:bundleIdentifier];
			if (bundle)
			{
				NSArray *subPathComponents = [pathComponents subarrayWithRange:NSMakeRange(1, [pathComponents count] - 1)];
				NSString *subPath = [NSString pathWithComponents:subPathComponents];
				
				NSString *path = [[bundle bundlePath] stringByAppendingPathComponent:subPath];
				[buffer appendString:[[NSURL fileURLWithPath:path] absoluteString]];
			}
		}
		else if ([aURIScheme isEqualToString:@"alias"])
		{
			BDAlias *alias = [BDAlias aliasWithQuickLookPseudoTagPath:aURIPath];
			NSString *path = [alias fullPath];
			if (path)
			{
				[buffer appendString:[[NSURL fileURLWithPath:path] absoluteString]];
			}
			else
			{
				[buffer appendString:@"cid:gray.gif"];
			}
		}
		else if ([aURIScheme isEqualToString:@"indocumentmedia"])
		{
			NSString *path = [mediaPath stringByAppendingPathComponent:aURIPath];
			[buffer appendString:[[NSURL fileURLWithPath:path] absoluteString]];
		}
		
		
		// Make sure we're ready to go round the loop again
		[scanner scanString:@">" intoString:NULL];
	}
	
	[scanner release];	// Tidy up after scanning
	if (QLPreviewRequestIsCancelled(preview)) return noErr;
	
	
	
	
	
	// Put a sticky note on there for metadata
	NSString *stickyHTML =
	@"<div style='z-index:999; background:#fef49c; position: fixed; top:50px; right:50px; padding:10px; border:1px solid #CCC; -webkit-box-shadow: 5px 5px 5px rgba(0, 0, 0, 0.5); width:200px; height:100px;'>Published at <a href='http://www.karelia.com/'>http://www.karelia.com/</a>.<br />Pages: 34</div></body>";
	
	// I think what we need to do is to use dojo to create a sticky note.  I'll have to research that!
	
	
	[buffer replaceOccurrencesOfString:@"</body>" withString:stickyHTML options:NSLiteralSearch range:NSMakeRange(0, [buffer length])];
	
	
	
	
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

	NSData *htmlData = [buffer dataUsingEncoding:NSUTF8StringEncoding];
	
	QLPreviewRequestSetDataRepresentation(preview,(CFDataRef)htmlData,kUTTypeHTML,(CFDictionaryRef)props); 

    [pool release]; 
    return noErr; 
} 

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}

