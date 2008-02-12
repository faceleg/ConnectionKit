
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

int main (int argc, const char * argv[])
{
	if (argc < 2)
	{
		printf("\nWhat's the path to the plugins?\n");
		return 1;
	}

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSMutableArray *dest = [NSMutableArray array];
	
	NSString *destFolder = [@"~/Desktop/CollectedPlugins" stringByExpandingTildeInPath];
	NSError *error;
	if (![[NSFileManager defaultManager] fileExistsAtPath:destFolder])
	{
		if (![[NSFileManager defaultManager] createDirectoryAtPath:destFolder withIntermediateDirectories:YES attributes:nil error:&error])
		{
			NSLog(@"couldn't create output directory: %@", [error localizedDescription]);
			return 2;
		}
	}
	
//	// Merge this into existing.
//	NSString *infoPlistPath = [destFolder stringByAppendingPathComponent:@"Info.plist"];
//	if ([[NSFileManager defaultManager] fileExistsAtPath:infoPlistPath])
//	{
//		NSArray *plist = [NSArray arrayWithContentsOfFile:infoPlistPath];
//		[dest addObjectsFromArray:plist];
//	}
	
	const char *pluginPath = argv[1];
	NSString *basePath = [NSString stringWithUTF8String:pluginPath];
	
//	NSLog(@"the basePath = %@", basePath);
	
	NSArray *contents = [[NSFileManager defaultManager] directoryContentsAtPath:basePath];
	NSEnumerator *enumerator = [contents objectEnumerator];
	NSString *fileName;
	
	while ((fileName = [enumerator nextObject]) != nil)
	{
		NSString *sourcePath = [basePath stringByAppendingPathComponent:fileName];
		if ([fileName hasPrefix:@"."])
		{
			continue;
		}
		
		
//		NSLog(@"%@", sourcePath);
		NSBundle *theBundle = [NSBundle bundleWithPath:sourcePath];
		
		NSDictionary * info = [theBundle infoDictionary];
		if (nil != info)
		{
			if ([info objectForKey:@"CFBundleIdentifier"])		// must be a real bundle with an identifier
			{
				NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
				NSDictionary *translatingKeys = [NSDictionary dictionaryWithObjectsAndKeys:
												 @"CFBundleIdentifier", @"CFBundleIdentifier",
												 @"CFBundleVersion", @"CFBundleVersion",
												 @"MinimumAppVersion", @"KTMinimumAppVersion",
												 @"title", @"title",		// design name
												 nil];
				NSEnumerator *keyEnum = [translatingKeys objectEnumerator];
				NSString *theKey;
				
				while ((theKey = [keyEnum nextObject]) != nil)
				{
					NSString *theDestKey = [translatingKeys objectForKey:theKey];
					NSString *value = [info objectForKey:theKey];
					if (value)
					{
						[newDict setObject:value forKey:theDestKey];
					}
				}
				
				// Get localized (English) name
				NSString *localizedName = [theBundle objectForInfoDictionaryKey:@"KTPluginName"];
				if (localizedName)
				{
					[newDict setObject:localizedName forKey:@"title"];
				}
				if (nil == [newDict objectForKey:@"title"])
				{
					[newDict setObject:[info objectForKey:@"CFBundleIdentifier"] forKey:@"title"];	// fallback
				}
				
				NSMutableString *identifierAsFileName = [NSMutableString stringWithString:[info objectForKey:@"CFBundleIdentifier"]];
				[identifierAsFileName replaceOccurrencesOfString:@" "
													  withString:@"_"
														 options:0
														   range:NSMakeRange(0, [identifierAsFileName length])];
				[identifierAsFileName replaceOccurrencesOfString:@"."
													  withString:@"_"
														 options:0
														   range:NSMakeRange(0, [identifierAsFileName length])];
				
				
				// Try to get plugin icon from info.plist
				NSString *path = nil;
				NSString *iconName = [info objectForKey:@"KTPluginIconName"];
				if (nil != iconName)
				{
					path = [theBundle pathForImageResource:iconName];
				}
				if (nil == path)
				{
					path = [theBundle pathForImageResource:@"thumbnail"];	// design usual name
				}
			
				if (nil != path)
				{
					NSString *imageFileName = [identifierAsFileName stringByAppendingPathExtension:[path pathExtension]];
					NSString *destPath = [destFolder stringByAppendingPathComponent:imageFileName];
				
					if (![[NSFileManager defaultManager] copyItemAtPath:path toPath:destPath error:&error])
					{
						NSLog(@"error copying plugin icon: %@ - %@", iconName, [error localizedDescription]);
					}
					else
					{
						[newDict setObject:imageFileName forKey:@"IconFile"];	// put a reference into my plist
					}
				}
				
				
				// Now compress the file and put it in the destination
				NSString *compressedFileName = [identifierAsFileName stringByAppendingPathExtension:@"tbz"];
				NSString *systemString = [NSString stringWithFormat:@"cd '%@'; tar -cf - '%@' | bzip2 > %@/%@", basePath, fileName, destFolder, compressedFileName];
				NSLog(@"%@", systemString);
				system([systemString UTF8String]);
				[newDict setObject:compressedFileName forKey:@"BundleFile"];	// put a reference into my plist
				
				
				// DONE MANIPULATING DICTIONARY
				[dest addObject:newDict];

			}
		}
	}
	
	NSData *xmlData;
	NSString *errorString;
	
	xmlData = [NSPropertyListSerialization dataFromPropertyList:dest
														 format:NSPropertyListXMLFormat_v1_0
											   errorDescription:&errorString];
	if(xmlData)
	{
		NSString *xmlDataPath = [destFolder stringByAppendingPathComponent:@"Info.plist"];
		[xmlData writeToFile:xmlDataPath atomically:NO];
	}
	else
	{
		NSLog(@"ERROR: %@", errorString);
		[errorString release];
	}
	
	
	
	
	[pool release];
	return 0;
}
