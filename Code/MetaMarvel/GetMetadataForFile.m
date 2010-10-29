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
	// we need to compute the path to the datastore inside the document
	// this computation mirrors [KTDocument datastoreURLforDocumentURL:] and assumes NSSQLiteStoreType
	NSString *datastorePath = [NSString stringWithString:(NSString *)pathToFile];
	datastorePath = [datastorePath stringByAppendingPathComponent:@"datastore"];
	datastorePath = [datastorePath stringByAppendingPathExtension:@"sqlite3"];
	
	NSURL *datastoreURL = [NSURL fileURLWithPath:datastorePath];
    	
	// we're just going to return all of our document's Core Data metadata
    NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:nil URL:datastoreURL error:NULL];
	if ( nil != metadata )
	{
		[(NSMutableDictionary *)attributes addEntriesFromDictionary:metadata];
		return YES;
	}
	
	// default if we didn't make it
	return NO;
}

