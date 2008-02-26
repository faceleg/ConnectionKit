
#import <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	OSStatus result = noErr;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *thumbnailPath = [[(NSURL *)url path] stringByAppendingPathComponent:@"QuickLook/thumbnail.png"];
	
	NSError *error = nil;
	NSData *thumbData = [[NSData alloc] initWithContentsOfFile:thumbnailPath options:NSUncachedRead error:&error];
	if (!thumbData) {
		NSLog(@"%@", error);
		return [error code];
	}
	
	NSDictionary *properties = [NSDictionary dictionaryWithObject:(NSString *)kUTTypePNG
														   forKey:(NSString *)kCGImageSourceTypeIdentifierHint];
														   
	QLThumbnailRequestSetImageWithData(thumbnail, (CFDataRef)thumbData, (CFDictionaryRef)properties);
	[thumbData release];
	
	[pool release];
	
    return result;
}