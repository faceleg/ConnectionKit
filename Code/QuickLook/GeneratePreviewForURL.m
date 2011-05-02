
#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>

#import "KSPlugInWrapper.h"

#import "BDAlias+QuickLook.h"
#import "NSBundle+QuickLook.h"
#import "NSScanner+Karelia.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, 
							   CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options) 
{ 
    // Prepare the general environment
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; 

	NSString *docPath = [((NSURL *)url) path];
	NSString *mediaPath = [[docPath stringByAppendingPathComponent:@"Site"] stringByAppendingPathComponent:@"_Media"];
	
	NSString *previewPath = [[docPath stringByAppendingPathComponent:@"QuickLook"] stringByAppendingPathComponent:@"preview.html"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:previewPath])
	{
		[pool release];
        return noErr; 
	}
	
	NSString *sandvoxPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.karelia.Sandvox"];
	NSBundle *sandvoxBundle = [NSBundle bundleWithPath:sandvoxPath];
	[KSPlugInWrapper setApplicationBundle:sandvoxBundle];
    
    if (QLPreviewRequestIsCancelled(preview))	// Before proceeding make sure the user didn't cancel the request 
	{
		[pool release];
		return noErr; 
	}
	
	
	// Let's build some preview HTML!
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
			NSString *path = [alias fullPathRelativeToPath:nil mountVolumes:NO];
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
	if (QLPreviewRequestIsCancelled(preview))
	{
		[pool release];
		return noErr;
	}
	
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

