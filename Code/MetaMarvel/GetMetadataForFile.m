#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 

#import <Cocoa/Cocoa.h>

Boolean GetMetadataForFile(
						   void* thisInterface,
						   CFMutableDictionaryRef attributes,
						   CFStringRef contentTypeUTI, 
						   CFStringRef pathToFile
						   )
{
	// we're just going to return all of our file's Core Data metadata for this
	NSURL *URL = [NSURL fileURLWithPath:(NSString *)pathToFile];
	NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreWithURL:URL error:NULL];
	if ( nil != metadata )
	{
		[(NSMutableDictionary *)attributes addEntriesFromDictionary:metadata];
		return YES;
	}
	
	// default if we didn't make it
	return NO;
}
